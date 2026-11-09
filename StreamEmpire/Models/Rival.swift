import Foundation

enum RivalPersonality: String, Codable {
    case aggressiveBidder, priceCutter, originalsHeavy, globalExpander, balanced

    var displayName: String {
        switch self {
        case .aggressiveBidder: return "Aggressive bidder"
        case .priceCutter: return "Price cutter"
        case .originalsHeavy: return "Originals-heavy"
        case .globalExpander: return "Global expander"
        case .balanced: return "Balanced"
        }
    }
}

struct Rival: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var personality: RivalPersonality
    var cash: Double
    var catalogStrength: Double       // 0...100
    var subs: [String: Double]        // country code -> subscribers (modeled markets)
    /// Subscribers in markets not yet modeled. Replaced by per-country data in Phase 2.
    var legacySubs: Double
    var weeklyGrowth: Double          // fractional weekly growth

    var totalSubs: Double { legacySubs + subs.values.reduce(0, +) }
}
