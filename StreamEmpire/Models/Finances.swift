import Foundation

/// One week of income and costs. `costs` includes licensing and launch spend
/// that was paid (and deducted from cash) earlier in the week.
struct WeeklyFinancials: Codable, Equatable {
    var subscriptionRevenue: Double = 0
    var adRevenue: Double = 0
    var licensing: Double = 0
    var streaming: Double = 0
    var staff: Double = 0
    var marketing: Double = 0
    var operations: Double = 0
    var launch: Double = 0

    var revenue: Double { subscriptionRevenue + adRevenue }
    var costs: Double { licensing + streaming + staff + marketing + operations + launch }
    var profit: Double { revenue - costs }
}

/// Spend already deducted from cash since the last weekly simulation.
struct SpendLedger: Codable, Equatable {
    var licensing: Double = 0
    var launch: Double = 0
}

struct Finances: Codable, Equatable {
    var cash: Double
    var weeksInDebt: Int = 0
    var ledger = SpendLedger()
    var lastWeek = WeeklyFinancials()
    var profitHistory: [Double] = []      // last 12 weeks
    var revenueHistory: [Double] = []     // last 52 weeks

    /// Average weekly profit over the last (up to) 4 weeks.
    var recentWeeklyProfit: Double {
        let recent = profitHistory.suffix(4)
        guard !recent.isEmpty else { return 0 }
        return recent.reduce(0, +) / Double(recent.count)
    }

    /// Weeks of cash left at the current burn rate; nil if profitable.
    var runwayWeeks: Double? {
        let profit = recentWeeklyProfit
        guard profit < 0 else { return nil }
        return max(0, cash) / -profit
    }

    /// Annualized revenue (last up to 52 weeks, scaled to a full year).
    var annualizedRevenue: Double {
        guard !revenueHistory.isEmpty else { return 0 }
        return revenueHistory.reduce(0, +) / Double(revenueHistory.count) * 52
    }
}
