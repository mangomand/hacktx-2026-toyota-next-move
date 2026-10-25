import Foundation

public enum ReconstructionCapability: String, Codable, Sendable { case cameraIMU, replayDemo }
public enum ReconstructionMode: String, Codable, Sendable { case cameraGuided, replayDemo }

/// Adapter-owned facts for the hackathon baseline. The normal path is camera
/// imagery plus IMU/world tracking; replay is the explicit fallback.
public struct DeviceCapabilities: Codable, Equatable, Sendable {
 public let hasCamera: Bool
 public let hasWorldTracking: Bool
 public let isReplay: Bool
 public init(hasCamera: Bool, hasWorldTracking: Bool, isReplay: Bool = false) { self.hasCamera=hasCamera; self.hasWorldTracking=hasWorldTracking; self.isReplay=isReplay }
 public var baselineAvailable: Bool { isReplay || (hasCamera && hasWorldTracking) }
 public var mode: ReconstructionMode { baselineAvailable ? (isReplay ? .replayDemo : .cameraGuided) : .replayDemo }
 public var capabilities: Set<ReconstructionCapability> { var result:Set<ReconstructionCapability>=[]; if hasCamera && hasWorldTracking { result.insert(.cameraIMU) }; if isReplay || !baselineAvailable { result.insert(.replayDemo) }; return result }
}
