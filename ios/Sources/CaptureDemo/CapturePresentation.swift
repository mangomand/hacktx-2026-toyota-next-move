import SwiftUI
import Foundation
#if canImport(AVFoundation)
import AVFoundation
#endif
#if canImport(ARKit) && canImport(UIKit)
import ARKit
import UIKit
#endif
#if canImport(CoreImage) && canImport(CoreVideo)
import CoreImage
import ImageIO
#endif

#if canImport(AVFoundation)
final class CameraFrameProbe: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    var onFrame: ((CMSampleBuffer) -> Void)?
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) { onFrame?(sampleBuffer) }
}
#endif
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
    /// A single stable user-facing message. Internal capture/network status can
    /// change for every sampled frame, but the scan surface should only change
    /// copy when the user has a meaningful next action.
    @Published private(set) var scanMessage = "Point the camera at the vehicle."
    @Published private(set) var cameraAvailable = false
    @Published private(set) var usingReplaySource = false
    @Published private(set) var evidenceProvenance = "Synthetic replay"
    @Published private(set) var arPoseAvailable = false
    @Published private(set) var sensingMode: CaptureSensingMode = .replay
    @Published private(set) var analyzedFrameCount = 0
    @Published private(set) var vehicleMatchStatus = "Looking for the vehicle…"
#if canImport(AVFoundation)
    private var captureSession: AVCaptureSession?
    var activeCaptureSession: AVCaptureSession? { captureSession }
    private let frameProbe = CameraFrameProbe()
    private var previousPixelFrame: VisionPixelFrame?
#endif
    private var observationAccumulator = VehicleObservationAccumulator()
    private var perceptionTask: Task<Void, Never>?
    private var sessionGeneration = UUID()
    private var lastSampleTime: TimeInterval = -.infinity
    private var observationEvidence: [CaptureRegion: [String]] = [:]
    private var previousEvidence: (regions: Set<CaptureRegion>, path: String)?
    @Published private(set) var semanticObservationCount = 0
    @Published private(set) var isPaused = false
    private var attempts: [CaptureRegion: Int] = [:]

    var coveredCount: Int { progress.coverage.values.filter { $0 == .covered }.count }
    var uncertainRegions: [CaptureRegion] { CaptureRegion.allCases.filter { progress[$0] != .covered } }

    private func invalidatePerception() {
        sessionGeneration = UUID()
        perceptionTask?.cancel()
        perceptionTask = nil
        observationAccumulator.breakContinuity()
        previousEvidence = nil
    }

    private func setScanMessage(_ message: String) {
        guard scanMessage != message else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            scanMessage = message
        }
    }

    func cancelScan() {
        invalidatePerception()
#if canImport(AVFoundation)
        captureSession?.stopRunning()
        captureSession = nil
#endif
        screen = .start
        cameraAvailable = false
        usingReplaySource = false
        sensingMode = .replay
        captureStatus = "Ready for the first view."
        scanMessage = "Point the camera at the vehicle."
    }

    func startScan() {
        invalidatePerception()
        observationAccumulator = VehicleObservationAccumulator()
        observationEvidence = [:]
        lastSampleTime = -.infinity
        semanticObservationCount = 0
        screen = .guided; progress = CaptureProgress(); attempts = [:]; isPaused = false; analyzedFrameCount = 0; vehicleMatchStatus = "Looking for the vehicle…"; updateGuide()
#if canImport(ARKit) && canImport(UIKit)
        arPoseAvailable = ARWorldTrackingConfiguration.isSupported
#else
        arPoseAvailable = false
#endif
#if canImport(AVFoundation)
        cameraAvailable = false
        let cameraDeviceAvailable = AVCaptureDevice.default(for: .video) != nil
        if cameraDeviceAvailable {
            let status = AVCaptureDevice.authorizationStatus(for: .video)
            if status == .authorized { configureAuthorizedCamera() }
            else if status == .notDetermined {
                Task { @MainActor [weak self] in
                    let granted = await AVCaptureDevice.requestAccess(for: .video)
                    guard let self else { return }
                    if granted { self.configureAuthorizedCamera() }
                    else { self.cameraAvailable = false; self.usingReplaySource = true; self.captureStatus = "Camera access was denied; use the Toyota video replay fallback." }
                }
            } else { cameraAvailable = false; usingReplaySource = true; captureStatus = "Camera access is unavailable; use the Toyota video replay fallback." }
        }
#else
        cameraAvailable = false
#endif
        sensingMode = cameraAvailable ? .cameraGuided : .replay
        usingReplaySource = !cameraAvailable
        evidenceProvenance = cameraAvailable ? "Live camera" : "Synthetic replay"
        captureStatus = cameraAvailable ? "Camera ready. Move through the prompted view; live frames are analyzed automatically." : "Camera unavailable; use the synthetic video replay fallback."
        setScanMessage(cameraAvailable ? "Point the camera at the vehicle." : "Camera unavailable. Use video replay.")
    }

#if canImport(AVFoundation)
    private func configureAuthorizedCamera() {
#if canImport(ARKit) && canImport(UIKit)
        // ARSCNView owns the camera on AR-capable devices. Its ARFrame.capturedImage
        // callback feeds the same analyzer, avoiding two camera producers competing
        // for the device and leaving progress stuck at zero.
        if arPoseAvailable {
            cameraAvailable = true
            usingReplaySource = false
            sensingMode = .cameraGuided
            evidenceProvenance = "Live camera"
        captureStatus = "Camera ready. Move through the prompted view; live analysis is active."
            setScanMessage("Point the camera at the vehicle.")
            return
        }
#endif
        frameProbe.onFrame = { [weak self] sampleBuffer in
            guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
            Task { @MainActor [weak self] in self?.consumeCameraFrame(pixelBuffer: buffer, timestamp: timestamp) }
        }
        let session = AVCaptureSession(); session.beginConfiguration()
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration()
            cameraAvailable = false
            usingReplaySource = true
            captureStatus = "Camera setup failed; use the Toyota video replay fallback."
            return
        }
        session.addInput(input)
        let output = AVCaptureVideoDataOutput()
        guard session.canAddOutput(output) else {
            session.commitConfiguration()
            cameraAvailable = false
            usingReplaySource = true
            captureStatus = "Camera output is unavailable; use the Toyota video replay fallback."
            return
        }
        session.addOutput(output)
        output.setSampleBufferDelegate(frameProbe, queue: DispatchQueue(label: "capture.frames"))
        session.commitConfiguration()
        captureSession = session
        session.startRunning()
        cameraAvailable = true
        usingReplaySource = false
        sensingMode = .cameraGuided
        evidenceProvenance = "Live camera"
        captureStatus = "Camera ready. Move through the prompted view; live analysis is active."
        setScanMessage("Point the camera at the vehicle.")
    }
#endif

#if canImport(ARKit) && canImport(UIKit)
    func consumeARFrame(pixelBuffer: CVPixelBuffer, timestamp: TimeInterval) {
        consumeCameraFrame(pixelBuffer: pixelBuffer, timestamp: timestamp)
    }

    func handleARSessionInterruption() {
        // Keep the AR view mounted so ARSession can deliver
        // sessionInterruptionEnded and resume in place.
        cameraAvailable = true
        captureStatus = "Camera paused. Keep the vehicle in view while the scan resumes."
        setScanMessage("Camera paused. Resume when ready.")
    }

    func handleARSessionInterruptionEnded() {
        cameraAvailable = true
        usingReplaySource = false
        sensingMode = .cameraGuided
        evidenceProvenance = "Live camera"
        captureStatus = "Camera resumed. Move through the prompted view; live analysis is active."
        setScanMessage("Point the camera at the vehicle.")
    }

    func handleARSessionFailure() {
        cameraAvailable = false
        usingReplaySource = true
        sensingMode = .replay
        captureStatus = "Camera unavailable after an AR session error; use the Toyota video replay fallback."
        setScanMessage("Camera unavailable. Use video replay.")
    }
#endif

#if canImport(CoreImage) && canImport(CoreVideo)
    private func consumeCameraFrame(pixelBuffer: CVPixelBuffer, timestamp: TimeInterval) {
        guard screen == .guided, !isPaused, perceptionTask == nil,
              timestamp.isFinite, timestamp - lastSampleTime >= 2 else { return }
        lastSampleTime = timestamp
        guard let configuration = PerceptionConfiguration.load() else {
            captureStatus = "Live perception needs a configured analysis server. No coverage has been inferred."
            vehicleMatchStatus = "Analysis server not connected"
            setScanMessage("Live analysis is unavailable. Check the connection.")
            return
        }
        let generation = sessionGeneration
        let frameID = UUID().uuidString
        let buffer = CameraPixelBuffer(value: pixelBuffer)
        captureStatus = "Analyzing this vehicle view…"
        // Keep the last actionable instruction visible while a request is in
        // flight. Replacing it with a transient "checking" label on every
        // sample made the card flicker and taught the user nothing new.
        perceptionTask = Task { [weak self] in
            do {
                let jpeg = try await Task.detached(priority: .utility) { try CameraJPEG.encode(buffer) }.value
                guard !Task.isCancelled else { return }
                let observation = try await PerceptionHTTPClient.observe(jpeg: jpeg, frameID: frameID, configuration: configuration)
                guard let self, !Task.isCancelled, self.sessionGeneration == generation,
                      self.screen == .guided, !self.isPaused else { return }
                self.analyzedFrameCount += 1
                self.semanticObservationCount += 1
                self.applyObservation(observation, jpeg: jpeg)
                self.perceptionTask = nil
            } catch {
                guard let self, self.sessionGeneration == generation, !Task.isCancelled else { return }
                self.observationAccumulator.breakContinuity()
                self.previousEvidence = nil
                self.captureStatus = "Analysis could not complete. Hold the view while we retry."
                self.vehicleMatchStatus = "No new coverage recorded"
                self.setScanMessage("Hold steady while we retry.")
                self.perceptionTask = nil
            }
        }
    }
#endif

    private func applyObservation(_ observation: VehicleObservation, jpeg: Data) {
        guard observation.isValid else { return }
        let newRegions = observationAccumulator.ingest(observation)
        let candidates = Set(observation.regions.filter { $0.confidence >= 0.7 }.map(\.id))
        vehicleMatchStatus = observation.vehiclePresent ? "Vehicle visible" : "Point the camera at the vehicle"
        do {
            let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("ScanEvidence/\(sessionGeneration.uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let file = directory.appendingPathComponent("\(observation.frameID).jpg")
            if observation.vehiclePresent && observation.usability != .unusable && !candidates.isEmpty {
                try jpeg.write(to: file, options: .atomic)
                for region in newRegions {
                    guard let previousEvidence, previousEvidence.regions.contains(region) else { continue }
                    observationEvidence[region] = [previousEvidence.path, file.path]
                    progress.recordModelObserved(region)
                }
                previousEvidence = (candidates, file.path)
            } else { previousEvidence = nil }
        } catch {
            observationAccumulator = VehicleObservationAccumulator()
            previousEvidence = nil
            captureStatus = "Could not save frame evidence; this view was not recorded."
            setScanMessage("This view was not saved. Hold steady and retry.")
            return
        }
        let generatedGuidance = VehicleGuidance.actionable(from: observation)
        if !newRegions.isEmpty {
            updateGuide()
            let names = newRegions.map { CaptureGuide.step(for: $0).title }.sorted().joined(separator: ", ")
            captureStatus = "Recorded \(names). \(nextGuideStep?.instruction ?? "All requested areas have observations.")"
            setScanMessage(generatedGuidance ?? (nextGuideStep.map { "\($0.title): \($0.instruction)" } ?? "Scan complete. You can finish."))
        } else if observation.usability != .unusable && !candidates.isEmpty && candidates.allSatisfy({ progress[$0] == .covered }) {
            captureStatus = nextGuideStep?.instruction ?? "All required areas have observations. You can finish the scan."
            setScanMessage(generatedGuidance ?? (nextGuideStep.map { "\($0.title): \($0.instruction)" } ?? "Scan complete. You can finish."))
        } else if !candidates.isEmpty && observation.usability != .unusable {
            captureStatus = "\(observation.guidance) Hold this view briefly to confirm it."
            setScanMessage(generatedGuidance ?? "Hold steady to confirm this view.")
        } else if !observation.vehiclePresent {
            setScanMessage("Move closer and keep the vehicle in view.")
        } else if observation.usability == .limited {
            setScanMessage(generatedGuidance ?? "Move to better light and hold steady.")
        } else { captureStatus = observation.guidance }
        if observation.usability == .unusable {
            setScanMessage("Move to better light and hold steady.")
        }
    }

    func useReplayFallback() { usingReplaySource = true; captureStatus = "Video replay fallback active; no camera evidence is claimed."; setScanMessage("Video replay active.") }

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

    func togglePause() {
        invalidatePerception()
        isPaused.toggle()
        captureStatus = isPaused ? "Paused. Stay still before moving." : "Resumed. Follow the prompt before moving."
        setScanMessage(isPaused ? "Paused. Resume when you are stationary." : "Point the camera at the vehicle.")
    }
    func skipCurrent() { guard let step = nextGuideStep else { return }; progress.markBlocked(step.region); captureStatus = "Skipped \(step.title); marked blocked. You can revisit it later."; updateGuide() }
    func retakeCurrent() { captureStatus = "Retake ready. Reframe \(nextGuideStep?.title ?? "this view") and capture again." }
    func lowerPhone() { captureStatus = "Lower the phone before walking or opening a door." }

    private func updateGuide() { nextGuideStep = CaptureGuide.nextDynamic(in: progress, attempts: attempts) }
    /// Finishes the current session without replacing live evidence with the
    /// deterministic replay fixture. The replay screen is reserved for an
    /// explicit synthetic fallback request.
    func finishScan() {
        invalidatePerception()
        #if canImport(AVFoundation)
        captureSession?.stopRunning()
        captureSession = nil
        #endif
        if usingReplaySource {
            screen = .replay
        } else {
            buildLiveResults()
        }
    }

    func showReplay() { screen = .replay }

    private func buildLiveResults() {
        visionRegions = CaptureRegion.allCases.map { region in
            let state: String
            switch progress[region] {
            case .covered: state = "covered"
            case .partial: state = "partial"
            case .unseen: state = "unseen"
            case .blocked: state = "blocked"
            }
            return PresentationRegion(
                id: region.rawValue,
                state: state,
                quality: state == "covered" ? "acceptable" : "limited",
                note: state == "covered" ? "Vehicle region identified in two sampled frames." : "More live evidence is needed for this area.",
                issueCount: 0
            )
        }
        visionUnknownRegions = CaptureRegion.allCases.filter { progress[$0] != .covered }.map(\.rawValue)
        visionFindings = []
        findingSummary = "No semantic vehicle finding was emitted from the live camera session."
        findingDescription = nil
        findingEvidenceLabel = "Live camera evidence · model-observed regions"
        findingRecommendedCheck = nil
        visionAnalysis = "Live camera session analyzed \(analyzedFrameCount) frames. Coverage reflects repeated model-observed regions, not the requested prompt. Orientation estimates remain uncertain; no damage detection is enabled."
        let hasUncertainty = !visionUnknownRegions.isEmpty
        recommendation = PresentationRecommendation(
            id: "recommendation-live-capture",
            nextMove: hasUncertainty ? "request_more_views" : "review_with_customer",
            rationale: hasUncertainty ? "Some areas remain unseen or quality-limited, so another live view is needed." : "All required regions have repeated model observations; review the evidence with a person.",
            confidence: hasUncertainty ? 0.2 : 0.5,
            caveats: ["Model-based region recognition can be wrong; exterior images do not diagnose mechanical condition."],
            basedOn: [],
            escalation: hasUncertainty ? "more_evidence" : "human_review"
        )
        replayStatus = "Live camera session finished; no synthetic replay data was substituted."
        errorMessage = nil
        screen = .results
    }

    func runReplay() {
        if usingReplaySource {
            runToyotaVideoFallback()
            return
        }
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
            evidenceProvenance = "Synthetic replay"
            replayStatus = "Demo · synthetic replay completed. Camera capture was not used."
        } catch {
            recommendation = nil
            errorMessage = "Replay could not be analyzed. Try the synthetic replay again."
            replayStatus = "Replay unavailable; no result was produced."
        }
        screen = .results
    }

    private func runToyotaVideoFallback() {
        do {
            let frames = try ToyotaVideoCapture.sample(configuration: .init(intervalSeconds: 1))
            progress = CaptureProgress()
            visionRegions = []
            visionUnknownRegions = CaptureRegion.allCases.map(\.rawValue)
            visionFindings = []
            visionAnalysis = "Toyota video replay decoded \(frames.count) pixel frames. The close side/rear clip is quality-only; region classification is unavailable."
            findingSummary = "No visible findings emitted from the quality-only video."
            findingDescription = nil; findingEvidenceLabel = "Demo · Toyota MOV pixel replay · glare/motion limited"
            findingRecommendedCheck = nil
            recommendation = PresentationRecommendation(id: "recommendation-video-quality-only", nextMove: "request_more_views", rationale: "The replay supplies glare- and motion-limited side/rear pixels without reliable canonical region classification.", confidence: 0.2, caveats: ["Unsupported regions remain unseen.", "Exterior imagery cannot assess hidden mechanical condition."], basedOn: [], escalation: "more_evidence")
            replayStatus = "Toyota MOV pixel replay completed: \(frames.count) decoded frames; no region claims made."
            errorMessage = nil
        } catch {
            errorMessage = "Toyota video replay could not be decoded."
            replayStatus = "Video fallback unavailable; no evidence was produced."
        }
        screen = .results
    }

    func requestHumanReview() {
        humanActionStatus = "Human review requested for this synthetic replay."
    }
}

private struct PerceptionConfiguration: Sendable {
    let endpoint: URL
    let accessToken: String
    static func load() -> Self? {
        func setting(_ name: String) -> String {
            ProcessInfo.processInfo.environment[name] ?? UserDefaults.standard.string(forKey: name) ??
            (Bundle.main.object(forInfoDictionaryKey: name) as? String ?? "")
        }
        guard let url = URL(string: setting("PERCEPTION_ENDPOINT")),
              url.scheme == "https", url.host != nil, url.user == nil, url.password == nil,
              !setting("PERCEPTION_ACCESS_TOKEN").isEmpty else { return nil }
        return Self(endpoint: url, accessToken: setting("PERCEPTION_ACCESS_TOKEN"))
    }
}

private enum PerceptionHTTPClient {
    static func observe(jpeg: Data, frameID: String, configuration: PerceptionConfiguration) async throws -> VehicleObservation {
        var request = URLRequest(url: configuration.endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(configuration.accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(PerceptionRequest(frameID: frameID, jpeg: jpeg))
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200, data.count < 32_768 else {
            throw URLError(.badServerResponse)
        }
        let observation = try JSONDecoder().decode(VehicleObservation.self, from: data)
        guard observation.frameID == frameID, observation.isValid else { throw URLError(.cannotParseResponse) }
        return observation
    }
}

#if canImport(CoreImage) && canImport(CoreVideo)
/// Retains an immutable captured camera buffer while sampled encoding runs off the UI thread.
private struct CameraPixelBuffer: @unchecked Sendable { let value: CVPixelBuffer }
private enum CameraJPEG {
    static func encode(_ buffer: CameraPixelBuffer) throws -> Data {
        let source = CIImage(cvPixelBuffer: buffer.value).oriented(.right)
        let scale = min(1, 1024 / max(source.extent.width, source.extent.height))
        let image = source.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let jpeg = CIContext().jpegRepresentation(of: image, colorSpace: CGColorSpaceCreateDeviceRGB(), options: [kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: 0.75]) else {
            throw URLError(.cannotDecodeContentData)
        }
        return jpeg
    }
}
#endif
