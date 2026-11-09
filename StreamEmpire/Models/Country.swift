import Foundation

/// Minimum requirement to unlock a big market. Meeting EITHER threshold unlocks it.
struct UnlockRequirement: Codable, Equatable {
    var minGlobalSubs: Double
    var minCatalogSize: Int
}

/// Static country definition (never changes during a game).
struct Country: Codable, Identifiable, Equatable {
    let id: String                       // ISO-style code, e.g. "IE"
    let name: String
    let flag: String
    let region: Region
    let households: Double               // broadband households, millions
    let priceTolerance: Double           // monthly USD at which the Standard tier is "fair"
    let adStrength: Double               // 0...1 ad market strength
    let genreTaste: [Genre: Double]      // multipliers, ~1.0 average
    let language: Language
    let localQuota: Double               // share of catalog that should be local (used from Phase 3)
    let launchCost: Double
    let regulatoryRisk: Double           // 0...1
    let unlock: UnlockRequirement?
    let isStarterPick: Bool

    var code: String { id }

    /// Streaming subscriptions per broadband household. Real households hold several services, and richer
    /// countries hold more (about 4 in the US and 1.8 in lower-income markets).
    var subscriptionsPerHousehold: Double { min(4.5, max(1.0, 1.2 + 0.2 * priceTolerance)) }

    /// Total paid subscriptions the country can hold across ALL services (not just yours).
    var subscriberCeiling: Double { households * 1_000_000 * subscriptionsPerHousehold }

    func taste(_ genre: Genre) -> Double { genreTaste[genre] ?? 1.0 }

    /// Short description of the market's size for the start screen.
    var sizeHint: String {
        if households < 5 { return "Small & cozy" }
        if households < 20 { return "Mid-size" }
        if households < 50 { return "Large" }
        return "Huge market"
    }

    /// Short description of what people can afford.
    var incomeHint: String {
        if priceTolerance >= 10 { return "High income" }
        if priceTolerance >= 5 { return "Middle income" }
        return "Low prices, thin margins"
    }
}
