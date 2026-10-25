import Foundation

public enum MaterialRevealState: String, Codable, Equatable, Sendable { case neutral, revealing, revealed, uncertain }

/// A presentation-only surface reveal instruction. It is model-space and surface
/// aware: the renderer expands a mask along the asset's UV/normal field, never as
/// a screen-space fill or region-color overlay.
public struct MaterialReveal: Codable, Equatable, Sendable {
 public let regionId: RegionID
 public let surface: VehicleSurface
 public let state: MaterialRevealState
 public let progress: Double
 public let spreadRadius: Double
 public let anchorId: String
 public let findingAccent: FindingCalloutState?

 public init(region: CoverageRegion, anchor: VehicleSurfaceAnchor, findingAccent: FindingCalloutState? = nil) throws {
  guard region.regionId == anchor.regionId else { throw VisionValidationError.emptyEvidence }
  self.regionId = region.regionId; self.surface = anchor.surface; self.anchorId = anchor.id; self.findingAccent = findingAccent
  switch region.state {
  case .unseen, .blocked:
   self.state = .neutral; self.progress = 0; self.spreadRadius = 0
  case .partial:
   self.state = .uncertain; self.progress = 0.35; self.spreadRadius = 0.18
  case .covered:
   self.state = .revealed; self.progress = 1; self.spreadRadius = 0.42
  }
 }
}

public enum MaterialRevealPlan {
 /// Builds deterministic per-surface instructions. Regions without authored
 /// anchors remain absent, rather than receiving a guessed or flat-colored fill.
 public static func make(map: VisualMap, findings: [VisibleFinding], anchors: [RegionID: VehicleSurfaceAnchor]) throws -> [MaterialReveal] {
  let grouped = Dictionary(grouping: findings, by: \.regionId)
  return try map.regions.compactMap { region in
   guard let anchor = anchors[region.regionId] else { return nil }
   let accent = grouped[region.regionId]?.isEmpty == false ? (region.state == .covered ? FindingCalloutState.resolved : .amber) : nil
   return try MaterialReveal(region: region, anchor: anchor, findingAccent: accent)
  }
 }
}
