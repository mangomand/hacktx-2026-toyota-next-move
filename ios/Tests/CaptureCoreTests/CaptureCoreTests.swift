import XCTest
@testable import CaptureCore
import VisionCore

final class CaptureCoreTests: XCTestCase {
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

    func testReplayIncludesPartialQualityAndUnknownRegions() throws {
        let output = try CaptureReplay.visionHandoff()
        XCTAssertTrue(output.qualityLimitedRegions.contains("rear-left"))
        XCTAssertTrue(output.unknownRegions.contains("trunk"))
    }
}
