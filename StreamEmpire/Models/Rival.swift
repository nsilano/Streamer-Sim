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

    /// Summed in sorted key order so floating-point results are identical across runs and loads.
    var totalSubs: Double { subs.keys.sorted().reduce(0) { $0 + (subs[$1] ?? 0) } }
    var countryCount: Int { subs.values.filter { $0 > 0 }.count }
}
