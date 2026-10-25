import XCTest
@testable import VisionCore
final class VisionCoreTests: XCTestCase {
 func testImg1404IsPartialAndFindingFree() throws { let out=try SyntheticReplay.run(frames:[SyntheticReplay.img1404],startedAt:Date(timeIntervalSince1970:0)); XCTAssertTrue(out.map.unknownRegions.contains(.front)); XCTAssertTrue(out.findings.isEmpty) }
 func testVisibleObservationProducesEvidenceBackedFinding() throws { let out=try SyntheticReplay.run(frames:[SyntheticReplay.visibleObservation],startedAt:Date(timeIntervalSince1970:0)); XCTAssertEqual(out.findings.count,1); XCTAssertEqual(out.findings[0].status,.notADiagnosis); XCTAssertEqual(out.findings[0].evidenceRefs.count,1) }
 func testQualityFlagsAndOrderStayPartial() throws { let clear=try ReplayFrame(id:"a",artifactRef:"fixtures/clear.jpg",regions:[.rear],quality:.high); let blur=try ReplayFrame(id:"z",artifactRef:"fixtures/blur.jpg",regions:[.rear],quality:.low,motionBlur:true); let out=try SyntheticReplay.run(frames:[clear,blur],startedAt:Date(timeIntervalSince1970:0)); let rear=try XCTUnwrap(out.map.regions.first{$0.regionId == .rear}); XCTAssertEqual(rear.state,.partial); XCTAssertEqual(rear.quality,.high); XCTAssertEqual(rear.notes,"quality limited; visible evidence remains uncertain"); XCTAssertTrue(out.map.unknownRegions.contains(.rear)) }
 func testLaterHighClearUpgradesEarlierLowQualityPartial() throws { let low=try ReplayFrame(id:"a",artifactRef:"fixtures/low.jpg",regions:[.rear],quality:.low); let high=try ReplayFrame(id:"z",artifactRef:"fixtures/high.jpg",regions:[.rear],quality:.high); let out=try SyntheticReplay.run(frames:[low,high],startedAt:Date(timeIntervalSince1970:0)); let rear=try XCTUnwrap(out.map.regions.first{$0.regionId == .rear}); XCTAssertEqual(rear.state,.covered); XCTAssertEqual(rear.quality,.high); XCTAssertNil(rear.notes); XCTAssertEqual(rear.artifactRefs ?? [],["fixtures/low.jpg","fixtures/high.jpg"]) }
 func testRejectsInvalidConstructionAndDecoding() throws { XCTAssertThrowsError(try ReplayFrame(id:"",artifactRef:"x",regions:[.rear],quality:.high)); XCTAssertThrowsError(try VisibleFindingRules.finding(id:"x",region:.rear,description:"x",confidence:.nan,evidenceRefs:[])); let data=Data("{\"id\":\"x\",\"artifactRef\":\"\",\"regions\":[\"rear\"],\"quality\":\"high\"}".utf8); XCTAssertThrowsError(try JSONDecoder().decode(ReplayFrame.self,from:data)) }
 func testRejectsConflictingDuplicateFrameIDs() throws { let a=try ReplayFrame(id:"same",artifactRef:"fixtures/a.jpg",regions:[.rear],quality:.high); let b=try ReplayFrame(id:"same",artifactRef:"fixtures/b.jpg",regions:[.rear],quality:.high); XCTAssertThrowsError(try SyntheticReplay.run(frames:[a,b],startedAt:Date())) }
 func testSanitizesExpandedClaims() throws { for claim in ["Engine healthy","No damage","Frame is bent","Brakes functioning","Transmission failed"] { let f=try VisibleFindingRules.finding(id:claim,region:.rear,description:claim,confidence:0.8,evidenceRefs:["fixtures/x.jpg"]); XCTAssertTrue(f.description.contains("mechanical condition is unknown")) } }
 func testPresentationMapsCanonicalStateToColorAndUnknown() throws {
  let out=try SyntheticReplay.run(frames:[SyntheticReplay.visibleObservation],startedAt:Date(timeIntervalSince1970:0))
  let rear=try XCTUnwrap(out.presentation.regions.first{$0.regionId == .rear})
  XCTAssertEqual(rear.state,.covered); XCTAssertEqual(rear.quality,.high); XCTAssertEqual(rear.color,.covered)
  XCTAssertFalse(rear.isUnknown); XCTAssertEqual(rear.findings.map(\.regionId),[.rear])
  let front=try XCTUnwrap(out.presentation.regions.first{$0.regionId == .front})
  XCTAssertEqual(front.color,.unknown); XCTAssertTrue(front.isUnknown)
 }
 func testPresentationAnalysisIsDeterministicAndBounded() throws {
  let started=Date(timeIntervalSince1970:0); let a=try SyntheticReplay.run(frames:[SyntheticReplay.visibleObservation],startedAt:started).presentation
  let b=try SyntheticReplay.run(frames:[SyntheticReplay.visibleObservation],startedAt:started).presentation
  XCTAssertEqual(a,b); XCTAssertLessThanOrEqual(a.analysis.count,MapPresentation.maxAnalysisLength)
  XCTAssertTrue(a.analysis.contains("quality-gated coverage")); XCTAssertTrue(a.analysis.contains("visible observation"))
  XCTAssertFalse(a.analysis.lowercased().contains("safe")); XCTAssertFalse(a.analysis.lowercased().contains("mechanical"))
 }

 func testPixelAnalyzerUsesRealPixelsAndKeepsRegionsUnknownWithoutEvidence() throws {
  var pixels = [UInt8](repeating: 0, count: 8 * 8 * 4)
  for y in 0..<8 { for x in 0..<8 { let i = (y * 8 + x) * 4; let value: UInt8 = (x + y).isMultiple(of: 2) ? 255 : 0; pixels[i] = value; pixels[i + 1] = value; pixels[i + 2] = value; pixels[i + 3] = 255 } }
  let frame = try VisionPixelFrame(width: 8, height: 8, rgba: pixels)
  let result = FrameAnalyzer().analyze(frame)
  XCTAssertGreaterThan(result.metrics.blurScore, 0)
  XCTAssertEqual(result.metrics.evidence, .unavailable)
  XCTAssertTrue(result.evidenceRegions.isEmpty)
  XCTAssertEqual(result.missingRegions.count, RegionID.allCases.count)
 }

 func testPixelAnalyzerMarksOnlyCallerSuppliedRegionsAndDetectsExposureMotion() throws {
  let dark = try VisionPixelFrame(width: 4, height: 4, rgba: [UInt8](repeating: 0, count: 64))
  let bright = try VisionPixelFrame(width: 4, height: 4, rgba: [UInt8](repeating: 255, count: 64))
  let result = FrameAnalyzer().analyze(bright, previous: dark, evidenceRegions: [.rear])
  XCTAssertEqual(result.metrics.evidence, .unavailable)
  XCTAssertTrue(result.metrics.exposureLimited)
  XCTAssertTrue(result.metrics.motionBlur)
  XCTAssertTrue(result.evidenceRegions.isEmpty)
  XCTAssertTrue(result.missingRegions.contains(.rear))
 }
}

extension VisionCoreTests {
 func testCameraTrackingBaselineUsesCameraIMU() {
  let device = DeviceCapabilities(hasCamera: true, hasWorldTracking: true)
  XCTAssertEqual(device.mode, .cameraGuided)
  XCTAssertTrue(device.capabilities.contains(.cameraIMU))
  XCTAssertFalse(device.capabilities.contains(.replayDemo))
 }
 func testUnsupportedDeviceFallsBackToExplicitReplayDemo() {
  let device = DeviceCapabilities(hasCamera: false, hasWorldTracking: false)
  XCTAssertEqual(device.mode, .replayDemo)
  XCTAssertTrue(device.capabilities.contains(.replayDemo))
 }
}

extension VisionCoreTests {
 func testMaterialRevealKeepsUnknownNeutralAndPartialUncertain() throws {
  let anchors = try VehicleSurfaceAnchor.heroDefaults()
  let map = try SyntheticReplay.run(frames: [SyntheticReplay.img1404], startedAt: Date(timeIntervalSince1970: 0)).map
  let reveals = try MaterialRevealPlan.make(map: map, findings: [], anchors: anchors)
  XCTAssertEqual(reveals.first(where: { $0.regionId == .front })?.state, .neutral)
  XCTAssertEqual(reveals.first(where: { $0.regionId == .rear })?.state, .uncertain)
 }
 func testMaterialRevealUsesSurfaceAnchorAndSeparateFindingAccent() throws {
  let anchor = try VehicleSurfaceAnchor(id: "rear-panel", regionId: .rear, surface: .bodyPanel, position: (0, 0, -0.8), cameraPreset: "rear-three-quarter", assetRevision: "hero-template-v1")
  let frame = try ReplayFrame(id: "observation", artifactRef: "fixtures/vision/panel.jpg", regions: [.rear], quality: .high, visibleObservation: "Visible surface mark")
  let output = try SyntheticReplay.run(frames: [frame], startedAt: Date(timeIntervalSince1970: 0))
  let reveal = try XCTUnwrap(try MaterialRevealPlan.make(map: output.map, findings: output.findings, anchors: [.rear: anchor]).first)
  XCTAssertEqual(reveal.state, .revealed); XCTAssertEqual(reveal.anchorId, "rear-panel"); XCTAssertEqual(reveal.surface, .bodyPanel); XCTAssertEqual(reveal.findingAccent, .resolved)
  XCTAssertEqual(reveal.progress, 1); XCTAssertGreaterThan(reveal.spreadRadius, 0)
 }
 func testMaterialRevealRejectsMismatchedAnchor() throws {
  let region = CoverageRegion(regionId: .rear, state: .covered, quality: .high, observedAt: Date(), artifactRefs: ["fixtures/vision/rear.jpg"], notes: nil)
  let anchor = try VehicleSurfaceAnchor(id: "front", regionId: .front, surface: .windshield, position: (0, 0, 0), cameraPreset: "front", assetRevision: "hero-template-v1")
  XCTAssertThrowsError(try MaterialReveal(region: region, anchor: anchor))
 }
}
