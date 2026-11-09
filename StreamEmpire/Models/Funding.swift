import Foundation

struct Loan: Codable, Identifiable, Equatable {
    var id: Int
    var principal: Double
    var balance: Double
    var annualRate: Double
    var weeklyPrincipal: Double     // scheduled repayment
}

/// Who owns the company.
struct Equity: Codable, Equatable {
    var ownership: Double = 1.0     // share still held by the player
    var roundsRaised: Int = 0
    var lastRoundWeek: Int = -100
    var ipoDone = false
}
