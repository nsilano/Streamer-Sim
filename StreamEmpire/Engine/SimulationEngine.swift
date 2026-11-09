import Foundation

/// Pure-Swift weekly simulation. No UI. Deterministic for a given state (RNG lives in the state).
enum SimulationEngine {
    static let milestones: [Double] = [1_000, 10_000, 50_000, 100_000, 250_000, 500_000,
                                       1_000_000, 5_000_000, 10_000_000, 50_000_000, 100_000_000]
    static let debtWeeksToLose = 8
    static let minWeeksToWin = 52

    /// Runs one week: content aging, market refresh, subscribers, rivals, money, win/lose checks.
    static func advanceWeek(_ input: GameState) -> GameState {
        var s = input
        guard s.outcome == .playing else { return s }

        var events: [GameEvent] = []
        var fin = WeeklyFinancials()
        let totalBefore = s.totalSubscribers

        // Spend already paid out of cash this week (licenses, market launches).
        fin.licensing = s.finances.ledger.licensing
        fin.launch = s.finances.ledger.launch
        s.finances.ledger = SpendLedger()

        ageCatalog(&s, events: &events)
        refreshLicenseMarket(&s, events: &events)

        // Markets
        var marketReports: [MarketReport] = []
        var totalNew = 0.0, totalChurned = 0.0, billedSubs = 0.0

        for code in s.markets.keys.sorted() {
            guard var market = s.markets[code], let country = CountryData.country(code) else { continue }

            switch market.status {
            case .notLaunched:
                continue
            case .launching(let weeksLeft):
                if weeksLeft <= 1 {
                    market.status = .live
                    events.append(s.makeEvent(.marketLive, "\(country.flag) \(country.name) is live!",
                                              "Subscribers can now sign up in \(country.name)."))
                } else {
                    market.status = .launching(weeksLeft: weeksLeft - 1)
                }
                s.markets[code] = market
                continue
            case .live:
                break
            }

            let titles = s.catalog.filter { $0.isAvailable(in: code) }
            let appeal = Formulas.catalogAppeal(titles, in: country)
            let ceiling = country.subscriberCeiling
            let startSubs = market.subs
            let ownSubs = startSubs.total
            let rivalSubs = s.rivals.reduce(0) { $0 + ($1.subs[code] ?? 0) }
            let presences = s.rivals.compactMap { rival -> Formulas.RivalPresence? in
                guard let subs = rival.subs[code], subs > 0 else { return nil }
                return Formulas.RivalPresence(share: subs / ceiling, strength: rival.catalogStrength,
                                              priceLevel: rival.priceLevel)
            }
            let pressure = Formulas.rivalPressure(presences)
            let penetration = ownSubs / ceiling
            let headroom = max(0, ceiling - ownSubs - rivalSubs)

            let price = Formulas.blendedPrice(market.prices)
            let noise = s.rng.nextDouble(in: 0.92...1.08)
            let gross = Formulas.grossAdds(
                headroom: headroom, appeal: appeal,
                priceFactor: Formulas.priceFactor(price: price, tolerance: country.priceTolerance),
                awareness: market.awareness,
                marketingFactor: Formulas.marketingFactor(spend: market.marketingBudget, households: country.households),
                wordOfMouth: Formulas.wordOfMouth(penetration: penetration),
                rivalFactor: Formulas.rivalFactor(rivalShare: pressure.effectiveShare),
                reach: s.platformReach, noise: noise)
            let adds = min(gross, headroom)
            let churn = Formulas.churnRate(appeal: appeal, price: price,
                                           tolerance: country.priceTolerance,
                                           serviceQuality: s.serviceQuality,
                                           rivalHeat: pressure.heat)
            let split = Formulas.tierSplit(prices: market.prices)

            // Revenue is billed on subscribers at the start of the week.
            let subRevenue = Formulas.subscriptionRevenue(subs: startSubs, prices: market.prices)
            let adRevenue = Formulas.adRevenue(adSubs: startSubs.ad, adStrength: country.adStrength)

            var newSubs = startSubs
            for tier in Tier.allCases {
                newSubs[tier] = max(0, startSubs[tier] * (1 - churn) + adds * split[tier])
            }
            market.subs = newSubs
            market.awareness = Formulas.nextAwareness(
                awareness: market.awareness, spend: market.marketingBudget,
                households: country.households, penetration: penetration)
            s.markets[code] = market

            fin.subscriptionRevenue += subRevenue
            fin.adRevenue += adRevenue
            fin.marketing += market.marketingBudget
            fin.operations += Formulas.operatingCost(for: country)
            billedSubs += ownSubs
            totalNew += adds
            totalChurned += ownSubs * churn
            marketReports.append(MarketReport(id: code, newSubs: adds, churned: ownSubs * churn,
                                              subs: newSubs.total, revenue: subRevenue + adRevenue))
        }

        fin.streaming = billedSubs * Formulas.streamingCostPerSubWeek
        fin.staff = Formulas.baseStaffCostPerWeek

        let leaderboardBefore = Dictionary(uniqueKeysWithValues: input.leaderboard.map { ($0.id, $0.subs) })
        advanceRivals(&s, events: &events)
        s.previousSubs = leaderboardBefore

        // Cash: licensing and launch costs were already deducted when paid.
        s.finances.cash += fin.profit + fin.licensing + fin.launch
        s.finances.lastWeek = fin
        s.finances.profitHistory.append(fin.profit)
        if s.finances.profitHistory.count > 12 { s.finances.profitHistory.removeFirst() }
        s.finances.revenueHistory.append(fin.revenue)
        if s.finances.revenueHistory.count > 52 { s.finances.revenueHistory.removeFirst() }
        s.finances.weeksInDebt = s.finances.cash < 0 ? s.finances.weeksInDebt + 1 : 0

        // Milestones
        let totalAfter = s.totalSubscribers
        for milestone in milestones where totalBefore < milestone && totalAfter >= milestone {
            events.append(s.makeEvent(.milestone, "\(Format.count(milestone)) subscribers!",
                                      "\(s.companyName) just passed \(Format.count(milestone)) subscribers worldwide."))
        }

        // Win / lose
        if s.finances.weeksInDebt >= debtWeeksToLose {
            s.outcome = .lost
            events.append(s.makeEvent(.warning, "Bankrupt",
                                      "Cash has been below zero for \(debtWeeksToLose) straight weeks. Creditors have taken over."))
        } else if s.week >= minWeeksToWin,
                  let topRival = s.rivals.map({ $0.totalSubs }).max(), totalAfter > topRival {
            s.outcome = .won
            events.append(s.makeEvent(.milestone, "You're #1!",
                                      "\(s.companyName) now has more subscribers than every rival."))
        } else if s.finances.cash < 0 {
            events.append(s.makeEvent(.warning, "Cash is negative",
                                      "Week \(s.finances.weeksInDebt) of \(debtWeeksToLose) in debt. Cut costs or raise revenue."))
        }

        let report = WeeklyReport(week: s.week, newSubs: totalNew, churned: totalChurned,
                                  totalSubs: totalAfter, financials: fin, cashEnd: s.finances.cash,
                                  rank: s.rank, markets: marketReports, events: events)
        s.lastReport = report
        s.reportHistory.append(report)
        if s.reportHistory.count > 26 { s.reportHistory.removeFirst() }
        s.week += 1
        return s
    }

    // MARK: Steps

    private static func ageCatalog(_ s: inout GameState, events: inout [GameEvent]) {
        for i in s.catalog.indices {
            s.catalog[i].ageWeeks += 1
            if let left = s.catalog[i].weeksRemaining { s.catalog[i].weeksRemaining = left - 1 }
        }
        let expired = s.catalog.filter { ($0.weeksRemaining ?? 1) <= 0 }
        s.catalog.removeAll { ($0.weeksRemaining ?? 1) <= 0 }
        for title in expired {
            events.append(s.makeEvent(.licenseExpired, "License expired",
                                      "\"\(title.name)\" has left your catalog."))
        }
    }

    private static func refreshLicenseMarket(_ s: inout GameState, events: inout [GameEvent]) {
        for i in s.licenseMarket.indices {
            s.licenseMarket[i].listingWeeksLeft -= 1
            s.licenseMarket[i].ageWeeks += 1
        }
        s.licenseMarket.removeAll { $0.listingWeeksLeft <= 0 }

        // Rivals bid on listings before you do; aggressive bidders win more often.
        var kept: [Title] = []
        var announced = 0
        for title in s.licenseMarket {
            var winner: Int?
            for index in s.rivals.indices {
                let chance = Formulas.bidChance(personality: s.rivals[index].personality, quality: title.quality)
                if s.rng.chance(chance) { winner = index; break }
            }
            guard let w = winner else { kept.append(title); continue }
            s.rivals[w].catalogStrength = min(100, s.rivals[w].catalogStrength + 0.3)
            if title.quality >= 65, announced < 2 {
                let name = s.rivals[w].name
                events.append(s.makeEvent(.licenseLost, "\(name) outbid you",
                                          "\"\(title.name)\" was licensed by \(name)."))
                announced += 1
            }
        }
        s.licenseMarket = kept

        var added = 0
        while s.licenseMarket.count < GameState.targetListings && added < 4 {
            let id = s.takeID()
            let title = TitleGenerator.generate(id: id, rng: &s.rng)
            s.licenseMarket.append(title)
            added += 1
        }
    }

    private static func advanceRivals(_ s: inout GameState, events: inout [GameEvent]) {
        let allCodes = CountryData.all.map { $0.code }
        var announcedExpansion = false
        var announcedPriceCut = false

        for i in s.rivals.indices {
            var rival = s.rivals[i]
            let noise = s.rng.nextDouble(in: 0.8...1.2)

            // Income and slow catalog improvement.
            rival.cash += rival.totalSubs * 0.12
            rival.catalogStrength = min(100, rival.catalogStrength + 0.02)

            // Growth in existing markets, squeezed by the ceiling.
            for code in rival.subs.keys.sorted() {
                guard let country = CountryData.country(code) else { continue }
                let own = s.markets[code]?.subs.total ?? 0
                var others = 0.0
                for (j, other) in s.rivals.enumerated() where j != i { others += other.subs[code] ?? 0 }
                let current = rival.subs[code] ?? 0
                let room = max(0, country.subscriberCeiling * 0.95 - (own + others + current))
                rival.subs[code] = current + min(current * rival.weeklyGrowth * noise, room)
            }

            // Expansion into a new country.
            if s.rng.chance(Formulas.expansionChance(personality: rival.personality)) {
                let absent = allCodes.filter { (rival.subs[$0] ?? 0) <= 0 }
                if !absent.isEmpty {
                    let choices = absent.map { ($0, CountryData.country($0)?.subscriberCeiling ?? 1) }
                    let code = s.rng.pickWeighted(choices)
                    if let country = CountryData.country(code), rival.cash >= country.launchCost * 0.5 {
                        rival.cash -= country.launchCost * 0.5
                        rival.subs[code] = country.subscriberCeiling * 0.005
                        if !announcedExpansion, s.markets[code]?.isLive == true {
                            announcedExpansion = true
                            events.append(s.makeEvent(.news, "\(rival.name) enters \(country.name)",
                                                      "\(rival.name) just launched in \(country.flag) \(country.name), where you operate."))
                        }
                    }
                }
            }

            // Pricing moves; cuts fade back toward normal.
            let previousLevel = rival.priceLevel
            if s.rng.chance(0.04) {
                let cutting = s.rng.chance(rival.personality == .priceCutter ? 0.75 : 0.45)
                let step = s.rng.nextDouble(in: 0.04...0.10)
                rival.priceLevel = Formulas.clamp(rival.priceLevel + (cutting ? -step : step), 0.7, 1.15)
            }
            rival.priceLevel += (1 - rival.priceLevel) * 0.01
            if !announcedPriceCut, previousLevel - rival.priceLevel >= 0.05 {
                let overlap = s.markets.contains { $0.value.isLive && (rival.subs[$0.key] ?? 0) > 0 }
                if overlap {
                    announcedPriceCut = true
                    events.append(s.makeEvent(.news, "\(rival.name) slashes prices",
                                              "Expect extra churn in markets where \(rival.name) competes with you."))
                }
            }

            s.rivals[i] = rival
        }
    }
}
