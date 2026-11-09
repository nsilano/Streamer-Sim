import Foundation

struct MarketReport: Codable, Equatable, Identifiable {
    var id: String            // country code
    var newSubs: Double
    var churned: Double
    var subs: Double          // subscribers at end of week
    var revenue: Double
}

struct WeeklyReport: Codable, Equatable {
    var week: Int
    var newSubs: Double
    var churned: Double
    var totalSubs: Double
    var financials: WeeklyFinancials
    var cashEnd: Double
    var rank: Int
    var markets: [MarketReport]
    var events: [GameEvent]

    var netSubs: Double { newSubs - churned }
}
