import Foundation

/// What the licensing manager did on one shopping trip.
struct CuratorRun: Equatable {
    var bought: [String] = []
    var spent = 0.0
    var available = 0.0
    var note = ""
}

extension GameState {
    /// The licensing manager shops the current listings within your rules. Returns nil if there is no manager.
    /// Unspent allowance carries over (up to 3 weeks' worth) so pricier titles become affordable.
    mutating func curatorShop() -> CuratorRun? {
        guard let stored = curator, let c = effectiveCurator() else { return nil }
        var run = CuratorRun()
        if c.enabled, let block = curatorRunwayBlock {
            run.note = block
            return run
        }
        guard c.enabled else {
            run.note = "Paused."
            return run
        }
        var renewal = (names: [String](), spent: 0.0, skipped: 0)
        if c.autoRenew { renewal = curatorRenew(c, allowance: c.weeklyBudget + c.carryBudget) }
        let renewNote = renewal.names.isEmpty && renewal.skipped == 0 ? "" :
            " Renewed \(renewal.names.count) (\(Format.money(renewal.spent)))\(renewal.skipped > 0 ? ", \(renewal.skipped) too pricey to renew" : "")."
        guard catalog.count < c.targetCatalogSize else {
            var saved = stored
            saved.carryBudget = min(curatorCarryWeeks * c.weeklyBudget, max(0, c.weeklyBudget + c.carryBudget - renewal.spent))
            curator = saved
            run.note = "Your catalog already has \(catalog.count) titles (your limit is \(c.targetCatalogSize)).\(renewNote)"
            return run
        }

        var languages: Set<Language> = [.english]
        for code in markets.keys.sorted() where markets[code]?.status != .notLaunched {
            if let language = CountryData.country(code)?.language { languages.insert(language) }
        }

        let available = c.weeklyBudget + c.carryBudget - renewal.spent
        run.available = available
        var rejected: [String: Int] = [:]
        var passing: [Title] = []
        for title in licenseMarket {
            if let reason = c.rejectReason(title, languages: languages) { rejected[reason, default: 0] += 1 } else { passing.append(title) }
        }

        func value(_ title: Title) -> Double {
            guard let license = title.license else { return 0 }
            let price = max(1, licensePrice(title))
            return marketFit(of: title) * (0.5 + Double(title.quality) / 100) * sqrt(Double(license.years)) / price
        }
        passing.sort { value($0) != value($1) ? value($0) > value($1) : $0.id < $1.id }

        for title in passing {
            if run.bought.count >= Curator.maxPurchasesPerWeek || catalog.count >= c.targetCatalogSize { break }
            let price = licensePrice(title)
            if price > c.maxPricePerTitle { rejected["tooExpensive", default: 0] += 1; continue }
            if run.spent + price > available { rejected["overBudget", default: 0] += 1; continue }
            if finances.cash - price < c.cashReserve { rejected["reserve", default: 0] += 1; continue }
            if (try? buyLicense(titleID: title.id)) != nil {
                run.spent += price
                run.bought.append(title.name)
            }
        }

        var saved = stored
        saved.carryBudget = min(curatorCarryWeeks * c.weeklyBudget, max(0, available - run.spent))
        curator = saved

        if !run.bought.isEmpty {
            run.note = "Signed \(run.bought.count) title\(run.bought.count == 1 ? "" : "s") for \(Format.money(run.spent)): \(run.bought.joined(separator: ", "))."
        } else if licenseMarket.isEmpty {
            run.note = "No titles on the market right now."
        } else {
            let top = rejected.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }.prefix(3)
            let reasons = top.map { "\($0.value) \(c.describe(reason: $0.key))" }.joined(separator: ", ")
            run.note = "Nothing bought from \(licenseMarket.count) listings (\(reasons)). Available this week: \(Format.money(available)).\(renewNote)"
        }
        if !run.bought.isEmpty { run.note += renewNote }
        return run
    }

    /// Shop right now instead of waiting for the next week.
    mutating func shopNow() throws {
        guard outcome == .playing else { throw ActionError.gameOver }
        guard curator != nil else { throw ActionError.invalidProject("Hire a licensing manager first.") }
        if let run = curatorShop() { curatorStatus = "Week \(week): \(run.note)" }
    }
}
