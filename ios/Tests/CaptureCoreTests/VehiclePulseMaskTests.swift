#if canImport(CoreImage) && canImport(CoreVideo)
import XCTest
import CoreImage
import CoreVideo
@testable import CaptureCore

final class VehiclePulseMaskTests: XCTestCase {
    func testPulseMaskKeepsForegroundOpaqueAndBackgroundTransparent() throws {
        var buffer: CVPixelBuffer?
        XCTAssertEqual(CVPixelBufferCreate(nil, 16, 16, kCVPixelFormatType_OneComponent8, nil, &buffer), kCVReturnSuccess)
        let pixelBuffer = try XCTUnwrap(buffer)
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        let base = try XCTUnwrap(CVPixelBufferGetBaseAddress(pixelBuffer)).assumingMemoryBound(to: UInt8.self)
        let stride = CVPixelBufferGetBytesPerRow(pixelBuffer)
        for y in 0..<16 {
            for x in 0..<16 {
                base[y * stride + x] = (4..<12).contains(x) && (4..<12).contains(y) ? 255 : 0
            }
        }
        CVPixelBufferUnlockBaseAddress(pixelBuffer, [])

        let context = CIContext(options: [.useSoftwareRenderer: true])
        let mask = try XCTUnwrap(VehiclePulseMask.image(from: pixelBuffer, context: context))
        var pixels = [UInt8](repeating: 0, count: 16 * 16 * 4)
        try pixels.withUnsafeMutableBytes { storage in
            let bitmap = try XCTUnwrap(CGContext(data: storage.baseAddress, width: 16, height: 16,
                bitsPerComponent: 8, bytesPerRow: 16 * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            bitmap.draw(mask, in: CGRect(x: 0, y: 0, width: 16, height: 16))
        }
        for y in 0..<16 {
            for x in 0..<16 {
                let expectedAlpha: UInt8 = (4..<12).contains(x) && (4..<12).contains(y) ? 255 : 0
                XCTAssertEqual(pixels[(y * 16 + x) * 4 + 3], expectedAlpha, "Mask alpha at \(x),\(y)")
            }
        }
    }
}
#endif
