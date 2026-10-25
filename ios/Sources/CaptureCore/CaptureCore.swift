import Foundation

/// Canonical v0.1.0 region identifiers.
public enum CaptureRegion: String, CaseIterable, Codable, Sendable {
    case front, frontLeft = "front-left", left, rearLeft = "rear-left", rear
    case rearRight = "rear-right", right, frontRight = "front-right"
    case roof, interiorFront = "interior-front", interiorRear = "interior-rear", trunk
}

public enum CoverageState: String, Codable, Sendable { case unseen, partial, covered, blocked }
public enum CapturePrompt: String, CaseIterable, Codable, Sendable { case blur, lighting, motion }
public enum CaptureSensingMode: String, Codable, Sendable { case cameraGuided = "camera_guided", replay = "replay" }

/// Ordered, human-readable guidance for a synthetic or live capture session.
/// Interior and trunk steps are intentionally named so the operator cannot mistake
/// them for exterior views.
public struct CaptureGuideStep: Equatable, Sendable {
    public let region: CaptureRegion
    public let title: String
    public let instruction: String
    public let safetyNote: String
    public let lowerPhonePrompt: String
    public init(region: CaptureRegion, title: String, instruction: String, safetyNote: String = "Stay clear of traffic and moving doors.", lowerPhonePrompt: String = "Hold the phone at chest height, then lower it before you move.") {
        self.region = region; self.title = title; self.instruction = instruction; self.safetyNote = safetyNote; self.lowerPhonePrompt = lowerPhonePrompt
    }
}

public enum CaptureGuide {
    /// Operator route intentionally begins at the front-left corner and proceeds clockwise.
    public static let steps: [CaptureGuideStep] = [
        .init(region: .frontLeft, title: "Front left", instruction: "Start at the front-left corner. Frame the headlight, wheel, and bumper seam."),
        .init(region: .front, title: "Front", instruction: "Step to the front. Frame the grille and both headlights."),
        .init(region: .frontRight, title: "Front right", instruction: "Walk to the front-right corner. Frame the headlight, wheel, and bumper seam."),
        .init(region: .right, title: "Right side", instruction: "Move along the passenger side. Frame the full right profile."),
        .init(region: .rearRight, title: "Rear right", instruction: "Walk to the rear-right corner. Frame the tail lamp, wheel, and bumper seam."),
        .init(region: .rear, title: "Rear", instruction: "Stand behind the vehicle. Frame the tailgate, lamps, and bumper."),
        .init(region: .rearLeft, title: "Rear left", instruction: "Walk to the rear-left corner. Frame the tail lamp and bumper seam."),
        .init(region: .left, title: "Left side", instruction: "Move along the driver's side. Frame the full left profile."),
        .init(region: .roof, title: "Roof", instruction: "From a safe distance, tilt the phone up to frame the roof and rails."),
        .init(region: .interiorFront, title: "Interior front", instruction: "With the vehicle parked, open the front door and frame the dashboard, seats, and footwell."),
        .init(region: .interiorRear, title: "Interior rear", instruction: "With the vehicle parked, open a rear door and frame the rear seats, floor, and trim."),
        .init(region: .trunk, title: "Trunk", instruction: "With the vehicle parked, open the trunk or liftgate and frame the cargo floor, walls, and latch.")
    ]
    public static func step(for region: CaptureRegion) -> CaptureGuideStep { steps.first { $0.region == region }! }
    public static func nextUncovered(in progress: CaptureProgress) -> CaptureGuideStep? { steps.first { progress[$0.region] != .covered && progress[$0.region] != .blocked } }
    /// Chooses the next prompt from live state rather than following a fixed route.
    /// Attempts are used to prevent repeatedly prompting a partial region when another
    /// region has not been seen; ties retain canonical region order for determinism.
    public static func nextDynamic(in progress: CaptureProgress, attempts: [CaptureRegion: Int]) -> CaptureGuideStep? {
        CaptureRegion.allCases
            .filter { progress[$0] != .covered && progress[$0] != .blocked }
            .sorted { lhs, rhs in
                let leftAttempts = attempts[lhs, default: 0], rightAttempts = attempts[rhs, default: 0]
                if leftAttempts != rightAttempts { return leftAttempts < rightAttempts }
                if progress[lhs] != progress[rhs] { return progress[lhs] == .unseen }
                return CaptureRegion.allCases.firstIndex(of: lhs)! < CaptureRegion.allCases.firstIndex(of: rhs)!
            }
            .first.map(step)
    }
}

public struct CaptureQuality: Equatable, Sendable {
    public let blur: Double; public let lighting: Double; public let motion: Double
    public init(blur: Double, lighting: Double, motion: Double) { self.blur = blur; self.lighting = lighting; self.motion = motion }
    public var prompts: [CapturePrompt] {
        var result: [CapturePrompt] = []
        if blur < Self.acceptanceThreshold { result.append(.blur) }
        if lighting < Self.acceptanceThreshold { result.append(.lighting) }
        if motion < Self.acceptanceThreshold { result.append(.motion) }
        return result
    }
    public var isFinite: Bool { [blur, lighting, motion].allSatisfy(\.isFinite) }
    public var isValid: Bool { isFinite && [blur, lighting, motion].allSatisfy { (0...1).contains($0) } }
    public var isAcceptable: Bool { isValid && prompts.isEmpty }
    public static let good = Self(blur: 1, lighting: 1, motion: 1)
    public static let acceptanceThreshold = 0.6
    fileprivate var contractQuality: String {
        guard isValid else { return "unknown" }; let lowest = min(blur, lighting, motion)
        if lowest >= 0.85 { return "high" }; if lowest >= Self.acceptanceThreshold { return "acceptable" }; return "low"
    }
}

public struct CaptureSample: Equatable, Sendable {
    public let frameID: String; public let timestampSeconds: Double; public let region: CaptureRegion; public let quality: CaptureQuality
    public init(frameID: String, timestampSeconds: Double, region: CaptureRegion, quality: CaptureQuality) {
        self.frameID = frameID; self.timestampSeconds = timestampSeconds; self.region = region; self.quality = quality
    }
    public var isFinite: Bool { timestampSeconds.isFinite && quality.isFinite }
}

public enum CaptureIngestResult: Equatable, Sendable {
    case observed(CaptureRegion), needsRetake(CaptureRegion, prompts: [CapturePrompt]), rejectedNonFinite, rejectedInvalidQuality
}

public struct CaptureProgress: Equatable, Sendable {
    public private(set) var coverage: [CaptureRegion: CoverageState]
    public private(set) var latestQuality: [CaptureRegion: CaptureQuality]
    public init() {
        coverage = Dictionary(uniqueKeysWithValues: CaptureRegion.allCases.map { ($0, .unseen) }); latestQuality = [:]
    }
    public subscript(region: CaptureRegion) -> CoverageState { coverage[region, default: .unseen] }
    public var allRegionsObserved: Bool { CaptureRegion.allCases.allSatisfy { self[$0] == .covered } }
    @discardableResult public mutating func ingest(_ sample: CaptureSample) -> CaptureIngestResult {
        guard sample.isFinite else { return .rejectedNonFinite }; guard sample.quality.isValid else { return .rejectedInvalidQuality }
        latestQuality[sample.region] = sample.quality
        if sample.quality.isAcceptable { coverage[sample.region] = .covered; return .observed(sample.region) }
        coverage[sample.region] = .partial; return .needsRetake(sample.region, prompts: sample.quality.prompts)
    }
    /// Coverage from repeated semantic observations, not fabricated pixel scores.
    public mutating func recordModelObserved(_ region: CaptureRegion) { coverage[region] = .covered }
    public mutating func markBlocked(_ region: CaptureRegion) { coverage[region] = .blocked }
    public mutating func reset() { self = Self() }
}

public struct CoverageRegionRecord: Codable, Equatable, Sendable {
    public let regionId: String; public let state: CoverageState; public let quality: String; public let observedAt: String
    public let artifactRefs: [String]?; public let notes: String?
    public init(region: CaptureRegion, state: CoverageState, quality: String, observedAt: String, artifactRefs: [String]? = nil, notes: String? = nil) {
        regionId = region.rawValue; self.state = state; self.quality = quality; self.observedAt = observedAt; self.artifactRefs = artifactRefs; self.notes = notes
    }
}

public struct ScanSessionRecord: Codable, Equatable, Sendable {
    public let id: String; public let startedAt: String; public let endedAt: String?; public let status: String; public let mode: String
    public let regions: [CoverageRegionRecord]; public let findingIds: [String]; public let artifactRefs: [String]; public let unknownRegions: [String]; public let schemaVersion: String
}

/// Local handoff envelope for the Vision consumer. This is intentionally not
/// a second wire schema: `sessionJSON` is the canonical ScanSession v0.1.0
/// payload and the remaining fields are typed routing metadata for the app.
public struct VisionHandoff: Equatable, Sendable {
    public let sessionJSON: Data
    public let artifactRefs: [String]
    public let unknownRegions: [String]
    public let qualityLimitedRegions: [String]

    public init(sessionJSON: Data, artifactRefs: [String], unknownRegions: [String], qualityLimitedRegions: [String]) {
        self.sessionJSON = sessionJSON
        self.artifactRefs = artifactRefs
        self.unknownRegions = unknownRegions
        self.qualityLimitedRegions = qualityLimitedRegions
    }
}

public enum CaptureReplay {
    public static let fixedStart = "2026-10-24T00:00:00Z"
    public static let fixedSequence: [CaptureSample] = [
        .init(frameID: "frame-001", timestampSeconds: 0, region: .front, quality: .good),
        .init(frameID: "frame-002", timestampSeconds: 1, region: .frontLeft, quality: .good), .init(frameID: "frame-003", timestampSeconds: 2, region: .left, quality: .good),
        .init(frameID: "frame-004", timestampSeconds: 3, region: .rearLeft, quality: .init(blur: 0.4, lighting: 0.5, motion: 0.8)), .init(frameID: "frame-005", timestampSeconds: 4, region: .rear, quality: .good),
        .init(frameID: "frame-006", timestampSeconds: 5, region: .rearRight, quality: .good), .init(frameID: "frame-007", timestampSeconds: 6, region: .right, quality: .good),
        .init(frameID: "frame-008", timestampSeconds: 7, region: .frontRight, quality: .init(blur: 0.2, lighting: 0.9, motion: 0.4)), .init(frameID: "frame-009", timestampSeconds: 8, region: .roof, quality: .good),
        .init(frameID: "frame-010", timestampSeconds: 9, region: .interiorFront, quality: .good)
    ]
    public static func run() -> CaptureProgress { fixedSequence.reduce(into: CaptureProgress()) { state, sample in _ = state.ingest(sample) } }
    /// Emits canonical ScanSession v0.1.0. Unseen regions use the fixed replay start
    /// as observedAt for deterministic fixtures; this is not evidence they were seen.
    public static func sessionJSON() throws -> Data {
        let progress = run()
        let regions = CaptureRegion.allCases.map { region -> CoverageRegionRecord in
            let state = progress[region]; let quality = progress.latestQuality[region]?.contractQuality ?? "unknown"
            let refs = state == .unseen ? nil : ["ios/replay/\(fixedSequence.first(where: { $0.region == region })?.frameID ?? "unknown").json"]
            let note = state == .unseen ? "No evidence captured in deterministic replay." : nil
            return CoverageRegionRecord(region: region, state: state, quality: quality, observedAt: fixedStart, artifactRefs: refs, notes: note)
        }
        let unknown = regions.filter { $0.state != .covered }.map(\.regionId)
        let session = ScanSessionRecord(id: "replay-20261024", startedAt: fixedStart, endedAt: fixedStart, status: "replay", mode: "synthetic_replay", regions: regions, findingIds: [], artifactRefs: ["ios/replay/README.md"], unknownRegions: unknown, schemaVersion: "0.1.0")
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; return try encoder.encode(session)
    }

    /// Packages the canonical session payload for Vision without adding a
    /// competing schema. Partial regions remain quality-limited evidence;
    /// unseen regions remain unknown and are never promoted to findings.
    public static func visionHandoff() throws -> VisionHandoff {
        let data = try sessionJSON()
        let progress = run()
        return VisionHandoff(
            sessionJSON: data,
            artifactRefs: ["ios/replay/replay-scan-session.json", "ios/replay/README.md"],
            unknownRegions: CaptureRegion.allCases.filter { progress[$0] != .covered }.map(\.rawValue),
            qualityLimitedRegions: CaptureRegion.allCases.filter { progress[$0] == .partial }.map(\.rawValue)
        )
    }
}
