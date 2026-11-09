import Foundation

/// Running numbers for one title in your catalog.
struct TitleStats: Codable, Equatable {
    var weeklyViewers = 0.0         // people who watched it this week, all markets
    var weeklyRevenue = 0.0         // share of subscription + ad revenue credited to it this week
    var peakViewers = 0.0
    var totalViews = 0.0            // viewer-weeks since you got it
    var lifetimeRevenue = 0.0
    var licenseIncome = 0.0         // fees from licensing it out to others
    var weeksLive = 0
    var topMarket = ""              // where it is watched most this week
    var topMarketViewers = 0.0
}

/// A title you have licensed out to another service for a while.
struct LoanedTitle: Codable, Equatable {
    var title: Title
    var weeksLeft: Int
    var fee: Double
    var to: String
}
