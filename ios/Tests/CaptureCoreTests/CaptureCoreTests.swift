import XCTest
@testable import CaptureCore
import VisionCore
#if canImport(CoreImage) && canImport(CoreVideo)
import CoreImage
import CoreVideo
#endif

final class CaptureCoreTests: XCTestCase {
#if canImport(CoreImage) && canImport(CoreVideo)
    func testVehiclePulseMaskMakesBackgroundTransparent() throws {
        var buffer: CVPixelBuffer?
        XCTAssertEqual(CVPixelBufferCreate(nil, 16, 16, kCVPixelFormatType_OneComponent8, nil, &buffer), kCVReturnSuccess)
        let pixelBuffer = try XCTUnwrap(buffer)
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        let base = try XCTUnwrap(CVPixelBufferGetBaseAddress(pixelBuffer)).assumingMemoryBound(to: UInt8.self)
        let stride = CVPixelBufferGetBytesPerRow(pixelBuffer)
        for y in 0..<16 { for x in 0..<16 { base[y * stride + x] = (4..<12).contains(x) && (4..<12).contains(y) ? 255 : 0 } }
        CVPixelBufferUnlockBaseAddress(pixelBuffer, [])

        let context = CIContext(options: [.useSoftwareRenderer: true])
        let mask = try XCTUnwrap(VehiclePulseMask.image(from: pixelBuffer, context: context))
        var pixels = [UInt8](repeating: 0, count: 16 * 16 * 4)
        try pixels.withUnsafeMutableBytes { storage in
            let bitmap = try XCTUnwrap(CGContext(data: storage.baseAddress, width: 16, height: 16, bitsPerComponent: 8, bytesPerRow: 16 * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            bitmap.draw(mask, in: CGRect(x: 0, y: 0, width: 16, height: 16))
        }
        for y in 0..<16 { for x in 0..<16 { let expected: UInt8 = (4..<12).contains(x) && (4..<12).contains(y) ? 255 : 0; XCTAssertEqual(pixels[(y * 16 + x) * 4 + 3], expected, "Mask alpha at \(x),\(y)") } }
    }
#endif

    func testBundledVideoIsAddressableOrUnsupportedExplicitly() {
        #if canImport(AVFoundation)
        XCTAssertNotNil(ToyotaVideoCapture.bundledURL())
        #else
        XCTAssertThrowsError(try ToyotaVideoCapture.sample(configuration: .init(intervalSeconds: 1))) { error in
            XCTAssertEqual(error as? MediaCaptureError, .unsupportedPlatform)
        }
        #endif
    }

    func testSamplingRejectsNonPositiveOrNonFiniteInterval() {
        XCTAssertThrowsError(try ToyotaVideoCapture.sample(configuration: .init(intervalSeconds: 0))) { XCTAssertEqual($0 as? MediaCaptureError, .invalidSamplingInterval) }
        XCTAssertThrowsError(try ToyotaVideoCapture.sample(configuration: .init(intervalSeconds: .nan))) { XCTAssertEqual($0 as? MediaCaptureError, .invalidSamplingInterval) }
    }

    func testCanonicalRegionsAndInitialUnseen() {
        XCTAssertEqual(CaptureRegion.allCases.map(\.rawValue), ["front", "front-left", "left", "rear-left", "rear", "rear-right", "right", "front-right", "roof", "interior-front", "interior-rear", "trunk"])
        let state = CaptureProgress(); XCTAssertTrue(CaptureRegion.allCases.allSatisfy { state[$0] == .unseen })
    }

    func testQualityMapsToPartialAndCovered() {
        var state = CaptureProgress()
        XCTAssertEqual(state.ingest(.init(frameID: "bad", timestampSeconds: 0, region: .front, quality: .init(blur: 0.2, lighting: 1, motion: 1))), .needsRetake(.front, prompts: [.blur]))
        XCTAssertEqual(state[.front], .partial)
        XCTAssertEqual(state.ingest(.init(frameID: "good", timestampSeconds: 1, region: .front, quality: .good)), .observed(.front))
        XCTAssertEqual(state[.front], .covered)
    }

    func testReplayIsDeterministicAndKeepsExplicitPartialAndUnseen() {
        XCTAssertEqual(CaptureReplay.run(), CaptureReplay.run())
        let state = CaptureReplay.run(); XCTAssertEqual(state[.rearLeft], .partial); XCTAssertEqual(state[.frontRight], .partial)
        XCTAssertEqual(state[.interiorRear], .unseen); XCTAssertEqual(state[.trunk], .unseen); XCTAssertTrue(state.allRegionsObserved == false)
    }

    func testSessionJSONHasTwelveUniqueCanonicalRegions() throws {
        let data = try CaptureReplay.sessionJSON(); let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["schemaVersion"] as? String, "0.1.0"); XCTAssertEqual(object["mode"] as? String, "synthetic_replay")
        let regions = try XCTUnwrap(object["regions"] as? [[String: Any]]); XCTAssertEqual(regions.count, 12)
        let ids = regions.compactMap { $0["regionId"] as? String }; XCTAssertEqual(Set(ids).count, 12)
        XCTAssertTrue(regions.allSatisfy { ($0["observedAt"] as? String) == CaptureReplay.fixedStart })
        XCTAssertEqual(Set(object["unknownRegions"] as? [String] ?? []), Set(["rear-left", "front-right", "interior-rear", "trunk"]))
    }

    func testNonFiniteSampleRejectedWithoutMutation() {
        var state = CaptureProgress(); let sample = CaptureSample(frameID: "nan", timestampSeconds: .nan, region: .front, quality: .good)
        XCTAssertEqual(state.ingest(sample), .rejectedNonFinite); XCTAssertEqual(state[.front], .unseen)
    }

    func testVisionHandoffCarriesCanonicalPayloadAndQualityLimits() throws {
        let handoff = try CaptureReplay.visionHandoff()
        XCTAssertEqual(handoff.sessionJSON, try CaptureReplay.sessionJSON())
        XCTAssertEqual(handoff.artifactRefs, ["ios/replay/replay-scan-session.json", "ios/replay/README.md"])
        XCTAssertEqual(handoff.unknownRegions, ["rear-left", "front-right", "interior-rear", "trunk"])
        XCTAssertEqual(handoff.qualityLimitedRegions, ["rear-left", "front-right"])
    }

    func testVisionDependencyPreservesPartialAndUnseenOutput() throws {
        let frame = try VisionCore.ReplayFrame(id: "quality-only", artifactRef: "ios/replay/frame-004.json", regions: [.rearLeft], quality: .low, glareLimited: true, motionBlur: true)
        let output = try VisionCore.SyntheticReplay.run(frames: [frame], startedAt: Date(timeIntervalSince1970: 1_792_771_200))
        XCTAssertEqual(output.map.regions.first(where: { $0.regionId == .rearLeft })?.state, .partial)
        XCTAssertTrue(output.map.unknownRegions.contains(.rearLeft))
        XCTAssertTrue(output.map.unknownRegions.contains(.trunk))
        XCTAssertTrue(output.findings.isEmpty)
    }
}

extension CaptureCoreTests {
    func testGuidanceIsCanonicalAndExplicitForCabinAndTrunk() {
        XCTAssertEqual(Set(CaptureGuide.steps.map(\.region)), Set(CaptureRegion.allCases))
        XCTAssertTrue(CaptureGuide.step(for: .interiorFront).instruction.localizedCaseInsensitiveContains("front door"))
        XCTAssertTrue(CaptureGuide.step(for: .interiorRear).instruction.localizedCaseInsensitiveContains("rear door"))
        XCTAssertTrue(CaptureGuide.step(for: .trunk).instruction.localizedCaseInsensitiveContains("trunk"))
    }

    func testNextGuidanceAdvancesOnlyAfterCoveredCapture() {
        var progress = CaptureProgress()
        XCTAssertEqual(CaptureGuide.nextUncovered(in: progress)?.region, .frontLeft)
        _ = progress.ingest(.init(frameID: "partial-front-left", timestampSeconds: 0, region: .frontLeft, quality: .init(blur: 0.2, lighting: 1, motion: 1)))
        XCTAssertEqual(CaptureGuide.nextUncovered(in: progress)?.region, .frontLeft)
        _ = progress.ingest(.init(frameID: "front-left", timestampSeconds: 1, region: .frontLeft, quality: .good))
        XCTAssertEqual(CaptureGuide.nextUncovered(in: progress)?.region, .front)
    }

    func testBlockedGuidanceCanBeSkippedAndRouteStartsFrontLeft() {
        XCTAssertEqual(CaptureGuide.steps.first?.region, .frontLeft)
        var progress = CaptureProgress(); progress.markBlocked(.frontLeft)
        XCTAssertEqual(CaptureGuide.nextUncovered(in: progress)?.region, .front)
    }
    func testSensingModeUsesCameraBaselineOrReplay() {
        XCTAssertEqual(CaptureSensingMode.cameraGuided.rawValue, "camera_guided")
        XCTAssertEqual(CaptureSensingMode.replay.rawValue, "replay")
    }

    func testDynamicGuidancePrioritizesUnseenRegionsAfterAQualityLimitedAttempt() {
        var progress = CaptureProgress()
        _ = progress.ingest(.init(frameID: "partial", timestampSeconds: 0, region: .frontLeft, quality: .init(blur: 0.1, lighting: 1, motion: 1)))
        XCTAssertEqual(CaptureGuide.nextDynamic(in: progress, attempts: [.frontLeft: 1])?.region, .front)
    }

    func testPixelAnalyzerFlagsFlatOrDarkPixelsAndAcceptsDetailedPixels() {
        let flat = Array(repeating: UInt8(8), count: 4 * 4 * 4)
        let flatQuality = CapturePixelQualityAnalyzer().analyze(width: 4, height: 4, rgba: flat)
        XCTAssertLessThan(flatQuality.blur, CaptureQuality.acceptanceThreshold)
        XCTAssertLessThan(flatQuality.lighting, CaptureQuality.acceptanceThreshold)

        var detailed = [UInt8](repeating: 0, count: 4 * 4 * 4)
        for i in stride(from: 0, to: detailed.count, by: 4) { let bright = (i / 4).isMultiple(of: 2) ? UInt8(240) : UInt8(20); detailed[i] = bright; detailed[i + 1] = bright; detailed[i + 2] = bright; detailed[i + 3] = 255 }
        let detailedQuality = CapturePixelQualityAnalyzer().analyze(width: 4, height: 4, rgba: detailed)
        XCTAssertGreaterThan(detailedQuality.blur, flatQuality.blur)
    }

    func testPixelAnalyzerUsesPreviousFrameForMotionQuality() {
        let analyzer = CapturePixelQualityAnalyzer()
        let first = Array(repeating: UInt8(32), count: 4 * 4 * 4)
        var changed = first
        for i in stride(from: 0, to: changed.count, by: 4) { changed[i] = 240 }
        let quality = analyzer.analyze(width: 4, height: 4, rgba: changed, previousRGBA: first)
        XCTAssertLessThan(quality.motion, 1)
    }

    func testReplayIncludesPartialQualityAndUnknownRegions() throws {
        let output = try CaptureReplay.visionHandoff()
        XCTAssertTrue(output.qualityLimitedRegions.contains("rear-left"))
        XCTAssertTrue(output.unknownRegions.contains("trunk"))
    }
}

extension CaptureCoreTests {
    func testModelObservationsConfirmActualRegionNotPromptedRegion() {
        var accumulator = VehicleObservationAccumulator()
        var progress = CaptureProgress()
        func observation(_ id: String) -> VehicleObservation {
            .init(frameID: id, vehiclePresent: true, usability: .limited,
                  regions: [.init(id: .rear, confidence: 0.85)], guidance: "Rear bumper visible in dim light.")
        }
        XCTAssertTrue(accumulator.ingest(observation("night-1")).isEmpty)
        let accepted = accumulator.ingest(observation("night-2"))
        accepted.forEach { progress.recordModelObserved($0) }
        XCTAssertEqual(accepted, [.rear])
        XCTAssertEqual(progress[.rear], .covered)
        XCTAssertEqual(progress[.front], .unseen)
        XCTAssertNil(progress.latestQuality[.rear], "Model coverage must not invent pixel-quality measurements")
    }

    func testObservationDuplicatesAmbiguityAndPauseDoNotAdvance() {
        var accumulator = VehicleObservationAccumulator()
        let region = VehicleObservation.Region(id: .front, confidence: 0.9)
        let first = VehicleObservation(frameID: "1", vehiclePresent: true, usability: .usable, regions: [region], guidance: "Front visible")
        XCTAssertTrue(accumulator.ingest(first).isEmpty)
        XCTAssertTrue(accumulator.ingest(first).isEmpty)
        accumulator.breakContinuity()
        XCTAssertTrue(accumulator.ingest(.init(frameID: "2", vehiclePresent: true, usability: .usable, regions: [region], guidance: "Front visible")).isEmpty)
        XCTAssertTrue(accumulator.ingest(.init(frameID: "3", vehiclePresent: false, usability: .unusable, regions: [], guidance: "Point toward the car")).isEmpty)
        XCTAssertTrue(accumulator.ingest(.init(frameID: "4", vehiclePresent: true, usability: .usable, regions: [region], guidance: "Front visible")).isEmpty)
    }

    func testModelGuidanceIsActionableOnlyForUsableVehicleObservations() {
        let observation = VehicleObservation(frameID: "guidance", vehiclePresent: true, usability: .usable, regions: [], guidance: "  Hold the front view\nbriefly.  ")
        XCTAssertEqual(VehicleGuidance.actionable(from: observation), "Hold the front view briefly.")
        let noVehicle = VehicleObservation(frameID: "no-car", vehiclePresent: false, usability: .unusable, regions: [], guidance: "Point at the car.")
        XCTAssertNil(VehicleGuidance.actionable(from: noVehicle))
    }

    func testMalformedAndLowConfidenceModelOutputCannotConfirmCoverage() throws {
        var accumulator = VehicleObservationAccumulator()
        for id in ["1", "2"] {
            XCTAssertTrue(accumulator.ingest(.init(frameID: id, vehiclePresent: true, usability: .limited,
                regions: [.init(id: .front, confidence: 0.4)], guidance: "Uncertain view")).isEmpty)
        }
        let invalid = VehicleObservation(frameID: "3", vehiclePresent: true, usability: .usable,
            regions: [.init(id: .front, confidence: .nan)], guidance: "Bad confidence")
        XCTAssertFalse(invalid.isValid)
        XCTAssertTrue(accumulator.ingest(invalid).isEmpty)
        let unknown = Data(#"{"frameID":"4","vehiclePresent":true,"usability":"usable","regions":[{"id":"imaginary-panel","confidence":0.9}],"guidance":"x"}"#.utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(VehicleObservation.self, from: unknown))
    }
}
