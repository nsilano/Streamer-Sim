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
        if !s.acquiredRivals.isEmpty { goals.append("takeover") }
        if s.finances.annualizedRevenue >= 10_000_000_000 { goals.append("revenue10B") }
        if s.liveMarketCodes.count == CountryData.all.count { goals.append("allMarkets") }
        return goals
    }

    static func goalTitle(_ goal: String) -> String {
        switch goal {
        case "ipo": return "IPO"
        case "revenue10B": return "$10B annual revenue"
        case "takeover": return "Acquire a rival"
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

        // The licensing manager shops the listings you can see now, before the weekly refresh.
        runCurator(&s, events: &events)

        ageCatalog(&s, events: &events)
        refreshLicenseMarket(&s, events: &events)
        produceOriginals(&s, fin: &fin, events: &events)
        let recession = s.recessionWeeksLeft > 0
        let policy = s.policyEffects()
        progressPlatformBuilds(&s, events: &events)

        progressDatacenters(&s, events: &events)

        // Server strain per region (start-of-week subscribers, plus any traffic surge, vs capacity).
        var regionQuality: [Region: Double] = [:]
        var regionLoad: [Region: Double] = [:]
        for region in Region.allCases {
            let load = s.effectiveLoad(region)
            regionLoad[region] = load
            var quality = Formulas.serviceQuality(load: load)
            if (s.outages[region.rawValue] ?? 0) > 0 { quality *= Formulas.outageQualityMultiplier }
            regionQuality[region] = quality
            if load > 1, s.week % 4 == 0 {
                events.append(s.makeEvent(.warning, "Buffering in \(region.displayName)",
                                          "Servers are at \(Format.percent(load)) of capacity. Viewers are cancelling, and a crash is possible. Add datacenters or rent cloud capacity."))
            } else if load > 0.9, load <= 1, s.week % 4 == 0 {
                events.append(s.makeEvent(.warning, "Lag in \(region.displayName)",
                                          "Servers are at \(Format.percent(load)) of capacity. Add capacity before you grow further."))
            }
        }
        let marketingBoost = Formulas.marketingBoost(marketingLevel: s.staff.effectiveLevel(.marketing))

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

            // Tiers being set up in this market.
            var finished: [Tier] = []
            for i in market.tierBuilds.indices {
                market.tierBuilds[i].weeksLeft -= 1
                if market.tierBuilds[i].weeksLeft <= 0 { finished.append(market.tierBuilds[i].tier) }
            }
            if !finished.isEmpty {
                market.tierBuilds.removeAll { finished.contains($0.tier) }
                for tier in finished where !market.liveTiers.contains(tier) {
                    market.liveTiers.append(tier)
                    events.append(s.makeEvent(.news, "\(tier.displayName) tier live in \(country.name)",
                                              "\(country.flag) Customers in \(country.name) can now choose the \(tier.displayName) plan."))
                }
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

            let price = Formulas.blendedPrice(market.prices, tiers: market.liveTiers)
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
            let adds = min(gross * policy.adds, headroom)
            let baseChurn = Formulas.churnRate(appeal: appeal, price: price,
                                               tolerance: country.priceTolerance,
                                               serviceQuality: quality,
                                               rivalHeat: pressure.heat)
            let churn = min(0.5, (recession ? 1.1 : 1.0) * policy.churn * baseChurn)
            let split = Formulas.tierSplit(prices: market.prices, tiers: market.liveTiers)

            // Revenue is billed on subscribers at the start of the week.
            let subRevenue = Formulas.subscriptionRevenue(subs: startSubs, prices: market.prices) * policy.arpu
            let adRevenue = Formulas.adRevenue(adSubs: startSubs.ad, adStrength: country.adStrength) * policy.adRevenue

            var newSubs = startSubs
            for tier in Tier.allCases {
                newSubs[tier] = max(0, startSubs[tier] * (1 - churn) + adds * split[tier])
            }
            market.subs = newSubs
            market.awareness = Formulas.clamp(Formulas.nextAwareness(
                awareness: market.awareness, spend: marketingSpend,
                households: country.households, penetration: penetration) + policy.awareness, 0, 1)
            s.markets[code] = market

            // Local-content quota: a catalog short on local-language titles draws regulatory fines.
            let localCount = titles.filter { $0.language == country.language || $0.dubs.contains(country.language) }.count
            let compliance = Formulas.quotaCompliance(localCount: localCount, total: titles.count, quota: country.localQuota)
            var marketFine = 0.0
            if Formulas.quotaFinesApply(week: s.week, subscribers: ownSubs) {
                let raw = Formulas.quotaFine(revenue: subRevenue + adRevenue, risk: country.regulatoryRisk,
                                             compliance: compliance)
                    * Formulas.fineMultiplier(legalLevel: s.staff.effectiveLevel(.legal)) * policy.fines
                marketFine = min(raw, Formulas.maxFineShareOfRevenue * (subRevenue + adRevenue))
            } else if compliance < 1, titles.count >= 5, ownSubs > 0, !s.quotaWarned.contains(code),
                      s.week >= Formulas.quotaGraceWeeks - 12 {
                s.quotaWarned.append(code)
                events.append(s.makeEvent(.warning, "Regulators are watching \(country.name)",
                                          "\(country.flag) Too little of your \(country.name) catalog is in \(country.language.displayName) (quota \(Format.percent(country.localQuota))). Fines start once you are established there. Add local titles or dub existing ones to stay clear."))
            }
            fin.fines += marketFine

            fin.subscriptionRevenue += subRevenue
            fin.adRevenue += adRevenue
            fin.marketing += market.marketingBudget
            fin.operations += Formulas.operatingCost(for: country)
            billedSubs += ownSubs
            totalNew += adds
            totalChurned += ownSubs * churn
            let marketCosts = ownSubs * Formulas.streamingCostPerSubWeek * policy.streamingCost + Formulas.operatingCost(for: country)
                + market.marketingBudget + marketFine
            marketReports.append(MarketReport(id: code, newSubs: adds, churned: ownSubs * churn,
                                              subs: newSubs.total, revenue: subRevenue + adRevenue, costs: marketCosts))
        }

        // Overloaded servers can crash: subscribers leave and the region limps for two weeks.
        for region in Region.allCases {
            guard let load = regionLoad[region], load > 1.05 else { continue }
            let online = s.datacenters.filter { $0.region == region && $0.isOnline }.count
            let chance = Formulas.crashChance(load: load, datacenters: online,
                                              engineeringLevel: s.staff.effectiveLevel(.engineering))
            guard chance > 0, s.rng.chance(chance) else { continue }
            let before = s.subscribers(in: region)
            let loss = Formulas.crashLoss(load: load)
            for code in s.markets.keys.sorted() {
                guard var market = s.markets[code], market.isLive,
                      CountryData.country(code)?.region == region else { continue }
                for tier in Tier.allCases { market.subs[tier] *= (1 - loss) }
                market.awareness = Formulas.clamp(market.awareness - 0.04, 0, 1)
                s.markets[code] = market
            }
            let lost = before - s.subscribers(in: region)
            totalChurned += lost
            s.outages[region.rawValue] = 3     // ticks down at week end, so service stays degraded for the next two weeks
            events.append(s.makeEvent(.warning, "Servers crashed in \(region.displayName)",
                                      "Overloaded servers went down. About \(Format.count(lost)) subscribers left and service will be shaky for two weeks. Add capacity so it doesn't happen again."))
        }

        fin.streaming = billedSubs * Formulas.streamingCostPerSubWeek * policy.streamingCost
        fin.policies = policy.flatCost + policy.overhead * fin.revenue
        fin.studios = s.weeklyStudioCost
        applyAttrition(&s, events: &events)
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

        for key in s.outages.keys.sorted() {
            let left = (s.outages[key] ?? 0) - 1
            s.outages[key] = left > 0 ? left : nil
        }
        for key in s.surges.keys.sorted() {
            let left = (s.surges[key] ?? 0) - 1
            s.surges[key] = left > 0 ? left : nil
        }

        if s.recessionWeeksLeft > 0 {
            s.recessionWeeksLeft -= 1
            if s.recessionWeeksLeft == 0 {
                events.append(s.makeEvent(.news, "Recession over", "Consumer spending is recovering."))
                s.addNews(.industry, "The recession is over", "Streaming demand is recovering across the industry.")
            }
        }

        s.advancePolicyState(effects: policy)

        let leaderboardBefore = Dictionary(uniqueKeysWithValues: input.leaderboard.map { ($0.id, $0.subs) })
        advanceRivals(&s, events: &events)
        progressTakeover(&s, events: &events)
        s.previousSubs = leaderboardBefore
        NewsEngine.update(&s)

        // Cash: prepaid items were already deducted when paid; principal repayments aren't P&L.
        s.finances.cash += fin.profit + prepaid - principalPaid
        s.finances.lastWeek = fin
        s.finances.history.append(fin)
        if s.finances.history.count > 26 { s.finances.history.removeFirst() }
        s.finances.lifetime = s.finances.lifetime.adding(fin)
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
            s.addNews(.you, "\(s.companyName) passes \(Format.count(milestone)) subscribers",
                      "Your service now has \(Format.count(totalAfter)) subscribers worldwide.")
        }

        // Win / lose
        // Goals
        let newGoals = achievedGoals(s).filter { !s.goals.contains($0) }
        for goal in newGoals {
            s.goals.append(goal)
            events.append(s.makeEvent(.milestone, "Goal reached: \(goalTitle(goal))", "A bonus goal is complete!"))
            s.addNews(.you, "\(s.companyName) reaches a goal: \(goalTitle(goal))", "A major milestone for your company.")
        }

        let broke = s.finances.weeksInDebt >= debtWeeksToLose
        if s.finances.cash < -s.overdraftLimit {
            // Debt can't grow forever: past the overdraft limit lenders pull the plug immediately.
            let reason = "Your debts reached \(Format.money(-s.finances.cash)), past the \(Format.money(s.overdraftLimit)) that lenders would tolerate. Creditors have taken over."
            s.outcome = .lost
            s.lossReason = reason
            events.append(s.makeEvent(.warning, "Bankrupt", reason))
        } else if broke && (!s.fundingAvailable || s.finances.weeksInDebt >= hardDebtLimit) {
            let reason = "Cash has been below zero for \(s.finances.weeksInDebt) straight weeks with no funding left. Creditors have taken over."
            s.outcome = .lost
            s.lossReason = reason
            events.append(s.makeEvent(.warning, "Bankrupt", reason))
        } else if s.week >= minWeeksToWin,
                  let topRival = s.rivals.map({ $0.totalSubs }).max(), totalAfter > topRival {
            s.outcome = .won
            events.append(s.makeEvent(.milestone, "You're #1!",
                                      "\(s.companyName) now has more subscribers than every rival."))
        } else if s.finances.cash < 0 {
            let used = Int(-s.finances.cash / s.overdraftLimit * 100)
            events.append(s.makeEvent(.warning, "Cash is negative (\(used)% of your credit limit)",
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

    /// Underpaid departments lose people; underpaid studio crews lose experience.
    private static func applyAttrition(_ s: inout GameState, events: inout [GameEvent]) {
        for department in Department.allCases where s.staff[department] > 0 {
            let chance = Formulas.attritionChance(pay: s.staff.payScale(department))
            if chance > 0, s.rng.chance(chance) {
                s.staff[department] -= 1
                events.append(s.makeEvent(.warning, "\(department.displayName) team member quit",
                                          "Low pay is costing you talent. \(department.displayName) dropped to level \(s.staff[department])."))
            }
        }
        let decay = Formulas.studioExperienceDecay(pay: s.staff.studioPay)
        if decay > 0 {
            for i in s.studios.indices { s.studios[i].experience = max(0, s.studios[i].experience - decay) }
        }
    }

    /// The hired licensing manager shops the market within the limits you set.
    private static func runCurator(_ s: inout GameState, events: inout [GameEvent]) {
        guard let run = s.curatorShop() else { return }
        s.curatorStatus = "Week \(s.week): \(run.note)"
        if !run.bought.isEmpty {
            events.append(s.makeEvent(.news, "Licensing manager signed \(run.bought.count) title\(run.bought.count == 1 ? "" : "s")",
                                      "\(run.bought.joined(separator: ", ")) for \(Format.money(run.spent)), within your limits."))
        }
    }

    private static func progressDatacenters(_ s: inout GameState, events: inout [GameEvent]) {
        for i in s.datacenters.indices where s.datacenters[i].weeksToBuild > 0 {
            s.datacenters[i].weeksToBuild -= 1
            if s.datacenters[i].weeksToBuild == 0 {
                let dc = s.datacenters[i]
                events.append(s.makeEvent(.news, "\(dc.name) is online",
                                          "+\(Format.count(Formulas.datacenterCapacity(level: dc.level))) viewers of capacity in \(dc.region.displayName)."))
            }
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

            let studioIndex = project.studioID.flatMap { id in s.studios.firstIndex { $0.id == id } }
            var studioBonus = 0.0
            var popularityBonus = 0
            if let si = studioIndex {
                studioBonus = s.studioBonus(for: s.studios[si], genre: project.genre)
                popularityBonus = Formulas.studioPopularityBonus(experience: s.studios[si].experience)
            }
            let expected = Formulas.expectedOriginalQuality(kind: project.kind, budget: project.budget,
                                                            weeks: project.weeksTotal)
                + Formulas.originalQualityBonus(contentLevel: s.staff.effectiveLevel(.content))
                + studioBonus
            let u1 = s.rng.nextDouble(), u2 = s.rng.nextDouble(), u3 = s.rng.nextDouble()
            let breakout = s.rng.chance(0.05)
            let quality = Formulas.rolledOriginalQuality(expected: expected, u1: u1, u2: u2, u3: u3, breakout: breakout)
            let popularity = min(100, Formulas.originalPopularity(quality: quality, u: s.rng.nextDouble()) + popularityBonus)
            let title = Title(id: s.takeID(), name: project.name, kind: project.kind, genre: project.genre,
                              language: project.language, quality: quality, popularity: popularity,
                              ageWeeks: 0, isOriginal: true, license: nil, weeksRemaining: nil,
                              listingWeeksLeft: 0)
            s.catalog.append(title)
            if quality >= 80, let region = s.busiestRegion { s.surges[region.rawValue] = max(s.surges[region.rawValue] ?? 0, 1) }
            let verdict = breakout ? "A runaway hit!" : quality >= 75 ? "Critics love it." : quality <= 40 ? "A flop." : "A solid addition."
            var origin = ""
            if let si = studioIndex {
                s.studios[si].experience = min(100, s.studios[si].experience + Formulas.studioExperienceGain(quality: quality))
                origin = " from \(s.studios[si].name)"
            }
            events.append(s.makeEvent(.news, "\"\(project.name)\" premieres",
                                      "Your original\(origin) (quality \(quality), popularity \(popularity)) is live worldwide. \(verdict)"))
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
        var newsLicenses = 0
        let threats = s.rivals.map { s.threat(from: $0) }     // rivals bid harder against a dominant player
        for title in s.licenseMarket {
            var winner: Int?
            for index in s.rivals.indices {
                let chance = Formulas.bidChance(personality: s.rivals[index].personality, quality: title.quality)
                    * (1 + 0.5 * threats[index])
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
            if title.quality >= 70, newsLicenses < 2 {
                let rival = s.rivals[w]
                s.addNews(.licensing, "\(rival.name) licenses \"\(title.name)\"",
                          "A \(title.quality)-quality \(title.genre.displayName.lowercased()) \(title.kind.displayName.lowercased()) goes to \(rival.name), strengthening its catalog.",
                          rival: rival.id)
                newsLicenses += 1
            }
        }
        s.licenseMarket = kept

        var added = 0
        while s.licenseMarket.count < GameState.targetListings && added < 4 {
            let id = s.takeID()
            let taken = Set(s.licenseMarket.map(\.name) + s.catalog.map(\.name) + s.projects.map(\.name))
            let title = TitleGenerator.generate(id: id, rng: &s.rng, avoiding: taken)
            s.licenseMarket.append(title)
            added += 1
        }
    }

    private static func advanceRivals(_ s: inout GameState, events: inout [GameEvent]) {
        let allCodes = CountryData.all.map { $0.code }
        var announcedExpansion = false
        var announcedPriceCut = false
        var announcedPriceWar = false

        for i in s.rivals.indices {
            var rival = s.rivals[i]
            let noise = s.rng.nextDouble(in: 0.8...1.2)

            // How threatened is this rival by your market share where they compete?
            let threat = s.threat(from: rival)

            // Income and slow catalog improvement (originals-heavy rivals invest harder when threatened).
            rival.cash += rival.totalSubs * 0.12
            let investment = rival.personality == .originalsHeavy ? 0.15 : 0.05
            rival.catalogStrength = min(100, rival.catalogStrength + 0.02 + investment * threat)

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
                    // Regional champions expand into neighbouring countries first.
                    let homeRegions = Set(rival.subs.keys.compactMap { CountryData.country($0)?.region })
                    let choices = absent.map { code -> (String, Double) in
                        let country = CountryData.country(code)
                        let neighbour = rival.personality == .regionalChampion
                            && country.map { homeRegions.contains($0.region) } == true
                        return (code, (country?.subscriberCeiling ?? 1) * (neighbour ? 4 : 1))
                    }
                    let code = s.rng.pickWeighted(choices)
                    if let country = CountryData.country(code), rival.cash >= country.launchCost * 0.5 {
                        rival.cash -= country.launchCost * 0.5
                        rival.subs[code] = country.subscriberCeiling * 0.005
                        s.addNews(.expansion, "\(rival.name) launches in \(country.name)",
                                  "\(country.flag) \(rival.name) opens in \(country.name), a market of \(Format.count(country.subscriberCeiling)) subscriptions, now in \(rival.countryCount) countries.",
                                  rival: rival.id)
                        if !announcedExpansion, s.markets[code]?.isLive == true {
                            announcedExpansion = true
                            events.append(s.makeEvent(.news, "\(rival.name) enters \(country.name)",
                                                      "\(rival.name) just launched in \(country.flag) \(country.name), where you operate."))
                        }
                    }
                }
            }

            // Pricing moves. A dominant player triggers price wars; ordinary promotions fade back to normal.
            let previousLevel = rival.priceLevel
            var warCut = false
            if s.rng.chance(Formulas.retaliationChance(personality: rival.personality, threat: threat)) {
                let cutting = threat > 0.15 ? true : s.rng.chance(rival.personality == .priceCutter ? 0.75 : 0.45)
                let step = s.rng.nextDouble(in: 0.04...0.10) * (1 + threat)
                rival.priceLevel = Formulas.clamp(rival.priceLevel + (cutting ? -step : step),
                                                  Formulas.priceFloor(threat: threat), 1.15)
                warCut = cutting && threat >= 0.3
            }
            // While you're a threat, discounts stick instead of fading.
            rival.priceLevel += (1 - rival.priceLevel) * (threat > 0.3 ? 0.002 : 0.01)

            // Customers swing back: a discounting rival pulls subscribers out of markets you dominate.
            if rival.priceLevel < 0.95 {
                for code in rival.subs.keys.sorted() {
                    guard var market = s.markets[code], market.isLive else { continue }
                    let rate = Formulas.poachRate(priceLevel: rival.priceLevel, threat: s.countryThreat(code))
                    guard rate > 0 else { continue }
                    let defected = market.subs.total * rate
                    for tier in Tier.allCases { market.subs[tier] *= (1 - rate) }
                    s.markets[code] = market
                    rival.subs[code, default: 0] += defected
                }
            }

            let overlap = s.markets.contains { $0.value.isLive && (rival.subs[$0.key] ?? 0) > 0 }
            let priceMove = rival.priceLevel - previousLevel
            if warCut {
                s.addNews(.pricing, "\(rival.name) declares a price war on \(s.companyName)",
                          "Prices are down \(Int(-priceMove * 100))% in a bid to win back subscribers.", rival: rival.id)
            } else if priceMove <= -0.05 {
                s.addNews(.pricing, "\(rival.name) cuts prices",
                          "A promotion takes about \(Int(-priceMove * 100))% off its plans. Expect a fight for budget-conscious viewers.", rival: rival.id)
            } else if priceMove >= 0.05 {
                s.addNews(.pricing, "\(rival.name) raises prices",
                          "Plans cost about \(Int(priceMove * 100))% more, which may push customers to cheaper services.", rival: rival.id)
            }
            if warCut, !announcedPriceWar, overlap {
                announcedPriceWar = true
                announcedPriceCut = true
                events.append(s.makeEvent(.warning, "\(rival.name) declares a price war",
                                          "Your growing share has \(rival.name) slashing prices to win customers back. Expect churn and defections where you compete. Consider matching with better content or sharper prices."))
            } else if !announcedPriceCut, previousLevel - rival.priceLevel >= 0.05, overlap {
                announcedPriceCut = true
                events.append(s.makeEvent(.news, "\(rival.name) slashes prices",
                                          "Expect extra churn in markets where \(rival.name) competes with you."))
            }

            // Investor mood drifts back to normal with random swings.
            rival.sentiment = Formulas.clamp(rival.sentiment + (1 - rival.sentiment) * 0.04 + s.rng.nextDouble(in: -0.03...0.03), 0.6, 1.6)

            s.rivals[i] = rival
        }
    }

    /// Counts a takeover bid down and holds the shareholder vote when time is up.
    private static func progressTakeover(_ s: inout GameState, events: inout [GameEvent]) {
        guard var bid = s.takeover else { return }
        bid.weeksLeft -= 1
        s.takeover = bid
        guard let rival = s.rivals.first(where: { $0.id == bid.rivalID }) else { s.takeover = nil; return }
        if bid.weeksLeft > 0 {
            if bid.weeksLeft == 2 {
                s.addNews(.industry, "\(rival.name)'s board urges shareholders to reject \(s.companyName)",
                          "The board calls the \(Int(bid.premium * 100))% premium opportunistic and hunts for a white knight.", rival: rival.id)
            }
            return
        }
        let chance = s.takeoverChance(rival, premium: bid.premium)
        let success = s.rng.chance(chance)
        let name = rival.name
        s.finishTakeover(success: success)
        events.append(s.makeEvent(success ? .milestone : .warning,
                                  success ? "You acquired \(name)!" : "Takeover of \(name) failed",
                                  success ? "Shareholders accepted your bid. Their subscribers, cash and library are yours."
                                          : "Shareholders rejected your bid. You recover your offer minus a 2% fee."))
    }
}
