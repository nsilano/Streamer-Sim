import Foundation

/// Generates the rival stories: milestones and overtakes. (Launches, price moves and license wins are
/// published where they happen in `SimulationEngine`.)
enum NewsEngine {
    static let subscriberThresholds: [Double] = [1, 5, 10, 25, 50, 100, 150, 200, 250, 300, 350, 400, 500].map { $0 * 1_000_000 }
    static let profitThresholds: [Double] = [100, 250, 500, 1_000, 2_000, 3_000, 5_000, 10_000].map { $0 * 1_000_000 }

    static func key(_ rivalID: String, _ kind: String, _ threshold: Double) -> String {
        "\(rivalID)-\(kind)-\(Int(threshold / 1_000_000))"
    }

    /// Marks every milestone rivals have already passed so the feed doesn't announce them in week 1.
    static func seed(_ s: inout GameState) {
        for rival in s.rivals {
            for t in subscriberThresholds where rival.totalSubs >= t { s.milestonesReached.append(key(rival.id, "subs", t)) }
            for t in profitThresholds where rival.annualProfit >= t { s.milestonesReached.append(key(rival.id, "profit", t)) }
        }
    }

    /// Announces new rival milestones and who overtook whom. Call after rivals have been updated.
    static func update(_ s: inout GameState) {
        for rival in s.rivals {
            for t in subscriberThresholds where rival.totalSubs >= t {
                let k = key(rival.id, "subs", t)
                guard !s.milestonesReached.contains(k) else { continue }
                s.milestonesReached.append(k)
                s.addNews(.subscribers, "\(rival.name) passes \(Format.count(t)) subscribers",
                          "\(rival.name) now serves \(Format.count(rival.totalSubs)) subscribers in \(rival.countryCount) countries.",
                          rival: rival.id)
            }
            for t in profitThresholds where rival.annualProfit >= t {
                let k = key(rival.id, "profit", t)
                guard !s.milestonesReached.contains(k) else { continue }
                s.milestonesReached.append(k)
                s.addNews(.profit, "\(rival.name) hits \(Format.money(t)) in yearly profit",
                          "Analysts estimate \(rival.name) now earns about \(Format.money(rival.annualProfit)) a year after costs.",
                          rival: rival.id)
            }
        }

        let order = s.leaderboard.map { $0.id }
        var published = 0
        for index in 0..<min(6, order.count) where published < 2 {
            let id = order[index]
            guard let before = s.previousRanking.firstIndex(of: id), before > index else { continue }
            let overtaken = s.previousRanking[index]
            guard overtaken != id, let after = order.firstIndex(of: overtaken), after > index else { continue }
            func name(_ id: String) -> String {
                id == "player" ? s.companyName : (s.rivals.first { $0.id == id }?.name ?? id)
            }
            let involvesYou = id == "player" || overtaken == "player"
            s.addNews(involvesYou ? .you : .ranking, "\(name(id)) overtakes \(name(overtaken))",
                      "\(name(id)) moves up to #\(index + 1) in the global subscriber race.",
                      rival: id == "player" ? nil : id)
            published += 1
        }
        s.previousRanking = order
    }
}
