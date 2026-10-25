import SwiftUI
import Foundation
#if SWIFT_PACKAGE
import CaptureCore
#endif
import VisionCore

enum CaptureScreen: Equatable { case start, guided, replay, results }

struct PresentationRecommendation: Equatable {
    let id: String
    let nextMove: String
    let rationale: String
    let confidence: Double
    let caveats: [String]
    let basedOn: [String]
    let escalation: String
}

struct PresentationRegion: Identifiable, Equatable {
    let id: String
    let state: String
    let quality: String
    let note: String
    let issueCount: Int
}
struct PresentationFinding: Identifiable, Equatable {
    let id: String; let region: String; let description: String; let evidence: String; let confidence: Double
}

@MainActor
final class CapturePresentationModel: ObservableObject {
    @Published private(set) var screen: CaptureScreen = .start
    @Published private(set) var progress = CaptureProgress()
    @Published private(set) var findingSummary = "No visible findings emitted by Vision."
    @Published private(set) var findingDescription: String?
    @Published private(set) var findingEvidenceLabel: String?
    @Published private(set) var findingRecommendedCheck: String?
    @Published private(set) var recommendation: PresentationRecommendation?
    @Published private(set) var replayStatus = "Synthetic replay is available if camera capture is unavailable."
    @Published private(set) var humanActionStatus: String?
    @Published private(set) var visionRegions: [PresentationRegion] = []
    @Published private(set) var visionUnknownRegions: [String] = []
    @Published private(set) var visionAnalysis = ""
    @Published private(set) var visionFindings: [PresentationFinding] = []
    @Published private(set) var errorMessage: String?
    @Published private(set) var nextGuideStep: CaptureGuideStep?
    @Published private(set) var captureStatus = "Ready for the first view."
    @Published private(set) var isPaused = false
    private var attempts: [CaptureRegion: Int] = [:]

    var coveredCount: Int { progress.coverage.values.filter { $0 == .covered }.count }
    var uncertainRegions: [CaptureRegion] { CaptureRegion.allCases.filter { progress[$0] != .covered } }

    func startScan() {
        screen = .guided; progress = CaptureProgress(); attempts = [:]; isPaused = false; updateGuide()
        captureStatus = "Synthetic capture is enabled for this prototype."
    }

    func captureSample() {
        guard !isPaused else { captureStatus = "Paused. Resume when you are stationary."; return }
        guard let step = nextGuideStep else { captureStatus = "All guided regions are covered."; return }
        let attempt = attempts[step.region, default: 0]; attempts[step.region] = attempt + 1
        let quality: CaptureQuality = (attempt == 0 && (step.region == .frontLeft || step.region == .rearLeft)) ? .init(blur: 0.35, lighting: 0.75, motion: 0.45) : .good
        switch progress.ingest(.init(frameID: "guided-\(step.region.rawValue)-\(attempt + 1)", timestampSeconds: Double(attempts.count), region: step.region, quality: quality)) {
        case .needsRetake(_, let prompts): captureStatus = "Retake this view: " + prompts.map(\.rawValue).joined(separator: ", ") + "."
        default: captureStatus = "Captured \(step.title)."; updateGuide()
        }
    }

    func togglePause() { isPaused.toggle(); captureStatus = isPaused ? "Paused. Stay still before moving." : "Resumed. Follow the prompt before moving." }
    func skipCurrent() { guard let step = nextGuideStep else { return }; progress.markBlocked(step.region); captureStatus = "Skipped \(step.title); marked blocked. You can revisit it later."; updateGuide() }
    func retakeCurrent() { captureStatus = "Retake ready. Reframe \(nextGuideStep?.title ?? "this view") and capture again." }
    func lowerPhone() { captureStatus = "Lower the phone before walking or opening a door." }

    private func updateGuide() { nextGuideStep = CaptureGuide.nextUncovered(in: progress) }
    func showReplay() { screen = .replay }

    func runReplay() {
        do {
            progress = CaptureReplay.run()
            let handoff = try CaptureReplay.visionHandoff()
            let unknown = Set(handoff.unknownRegions)
            let partial = Set(handoff.qualityLimitedRegions)
            var visionFrames: [VisionCore.ReplayFrame] = []
            for sample in CaptureReplay.fixedSequence {
                guard let region = VisionCore.RegionID(rawValue: sample.region.rawValue) else { continue }
                let quality: VisionCore.Quality = sample.quality.isAcceptable ? .high : .low
                visionFrames.append(try VisionCore.ReplayFrame(id: sample.frameID, artifactRef: "ios/replay/\(sample.frameID).json", regions: [region], quality: quality, glareLimited: !sample.quality.isAcceptable, motionBlur: sample.quality.motion < CaptureQuality.acceptanceThreshold))
            }
            // The observation is synthetic and joins an artifact checked into the replay fixture.
            visionFrames.append(try VisionCore.ReplayFrame(id: "visible-panel-observation", artifactRef: "ios/replay/frame-005.json", regions: [.rear], quality: .high, visibleObservation: "Visible surface mark on the rear panel"))
            let visionOutput = try VisionCore.SyntheticReplay.run(frames: visionFrames, startedAt: Date(timeIntervalSince1970: 1_792_771_200))
            visionRegions = visionOutput.presentation.regions.map { PresentationRegion(id: $0.regionId.rawValue, state: $0.state.rawValue, quality: $0.quality.rawValue, note: $0.accessibilityText, issueCount: $0.findings.count) }
            visionUnknownRegions = visionOutput.presentation.unknownRegions.map(\.rawValue)
            visionAnalysis = visionOutput.presentation.analysis
            visionFindings = visionOutput.findings.map { PresentationFinding(id: $0.id, region: $0.regionId.rawValue, description: $0.description, evidence: $0.evidenceRefs.joined(separator: ", "), confidence: $0.confidence) }
            let visionOutputFindingsIDs = visionOutput.findings.map(\.id)
            if let finding = visionOutput.findings.first {
                findingSummary = "Visible finding in \(finding.regionId.rawValue)"
                findingDescription = "\(finding.description) (confidence \(String(format: "%.2f", finding.confidence)), status \(finding.status.rawValue))"
                findingEvidenceLabel = "Demo · synthetic image · \(finding.evidenceRefs.joined(separator: ", "))"
                findingRecommendedCheck = "\(finding.recommendedCheck ?? "Review this visible area") · region \(finding.regionId.rawValue)"
            } else {
                findingSummary = "No visible findings emitted by Vision."
                findingDescription = nil
                findingEvidenceLabel = nil
                findingRecommendedCheck = nil
            }
            let hasUncertainty = !unknown.isEmpty || !partial.isEmpty
            recommendation = PresentationRecommendation(
            id: "recommendation-replay-review",
            nextMove: hasUncertainty ? "request_more_views" : "review_with_customer",
            rationale: hasUncertainty ? "Partial or unseen regions remain, and the visible evidence needs another view before review." : "The visible map and finding are ready for a customer review.",
            confidence: hasUncertainty ? 0.42 : 0.9,
            caveats: ["Exterior imagery cannot assess hidden mechanical condition."],
                basedOn: visionOutputFindingsIDs,
                escalation: hasUncertainty ? "more_evidence" : "human_review"
            )
            errorMessage = nil
            replayStatus = "Demo · synthetic replay completed. Camera capture was not used."
        } catch {
            recommendation = nil
            errorMessage = "Replay could not be analyzed. Try the synthetic replay again."
            replayStatus = "Replay unavailable; no result was produced."
        }
        screen = .results
    }

    func requestHumanReview() {
        humanActionStatus = "Human review requested for this synthetic replay."
    }
}
