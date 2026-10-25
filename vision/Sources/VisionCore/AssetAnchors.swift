import Foundation

/// Asset choices are presentation infrastructure, not canonical scan fields.
public enum VehicleAssetSource: String, Codable, Equatable, Sendable {
 case approvedUSDZ = "approved_usdz"
 case approvedGLTF = "approved_gltf"
 case generatedMultiView = "generated_multiview"
 case stylizedTurntable = "stylized_turntable"
}

public struct VehicleAssetManifest: Codable, Equatable, Sendable {
 public let id: String
 public let source: VehicleAssetSource
 public let artifactRef: String
 public let provenanceRef: String
 public let revision: String

 public init(id: String, source: VehicleAssetSource, artifactRef: String, provenanceRef: String, revision: String) throws {
  guard !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
        !artifactRef.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
        !provenanceRef.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
        !revision.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
   throw VisionValidationError.emptyArtifactRef
  }
  self.id = id; self.source = source; self.artifactRef = artifactRef
  self.provenanceRef = provenanceRef; self.revision = revision
 }
}

public enum VehicleSurface: String, Codable, Equatable, Sendable {
 case bodyPanel = "body_panel", tire, windshield, light
}

public struct CameraPoseReference: Codable, Equatable, Sendable {
 public let id: String
 public let artifactRef: String
 public let revision: String

 public init(id: String, artifactRef: String, revision: String) throws {
  guard !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
        !artifactRef.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
        !revision.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
   throw VisionValidationError.emptyArtifactRef
  }
  self.id = id; self.artifactRef = artifactRef; self.revision = revision
 }
}

/// Evidence geometry is camera-aligned reference data. It may position a
/// temporary overlay, but it never upgrades coverage or makes an unseen mesh
/// surface known. The point-cloud reference is retained for spatial layout only;
/// its visual style must not become the polished vehicle presentation.
public struct CameraAlignedEvidence: Codable, Equatable, Sendable {
 public let frameArtifactRef: String
 public let cameraPose: CameraPoseReference
 public let pointCloudArtifactRef: String?
 public let geometryRevision: String
 public let quality: Quality
 public let evidenceOnly: Bool

 public init(frameArtifactRef: String, cameraPose: CameraPoseReference, pointCloudArtifactRef: String? = nil, geometryRevision: String, quality: Quality) throws {
  guard !frameArtifactRef.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
        !geometryRevision.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
        pointCloudArtifactRef?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != true else {
   throw VisionValidationError.emptyArtifactRef
  }
  self.frameArtifactRef = frameArtifactRef; self.cameraPose = cameraPose
  self.pointCloudArtifactRef = pointCloudArtifactRef; self.geometryRevision = geometryRevision
  self.quality = quality; self.evidenceOnly = true
 }
}

public enum FindingCalloutState: String, Codable, Equatable, Sendable { case neutral, amber, resolved }

/// Presentation payload joining an existing evidence-backed finding to a stable
/// asset anchor. It cannot be constructed without finding evidence and a
/// matching canonical region; it does not detect or invent findings.
public struct FindingCallout: Codable, Equatable, Sendable {
 public let findingId: String
 public let anchorId: String
 public let regionId: RegionID
 public let evidenceRefs: [String]
 public let provenance: String
 public let uncertainty: String
 public let text: String
 public let state: FindingCalloutState
 public let assetRevision: String

 public init(finding: VisibleFinding, region: CoverageRegion, anchor: VehicleSurfaceAnchor, assetRevision: String, provenance: String, uncertainty: String) throws {
  guard finding.regionId == region.regionId, finding.regionId == anchor.regionId,
        anchor.attachment != nil,
        anchor.assetRevision == assetRevision,
        anchor.attachment?.assetRevision == assetRevision,
        !finding.evidenceRefs.isEmpty,
        finding.evidenceRefs.contains(provenance),
        !provenance.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
        !uncertainty.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
   throw VisionValidationError.emptyEvidence
  }
  self.findingId = finding.id; self.anchorId = anchor.id; self.regionId = finding.regionId
  self.evidenceRefs = finding.evidenceRefs; self.provenance = provenance
  self.uncertainty = uncertainty; self.text = finding.description
  self.state = region.state == .covered ? .resolved : (region.state == .partial ? .amber : .neutral)
  self.assetRevision = assetRevision
 }
}

/// A revisioned, normalized model-space anchor. Coordinates are presentation
/// data and never assert that an unseen surface was observed.
public struct VehicleSurfaceAnchor: Codable, Equatable, Sendable {
 public struct Position: Codable, Equatable, Sendable {
  public let x: Double; public let y: Double; public let z: Double
 }
 public let id: String
 public let regionId: RegionID
 public let surface: VehicleSurface
 public let position: Position
 public let cameraPreset: String
 public struct SurfaceAttachment: Codable, Equatable, Sendable {
  public let assetRevision: String
  public let meshId: String
  public let primitiveIndex: Int
  public let triangleIndex: Int
  public let triangleVertexIndices: [Int]
  public let barycentric: [Double]
  public let normal: Position

  public init(assetRevision: String, meshId: String, primitiveIndex: Int, triangleIndex: Int, triangleVertexIndices: [Int], barycentric: [Double], normal: (Double, Double, Double)) throws {
   guard !assetRevision.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
         !meshId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
         primitiveIndex >= 0, triangleIndex >= 0,
         triangleVertexIndices.count == 3, triangleVertexIndices.allSatisfy({ $0 >= 0 }),
         barycentric.count == 3, barycentric.allSatisfy({ $0.isFinite && $0 >= 0 && $0 <= 1 }),
         abs(barycentric.reduce(0, +) - 1) <= 0.0001,
         normal.0.isFinite && normal.1.isFinite && normal.2.isFinite,
         (normal.0 * normal.0 + normal.1 * normal.1 + normal.2 * normal.2) > 0.000001 else {
    throw VisionValidationError.emptyID
   }
   self.assetRevision = assetRevision
   self.meshId = meshId; self.primitiveIndex = primitiveIndex; self.triangleIndex = triangleIndex
   self.triangleVertexIndices = triangleVertexIndices; self.barycentric = barycentric
   self.normal = Position(x: normal.0, y: normal.1, z: normal.2)
  }
 }
 public let attachment: SurfaceAttachment?
 public let assetRevision: String

 public init(id: String, regionId: RegionID, surface: VehicleSurface, position: (Double, Double, Double), cameraPreset: String, assetRevision: String, attachment: SurfaceAttachment? = nil) throws {
  guard !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
        !cameraPreset.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
        !assetRevision.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
        position.0.isFinite && position.1.isFinite && position.2.isFinite,
        (-1...1).contains(position.0), (-1...1).contains(position.1), (-1...1).contains(position.2),
        attachment == nil || attachment?.assetRevision == assetRevision else {
   throw VisionValidationError.emptyID
  }
  self.id = id; self.regionId = regionId; self.surface = surface
  self.position = Position(x: position.0, y: position.1, z: position.2); self.cameraPreset = cameraPreset; self.assetRevision = assetRevision; self.attachment = attachment
 }

 public static func heroDefaults() throws -> [RegionID: VehicleSurfaceAnchor] {
  [
   .rear: try VehicleSurfaceAnchor(id: "rear-panel", regionId: .rear, surface: .bodyPanel, position: (0, 0.25, -0.82), cameraPreset: "rear-three-quarter", assetRevision: "hero-template-v1", attachment: .init(assetRevision: "hero-template-v1", meshId: "hero-template-rear", primitiveIndex: 0, triangleIndex: 0, triangleVertexIndices: [0, 1, 2], barycentric: [1, 0, 0], normal: (0, 0, 1))),
   .rearLeft: try VehicleSurfaceAnchor(id: "rear-left-panel", regionId: .rearLeft, surface: .bodyPanel, position: (-0.62, 0.2, -0.72), cameraPreset: "rear-left-three-quarter", assetRevision: "hero-template-v1", attachment: .init(assetRevision: "hero-template-v1", meshId: "hero-template-rear-left", primitiveIndex: 0, triangleIndex: 0, triangleVertexIndices: [0, 1, 2], barycentric: [1, 0, 0], normal: (0, 0, 1))),
   .right: try VehicleSurfaceAnchor(id: "right-side-panel", regionId: .right, surface: .bodyPanel, position: (0.88, 0.2, 0), cameraPreset: "right-side", assetRevision: "hero-template-v1", attachment: .init(assetRevision: "hero-template-v1", meshId: "hero-template-right", primitiveIndex: 0, triangleIndex: 0, triangleVertexIndices: [0, 1, 2], barycentric: [1, 0, 0], normal: (0, 0, 1))),
   .front: try VehicleSurfaceAnchor(id: "front-windshield", regionId: .front, surface: .windshield, position: (0, 0.55, 0.48), cameraPreset: "front-three-quarter", assetRevision: "hero-template-v1", attachment: .init(assetRevision: "hero-template-v1", meshId: "hero-template-windshield", primitiveIndex: 0, triangleIndex: 0, triangleVertexIndices: [0, 1, 2], barycentric: [1, 0, 0], normal: (0, 0, 1)))
  ]
 }
}
