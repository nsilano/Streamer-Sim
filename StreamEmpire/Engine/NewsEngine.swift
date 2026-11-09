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

    // MARK: Your price changes

    /// Publishes this week's net price changes: one story per country, or a summary if you changed many.
    static func publishPlayerPrices(_ s: inout GameState) {
        struct Change { var code: String; var old: TierSet; var new: TierSet }
        var changes: [Change] = []
        for code in s.pendingPriceChanges.keys.sorted() {
            guard let old = s.pendingPriceChanges[code], let new = s.markets[code]?.prices else { continue }
            if Tier.allCases.contains(where: { abs(old[$0] - new[$0]) > 0.005 }) { changes.append(Change(code: code, old: old, new: new)) }
        }
        s.pendingPriceChanges = [:]
        guard !changes.isEmpty else { return }

        func lines(_ c: Change) -> String {
            Tier.allCases.filter { abs(c.old[$0] - c.new[$0]) > 0.005 }.map { tier in
                let pct = c.old[tier] > 0 ? (c.new[tier] - c.old[tier]) / c.old[tier] * 100 : 0
                return String(format: "%@ $%.2f → $%.2f (%@%.0f%%)", tier.displayName, c.old[tier], c.new[tier], pct >= 0 ? "+" : "", pct)
            }.joined(separator: ", ")
        }
        func direction(_ c: Change) -> Int {
            let delta = Tier.allCases.reduce(0.0) { $0 + (c.new[$1] - c.old[$1]) }
            return delta > 0 ? 1 : (delta < 0 ? -1 : 0)
        }

        if changes.count <= 3 {
            for change in changes {
                let country = CountryData.country(change.code)
                let verb = direction(change) > 0 ? "raises prices" : (direction(change) < 0 ? "cuts prices" : "reshuffles its plans")
                s.addNews(.pricing, "\(s.companyName) \(verb) in \(country?.name ?? change.code)", lines(change))
            }
        } else {
            let up = changes.filter { direction($0) > 0 }.count
            let down = changes.filter { direction($0) < 0 }.count
            s.addNews(.pricing, "\(s.companyName) changes prices in \(changes.count) markets",
                      "\(up) increases and \(down) cuts, including \(changes.prefix(3).compactMap { CountryData.country($0.code)?.name }.joined(separator: ", ")).")
        }
    }

    // MARK: Rival price example

    /// "Standard in Ireland: $11.49 → $9.99" for the rival's biggest market.
    static func priceExample(_ rival: Rival, before: Double, after: Double) -> String {
        guard let code = rival.subs.keys.sorted().max(by: { (rival.subs[$0] ?? 0) < (rival.subs[$1] ?? 0) }),
              let country = CountryData.country(code) else { return "" }
        let from = Formulas.rivalPrice(country: country, priceFactor: rival.priceFactor, priceLevel: before, tier: .standard)
        let to = Formulas.rivalPrice(country: country, priceFactor: rival.priceFactor, priceLevel: after, tier: .standard)
        return String(format: " Standard in %@: $%.2f → $%.2f.", country.name, from, to)
    }
}
