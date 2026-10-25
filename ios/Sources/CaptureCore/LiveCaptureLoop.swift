import Foundation

public struct LiveCaptureFrame: Sendable {
    public let frameID: String
    public let timestampSeconds: Double
    public let width: Int
    public let height: Int
    public let rgba: [UInt8]
    public let region: CaptureRegion
    public init(frameID: String, timestampSeconds: Double, width: Int, height: Int, rgba: [UInt8], region: CaptureRegion) {
        self.frameID = frameID; self.timestampSeconds = timestampSeconds; self.width = width; self.height = height; self.rgba = rgba; self.region = region
    }
}

public struct LiveCaptureFrameLoop: Sendable {
    public let analyzer: CapturePixelQualityAnalyzer
    private var previousRGBA: [UInt8]?
    public init(analyzer: CapturePixelQualityAnalyzer = .init()) { self.analyzer = analyzer }

    public mutating func ingest(_ frame: LiveCaptureFrame, into progress: inout CaptureProgress) -> CaptureIngestResult {
        let quality = analyzer.analyze(width: frame.width, height: frame.height, rgba: frame.rgba, previousRGBA: previousRGBA)
        previousRGBA = frame.rgba
        return progress.ingest(.init(frameID: frame.frameID, timestampSeconds: frame.timestampSeconds, region: frame.region, quality: quality))
    }
    public mutating func reset() { previousRGBA = nil }
}

#if canImport(CoreVideo)
import CoreVideo

public enum PixelBufferFrame {
    public static func rgba(_ buffer: CVPixelBuffer) -> (width: Int, height: Int, rgba: [UInt8])? {
        let format = CVPixelBufferGetPixelFormatType(buffer)
        guard format == kCVPixelFormatType_32BGRA || format == kCVPixelFormatType_32RGBA else { return nil }
        CVPixelBufferLockBaseAddress(buffer, .readOnly); defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(buffer) else { return nil }
        let width = CVPixelBufferGetWidth(buffer), height = CVPixelBufferGetHeight(buffer), stride = CVPixelBufferGetBytesPerRow(buffer)
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<height {
            let row = base.advanced(by: y * stride).assumingMemoryBound(to: UInt8.self)
            for x in 0..<width {
                let source = x * 4, target = (y * width + x) * 4
                if format == kCVPixelFormatType_32BGRA { pixels[target] = row[source + 2]; pixels[target + 1] = row[source + 1]; pixels[target + 2] = row[source]; pixels[target + 3] = row[source + 3] }
                else { for offset in 0..<4 { pixels[target + offset] = row[source + offset] } }
            }
        }
        return (width, height, pixels)
    }
}
#endif
