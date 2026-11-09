import Foundation

enum PolicyCategory: String, CaseIterable, Identifiable {
    case accounts, pricing, content, ads, product, retention, partnerships
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .accounts: return "Accounts & sharing"
        case .pricing: return "Pricing & offers"
        case .content: return "Content & ratings"
        case .ads: return "Ads & data"
        case .product: return "Product & quality"
        case .retention: return "Keeping subscribers"
        case .partnerships: return "Partnerships"
        }
    }

    var icon: String {
        switch self {
        case .accounts: return "person.2.badge.key.fill"
        case .pricing: return "tag.fill"
        case .content: return "film.stack"
        case .ads: return "rectangle.3.group.fill"
        case .product: return "sparkles.tv.fill"
        case .retention: return "arrow.triangle.2.circlepath"
        case .partnerships: return "link"
        }
    }
}

/// What a policy option does to the business every week. Multipliers are 1.0 when neutral.
struct PolicyEffects: Equatable {
    var adds = 1.0              // new subscribers
    var churn = 1.0             // subscribers lost
    var arpu = 1.0              // subscription revenue per subscriber
    var adRevenue = 1.0
    var streamingCost = 1.0
    var fines = 1.0
    var awareness = 0.0         // weekly drift added to brand awareness
    var trust = 0.0             // weekly drift of brand trust (points)
    var heat = 0.0              // weekly drift of regulatory heat (points)
    var overhead = 0.0          // extra running cost as a share of revenue
    var flatCost = 0.0          // extra running cost per week

    static let neutral = PolicyEffects()

    /// Multipliers multiply; drifts and costs add.
    mutating func combine(_ other: PolicyEffects) {
        adds *= other.adds
        churn *= other.churn
        arpu *= other.arpu
        adRevenue *= other.adRevenue
        streamingCost *= other.streamingCost
        fines *= other.fines
        awareness += other.awareness
        trust += other.trust
        heat += other.heat
        overhead += other.overhead
        flatCost += other.flatCost
    }
}

/// How the world reacts when you change a policy.
struct PolicyOutcome: Equatable {
    var headline: String
    var detail: String
    var subsPct = 0.0           // immediate change in subscribers (+0.03 = +3%)
    var trust = 0.0             // immediate brand trust change (points)
    var heat = 0.0              // immediate regulatory heat change (points)
    var shockWeeks = 0          // weeks of temporary extra churn / sign-ups
    var shockChurn = 1.0
    var shockAdds = 1.0
    var rivalPounces = false    // a rival capitalises on it
}

struct PolicyOption: Identifiable, Equatable {
    var id: String
    var title: String
    var detail: String
    var effects: PolicyEffects
    var cost = 0.0                      // one-time cost to enact
    var minSubscribers = 0.0            // audience needed before you can try this
    var pros: [String]
    var cons: [String]
    var badChance = 0.0                 // risk of a bad reaction (lower with high brand trust)
    var good: PolicyOutcome?
    var bad: PolicyOutcome?
}

struct PolicyDefinition: Identifiable, Equatable {
    var id: String
    var category: PolicyCategory
    var title: String
    var icon: String
    var summary: String
    var defaultOption: String
    var options: [PolicyOption]

    func option(_ id: String) -> PolicyOption? { options.first { $0.id == id } }
}

enum PolicyTone: String, Codable {
    case good, mixed, bad
}

/// A line in the policy reaction log.
struct PolicyReaction: Codable, Identifiable, Equatable {
    var id: Int
    var week: Int
    var policyTitle: String
    var optionTitle: String
    var tone: PolicyTone
    var headline: String
    var detail: String
    var subscribersChange: Double
}

/// Temporary extra churn or sign-ups after a policy change.
struct PolicyShock: Codable, Equatable {
    var policyID: String
    var weeksLeft: Int
    var churn: Double
    var adds: Double
}
