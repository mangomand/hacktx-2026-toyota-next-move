import XCTest
@testable import VisionCore

final class AssetAnchorsTests: XCTestCase {
 func testHeroAnchorsAreStableAndBounded() throws {
  let anchors = try VehicleSurfaceAnchor.heroDefaults()
  XCTAssertEqual(anchors[.rear]?.id, "rear-panel")
  XCTAssertEqual(anchors[.rear]?.cameraPreset, "rear-three-quarter")
  XCTAssertEqual(anchors[.front]?.surface, .windshield)
  for anchor in anchors.values {
   XCTAssertTrue((-1...1).contains(anchor.position.x))
   XCTAssertTrue((-1...1).contains(anchor.position.y))
   XCTAssertTrue((-1...1).contains(anchor.position.z))
   XCTAssertNotNil(anchor.attachment)
   XCTAssertEqual(anchor.attachment?.triangleVertexIndices.count, 3)
   XCTAssertEqual(anchor.attachment?.barycentric.reduce(0, +) ?? 0, 1, accuracy: 0.0001)
  }
 }

 func testSurfaceAttachmentRejectsInvalidBarycentricOrNormal() {
   XCTAssertThrowsError(try VehicleSurfaceAnchor.SurfaceAttachment(assetRevision: "hero-template-v1", meshId: "mesh", primitiveIndex: 0, triangleIndex: 0, triangleVertexIndices: [0, 1, 2], barycentric: [0.5, 0.5, 0.5], normal: (0, 0, 1)))
   XCTAssertThrowsError(try VehicleSurfaceAnchor.SurfaceAttachment(assetRevision: "hero-template-v1", meshId: "mesh", primitiveIndex: 0, triangleIndex: 0, triangleVertexIndices: [0, 1, 2], barycentric: [1, 0, 0], normal: (0, 0, 0)))
 }

 func testAssetManifestRequiresProvenance() {
  XCTAssertThrowsError(try VehicleAssetManifest(id: "hero", source: .approvedUSDZ, artifactRef: "assets/hero.usdz", provenanceRef: "", revision: "1"))
 }
}

extension AssetAnchorsTests {
 func testCameraAlignedEvidenceRemainsEvidenceOnly() throws {
  let pose = try CameraPoseReference(id: "pose-1", artifactRef: "fixtures/pose.json", revision: "1")
  let evidence = try CameraAlignedEvidence(frameArtifactRef: "fixtures/frame.jpg", cameraPose: pose, pointCloudArtifactRef: "fixtures/supervisely-reference.ply", geometryRevision: "geom-1", quality: .acceptable)
  XCTAssertTrue(evidence.evidenceOnly)
  XCTAssertEqual(evidence.pointCloudArtifactRef, "fixtures/supervisely-reference.ply")
 }

 func testCameraAlignedEvidenceRejectsBlankPointCloudReference() throws {
  let pose = try CameraPoseReference(id: "pose-1", artifactRef: "fixtures/pose.json", revision: "1")
  XCTAssertThrowsError(try CameraAlignedEvidence(frameArtifactRef: "fixtures/frame.jpg", cameraPose: pose, pointCloudArtifactRef: " ", geometryRevision: "geom-1", quality: .high))
 }

 func testCalloutMapsExistingFindingToStableAnchor() throws {
  let out = try SyntheticReplay.run(frames: [SyntheticReplay.visibleObservation], startedAt: Date(timeIntervalSince1970: 0))
  let finding = try XCTUnwrap(out.findings.first)
  let region = try XCTUnwrap(out.map.regions.first(where: { $0.regionId == .rear }))
  let anchor = try XCTUnwrap(VehicleSurfaceAnchor.heroDefaults()[.rear])
  let callout = try FindingCallout(finding: finding, region: region, anchor: anchor, assetRevision: "hero-template-v1", provenance: "fixtures/vision/panel-observation.jpg", uncertainty: "Visible surface observation; hidden condition remains unknown.")
  XCTAssertEqual(callout.anchorId, "rear-panel")
  XCTAssertEqual(callout.evidenceRefs, finding.evidenceRefs)
  XCTAssertEqual(callout.state, .resolved)
 }

 func testCalloutKeepsPartialRegionAmber() throws {
  let finding = try VisibleFindingRules.finding(id: "finding-rear", region: .rear, description: "Visible mark", confidence: 0.8, evidenceRefs: ["fixtures/rear.jpg"])
  let region = CoverageRegion(regionId: .rear, state: .partial, quality: .low, observedAt: Date(timeIntervalSince1970: 0), artifactRefs: ["fixtures/rear.jpg"], notes: "quality limited")
  let anchor = try XCTUnwrap(VehicleSurfaceAnchor.heroDefaults()[.rear])
  let callout = try FindingCallout(finding: finding, region: region, anchor: anchor, assetRevision: "hero-template-v1", provenance: "fixtures/rear.jpg", uncertainty: "Quality-limited visible evidence.")
  XCTAssertEqual(callout.state, .amber)
 }

 func testCalloutRejectsUnrelatedProvenance() throws {
  let finding = try VisibleFindingRules.finding(id: "finding-rear", region: .rear, description: "Visible mark", confidence: 0.8, evidenceRefs: ["fixtures/rear.jpg"])
  let region = CoverageRegion(regionId: .rear, state: .covered, quality: .high, observedAt: Date(timeIntervalSince1970: 0), artifactRefs: ["fixtures/rear.jpg"], notes: nil)
  let anchor = try XCTUnwrap(VehicleSurfaceAnchor.heroDefaults()[.rear])
  XCTAssertThrowsError(try FindingCallout(finding: finding, region: region, anchor: anchor, assetRevision: "hero-template-v1", provenance: "fixtures/unrelated.jpg", uncertainty: "Visible evidence only."))
 }

 func testCalloutRejectsStaleAssetRevision() throws {
  let finding = try VisibleFindingRules.finding(id: "finding-rear", region: .rear, description: "Visible mark", confidence: 0.8, evidenceRefs: ["fixtures/rear.jpg"])
  let region = CoverageRegion(regionId: .rear, state: .covered, quality: .high, observedAt: Date(timeIntervalSince1970: 0), artifactRefs: ["fixtures/rear.jpg"], notes: nil)
  let anchor = try XCTUnwrap(VehicleSurfaceAnchor.heroDefaults()[.rear])
  XCTAssertThrowsError(try FindingCallout(finding: finding, region: region, anchor: anchor, assetRevision: "crown-reveal-2.0", provenance: "fixtures/rear.jpg", uncertainty: "Visible evidence only."))
 }
}
