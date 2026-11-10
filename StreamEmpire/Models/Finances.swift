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
    var originals: Double = 0
    var localization: Double = 0
    var interest: Double = 0
    var fines: Double = 0
    var other: Double = 0          // event, hiring and platform-build spending
    var tech: Double = 0           // platform upkeep and CDN
    var studios: Double = 0        // studio upkeep
    var policies: Double = 0       // running cost of policies (support, moderation, ...)
    var promotions: Double = 0     // campaign budgets
    var licenseOutRevenue: Double = 0   // fees for licensing your titles to others
    var taxes: Double = 0               // digital services taxes

    var revenue: Double { subscriptionRevenue + adRevenue + licenseOutRevenue }
    var costs: Double {
        licensing + streaming + staff + marketing + operations + launch
            + originals + localization + interest + fines + other + tech + studios + policies + promotions + taxes
    }
    var profit: Double { revenue - costs }

    /// Field-by-field sum, used for lifetime totals.
    func adding(_ other: WeeklyFinancials) -> WeeklyFinancials {
        var sum = self
        sum.subscriptionRevenue += other.subscriptionRevenue
        sum.adRevenue += other.adRevenue
        sum.licensing += other.licensing
        sum.streaming += other.streaming
        sum.staff += other.staff
        sum.marketing += other.marketing
        sum.operations += other.operations
        sum.launch += other.launch
        sum.originals += other.originals
        sum.localization += other.localization
        sum.interest += other.interest
        sum.fines += other.fines
        sum.other += other.other
        sum.tech += other.tech
        sum.studios += other.studios
        sum.policies += other.policies
        sum.promotions += other.promotions
        sum.licenseOutRevenue += other.licenseOutRevenue
        sum.taxes += other.taxes
        return sum
    }
}

/// Spend already deducted from cash since the last weekly simulation.
struct SpendLedger: Codable, Equatable {
    var licensing: Double = 0
    var launch: Double = 0
    var localization: Double = 0
    var other: Double = 0
    var promotions: Double = 0
    var licenseIncome: Double = 0   // received (already in cash); not part of `total`, which is spending

    var total: Double { licensing + launch + localization + other + promotions }
}

struct Finances: Codable, Equatable {
    var cash: Double
    var weeksInDebt: Int = 0
    var ledger = SpendLedger()
    var lastWeek = WeeklyFinancials()
    var history: [WeeklyFinancials] = []      // last 26 weeks, oldest first
    var lifetime = WeeklyFinancials()         // everything since week 1
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
