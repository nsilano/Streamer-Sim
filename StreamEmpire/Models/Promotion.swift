import Foundation

enum PromotionKind: String, Codable, CaseIterable, Identifiable {
    case discount, freeTrial, twoForOne, blitz, winback
    var id: String { rawValue }

    var title: String {
        switch self {
        case .discount: return "Percent-off deal"
        case .freeTrial: return "Free trial blast"
        case .twoForOne: return "2-for-1 offer"
        case .blitz: return "Marketing blitz"
        case .winback: return "Win-back campaign"
        }
    }

    var icon: String {
        switch self {
        case .discount: return "percent"
        case .freeTrial: return "gift.fill"
        case .twoForOne: return "person.2.fill"
        case .blitz: return "megaphone.fill"
        case .winback: return "arrow.uturn.left.circle.fill"
        }
    }

    var blurb: String {
        switch self {
        case .discount: return "Take a chunk off every plan for a limited time. The deeper the discount, the bigger the rush."
        case .freeTrial: return "Free access for new people. Huge reach, but many only come for the freebie."
        case .twoForOne: return "Bring a friend free. Steady sign-ups at a small revenue cost."
        case .blitz: return "A big ad push and premiere buzz. Builds awareness without cutting prices."
        case .winback: return "Reach out to people who left. A gentle boost that also eases churn."
        }
    }

    var pros: [String] {
        switch self {
        case .discount: return ["Biggest sign-up boost"]
        case .freeTrial: return ["Large, fast sign-ups"]
        case .twoForOne: return ["Good boost for modest cost"]
        case .blitz: return ["No revenue hit", "Builds awareness"]
        case .winback: return ["Cheap", "Less churn while it runs"]
        }
    }

    var cons: [String] {
        switch self {
        case .discount: return ["Lowers revenue per subscriber", "Churn spike afterwards"]
        case .freeTrial: return ["Costs hosting for non-payers", "Churn spike afterwards"]
        case .twoForOne: return ["Slightly lower revenue per subscriber"]
        case .blitz: return ["Expensive every week"]
        case .winback: return ["Smaller boost"]
        }
    }

    var usesIntensity: Bool { self == .discount }
}

/// A running campaign.
struct Promotion: Codable, Identifiable, Equatable {
    var id: Int
    var kind: PromotionKind
    var scope: String            // country code, or "" for all your markets
    var weeksTotal: Int
    var weeksLeft: Int
    var intensity: Double        // discount fraction for percent-off deals
    var strength: Double         // effectiveness locked in at launch (policies, fatigue)
    var startWeek: Int
    var startSubs: Double        // subscribers in scope when it began
    var cost: Double
}

/// Churn spike after a campaign ends.
struct PromoHangover: Codable, Equatable {
    var scope: String
    var weeksLeft: Int
    var churn: Double
}

/// A finished campaign, for the results list.
struct PromoResult: Codable, Identifiable, Equatable {
    var id: Int
    var week: Int
    var kind: PromotionKind
    var scope: String
    var weeks: Int
    var cost: Double
    var subscribersGained: Double
    var note: String
}

struct PromoEffects: Equatable {
    var adds = 1.0
    var churn = 1.0
    var arpu = 1.0
    var streaming = 1.0
    var awareness = 0.0

    static let neutral = PromoEffects()
}
