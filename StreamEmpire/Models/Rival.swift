import Foundation

enum RivalPersonality: String, Codable {
    case aggressiveBidder, priceCutter, originalsHeavy, globalExpander, balanced, regionalChampion, nicheSpecialist

    var displayName: String {
        switch self {
        case .aggressiveBidder: return "Aggressive bidder"
        case .priceCutter: return "Price cutter"
        case .originalsHeavy: return "Originals-heavy"
        case .globalExpander: return "Global expander"
        case .balanced: return "Balanced"
        case .regionalChampion: return "Regional champion"
        case .nicheSpecialist: return "Niche specialist"
        }
    }
}

struct Rival: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var personality: RivalPersonality
    var cash: Double
    var catalogStrength: Double       // 0...100
    var subs: [String: Double]        // country code -> subscribers
    var priceLevel: Double            // 1.0 = normal; below 1 = price cuts (0.7...1.15)
    var weeklyGrowth: Double          // fractional weekly growth in existing markets
    var priceFactor: Double = 1.0     // how expensive the brand is relative to a country's fair price
    var sentiment: Double = 1.0       // investor mood: moves the share price (0.6...1.6)
    var poisonPill = false            // a defence adopted once you hold a large stake
    /// Weekly profit per subscriber (also what the engine adds to a rival's cash).
    static let profitPerSubscriberWeek = 0.12
    var annualProfit: Double { totalSubs * Rival.profitPerSubscriberWeek * 52 }
    /// Summed in sorted key order so floating-point results are identical across runs and loads.
    var totalSubs: Double { subs.keys.sorted().reduce(0) { $0 + (subs[$1] ?? 0) } }
    var countryCount: Int { subs.values.filter { $0 > 0 }.count }
}
