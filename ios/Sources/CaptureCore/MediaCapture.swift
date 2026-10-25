import Foundation

/// A decoded video frame that can be handed to capture/Vision adapters.
/// `imageData` is PNG encoded and deliberately contains pixels, rather than
/// synthetic JSON observations.
public struct MediaFrame: Equatable, Sendable {
    public let frameID: String
    public let timestampSeconds: Double
    public let imageData: Data
    public let quality: CaptureQuality

    public init(frameID: String, timestampSeconds: Double, imageData: Data, quality: CaptureQuality) {
        self.frameID = frameID
        self.timestampSeconds = timestampSeconds
        self.imageData = imageData
        self.quality = quality
    }
}

public enum MediaCaptureError: Error, Equatable, Sendable {
    case assetUnavailable(String)
    case invalidSamplingInterval
    case decodeFailed(Double)
    case unsupportedPlatform
}

public struct MediaCaptureConfiguration: Equatable, Sendable {
    public let intervalSeconds: Double
    public init(intervalSeconds: Double = 1.0) { self.intervalSeconds = intervalSeconds }
}

public struct CapturePixelQualityAnalyzer: Sendable {
    public let blurThreshold: Double
    public let motionThreshold: Double
    public init(blurThreshold: Double = 0.012, motionThreshold: Double = 0.16) {
        self.blurThreshold = blurThreshold; self.motionThreshold = motionThreshold
    }
    public func analyze(width: Int, height: Int, rgba: [UInt8], previousRGBA: [UInt8]? = nil) -> CaptureQuality {
        guard width > 1, height > 1, rgba.count == width * height * 4 else { return .init(blur: 0, lighting: 0, motion: 1) }
        var luma = [Double](); luma.reserveCapacity(width * height)
        for i in stride(from: 0, to: rgba.count, by: 4) { luma.append((0.2126 * Double(rgba[i]) + 0.7152 * Double(rgba[i + 1]) + 0.0722 * Double(rgba[i + 2])) / 255) }
        var gradient = 0.0
        for y in 0..<(height - 1) { for x in 0..<(width - 1) { let i = y * width + x; gradient += abs(luma[i] - luma[i + 1]) + abs(luma[i] - luma[i + width]) } }
        gradient /= Double(max(1, (width - 1) * (height - 1)))
        let mean = luma.reduce(0, +) / Double(luma.count)
        let lighting = max(0, min(1, 1 - abs(mean - 0.5) * 2))
        let motion = previousRGBA.flatMap { old -> Double? in
            guard old.count == rgba.count else { return nil }
            var delta = 0.0
            var index = 0
            while index < rgba.count {
                delta += abs(Double(rgba[index]) - Double(old[index])) / 255
                index += 4
            }
            return delta / Double(max(1, width * height))
        } ?? 0
        return .init(blur: min(1, gradient / max(blurThreshold * 2, 0.0001)), lighting: lighting, motion: max(0, 1 - min(1, motion / max(motionThreshold, 0.001))))
    }
}

/// Deterministic AVFoundation frame sampler for the bundled Toyota demo.
/// On platforms without AVFoundation this returns an explicit unsupported error.
public enum ToyotaVideoCapture {
    public static let resourceName = "toyota-demo"
    public static let resourceExtension = "mov"

    public static func bundledURL(bundle: Bundle? = nil) -> URL? {
#if SWIFT_PACKAGE
        return (bundle ?? Bundle.module).url(forResource: resourceName, withExtension: resourceExtension)
#else
        return (bundle ?? Bundle.main).url(forResource: resourceName, withExtension: resourceExtension)
#endif
    }

    public static func sample(configuration: MediaCaptureConfiguration = .init(), bundle: Bundle? = nil) throws -> [MediaFrame] {
        guard configuration.intervalSeconds > 0, configuration.intervalSeconds.isFinite else { throw MediaCaptureError.invalidSamplingInterval }
        guard let url = bundledURL(bundle: bundle) else { throw MediaCaptureError.assetUnavailable("Bundle resource \(resourceName).\(resourceExtension) is missing") }
#if canImport(AVFoundation) && canImport(ImageIO) && canImport(CoreGraphics)
        return try AVFoundationSampler.sample(url: url, configuration: configuration)
#else
        _ = url
        throw MediaCaptureError.unsupportedPlatform
#endif
    }
}

#if canImport(AVFoundation) && canImport(ImageIO) && canImport(CoreGraphics)
import AVFoundation
import CoreGraphics
import ImageIO

private enum AVFoundationSampler {
    static func sample(url: URL, configuration: MediaCaptureConfiguration) throws -> [MediaFrame] {
        let asset = AVAsset(url: url)
        let duration = asset.duration.seconds
        guard duration.isFinite, duration > 0 else { throw MediaCaptureError.decodeFailed(0) }
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        let analyzer = CapturePixelQualityAnalyzer()
        var previousRGBA: [UInt8]?
        var frames: [MediaFrame] = []
        var t = 0.0
        while t < duration {
            let seconds = t
            do {
                let image = try generator.copyCGImage(at: CMTime(seconds: seconds, preferredTimescale: 600), actualTime: nil)
                guard let data = pngData(image) else { throw MediaCaptureError.decodeFailed(seconds) }
                let rgba = rgbaData(image)
                let quality: CaptureQuality
                if let rgba {
                    quality = analyzer.analyze(width: image.width, height: image.height, rgba: rgba, previousRGBA: previousRGBA)
                    previousRGBA = rgba
                } else {
                    quality = .init(blur: 0, lighting: 0, motion: 1)
                }
                frames.append(.init(frameID: String(format: "video-%06d", frames.count + 1), timestampSeconds: seconds, imageData: data, quality: quality))
            } catch { throw MediaCaptureError.decodeFailed(seconds) }
            t += configuration.intervalSeconds
        }
        return frames
    }

    private static func pngData(_ image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }

    private static func rgbaData(_ image: CGImage) -> [UInt8]? {
        var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
        guard let context = CGContext(data: &pixels, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height)); return pixels
    }
}
#endif
