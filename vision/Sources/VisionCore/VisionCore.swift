import Foundation

public enum VisionValidationError: Error, Equatable { case emptyID, emptyArtifactRef, emptyRegions, invalidConfidence, emptyEvidence, duplicateFrameID(String), conflictingFrameID(String), prohibitedClaim }
public enum RegionID: String, CaseIterable, Codable, Sendable { case front, frontLeft = "front-left", left, rearLeft = "rear-left", rear, rearRight = "rear-right", right, frontRight = "front-right", roof, interiorFront = "interior-front", interiorRear = "interior-rear", trunk }
public enum CoverageState: String, Codable, Sendable { case unseen, partial, covered, blocked }
public enum Quality: String, Codable, Sendable { case unknown, low, acceptable, high }
public enum FindingCategory: String, Codable, Sendable { case visibleDamage = "visible_damage", wear, warningIndicator = "warning_indicator", missingContext = "missing_context", unknown }
public enum FindingSeverity: String, Codable, Sendable { case info, low, medium, high, unknown }
public enum FindingStatus: String, Codable, Sendable { case observed, needsReview = "needs_review", unseen, notADiagnosis = "not_a_diagnosis" }

public struct ReplayFrame: Codable, Equatable, Sendable {
 public let id: String; public let artifactRef: String; public let regions: [RegionID]; public let quality: Quality; public let glareLimited: Bool; public let motionBlur: Bool; public let visibleObservation: String?
 public init(id:String, artifactRef:String, regions:[RegionID], quality:Quality, glareLimited:Bool=false, motionBlur:Bool=false, visibleObservation:String?=nil) throws { guard !id.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else { throw VisionValidationError.emptyID }; guard !artifactRef.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else { throw VisionValidationError.emptyArtifactRef }; guard !regions.isEmpty else { throw VisionValidationError.emptyRegions }; self.id=id; self.artifactRef=artifactRef; self.regions=regions; self.quality=quality; self.glareLimited=glareLimited; self.motionBlur=motionBlur; self.visibleObservation=visibleObservation }
 private enum CodingKeys: String, CodingKey { case id, artifactRef, regions, quality, glareLimited, motionBlur, visibleObservation }
 public init(from decoder: Decoder) throws { let c=try decoder.container(keyedBy:CodingKeys.self); try self.init(id: c.decode(String.self,forKey:.id), artifactRef:c.decode(String.self,forKey:.artifactRef), regions:c.decode([RegionID].self,forKey:.regions), quality:c.decode(Quality.self,forKey:.quality), glareLimited:c.decodeIfPresent(Bool.self,forKey:.glareLimited) ?? false, motionBlur:c.decodeIfPresent(Bool.self,forKey:.motionBlur) ?? false, visibleObservation:c.decodeIfPresent(String.self,forKey:.visibleObservation)) }
}

public struct CoverageRegion: Codable, Equatable, Sendable { public let regionId: RegionID; public let state: CoverageState; public let quality: Quality; public let observedAt: Date; public let artifactRefs: [String]?; public let notes: String? }
public struct VisualMap: Equatable, Sendable { public let regions: [CoverageRegion]; public let unknownRegions: [RegionID] }

/// Presentation-only semantic tokens for the progressive vehicle map. These are
/// deliberately state-shaped rather than UI color values so clients can choose
/// an accessible palette without changing the canonical coverage contract.
public enum MapRegionColor: String, Codable, Equatable, Sendable {
 case covered, partial, blocked, unknown
}

public struct MapRegionPresentation: Equatable, Sendable {
 public let regionId: RegionID
 public let state: CoverageState
 public let quality: Quality
 public let color: MapRegionColor
 public let findings: [VisibleFinding]
 public let isUnknown: Bool
 public let accessibilityText: String

 fileprivate init(region: CoverageRegion, findings: [VisibleFinding]) {
  self.regionId = region.regionId
  self.state = region.state
  self.quality = region.quality
  self.color = Self.color(for: region.state)
  self.findings = findings
  self.isUnknown = region.state != .covered
  let quality = region.quality.rawValue
  let findingText = findings.isEmpty ? "no visible findings" : "\(findings.count) visible finding\(findings.count == 1 ? "" : "s")"
  self.accessibilityText = "\(region.regionId.rawValue): \(region.state.rawValue), \(quality) quality, \(findingText)"
 }

 static func color(for state: CoverageState) -> MapRegionColor {
  switch state { case .covered: .covered; case .partial: .partial; case .blocked: .blocked; case .unseen: .unknown }
 }
}

/// A deterministic, bounded presentation model for a progressive 2.5D map.
/// It carries canonical region status and evidence-backed findings without
/// implying that an uncovered area is clear or mechanically healthy.
public struct MapPresentation: Equatable, Sendable {
 public static let maxAnalysisLength = 240
 public let regions: [MapRegionPresentation]
 public let unknownRegions: [RegionID]
 public let analysis: String

 fileprivate init(map: VisualMap, findings: [VisibleFinding]) {
  let findingsByRegion = Dictionary(grouping: findings, by: \.regionId)
  self.regions = map.regions.map { MapRegionPresentation(region: $0, findings: findingsByRegion[$0.regionId] ?? []) }
  self.unknownRegions = map.unknownRegions
  let covered = map.regions.filter { $0.state == .covered }.count
  let unknown = map.unknownRegions.count
  let findingCount = findings.count
  var text = "\(covered) of \(map.regions.count) regions have quality-gated coverage."
  if unknown > 0 { text += " \(unknown) region\(unknown == 1 ? " needs" : "s need") another view." }
  if findingCount > 0 { text += " \(findingCount) visible observation\(findingCount == 1 ? "" : "s") attached to the map." }
  self.analysis = String(text.prefix(Self.maxAnalysisLength))
 }
}
public struct VisibleFinding: Codable, Equatable, Sendable {
 public let id: String; public let category: FindingCategory; public let severity: FindingSeverity; public let confidence: Double; public let status: FindingStatus; public let regionId: RegionID; public let description: String; public let evidenceRefs: [String]; public let recommendedCheck: String?
 private enum CodingKeys: String, CodingKey { case id, category, severity, confidence, status, regionId, description, evidenceRefs, recommendedCheck }
 fileprivate init(id:String, category:FindingCategory, severity:FindingSeverity, confidence:Double, status:FindingStatus, regionId:RegionID, description:String, evidenceRefs:[String], recommendedCheck:String?) { self.id=id; self.category=category; self.severity=severity; self.confidence=confidence; self.status=status; self.regionId=regionId; self.description=description; self.evidenceRefs=evidenceRefs; self.recommendedCheck=recommendedCheck }
 public init(from decoder: Decoder) throws { let c=try decoder.container(keyedBy:CodingKeys.self); let id=try c.decode(String.self,forKey:.id); guard !id.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else { throw VisionValidationError.emptyID }; let rebuilt=try VisibleFindingRules.finding(id:id,region:try c.decode(RegionID.self,forKey:.regionId),description:try c.decode(String.self,forKey:.description),confidence:try c.decode(Double.self,forKey:.confidence),evidenceRefs:try c.decode([String].self,forKey:.evidenceRefs),category:try c.decode(FindingCategory.self,forKey:.category),severity:try c.decode(FindingSeverity.self,forKey:.severity)); self=rebuilt }
}
public struct ReplayOutput: Equatable, Sendable { public let map: VisualMap; public let findings: [VisibleFinding]; public let presentation: MapPresentation
 public var mapPresentation: MapPresentation { presentation }
}

public enum SyntheticReplay {
 public static let allRegions = RegionID.allCases
 public static let img1404 = try! ReplayFrame(id:"IMG_1404-quality-only",artifactRef:"fixtures/vision/IMG_1404.mov",regions:[.left,.rearLeft,.rear,.rearRight,.right],quality:.low,glareLimited:true,motionBlur:true)
 public static let visibleObservation = try! ReplayFrame(id:"visible-panel-observation",artifactRef:"fixtures/vision/panel-observation.jpg",regions:[.rear],quality:.high,visibleObservation:"Visible surface mark on the rear panel")
 public static func run(frames:[ReplayFrame], startedAt:Date) throws -> ReplayOutput {
  var unique:[String:ReplayFrame]=[:]
  for frame in frames { if let prior=unique[frame.id] { guard prior == frame else { throw VisionValidationError.conflictingFrameID(frame.id) } } else { unique[frame.id]=frame } }
  // Keep the reducer deterministic: frame IDs define replay order, quality retains
  // the best evidence seen, and a glare/motion limitation is sticky for that
  // region. A later clear acceptable/high frame can recover a low-quality partial
  // region, but it cannot erase a limitation that was actually observed.
  var obs:[RegionID:(quality:Quality,artifactRefs:[String],limited:Bool)]=[:]; var findings:[VisibleFinding]=[]
  for frame in unique.values.sorted(by:{$0.id < $1.id}) {
   let limited=frame.glareLimited || frame.motionBlur
   for region in frame.regions {
    if let current=obs[region] {
     let quality=rank(frame.quality) > rank(current.quality) ? frame.quality : current.quality
     obs[region]=(quality,current.artifactRefs+[frame.artifactRef],current.limited || limited)
    } else {
     obs[region]=(frame.quality,[frame.artifactRef],limited)
    }
   }
   if let text=frame.visibleObservation, !limited, let region=frame.regions.first { findings.append(try VisibleFindingRules.finding(id:"finding-\(frame.id)",region:region,description:text,confidence:0.9,evidenceRefs:[frame.artifactRef])) }
  }
  let regions=allRegions.map { region -> CoverageRegion in
   guard let item=obs[region] else { return CoverageRegion(regionId:region,state:.unseen,quality:.unknown,observedAt:startedAt,artifactRefs:nil,notes:"not observed in replay") }
   let state:CoverageState=(rank(item.quality) >= rank(.acceptable) && !item.limited) ? .covered : .partial
   let notes=item.limited ? "quality limited; visible evidence remains uncertain" : nil
   return CoverageRegion(regionId:region,state:state,quality:item.quality,observedAt:startedAt,artifactRefs:item.artifactRefs,notes:notes)
  }
  let map = VisualMap(regions:regions,unknownRegions:regions.filter{$0.state != .covered}.map(\.regionId))
  return ReplayOutput(map:map,findings:findings,presentation:MapPresentation(map:map,findings:findings))
 }
 private static func rank(_ q:Quality)->Int { switch q { case .unknown:0; case .low:1; case .acceptable:2; case .high:3 } }
}

public enum VisibleFindingRules {
 private static let prohibited=["safe","healthy","bent","functioning","roadworthy","clear to drive","unsafe","mechanical","hidden damage","hidden condition","engine failure","brake failure","transmission","diagnos","no damage","frame is bent","brakes functioning"]
 public static func finding(id:String,region:RegionID,description:String,confidence:Double,evidenceRefs:[String],category:FindingCategory = .visibleDamage,severity:FindingSeverity = .medium) throws -> VisibleFinding { guard !evidenceRefs.isEmpty && evidenceRefs.allSatisfy({ !$0.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty }) else { throw VisionValidationError.emptyEvidence }; guard confidence.isFinite && (0...1).contains(confidence) else { throw VisionValidationError.invalidConfidence }; let normalized=description.lowercased(); let safeDescription=prohibited.contains(where:{normalized.contains($0)}) ? "Visible observation requires qualified review; mechanical condition is unknown." : description; return VisibleFinding(id:id,category:category,severity:severity,confidence:confidence,status:.notADiagnosis,regionId:region,description:safeDescription,evidenceRefs:evidenceRefs,recommendedCheck:"Review this visible area with a qualified person") }
}
