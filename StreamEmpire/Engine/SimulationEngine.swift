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
                rivalFactor: Formulas.rivalFactor(rivalShare: rivalSubs / ceiling),
                reach: s.platformReach, noise: noise)
            let adds = min(gross, headroom)
            let churn = Formulas.churnRate(appeal: appeal, price: price,
                                           tolerance: country.priceTolerance,
                                           serviceQuality: s.serviceQuality)
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

        advanceRivals(&s)

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

        // Rivals occasionally snap up listings before you do.
        let rivalNames = s.rivals.map { $0.name }
        var kept: [Title] = []
        var announced = 0
        for title in s.licenseMarket {
            if s.rng.chance(0.05) {
                if title.quality >= 65, announced < 2, !rivalNames.isEmpty {
                    let rival = s.rng.pick(rivalNames)
                    events.append(s.makeEvent(.licenseLost, "\(rival) outbid you",
                                              "\"\(title.name)\" was licensed by \(rival)."))
                    announced += 1
                }
            } else {
                kept.append(title)
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

    private static func advanceRivals(_ s: inout GameState) {
        for i in s.rivals.indices {
            var rival = s.rivals[i]
            let noise = s.rng.nextDouble(in: 0.8...1.2)
            rival.legacySubs *= 1 + rival.weeklyGrowth * noise
            for code in rival.subs.keys.sorted() {
                guard let country = CountryData.country(code) else { continue }
                let own = s.markets[code]?.subs.total ?? 0
                let others = s.rivals.enumerated().reduce(0.0) { $0 + ($1.offset == i ? 0 : ($1.element.subs[code] ?? 0)) }
                let occupied = own + others + (rival.subs[code] ?? 0)
                let room = max(0, country.subscriberCeiling * 0.95 - occupied)
                let growth = (rival.subs[code] ?? 0) * rival.weeklyGrowth * noise
                rival.subs[code, default: 0] += min(growth, room)
            }
            s.rivals[i] = rival
        }
    }
}
