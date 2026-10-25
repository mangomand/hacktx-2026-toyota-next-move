import Foundation

public struct VehicleEvaluationProfile: Codable, Equatable, Sendable {
    public enum Ownership: String, Codable, Sendable { case owned, leased }
    public let ownership: Ownership
    public let annualIncome: Double
    public let mileage: Int
    public let leasePayment: Double?
    public let leaseMonthsRemaining: Int?
    public let vehicleYear: Int
    public let vehicleModel: String
    public let vehicleTrim: String

    public init(ownership: Ownership, annualIncome: Double, mileage: Int, leasePayment: Double? = nil, leaseMonthsRemaining: Int? = nil, vehicleYear: Int, vehicleModel: String, vehicleTrim: String) {
        self.ownership = ownership; self.annualIncome = annualIncome; self.mileage = mileage
        self.leasePayment = leasePayment; self.leaseMonthsRemaining = leaseMonthsRemaining
        self.vehicleYear = vehicleYear; self.vehicleModel = vehicleModel; self.vehicleTrim = vehicleTrim
    }

    public var isValid: Bool {
        annualIncome > 0 && annualIncome.isFinite && (0...1_000_000).contains(mileage) &&
        (1900...Calendar.current.component(.year, from: Date()) + 1).contains(vehicleYear) &&
        !vehicleModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !vehicleTrim.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        (ownership == .owned || ((leasePayment ?? 0) > 0 && (leaseMonthsRemaining ?? 0) > 0))
    }
}

public struct VehicleEvaluationImage: Codable, Equatable, Sendable {
    public let evidenceRef: String
    public let region: String
    public let imageBase64: String
    public init(evidenceRef: String, region: String, imageBase64: String) { self.evidenceRef = evidenceRef; self.region = region; self.imageBase64 = imageBase64 }
}

public struct VehicleEvaluationRequest: Codable, Equatable, Sendable {
    public let images: [VehicleEvaluationImage]
    public let profile: VehicleEvaluationProfile
    public init(images: [VehicleEvaluationImage], profile: VehicleEvaluationProfile) { self.images = images; self.profile = profile }
}

public struct VehicleEvaluationFinding: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let region: CaptureRegion
    public let issue: String
    public let confidence: Double
    public let evidenceRefs: [String]
    public let recommendedCheck: String
}

public struct VehicleEvaluationResult: Codable, Equatable, Sendable {
    public let findings: [VehicleEvaluationFinding]
    public let resaleLow: Int
    public let resaleHigh: Int
    public let longevityParagraph: String
    public let replacementHorizon: String
    public let financialServicesRecommendation: String
    public let leaseBurden: String?
    public let assumptions: [String]
    public let uncertainty: [String]

    public var isValid: Bool {
        resaleLow >= 0 && resaleHigh >= resaleLow && resaleHigh <= 2_000_000 &&
        !longevityParagraph.isEmpty && !replacementHorizon.isEmpty && !financialServicesRecommendation.isEmpty &&
        findings.allSatisfy { !$0.id.isEmpty && !$0.issue.isEmpty && !$0.evidenceRefs.isEmpty && $0.confidence.isFinite && (0...1).contains($0.confidence) }
    }
}

/// A bounded fallback used when the analysis service is unavailable. It never
/// claims mechanical health and keeps the estimate visibly approximate.
public enum VehicleEvaluationEstimator {
    public static func estimate(profile: VehicleEvaluationProfile, findings: [VehicleEvaluationFinding]) -> VehicleEvaluationResult? {
        guard profile.isValid else { return nil }
        let age = max(0, Calendar.current.component(.year, from: Date()) - profile.vehicleYear)
        let base = max(2_000, 28_000 - age * 2_400 - profile.mileage / 10)
        let adjustment = findings.reduce(0) { $0 + ($1.issue.lowercased().contains("scratch") ? 350 : 700) }
        let low = max(1_000, base - adjustment - 1_500)
        let high = max(low, base - adjustment + 1_500)
        let horizon = age >= 10 || profile.mileage >= 120_000 ? "Plan to replace or reassess within 1–2 years." : "Reassess after the next 12 months of maintenance and mileage." 
        return VehicleEvaluationResult(findings: findings, resaleLow: low, resaleHigh: high,
            longevityParagraph: "This is a planning estimate based on age, mileage, visible observations, and the information provided. Exterior photos cannot establish hidden mechanical condition or guarantee how long the vehicle will last; have any flagged areas inspected before making a purchase or replacement decision.",
            replacementHorizon: horizon,
            financialServicesRecommendation: profile.ownership == .leased ? "Contact Toyota Financial Services to confirm the current payoff or residual, mileage allowance, and end-of-lease charges before choosing a buyout, renewal, or replacement." : "If the vehicle is financed through Toyota Financial Services, compare the remaining payoff and payment burden with the resale range before replacing it.",
            leaseBurden: profile.leasePayment.map { String(format: "%.1f%% of stated gross income", ($0 * 12 / profile.annualIncome) * 100) },
            assumptions: ["Toyota vehicle baseline; local market, trim, title, service history, and drivetrain were not verified."],
            uncertainty: ["Visible findings are model observations, not a mechanical diagnosis."])
    }
}
