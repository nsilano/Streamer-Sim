import Foundation

extension GameState {
    /// Owned licenses that can be renewed now, soonest first.
    var expiringTitles: [Title] {
        catalog.filter { $0.license != nil && ($0.weeksRemaining ?? .max) <= Formulas.renewalWindowWeeks }
            .sorted { ($0.weeksRemaining ?? 0) != ($1.weeksRemaining ?? 0) ? ($0.weeksRemaining ?? 0) < ($1.weeksRemaining ?? 0) : $0.id < $1.id }
    }

    /// What it costs to extend this license by `years` (1...5).
    func renewalPrice(_ title: Title, years: Int) -> Double {
        guard let license = title.license else { return 0 }
        let paid = title.paidPrice > 0 ? title.paidPrice : licensePrice(title)
        let perYear = paid / Double(max(1, license.years))
        return Formulas.renewalPrice(perYearPaid: perYear, years: years,
                                     popularityGain: title.popularity - title.popularityAtPurchase, sought: title.sought)
    }

    /// True if the title is now more popular than when you signed it.
    func hasPopularityJump(_ title: Title) -> Bool { title.popularity - title.popularityAtPurchase >= 10 }

    mutating func renewLicense(titleID: Int, years: Int) throws {
        guard outcome == .playing else { throw ActionError.gameOver }
        guard let index = catalog.firstIndex(where: { $0.id == titleID }), catalog[index].license != nil else {
            throw ActionError.titleNotFound
        }
        guard (1...5).contains(years) else { throw ActionError.invalidProject("Pick a term of 1 to 5 years.") }
        let left = catalog[index].weeksRemaining ?? .max
        guard left <= Formulas.renewalWindowWeeks else {
            throw ActionError.invalidProject("You can renew within \(Formulas.renewalWindowWeeks) weeks of the end of the license.")
        }
        let price = renewalPrice(catalog[index], years: years)
        guard finances.cash >= price else { throw ActionError.insufficientFunds(needed: price) }
        finances.cash -= price
        finances.ledger.licensing += price
        catalog[index].weeksRemaining = left + years * 52
        catalog[index].license?.years = years
        catalog[index].paidPrice = price
        catalog[index].invested += price
        catalog[index].popularityAtPurchase = catalog[index].popularity
        addNews(.you, "\(companyName) renews \"\(catalog[index].name)\"",
                "Kept for \(years) more year\(years == 1 ? "" : "s") at \(Format.money(price)).")
    }

    /// Weeks left at which an expiring license can stop the sim (only with `expiryAlerts == .stop`).
    static let expiryStopWeeks = 4
    /// Minimum weeks between two expiry stops: one stop covers everything expiring in the next 8 weeks.
    static let expiryStopCooldown = 4

    /// Licenses that should stop the sim this week: only with alerts set to Stop, when a license your
    /// auto-renew style didn't take reaches 4 weeks left, at most once every 4 weeks. The stop then
    /// lists everything expiring within 8 weeks, so one pause covers a whole batch.
    var newlyExpiring: [Title] {
        guard expiryAlerts == .stop, week - lastExpiryStopWeek >= GameState.expiryStopCooldown else { return [] }
        let hit = catalog.contains { $0.license != nil && ($0.weeksRemaining ?? 99) <= GameState.expiryStopWeeks && ($0.weeksRemaining ?? 0) > 0 }
        guard hit else { return [] }
        return expiringTitles.filter { ($0.weeksRemaining ?? 99) <= 8 }
    }

    /// Total to renew every expiring title for `years`.
    func renewAllPrice(years: Int) -> Double {
        expiringTitles.reduce(0) { $0 + renewalPrice($1, years: years) }
    }

    /// Renews every expiring title you can afford, cheapest first. Returns how many were renewed.
    @discardableResult
    mutating func renewAll(years: Int) throws -> Int {
        guard outcome == .playing else { throw ActionError.gameOver }
        let queue = expiringTitles.sorted { renewalPrice($0, years: years) < renewalPrice($1, years: years) }
        guard !queue.isEmpty else { throw ActionError.invalidProject("Nothing is expiring.") }
        var renewed = 0
        for title in queue where finances.cash >= renewalPrice(title, years: years) {
            try renewLicense(titleID: title.id, years: years)
            renewed += 1
        }
        guard renewed > 0 else { throw ActionError.insufficientFunds(needed: renewalPrice(queue[0], years: years)) }
        return renewed
    }

    /// Why a renewal can't happen automatically under your renewal style, or nil if it can.
    func renewalBlock(_ title: Title) -> String? {
        let mode = renewalMode
        guard mode != .off else { return "Auto-renew is off" }
        guard let license = title.license else { return nil }
        if title.noAutoRenew { return "You excluded it from auto-renew" }
        if let why = renewalPerformanceBlock(title) { return why }
        let price = renewalPrice(title, years: renewalRules.years)
        let paidPerYear = max(1, (title.paidPrice > 0 ? title.paidPrice : licensePrice(title)) / Double(max(1, license.years)))
        let ratio = price / Double(renewalRules.years) / paidPerYear
        if ratio > mode.maxPriceRatio {
            return "Price jumped to \(String(format: "%.1f", ratio))x what you paid per year"
        }
        if price > mode.cashShare * max(0, finances.cash) {
            return "Costs \(Format.money(price)), over \(Format.percent(mode.cashShare)) of your cash"
        }
        let reserve = 4 * max(finances.lastWeek.costs, 100_000)
        if finances.cash - price < reserve { return "Would leave less than 4 weeks of costs in the bank" }
        return nil
    }

    /// Your quality bar and "let the weakest lapse" rule, or nil if the title passes. Sought-after titles skip both if you keep them.
    func renewalPerformanceBlock(_ title: Title) -> String? {
        if title.sought, renewalRules.keepSought { return nil }
        if title.quality < renewalRules.minQuality { return "Quality \(title.quality) is below your bar of \(renewalRules.minQuality)" }
        let share = renewalRules.dropWeakestShare
        guard share > 0, catalog.count >= 10 else { return nil }
        let mine = stats(for: title)
        guard mine.weeksLive >= 8 else { return nil }            // too new to judge
        let better = catalog.reduce(0) { $0 + (stats(for: $1).weeklyViewers > mine.weeklyViewers ? 1 : 0) }
        if Double(better) / Double(catalog.count) > 1 - share { return "Among your weakest \(Int(share * 100))% by viewers" }
        return nil
    }

    mutating func setAutoRenew(titleID: Int, enabled: Bool) throws {
        guard let index = catalog.firstIndex(where: { $0.id == titleID }) else { throw ActionError.titleNotFound }
        catalog[index].noAutoRenew = !enabled
    }

    mutating func updateRenewalRules(_ rules: RenewalRules) throws {
        guard outcome == .playing else { throw ActionError.gameOver }
        guard (1...5).contains(rules.years), (0...100).contains(rules.minQuality), (0...0.9).contains(rules.dropWeakestShare) else {
            throw ActionError.invalidAmount
        }
        renewalRules = rules
    }

    /// Renews (per your renewal rules, 2 years by default) every license 13 weeks or less from expiry whose price your renewal style accepts,
    /// before the 12-week warning. Only the ones it refuses ever stop the sim.
    mutating func autoRenewEverything(events: inout [GameEvent]) {
        guard renewalMode != .off else { return }
        var names: [String] = []
        var spent = 0.0
        for title in catalog where title.license != nil && (title.weeksRemaining ?? 99) <= 13 && renewalBlock(title) == nil {
            let price = renewalPrice(title, years: renewalRules.years)
            guard (try? renewLicense(titleID: title.id, years: renewalRules.years)) != nil else { continue }
            names.append(title.name)
            spent += price
        }
        if !names.isEmpty {
            events.append(makeEvent(.news, "Auto-renewed \(names.count) title\(names.count == 1 ? "" : "s")",
                                    "\(names.prefix(3).joined(separator: ", "))\(names.count > 3 ? " and more" : "") kept for \(renewalRules.years) more year\(renewalRules.years == 1 ? "" : "s") (\(Format.money(spent)))."))
        }
    }

    /// The licensing manager renews expiring titles that still pass the quality bar and fit the price and budget.
    /// Returns the names renewed, the money spent and how many were skipped.
    mutating func curatorRenew(_ c: Curator, allowance: Double) -> (names: [String], spent: Double, skipped: Int) {
        var names: [String] = []
        var spent = 0.0
        var skipped = 0
        for title in expiringTitles where (title.weeksRemaining ?? 99) <= 8 {
            guard title.quality >= c.minQuality, !title.noAutoRenew, renewalPerformanceBlock(title) == nil else { continue }
            let price = renewalPrice(title, years: c.renewYears)
            if price > c.renewMaxPrice || spent + price > allowance || finances.cash - price < c.cashReserve { skipped += 1; continue }
            if (try? renewLicense(titleID: title.id, years: c.renewYears)) != nil {
                spent += price
                names.append(title.name)
            }
        }
        return (names, spent, skipped)
    }
}
