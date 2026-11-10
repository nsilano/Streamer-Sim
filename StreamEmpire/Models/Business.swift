import Foundation

/// One quarter's results, judged against what analysts expected.
struct QuarterReport: Codable, Equatable, Identifiable {
    var id: Int                    // quarter number
    var week: Int
    var revenue: Double
    var profit: Double             // cash profit
    var accountingProfit: Double   // content costs spread over two years
    var expectedProfit: Double
    var subscribers: Double
    var verdict: String            // "beat", "met" or "missed"
}

/// Product features you build once and keep paying for.
enum ProductFeature: String, Codable, CaseIterable, Identifiable {
    case kidsProfiles, downloads, fourK, recommendations
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .kidsProfiles: return "Kids profiles"
        case .downloads: return "Offline downloads"
        case .fourK: return "4K streaming"
        case .recommendations: return "Recommendation engine"
        }
    }
    var blurb: String {
        switch self {
        case .kidsProfiles: return "Families stay longer: churn -3%."
        case .downloads: return "Big in lower-income markets: churn -3% and +4% sign-ups there, -1% elsewhere."
        case .fourK: return "Churn -2% and it cancels the 4K-expectation trend, but streaming costs +12%."
        case .recommendations: return "Each level makes your catalog work harder: +3% appeal per level."
        }
    }
    var maxLevel: Int { self == .recommendations ? 3 : 1 }
    var baseCost: Double {
        switch self { case .kidsProfiles: return 1_500_000; case .downloads: return 1_000_000
                      case .fourK: return 2_000_000; case .recommendations: return 1_200_000 }
    }
    var baseUpkeep: Double {
        switch self { case .kidsProfiles: return 12_000; case .downloads: return 8_000
                      case .fourK: return 20_000; case .recommendations: return 10_000 }
    }
}

/// A sports rights package up for auction.
struct SportsOffer: Codable, Equatable, Identifiable {
    var id: Int
    var name: String
    var region: Region
    var askPrice: Double
    var weeksLeft: Int
}

struct SportsRight: Codable, Equatable, Identifiable {
    var id: Int
    var name: String
    var region: Region
    var weeksLeft: Int
}

enum PartnershipKind: String, Codable, CaseIterable, Identifiable {
    case carrier, rivalBundle
    var id: String { rawValue }
    var displayName: String { self == .carrier ? "Mobile carrier bundle" : "Bundle with a rival" }
    var blurb: String {
        self == .carrier ? "+25% sign-ups, but bundled customers pay 12% less."
                         : "+15% sign-ups, bundled customers pay 8% less. Needs a rival in that country."
    }
    var adds: Double { self == .carrier ? 1.25 : 1.15 }
    var arpu: Double { self == .carrier ? 0.88 : 0.92 }
}

struct Partnership: Codable, Equatable, Identifiable {
    var id: Int
    var country: String
    var kind: PartnershipKind
    var weeksLeft: Int
}

enum AcquisitionKind: String, Codable { case library, studio }

/// A chance to buy a film library or a small studio outright.
struct AcquisitionOffer: Codable, Equatable, Identifiable {
    var id: Int
    var kind: AcquisitionKind
    var name: String
    var price: Double
    var titleCount: Int
    var weeksLeft: Int
}

/// A studio that delivers a new title to you every few weeks for a weekly fee.
struct OutputDeal: Codable, Equatable, Identifiable {
    var id: Int
    var studio: String
    var genre: Genre
    var weeklyFee: Double
    var weeksLeft: Int
    var nextDelivery: Int          // weeks until the next title arrives
    var delivered = 0
}
