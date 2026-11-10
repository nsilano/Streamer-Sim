import Foundation

/// Hands-on decisions a streaming CEO makes: negotiating, output deals, exiting markets,
/// cancelling productions, pulling titles, and corporate finance.
extension GameState {
    // MARK: License negotiation

    /// The asking price for a listing under different terms.
    func askingPrice(_ title: Title, years: Int, exclusive: Bool) -> Double {
        guard let license = title.license else { return 0 }
        let original = Formulas.licenseCost(kind: title.kind, quality: title.quality, popularity: title.popularity,
                                            years: license.years, ageWeeks: title.ageWeeks, exclusive: license.exclusive)
        let wanted = Formulas.licenseCost(kind: title.kind, quality: title.quality, popularity: title.popularity,
                                          years: years, ageWeeks: title.ageWeeks, exclusive: exclusive)
        return licensePrice(title) * wanted / max(1, original)
    }

    /// Chance the rights holder accepts `offer` (a share of the asking price, 0.5...1.0).
    func acceptChance(_ title: Title, offer: Double) -> Double {
        let gap = 1 - offer
        return Formulas.clamp(0.95 - 2.2 * gap - (title.sought ? 0.25 : 0) - Double(title.popularity) / 400, 0.02, 0.95)
    }

    /// Counter-offer on a listing. Returns true if accepted (you then own it on your terms).
    /// A refusal makes the seller walk away from talks for 4 weeks and nudges the price up 5%.
    @discardableResult
    mutating func negotiate(titleID: Int, offer: Double, years: Int, exclusive: Bool) throws -> Bool {
        guard outcome == .playing else { throw ActionError.gameOver }
        guard let index = licenseMarket.firstIndex(where: { $0.id == titleID }), licenseMarket[index].license != nil else {
            throw ActionError.titleNotFound
        }
        guard (0.5...1.0).contains(offer), (1...5).contains(years) else { throw ActionError.invalidAmount }
        let title = licenseMarket[index]
        guard title.embargoWeeks == 0 else { throw ActionError.invalidProject("Rights go on sale in \(title.embargoWeeks) weeks.") }
        guard title.talksBlockedUntil <= week else {
            throw ActionError.invalidProject("The seller won't talk again until week \(title.talksBlockedUntil).")
        }
        let price = askingPrice(title, years: years, exclusive: exclusive) * offer
        guard finances.cash >= price else { throw ActionError.insufficientFunds(needed: price) }
        if rng.chance(acceptChance(title, offer: offer)) {
            var bought = licenseMarket.remove(at: index)
            bought.license?.years = years
            bought.license?.exclusive = exclusive
            bought.weeksRemaining = years * 52
            bought.listingWeeksLeft = 0
            bought.paidPrice = price
            bought.invested = price
            bought.popularityAtPurchase = bought.popularity
            finances.cash -= price
            finances.ledger.licensing += price
            catalog.append(bought)
            lastNegotiation = "Deal! \"\(bought.name)\" for \(Format.money(price)), \(years) yr\(exclusive ? ", exclusive" : "")."
            addNews(.you, "\(companyName) negotiates \"\(bought.name)\"", "Signed for \(Format.money(price)) over \(years) years.")
            return true
        }
        licenseMarket[index].talksBlockedUntil = week + 4
        licenseMarket[index].license?.cost *= 1.05
        lastNegotiation = "Rejected. The rights holder for \"\(title.name)\" walked away and raised the price 5%."
        return false
    }

    // MARK: Output deals

    static let maxOutputDeals = 2
    static let outputDealWeeks = 104
    static let outputDeliveryEvery = 8

    func outputDealFee() -> Double {
        scaled(120_000) * min(6, sqrt(Formulas.licenseAudienceScale(totalSubscribers: totalSubscribers)))
    }

    mutating func signOutputDeal(genre: Genre) throws {
        guard outcome == .playing else { throw ActionError.gameOver }
        guard outputDeals.count < Self.maxOutputDeals else { throw ActionError.invalidProject("You can run 2 output deals at once.") }
        let fee = outputDealFee()
        guard finances.cash >= fee * 4 else { throw ActionError.insufficientFunds(needed: fee * 4) }
        let studio = StudioNames.make(rng: &rng)
        outputDeals.append(OutputDeal(id: takeID(), studio: studio, genre: genre, weeklyFee: fee,
                                      weeksLeft: Self.outputDealWeeks, nextDelivery: Self.outputDeliveryEvery))
        addNews(.you, "\(companyName) signs an output deal with \(studio)",
                "Every \(Self.outputDeliveryEvery) weeks for two years, \(studio) delivers a new \(genre.displayName.lowercased()) title. \(Format.money(fee))/wk.")
    }

    /// Ending early costs 8 weeks of fees.
    mutating func cancelOutputDeal(id: Int) throws {
        guard let index = outputDeals.firstIndex(where: { $0.id == id }) else { throw ActionError.invalidAmount }
        let penalty = outputDeals[index].weeklyFee * 8
        finances.cash -= penalty
        finances.ledger.other += penalty
        let deal = outputDeals.remove(at: index)
        addNews(.you, "\(companyName) ends its deal with \(deal.studio)", "Breaking the contract cost \(Format.money(penalty)).")
    }

    /// Weekly: charges fees and delivers titles. Returns the fees for this week's report.
    mutating func runOutputDeals(events: inout [GameEvent]) -> Double {
        var fees = 0.0
        for i in outputDeals.indices {
            fees += outputDeals[i].weeklyFee
            outputDeals[i].weeksLeft -= 1
            outputDeals[i].nextDelivery -= 1
            guard outputDeals[i].nextDelivery <= 0 else { continue }
            outputDeals[i].nextDelivery = Self.outputDeliveryEvery
            outputDeals[i].delivered += 1
            let deal = outputDeals[i]
            let taken = Set(catalog.map(\.name) + licenseMarket.map(\.name) + projects.map(\.name) + loanedOut.map(\.title.name))
            var title = TitleGenerator.generate(id: takeID(), rng: &rng, avoiding: taken)
            title.genre = deal.genre
            title.quality = Int(Formulas.clamp(Double(title.quality), 55, 82))
            title.ageWeeks = 0
            title.license = LicenseTerms(cost: deal.weeklyFee * Double(Self.outputDeliveryEvery), years: 3, regions: [], exclusive: true)
            title.weeksRemaining = 156
            title.listingWeeksLeft = 0
            title.embargoWeeks = 0
            title.paidPrice = deal.weeklyFee * Double(Self.outputDeliveryEvery)
            title.invested = title.paidPrice
            title.popularityAtPurchase = title.popularity
            catalog.append(title)
            events.append(makeEvent(.news, "\(deal.studio) delivers \"\(title.name)\"",
                                    "A new exclusive \(deal.genre.displayName.lowercased()) title from your output deal."))
        }
        for deal in outputDeals where deal.weeksLeft <= 0 {
            addNews(.you, "Output deal with \(deal.studio) ends", "\(deal.delivered) titles delivered over two years.")
        }
        outputDeals.removeAll { $0.weeksLeft <= 0 }
        return fees
    }

    // MARK: Leaving a market

    func exitPrice(_ country: Country) -> Double { scaled(country.launchCost * 0.2) }

    /// Shut down in a country: subscribers are let go, local deals end, and you pay wind-down costs.
    mutating func exitMarket(code: String) throws {
        guard outcome == .playing else { throw ActionError.gameOver }
        guard let country = CountryData.country(code), let market = markets[code], market.status != .notLaunched else {
            throw ActionError.countryNotFound
        }
        guard liveMarketCodes.filter({ $0 != code }).count >= 1 || market.status != .live else {
            throw ActionError.invalidProject("You can't leave your only live market.")
        }
        let cost = exitPrice(country)
        finances.cash -= cost
        finances.ledger.other += cost
        let lost = market.subs.total
        markets[code] = MarketState(prices: market.prices)
        partnerships.removeAll { $0.country == code }
        promotions.removeAll { $0.scope == code }
        addNews(.you, "\(companyName) pulls out of \(country.name)",
                "\(country.flag) \(Format.count(lost)) subscribers lose the service. Wind-down cost \(Format.money(cost)).")
    }

    // MARK: Productions and titles

    /// Stop a production. Money already spent is gone.
    mutating func cancelProduction(id: Int) throws {
        guard let index = projects.firstIndex(where: { $0.id == id }) else { throw ActionError.invalidAmount }
        let project = projects.remove(at: index)
        let spent = project.weeklyCost * Double(project.weeksTotal - project.weeksLeft)
        addNews(.you, "\(companyName) cancels \"\(project.name)\"", "Production stops after \(Format.money(spent)) spent.")
    }

    /// Pull a licensed title from the service (no refund), or write off an original for a 10% tax benefit.
    mutating func removeTitle(titleID: Int) throws {
        guard let index = catalog.firstIndex(where: { $0.id == titleID }) else { throw ActionError.titleNotFound }
        let title = catalog.remove(at: index)
        titleStats[title.id] = nil
        if title.isOriginal {
            let benefit = title.invested * 0.10
            finances.cash += benefit
            finances.ledger.other -= benefit
            addNews(.you, "\(companyName) writes off \"\(title.name)\"", "The original is pulled for a \(Format.money(benefit)) tax benefit. Fans are not amused.")
            brandTrust = max(0, brandTrust - 2)
        } else {
            addNews(.you, "\(companyName) pulls \"\(title.name)\"", "The title leaves the service early.")
        }
    }

    // MARK: Corporate

    mutating func renameCompany(_ name: String) throws {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (2...30).contains(clean.count) else { throw ActionError.invalidProject("Pick a name of 2 to 30 characters.") }
        let old = companyName
        companyName = clean
        addNews(.you, "\(old) is now \(clean)", "A new name for a new chapter.")
    }

    /// Public companies only: buy back `percent` (1-10%) of shares at a 10% premium to raise your ownership.
    func buybackPrice(percent: Double) -> Double { valuation * percent * 1.1 }

    mutating func buyBackShares(percent: Double) throws {
        guard equity.ipoDone else { throw ActionError.invalidProject("Only public companies can buy back shares.") }
        guard (0.01...0.10).contains(percent) else { throw ActionError.invalidAmount }
        let room = 1 - equity.ownership
        guard room > 0.0001 else { throw ActionError.invalidProject("You already own everything.") }
        let amount = min(percent, room)
        let price = buybackPrice(percent: amount)
        guard finances.cash >= price else { throw ActionError.insufficientFunds(needed: price) }
        finances.cash -= price
        finances.ledger.other += price
        equity.ownership += amount
        earningsSentiment = min(1.35, earningsSentiment + 0.02)
        addNews(.you, "\(companyName) buys back shares", "\(Format.percent(amount)) of the company for \(Format.money(price)). You now own \(Format.percent(equity.ownership)).")
    }

    /// Public companies only: return cash to shareholders. Investors like it.
    func dividendPrice() -> Double { valuation * 0.01 }

    mutating func payDividend() throws {
        guard equity.ipoDone else { throw ActionError.invalidProject("Only public companies pay dividends.") }
        let price = dividendPrice()
        guard finances.cash >= price else { throw ActionError.insufficientFunds(needed: price) }
        guard week - lastDividendWeek >= 13 else { throw ActionError.invalidProject("At most one dividend per quarter.") }
        finances.cash -= price
        finances.ledger.other += price
        lastDividendWeek = week
        earningsSentiment = min(1.35, earningsSentiment + 0.04)
        addNews(.you, "\(companyName) pays a dividend", "\(Format.money(price)) goes back to shareholders. Investors cheer.")
    }
}
