import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
#if canImport(CoreVideo)
import CoreVideo
#endif

/// A portable pixel input used by the capture adapter. Pixels are tightly packed RGBA8.
/// Keeping this value type makes analysis deterministic in tests and on platforms without
/// CoreVideo, while the conditional initializers below bridge native camera buffers.
public struct VisionPixelFrame: Sendable, Equatable {
 public let width: Int
 public let height: Int
 public let rgba: [UInt8]

 public init(width: Int, height: Int, rgba: [UInt8]) throws {
  guard width > 0, height > 0, rgba.count == width * height * 4 else { throw FrameAnalysisError.invalidPixels }
  self.width = width; self.height = height; self.rgba = rgba
 }

#if canImport(CoreGraphics)
 public init(cgImage: CGImage) throws {
  let width = cgImage.width, height = cgImage.height
  var pixels = [UInt8](repeating: 0, count: width * height * 4)
  guard let context = CGContext(data: &pixels, width: width, height: height, bitsPerComponent: 8,
                                bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw FrameAnalysisError.unsupportedImage }
  context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
  try self.init(width: width, height: height, rgba: pixels)
 }
#endif

#if canImport(CoreVideo)
 public init?(pixelBuffer: CVPixelBuffer) {
  let format = CVPixelBufferGetPixelFormatType(pixelBuffer)
  if format == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange || format == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange {
   CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly); defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
   guard let yBase = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0),
         let uvBase = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1) else { return nil }
   let width = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0)
   let height = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0)
   let yStride = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)
   let uvStride = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1)
   let yPlane = yBase.assumingMemoryBound(to: UInt8.self)
   let uvPlane = uvBase.assumingMemoryBound(to: UInt8.self)
   var output = [UInt8](repeating: 255, count: width * height * 4)
   let fullRange = format == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
   for y in 0..<height {
    let yRow = yPlane.advanced(by: y * yStride)
    let uvRow = uvPlane.advanced(by: (y / 2) * uvStride)
    for x in 0..<width {
     let ySample = Double(yRow[x])
     let uvOffset = (x / 2) * 2
     let cb = Double(uvRow[uvOffset]) - 128.0
     let cr = Double(uvRow[uvOffset + 1]) - 128.0
     let luminance = fullRange ? ySample : (ySample - 16.0) * (255.0 / 219.0)
     let scale = fullRange ? 1.0 : (255.0 / 224.0)
     let red = luminance + 1.402 * cr * scale
     let green = luminance - 0.344136 * cb * scale - 0.714136 * cr * scale
     let blue = luminance + 1.772 * cb * scale
     let destination = (y * width + x) * 4
     output[destination] = UInt8(max(0, min(255, red)))
     output[destination + 1] = UInt8(max(0, min(255, green)))
     output[destination + 2] = UInt8(max(0, min(255, blue)))
    }
   }
   guard let normalized = try? VisionPixelFrame(width: width, height: height, rgba: output) else { return nil }
   self = normalized
   return
  }
  guard format == kCVPixelFormatType_32BGRA || format == kCVPixelFormatType_32RGBA else { return nil }
  CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly); defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
  guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }
  let width = CVPixelBufferGetWidth(pixelBuffer), height = CVPixelBufferGetHeight(pixelBuffer)
  let stride = CVPixelBufferGetBytesPerRow(pixelBuffer)
  var output = [UInt8](repeating: 0, count: width * height * 4)
  for y in 0..<height {
   let row = base.advanced(by: y * stride).assumingMemoryBound(to: UInt8.self)
   for x in 0..<width {
    let source = x * 4, destination = (y * width + x) * 4
    if format == kCVPixelFormatType_32BGRA {
     output[destination] = row[source + 2]; output[destination + 1] = row[source + 1]; output[destination + 2] = row[source]; output[destination + 3] = row[source + 3]
    } else { for offset in 0..<4 { output[destination + offset] = row[source + offset] } }
   }
  }
  guard let normalized = try? VisionPixelFrame(width: width, height: height, rgba: output) else { return nil }
  self = normalized
 }
#endif
}

public enum FrameAnalysisError: Error, Equatable { case invalidPixels, unsupportedImage }
public enum EvidenceAvailability: String, Codable, Sendable { case available, unavailable, unknown }

public struct FrameQualityMetrics: Codable, Equatable, Sendable {
 public let blurScore: Double
 public let clippedFraction: Double
 public let motionScore: Double?
 public let quality: Quality
 public let motionBlur: Bool
 public let exposureLimited: Bool
 public let evidence: EvidenceAvailability
}

/// Result of analyzing actual pixels. Region membership is caller supplied: this adapter
/// never classifies a surface from image presence alone.
public struct FrameAnalysisResult: Codable, Equatable, Sendable {
 public let metrics: FrameQualityMetrics
 public let evidenceRegions: [RegionID]
 public let missingRegions: [RegionID]
 public let missingRegionPrompt: String
}

public struct FrameAnalyzer: Sendable {
 public var blurThreshold: Double = 0.012
 public var motionThreshold: Double = 0.16
 public var clippingThreshold: Double = 0.18

 public init() {}

 public func analyze(_ frame: VisionPixelFrame, previous: VisionPixelFrame? = nil, evidenceRegions: Set<RegionID> = []) -> FrameAnalysisResult {
  func luminance(for rgba: [UInt8]) -> [Double] {
   var values: [Double] = []; values.reserveCapacity(rgba.count / 4)
   for i in stride(from: 0, to: rgba.count, by: 4) {
    let red = Double(rgba[i]), green = Double(rgba[i + 1]), blue = Double(rgba[i + 2])
    values.append((0.2126 * red + 0.7152 * green + 0.0722 * blue) / 255.0)
   }
   return values
  }
  let luminanceValues = luminance(for: frame.rgba)
  var gradients: [Double] = []; gradients.reserveCapacity(max(0, luminanceValues.count - frame.width))
  if frame.width > 1 && frame.height > 1 {
   for y in 0..<(frame.height - 1) { for x in 0..<(frame.width - 1) { let i = y * frame.width + x; gradients.append(abs(luminanceValues[i] - luminanceValues[i + 1]) + abs(luminanceValues[i] - luminanceValues[i + frame.width])) } }
  }
  let meanGradient = gradients.isEmpty ? 0 : gradients.reduce(0, +) / Double(gradients.count)
  let clippedCount = luminanceValues.filter { $0 < 0.02 || $0 > 0.98 }.count
  let clipped = Double(clippedCount) / Double(max(1, luminanceValues.count))
  let motion: Double? = previous.flatMap { old in
   guard old.width == frame.width, old.height == frame.height else { return nil }
   let oldL = luminance(for: old.rgba)
   let delta = zip(luminanceValues, oldL).map { abs($0 - $1) }.reduce(0, +)
   return delta / Double(max(1, luminanceValues.count))
  }
  let motionBlur = (motion ?? 0) >= motionThreshold
  let exposureLimited = clipped >= clippingThreshold
  let quality: Quality = (meanGradient < blurThreshold || motionBlur || exposureLimited) ? .low : (meanGradient < blurThreshold * 2 ? .acceptable : .high)
  let availability: EvidenceAvailability = quality == .low ? .unavailable : (evidenceRegions.isEmpty ? .unknown : .available)
  let observed = availability == .available ? evidenceRegions.sorted { $0.rawValue < $1.rawValue } : []
  let missing = RegionID.allCases.filter { !observed.contains($0) }
  let names = missing.map { $0.rawValue.replacingOccurrences(of: "-", with: " ") }
  let prompt = names.isEmpty ? "All requested areas have quality-gated evidence." : "Capture another view of: \(names.joined(separator: ", "))."
  return FrameAnalysisResult(metrics: FrameQualityMetrics(blurScore: meanGradient, clippedFraction: clipped, motionScore: motion, quality: quality, motionBlur: motionBlur, exposureLimited: exposureLimited, evidence: availability), evidenceRegions: observed, missingRegions: missing, missingRegionPrompt: prompt)
 }
}
