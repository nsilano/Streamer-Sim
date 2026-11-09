import Foundation

// MARK: Buying rights outright, licensing titles out, and per-title statistics

extension GameState {
    /// Price to own a licensed title forever (no more expiry or renewals).
    func buyoutPrice(_ title: Title) -> Double {
        guard let license = title.license, title.weeksRemaining != nil else { return 0 }
        let paid = title.paidPrice > 0 ? title.paidPrice : licensePrice(title)
        let perYear = paid / Double(max(1, license.years))
        let factor = 0.8 + Double(max(0, title.popularity - title.popularityAtPurchase)) / 50.0 + (title.sought ? 0.3 : 0)
        return perYear * Formulas.buyoutYears * factor
    }

    mutating func buyOutRights(titleID: Int) throws {
        guard outcome == .playing else { throw ActionError.gameOver }
        guard let index = catalog.firstIndex(where: { $0.id == titleID }), catalog[index].license != nil else {
            throw ActionError.titleNotFound
        }
        guard catalog[index].weeksRemaining != nil else { throw ActionError.invalidProject("You already own this title forever.") }
        let price = buyoutPrice(catalog[index])
        guard finances.cash >= price else { throw ActionError.insufficientFunds(needed: price) }
        finances.cash -= price
        finances.ledger.licensing += price
        catalog[index].weeksRemaining = nil
        catalog[index].invested += price
        addNews(.you, "\(companyName) buys \"\(catalog[index].name)\" outright",
                "The rights are yours forever for \(Format.money(price)). No more renewals.")
    }

    /// Fee for licensing a title to another service for `weeks`.
    func sublicenseFee(_ title: Title, weeks: Int) -> Double {
        let year = Formulas.licenseCost(kind: title.kind, quality: title.quality, popularity: title.popularity,
                                        years: 1, ageWeeks: title.ageWeeks, exclusive: false)
        return year * Formulas.sublicenseShare * Double(weeks) / 52.0
            * Formulas.licenseAudienceScale(totalSubscribers: totalSubscribers) * costScale * (title.sought ? Formulas.soughtPremium : 1)
    }

    /// Take a title off your service for a while and collect a fee from another service.
    mutating func licenseOut(titleID: Int, weeks: Int) throws {
        guard outcome == .playing else { throw ActionError.gameOver }
        guard let index = catalog.firstIndex(where: { $0.id == titleID }) else { throw ActionError.titleNotFound }
        guard Formulas.sublicenseTerms.contains(weeks) else { throw ActionError.invalidProject("Pick 13, 26, 52 or 104 weeks.") }
        if let left = catalog[index].weeksRemaining, left <= weeks {
            throw ActionError.invalidProject("You only hold the rights for \(left) more weeks.")
        }
        let fee = sublicenseFee(catalog[index], weeks: weeks)
        let title = catalog.remove(at: index)
        let buyers = rivals.filter { $0.totalSubs > 0 }
        let buyer = buyers.isEmpty ? "a rival service" : buyers[rng.nextInt(in: 0...(buyers.count - 1))].name
        finances.cash += fee
        finances.ledger.licenseIncome += fee
        titleStats[title.id, default: TitleStats()].licenseIncome += fee
        loanedOut.append(LoanedTitle(title: title, weeksLeft: weeks, fee: fee, to: buyer))
        addNews(.you, "\(companyName) licenses \"\(title.name)\" to \(buyer)",
                "\(Format.money(fee)) for \(weeks) weeks. It is off your service until it comes back.")
    }

    // MARK: Statistics

    mutating func resetWeeklyTitleStats() {
        for id in titleStats.keys.sorted() {
            titleStats[id]?.weeklyViewers = 0
            titleStats[id]?.weeklyRevenue = 0
            titleStats[id]?.topMarketViewers = 0
        }
    }

    /// Credits viewers and revenue in one market to the titles, in proportion to their appeal there.
    mutating func recordTitleViews(code: String, titles: [Title], country: Country, subs: Double, revenue: Double) {
        guard subs > 0, !titles.isEmpty else { return }
        let appeals = titles.map { Formulas.titleAppeal($0, in: country) }
        let total = appeals.reduce(0, +)
        guard total > 0 else { return }
        for (title, appeal) in zip(titles, appeals) {
            let share = appeal / total
            let viewers = subs * min(0.9, Formulas.viewingPerSubscriber * share)
            var stats = titleStats[title.id, default: TitleStats()]
            stats.weeklyViewers += viewers
            stats.weeklyRevenue += revenue * share
            if viewers > stats.topMarketViewers { stats.topMarketViewers = viewers; stats.topMarket = code }
            titleStats[title.id] = stats
        }
    }

    mutating func finalizeTitleStats() {
        for title in catalog {
            guard var stats = titleStats[title.id] else { continue }
            stats.totalViews += stats.weeklyViewers
            stats.lifetimeRevenue += stats.weeklyRevenue
            stats.peakViewers = max(stats.peakViewers, stats.weeklyViewers)
            stats.weeksLive += 1
            titleStats[title.id] = stats
        }
    }

    func stats(for title: Title) -> TitleStats { titleStats[title.id] ?? TitleStats() }

    /// Revenue plus licensing fees minus what you spent on it.
    func netReturn(_ title: Title) -> Double {
        let s = stats(for: title)
        return s.lifetimeRevenue + s.licenseIncome - title.invested
    }
}

/// Counts down titles licensed out and brings them home.
func progressLoans(_ s: inout GameState, events: inout [GameEvent]) {
    guard !s.loanedOut.isEmpty else { return }
    var remaining: [LoanedTitle] = []
    for var loan in s.loanedOut {
        loan.weeksLeft -= 1
        loan.title.ageWeeks += 1
        if let left = loan.title.weeksRemaining { loan.title.weeksRemaining = left - 1 }
        if let left = loan.title.weeksRemaining, left <= 0 {
            s.titleStats[loan.title.id] = nil
            events.append(s.makeEvent(.licenseExpired, "License expired",
                                      "\"\(loan.title.name)\" ran out of rights while licensed to \(loan.to)."))
        } else if loan.weeksLeft <= 0 {
            loan.title.listingWeeksLeft = 0
            s.catalog.append(loan.title)
            events.append(s.makeEvent(.news, "\"\(loan.title.name)\" is back",
                                      "\(loan.to) is done with it. It's on your service again."))
        } else {
            remaining.append(loan)
        }
    }
    s.loanedOut = remaining
}
