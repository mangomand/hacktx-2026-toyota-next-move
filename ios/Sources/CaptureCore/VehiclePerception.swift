import Foundation

/// App-internal model observation, independent of the currently requested view.
public struct VehicleObservation: Codable, Equatable, Sendable {
    public enum Usability: String, Codable, Sendable { case usable, limited, unusable }
    public struct Region: Codable, Equatable, Sendable {
        public let id: CaptureRegion
        public let confidence: Double
        public init(id: CaptureRegion, confidence: Double) { self.id = id; self.confidence = confidence }
    }
    public let frameID: String
    public let vehiclePresent: Bool
    public let usability: Usability
    public let regions: [Region]
    public let guidance: String
    public init(frameID: String, vehiclePresent: Bool, usability: Usability, regions: [Region], guidance: String) {
        self.frameID = frameID; self.vehiclePresent = vehiclePresent; self.usability = usability
        self.regions = regions; self.guidance = guidance
    }
    public var isValid: Bool {
        !frameID.isEmpty && guidance.count <= 240 && regions.count <= CaptureRegion.allCases.count &&
        Set(regions.map(\.id)).count == regions.count &&
        regions.allSatisfy { $0.confidence.isFinite && (0...1).contains($0.confidence) } &&
        (vehiclePresent || regions.isEmpty)
    }
}

/// Two distinct consecutive usable observations are required for each region.
/// Model confidence is a decision signal, not a measured probability of correctness.
public struct VehicleObservationAccumulator: Sendable {
    private var previous: Set<CaptureRegion> = []
    private var seenFrames: Set<String> = []
    public private(set) var confirmed: Set<CaptureRegion> = []
    public init() {}
    public mutating func ingest(_ observation: VehicleObservation) -> Set<CaptureRegion> {
        guard observation.isValid, seenFrames.insert(observation.frameID).inserted else { return [] }
        guard observation.vehiclePresent, observation.usability != .unusable else {
            previous = []; return []
        }
        let current = Set(observation.regions.filter { $0.confidence >= 0.7 }.map(\.id))
        let newlyConfirmed = current.intersection(previous).subtracting(confirmed)
        previous = current
        confirmed.formUnion(newlyConfirmed)
        return newlyConfirmed
    }
    public mutating func breakContinuity() { previous = [] }
}

public struct PerceptionRequest: Encodable, Sendable {
    public let frameID: String
    public let imageBase64: String
    public init(frameID: String, jpeg: Data) { self.frameID = frameID; imageBase64 = jpeg.base64EncodedString() }
}

#if canImport(CoreImage) && canImport(CoreVideo)
import CoreImage
import CoreVideo

/// Converts Vision's foreground mask into an image for the vehicle pulse layers.
public enum VehiclePulseMask {
    public static func image(from pixelBuffer: CVPixelBuffer, context: CIContext) -> CGImage? {
        // CALayer.mask clips by alpha, but Vision returns an opaque grayscale
        // image. Turn black background pixels transparent before compositing.
        let image = CIImage(cvPixelBuffer: pixelBuffer).applyingFilter("CIMaskToAlpha")
        return context.createCGImage(image, from: image.extent)
    }
}
#endif
