import Foundation

/// Pure-Swift weekly simulation. No UI. Deterministic for a given state (RNG lives in the state).
enum SimulationEngine {
    static let milestones: [Double] = [1_000, 10_000, 50_000, 100_000, 250_000, 500_000,
                                       1_000_000, 5_000_000, 10_000_000, 50_000_000, 100_000_000]
    static let debtWeeksToLose = 8
    static let minWeeksToWin = 52
    static let hardDebtLimit = 26          // lose even with funding available

    static func achievedGoals(_ s: GameState) -> [String] {
        var goals: [String] = []
        if s.equity.ipoDone { goals.append("ipo") }
        if s.finances.annualizedRevenue >= 10_000_000_000 { goals.append("revenue10B") }
        if s.liveMarketCodes.count == CountryData.all.count { goals.append("allMarkets") }
        return goals
    }

    static func goalTitle(_ goal: String) -> String {
        switch goal {
        case "ipo": return "IPO"
        case "revenue10B": return "$10B annual revenue"
        default: return "All 30 markets"
        }
    }

    /// Runs one week: content aging, market refresh, subscribers, rivals, money, win/lose checks.
    static func advanceWeek(_ input: GameState) -> GameState {
        var s = input
        // The game waits for the player to settle any pending decision.
        guard s.outcome == .playing, s.pendingEvent == nil else { return s }

        var events: [GameEvent] = s.queuedEvents
        s.queuedEvents = []
        var fin = WeeklyFinancials()
        let totalBefore = s.totalSubscribers

        // Spend already paid out of cash this week (licenses, launches, localization, event costs).
        fin.licensing = s.finances.ledger.licensing
        fin.launch = s.finances.ledger.launch
        fin.localization = s.finances.ledger.localization
        fin.other = s.finances.ledger.other
        let prepaid = s.finances.ledger.total
        s.finances.ledger = SpendLedger()

        ageCatalog(&s, events: &events)
        refreshLicenseMarket(&s, events: &events)
        produceOriginals(&s, fin: &fin, events: &events)
        let recession = s.recessionWeeksLeft > 0
        progressPlatformBuilds(&s, events: &events)

        // Infrastructure load per region (start-of-week subscribers vs CDN capacity).
        var regionQuality: [Region: Double] = [:]
        for region in Region.allCases {
            let load = s.cdnLoad(region)
            regionQuality[region] = Formulas.serviceQuality(load: load)
            if load > 1, s.week % 4 == 0 {
                events.append(s.makeEvent(.warning, "Buffering in \(region.displayName)",
                                          "Servers are at \(Format.percent(load)) of capacity. Subscribers are churning; expand the CDN in the Company tab."))
            }
        }
        let marketingBoost = Formulas.marketingBoost(marketingLevel: s.staff.marketing)

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
            let quality = regionQuality[country.region] ?? 1.0
            let marketingSpend = market.marketingBudget * marketingBoost
            let noise = s.rng.nextDouble(in: 0.92...1.08)
            let gross = Formulas.grossAdds(
                headroom: headroom, appeal: appeal,
                priceFactor: Formulas.priceFactor(price: price, tolerance: country.priceTolerance),
                awareness: market.awareness,
                marketingFactor: Formulas.marketingFactor(spend: marketingSpend, households: country.households),
                wordOfMouth: Formulas.wordOfMouth(penetration: penetration),
                rivalFactor: Formulas.rivalFactor(rivalShare: pressure.effectiveShare),
                reach: s.platformReach * (recession ? 0.85 : 1.0) * quality, noise: noise)
            let adds = min(gross, headroom)
            let churn = (recession ? 1.1 : 1.0) * Formulas.churnRate(appeal: appeal, price: price,
                                           tolerance: country.priceTolerance,
                                           serviceQuality: quality,
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
                awareness: market.awareness, spend: marketingSpend,
                households: country.households, penetration: penetration)
            s.markets[code] = market

            // Local-content quota: a catalog short on local-language titles draws regulatory fines.
            let localCount = titles.filter { $0.language == country.language || $0.dubs.contains(country.language) }.count
            let compliance = Formulas.quotaCompliance(localCount: localCount, total: titles.count, quota: country.localQuota)
            fin.fines += Formulas.quotaFine(revenue: subRevenue + adRevenue, risk: country.regulatoryRisk,
                                            compliance: compliance)
                * Formulas.fineMultiplier(legalLevel: s.staff.legal)

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
        fin.staff = Formulas.baseStaffCostPerWeek + s.weeklySalaries + Formulas.overheadRate * fin.revenue
        let mobileApps = [Platform.ios, .android].filter { s.platforms.contains($0) }.count
        fin.tech = s.weeklyTechCost + Double(mobileApps) * Formulas.appStoreFeeRate * fin.subscriptionRevenue

        // Loans: interest is a cost; scheduled principal is a cash outflow only.
        var principalPaid = 0.0
        for i in s.loans.indices {
            fin.interest += s.loans[i].balance * s.loans[i].annualRate / 52
            let pay = min(s.loans[i].balance, s.loans[i].weeklyPrincipal)
            principalPaid += pay
            s.loans[i].balance -= pay
        }
        s.loans.removeAll { $0.balance <= 0.01 }

        if s.recessionWeeksLeft > 0 {
            s.recessionWeeksLeft -= 1
            if s.recessionWeeksLeft == 0 {
                events.append(s.makeEvent(.news, "Recession over", "Consumer spending is recovering."))
            }
        }

        let leaderboardBefore = Dictionary(uniqueKeysWithValues: input.leaderboard.map { ($0.id, $0.subs) })
        advanceRivals(&s, events: &events)
        s.previousSubs = leaderboardBefore

        // Cash: prepaid items were already deducted when paid; principal repayments aren't P&L.
        s.finances.cash += fin.profit + prepaid - principalPaid
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
        // Goals
        let newGoals = achievedGoals(s).filter { !s.goals.contains($0) }
        for goal in newGoals {
            s.goals.append(goal)
            events.append(s.makeEvent(.milestone, "Goal reached: \(goalTitle(goal))", "A bonus goal is complete!"))
        }

        let broke = s.finances.weeksInDebt >= debtWeeksToLose
        if broke && (!s.fundingAvailable || s.finances.weeksInDebt >= hardDebtLimit) {
            s.outcome = .lost
            events.append(s.makeEvent(.warning, "Bankrupt",
                                      "Cash has been below zero for \(s.finances.weeksInDebt) straight weeks with no funding left. Creditors have taken over."))
        } else if s.week >= minWeeksToWin,
                  let topRival = s.rivals.map({ $0.totalSubs }).max(), totalAfter > topRival {
            s.outcome = .won
            events.append(s.makeEvent(.milestone, "You're #1!",
                                      "\(s.companyName) now has more subscribers than every rival."))
        } else if s.finances.cash < 0 {
            events.append(s.makeEvent(.warning, "Cash is negative",
                                      broke ? "Week \(s.finances.weeksInDebt) in debt. Raise funding now (Company tab) before lenders walk away."
                                            : "Week \(s.finances.weeksInDebt) of \(debtWeeksToLose) in debt. Cut costs or raise funding."))
        }

        // Random events (may pause the game for a decision).
        if s.outcome == .playing, let event = RandomEvents.roll(&s) { events.append(event) }

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

    private static func progressPlatformBuilds(_ s: inout GameState, events: inout [GameEvent]) {
        var remaining: [PlatformBuild] = []
        for var build in s.builds {
            build.weeksLeft -= 1
            if build.weeksLeft <= 0 {
                s.platforms.append(build.platform)
                events.append(s.makeEvent(.news, "\(build.platform.displayName) launched",
                                          "Your reach just grew to \(Format.percent(s.platformReach))."))
            } else {
                remaining.append(build)
            }
        }
        s.builds = remaining
    }

    private static func produceOriginals(_ s: inout GameState, fin: inout WeeklyFinancials,
                                         events: inout [GameEvent]) {
        var remaining: [OriginalProject] = []
        for var project in s.projects {
            fin.originals += project.weeklyCost
            project.weeksLeft -= 1
            guard project.weeksLeft <= 0 else { remaining.append(project); continue }

            let expected = Formulas.expectedOriginalQuality(kind: project.kind, budget: project.budget,
                                                            weeks: project.weeksTotal)
                + Formulas.originalQualityBonus(contentLevel: s.staff.content)
            let u1 = s.rng.nextDouble(), u2 = s.rng.nextDouble(), u3 = s.rng.nextDouble()
            let breakout = s.rng.chance(0.05)
            let quality = Formulas.rolledOriginalQuality(expected: expected, u1: u1, u2: u2, u3: u3, breakout: breakout)
            let popularity = Formulas.originalPopularity(quality: quality, u: s.rng.nextDouble())
            let title = Title(id: s.takeID(), name: project.name, kind: project.kind, genre: project.genre,
                              language: project.language, quality: quality, popularity: popularity,
                              ageWeeks: 0, isOriginal: true, license: nil, weeksRemaining: nil,
                              listingWeeksLeft: 0)
            s.catalog.append(title)
            let verdict = breakout ? "A runaway hit!" : quality >= 75 ? "Critics love it." : quality <= 40 ? "A flop." : "A solid addition."
            events.append(s.makeEvent(.news, "\"\(project.name)\" premieres",
                                      "Your original (quality \(quality), popularity \(popularity)) is live worldwide. \(verdict)"))
        }
        s.projects = remaining
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
