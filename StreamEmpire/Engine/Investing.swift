import Foundation

/// Buying shares in rivals and taking them over.
extension GameState {
    // MARK: Valuation

    func marketCap(_ rival: Rival) -> Double {
        Formulas.rivalMarketCap(annualProfit: rival.annualProfit, subscribers: rival.totalSubs, sentiment: rival.sentiment)
    }

    func stake(in rivalID: String) -> Double { stakes[rivalID] ?? 0 }

    func stakeValue(in rivalID: String) -> Double {
        guard let rival = rivals.first(where: { $0.id == rivalID }) else { return 0 }
        return marketCap(rival) * stake(in: rivalID)
    }

    var totalStakeValue: Double { stakes.keys.sorted().reduce(0) { $0 + stakeValue(in: $1) } }

    func sharePrice(_ rival: Rival, percent: Double) -> Double {
        Formulas.sharePurchaseCost(marketCap: marketCap(rival), currentStake: stake(in: rival.id),
                                   percent: percent, poisonPill: rival.poisonPill)
    }

    /// True if buying out this rival would make you too dominant for regulators.
    func antitrustRisk(_ rival: Rival) -> Bool {
        let all = totalSubscribers + rivals.reduce(0.0) { $0 + $1.totalSubs }
        guard all > 0 else { return false }
        return (totalSubscribers + rival.totalSubs) / all > 0.30
    }

    func takeoverCost(_ rival: Rival, premium: Double) -> Double {
        Formulas.takeoverCost(marketCap: marketCap(rival), stake: stake(in: rival.id), premium: premium)
    }

    func takeoverChance(_ rival: Rival, premium: Double) -> Double {
        Formulas.takeoverSuccessChance(premium: premium, stake: stake(in: rival.id), poisonPill: rival.poisonPill,
                                       catalogStrength: rival.catalogStrength, antitrust: antitrustRisk(rival))
    }

    // MARK: Shares

    mutating func buyShares(rivalID: String, percent: Double) throws {
        guard outcome == .playing else { throw ActionError.gameOver }
        guard let index = rivals.firstIndex(where: { $0.id == rivalID }) else {
            throw ActionError.invalidProject("That company isn't for sale.")
        }
        guard (0.005...0.25).contains(percent) else { throw ActionError.invalidAmount }
        let current = stake(in: rivalID)
        guard current + percent <= Formulas.openMarketLimit + 1e-9 else {
            throw ActionError.locked("You can own at most \(Format.percent(Formulas.openMarketLimit)) on the open market. Launch a takeover bid to go further.")
        }
        let rival = rivals[index]
        let cost = sharePrice(rival, percent: percent)
        guard finances.cash >= cost else { throw ActionError.insufficientFunds(needed: cost) }

        finances.cash -= cost
        stakes[rivalID] = current + percent
        stakeBasis[rivalID, default: 0] += cost
        rivals[index].sentiment = min(1.6, rival.sentiment + percent * 0.5)

        let now = current + percent
        if current < Formulas.disclosureStake, now >= Formulas.disclosureStake {
            addNews(.you, "\(companyName) discloses a \(Format.percent(now)) stake in \(rival.name)",
                    "Investors wonder whether \(companyName) is preparing a bid for \(rival.name).", rival: rivalID)
        }
        if current < Formulas.poisonPillStake, now >= Formulas.poisonPillStake {
            rivals[index].poisonPill = true
            addNews(.industry, "\(rival.name) adopts a poison pill",
                    "Alarmed by \(companyName)'s \(Format.percent(now)) stake, \(rival.name)'s board makes further share purchases far more expensive.",
                    rival: rivalID)
        }
    }

    mutating func sellShares(rivalID: String, percent: Double) throws {
        guard outcome == .playing else { throw ActionError.gameOver }
        guard let index = rivals.firstIndex(where: { $0.id == rivalID }) else { throw ActionError.invalidAmount }
        let current = stake(in: rivalID)
        guard percent > 0, percent <= current + 1e-9 else { throw ActionError.invalidAmount }
        let sold = min(percent, current)
        finances.cash += Formulas.shareSaleProceeds(marketCap: marketCap(rivals[index]), percent: sold)
        let remaining = current - sold
        let basis = stakeBasis[rivalID] ?? 0
        stakeBasis[rivalID] = current > 0 ? basis * remaining / current : 0
        stakes[rivalID] = remaining > 1e-9 ? remaining : nil
        if stakes[rivalID] == nil { stakeBasis[rivalID] = nil }
        rivals[index].sentiment = max(0.6, rivals[index].sentiment - sold * 0.5)
    }

    // MARK: Takeovers

    mutating func launchTakeover(rivalID: String, premium: Double) throws {
        guard outcome == .playing else { throw ActionError.gameOver }
        guard takeover == nil else { throw ActionError.invalidProject("You already have a takeover bid in progress.") }
        guard let rival = rivals.first(where: { $0.id == rivalID }) else { throw ActionError.invalidProject("That company isn't for sale.") }
        guard stake(in: rivalID) >= Formulas.disclosureStake else {
            throw ActionError.locked("Build a stake of at least \(Format.percent(Formulas.disclosureStake)) before bidding.")
        }
        guard (0.1...1.0).contains(premium) else { throw ActionError.invalidAmount }
        let cost = takeoverCost(rival, premium: premium)
        guard finances.cash >= cost else { throw ActionError.insufficientFunds(needed: cost) }
        finances.cash -= cost
        takeover = TakeoverBid(rivalID: rivalID, premium: premium, escrow: cost, weeksLeft: Formulas.takeoverWeeks,
                               startStake: stake(in: rivalID))
        addNews(.you, "\(companyName) launches a hostile bid for \(rival.name)",
                "An offer of \(Format.money(cost)) for the rest of the company, \(Int(premium * 100))% above the market price. Shareholders vote in \(Formulas.takeoverWeeks) weeks.",
                rival: rivalID)
    }

    /// Resolves the shareholder vote. `success` is decided by the engine's dice roll; tests can force it.
    mutating func finishTakeover(success: Bool) {
        guard let bid = takeover, let index = rivals.firstIndex(where: { $0.id == bid.rivalID }) else {
            takeover = nil
            return
        }
        takeover = nil
        let rival = rivals[index]
        if success {
            acquire(index: index)
        } else {
            let fee = bid.escrow * Formulas.takeoverFeeRate
            finances.cash += bid.escrow - fee
            finances.ledger.other += fee
            rivals[index].poisonPill = true
            rivals[index].priceLevel = max(0.6, rival.priceLevel - 0.08)
            rivals[index].sentiment = min(1.6, rival.sentiment + 0.1)
            addNews(.industry, "Shareholders reject \(companyName)'s bid for \(rival.name)",
                    "The offer failed. \(rival.name) adopts a poison pill and cuts prices to hit back. \(companyName) keeps its \(Format.percent(stake(in: rival.id))) stake and recovers its offer minus \(Format.money(fee)) in fees.",
                    rival: rival.id)
        }
    }

    /// Folds a rival into your company: its subscribers, cash and library become yours.
    private mutating func acquire(index: Int) {
        let rival = rivals[index]
        for code in rival.subs.keys.sorted() {
            guard var market = markets[code], let country = CountryData.country(code) else { continue }
            let inherited = (rival.subs[code] ?? 0) * Formulas.takeoverRetention
            if market.status != .live {
                market.status = .live                       // you inherit their presence: no launch needed
                market.awareness = max(market.awareness, 0.35)
                if !market.liveTiers.contains(.standard) { market.liveTiers.append(.standard) }
                market.prices = CountryData.defaultPrices(for: country)
            }
            market.subs.standard += inherited
            markets[code] = market
        }
        finances.cash += rival.cash * 0.5
        let titles = min(8, Int(rival.catalogStrength / 12))
        for _ in 0..<titles {
            let id = takeID()
            var title = TitleGenerator.generate(id: id, rng: &rng,
                                                avoiding: Set(catalog.map(\.name) + licenseMarket.map(\.name)))
            title.isOriginal = true
            title.license = nil
            title.weeksRemaining = nil
            title.listingWeeksLeft = 0
            title.quality = Int(Formulas.clamp(rival.catalogStrength + Double(rng.nextInt(in: -12...6)), 30, 98))
            title.ageWeeks = rng.nextInt(in: 10...120)
            catalog.append(title)
        }
        acquiredRivals.append(rival.id)
        stakes[rival.id] = nil
        stakeBasis[rival.id] = nil
        rivals.remove(at: index)
        addNews(.you, "\(companyName) acquires \(rival.name)!",
                "A landmark deal: \(rival.name)'s \(Format.count(rival.totalSubs)) subscribers in \(rival.countryCount) countries, its cash and \(titles) library titles now belong to \(companyName).")
    }
}
