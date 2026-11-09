import Foundation

enum NewsKind: String, Codable, CaseIterable {
    case expansion, subscribers, profit, pricing, licensing, ranking, industry, you

    var displayName: String {
        switch self {
        case .expansion: return "Expansion"
        case .subscribers: return "Subscribers"
        case .profit: return "Profit"
        case .pricing: return "Pricing"
        case .licensing: return "Licensing"
        case .ranking: return "Rankings"
        case .industry: return "Industry"
        case .you: return "You"
        }
    }

    var icon: String {
        switch self {
        case .expansion: return "globe.europe.africa.fill"
        case .subscribers: return "person.3.fill"
        case .profit: return "dollarsign.circle.fill"
        case .pricing: return "tag.fill"
        case .licensing: return "film.stack"
        case .ranking: return "trophy.fill"
        case .industry: return "newspaper.fill"
        case .you: return "star.fill"
        }
    }
}

/// One story in the in-game news feed.
struct NewsItem: Codable, Identifiable, Equatable {
    var id: Int
    var week: Int
    var kind: NewsKind
    var headline: String
    var body: String
    var rivalID: String?
}

/// Where your spending goes, for the Finances screen.
enum CostCategory: String, CaseIterable, Identifiable {
    case licensing, originals, localization, streaming, staff, marketing, operations, tech, studios, policies, promotions, launch, interest, fines, other
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .licensing: return "Licensing titles"
        case .originals: return "Making originals"
        case .localization: return "Dubbing & subtitles"
        case .streaming: return "Streaming & hosting"
        case .staff: return "Staff & overhead"
        case .marketing: return "Marketing"
        case .operations: return "Running countries"
        case .tech: return "Servers & apps"
        case .studios: return "Studio upkeep"
        case .policies: return "Policy programs"
        case .promotions: return "Promotions"
        case .launch: return "Launches & new plans"
        case .interest: return "Loan interest"
        case .fines: return "Regulatory fines"
        case .other: return "Hiring, builds & events"
        }
    }

    var icon: String {
        switch self {
        case .licensing: return "film.stack"
        case .originals: return "clapperboard.fill"
        case .localization: return "character.bubble.fill"
        case .streaming: return "antenna.radiowaves.left.and.right"
        case .staff: return "person.2.fill"
        case .marketing: return "megaphone.fill"
        case .operations: return "building.2.fill"
        case .tech: return "server.rack"
        case .studios: return "building.columns.fill"
        case .policies: return "list.bullet.clipboard.fill"
        case .promotions: return "megaphone.fill"
        case .launch: return "paperplane.fill"
        case .interest: return "percent"
        case .fines: return "exclamationmark.triangle.fill"
        case .other: return "wrench.and.screwdriver.fill"
        }
    }

    func amount(in week: WeeklyFinancials) -> Double {
        switch self {
        case .licensing: return week.licensing
        case .originals: return week.originals
        case .localization: return week.localization
        case .streaming: return week.streaming
        case .staff: return week.staff
        case .marketing: return week.marketing
        case .operations: return week.operations
        case .tech: return week.tech
        case .studios: return week.studios
        case .policies: return week.policies
        case .promotions: return week.promotions
        case .launch: return week.launch
        case .interest: return week.interest
        case .fines: return week.fines
        case .other: return week.other
        }
    }
}
