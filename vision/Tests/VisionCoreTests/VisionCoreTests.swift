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
}
