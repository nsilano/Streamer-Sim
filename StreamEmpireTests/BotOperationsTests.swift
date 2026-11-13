import XCTest
#if canImport(StreamEmpireCore)
@testable import StreamEmpireCore
#else
@testable import StreamEmpire
#endif

// MARK: - Randomized operations/growth bot ("fuzzer")

/// Plays the operations and growth side of the game with random (mostly invalid or silly) decisions,
/// and checks invariants after every action and every simulated week. All randomness is `SeededRNG`.
private final class Fuzz {
    let seed: UInt64
    var s: GameState
    var rng: SeededRNG
    var failures = 0
    var checks: Bool
    var sawGameOver = false

    init(seed: UInt64, home: String, difficulty: Difficulty, cash: Double?, checks: Bool = true) {
        var st = GameState.newGame(startCountry: home, companyName: "Fuzz Co", seed: seed, difficulty: difficulty)
        st.eventsEnabled = false
        if let c = cash { st.finances.cash = c }
        var r = SeededRNG(seed: seed &* 7919 &+ 13)
        st.renewalMode = r.pick(RenewalMode.allCases)
        st.expiryAlerts = .show
        self.seed = seed
        self.s = st
        self.rng = r
        self.checks = checks
    }

    // MARK: Assertion helpers

    func expect(_ ok: Bool, _ msg: @autoclosure () -> String) {
        if ok { return }
        failures += 1
        if failures <= 10 { XCTFail("[seed \(seed) week \(s.week)] \(msg())") }
    }

    func finite(_ v: Double, _ what: @autoclosure () -> String) {
        if v.isFinite { return }
        failures += 1
        if failures <= 10 { XCTFail("[seed \(seed) week \(s.week)] not finite: \(what()) = \(v)") }
    }

    func pickOpt<T>(_ items: [T]) -> T? { items.isEmpty ? nil : rng.pick(items) }

    // MARK: Running

    func run(weeks: Int) {
        var w = 0
        while w < weeks && failures < 25 {
            w += 1
            if s.outcome != .playing {
                sawGameOver = true
                // A finished game must be frozen, and late actions must not corrupt it.
                let again = SimulationEngine.advanceWeek(s)
                expect(again == s, "advanceWeek changed the state after the game ended (\(s.outcome.rawValue))")
                for _ in 0..<12 { doAction() }
                let later = SimulationEngine.advanceWeek(s)
                expect(later == s, "advanceWeek changed the state after late actions (\(s.outcome.rawValue))")
                break
            }
            shop()
            if s.week % 10 == 1 {
                let budget = min(40_000, max(0, s.finances.cash * 0.003))
                for code in s.liveMarketCodes { _ = try? s.setMarketing(code: code, weeklyBudget: budget) }
            }
            let n = rng.nextInt(in: 1...5)
            for _ in 0..<n { doAction() }

            let before = s
            let after = SimulationEngine.advanceWeek(before)
            if checks { checkWeek(before: before, after: after) }
            s = after
            if checks && s.week % 50 == 0 { roundTrip() }
        }
    }

    func roundTrip() {
        do {
            let data = try JSONEncoder().encode(s)
            let loaded = try JSONDecoder().decode(GameState.self, from: data)
            expect(loaded == s, "JSON round trip changed the state")
            s = loaded
        } catch {
            expect(false, "JSON round trip threw: \(error)")
        }
    }

    /// Keeps a modest catalog so the world has subscribers to break things with.
    func shop() {
        var bought = 0
        while bought < 2, s.catalog.count < 120 + s.week / 3 {
            bought += 1
            let cash = s.finances.cash
            let options = s.licenseMarket.filter { s.licensePrice($0) < cash * 0.25 && $0.embargoWeeks == 0 }
            guard let t = pickOpt(options) else { break }
            _ = try? s.buyLicense(titleID: t.id)
        }
    }

    // MARK: Actions

    func randomPrices() -> TierSet {
        func p() -> Double {
            if rng.chance(0.04) { return rng.chance(0.5) ? -1 : 150 }      // invalid on purpose
            return (rng.nextDouble(in: 0...25) * 2).rounded() / 2
        }
        let a = p(), b = p(), c = p()
        return TierSet(ad: a, standard: b, premium: c)
    }

    func statuses() -> [String: MarketStatus] {
        var out: [String: MarketStatus] = [:]
        for (code, m) in s.markets { out[code] = m.status }
        return out
    }

    /// One random action, followed by the check that market status moved legally.
    func doAction() {
        let pre = statuses()
        act(rng.nextInt(in: 0...47))
        let post = statuses()
        for code in pre.keys.sorted() {
            guard let a = pre[code], let b = post[code] else { continue }
            if a == b { continue }
            var ok = false
            if b == .notLaunched && a != .notLaunched { ok = true }                    // exitMarket
            if a == .notLaunched && b == .launching(weeksLeft: Formulas.marketLaunchWeeks) { ok = true }      // launchMarket
            expect(ok, "illegal market status change by an action in \(code): \(a) -> \(b)")
        }
        finite(s.finances.cash, "cash after action")
    }

    func act(_ kind: Int) {
        let live = s.liveMarketCodes
        switch kind {
        case 0, 1:
            let code = rng.pick(CountryData.all).code
            _ = try? s.launchMarket(code: code)
        case 2:
            if rng.chance(0.3), let c = pickOpt(live) { _ = try? s.exitMarket(code: c) }
        case 3:
            let tier = rng.pick(Tier.allCases)
            if let c = pickOpt(live) { _ = try? s.launchTier(tier, code: c) }
        case 4, 5:
            let prices = randomPrices()
            if let c = pickOpt(live) { _ = try? s.setPrices(code: c, prices: prices) }
        case 6:
            let level = rng.nextDouble(in: 0.3...2.2)
            _ = try? s.applyPriceLevel(level)
        case 7, 8:
            let budget = rng.nextDouble(in: -1_000...200_000)
            if let c = pickOpt(live) { _ = try? s.setMarketing(code: c, weeklyBudget: budget) }
        case 9, 10:
            let scope = rng.chance(0.4) ? "" : (pickOpt(live) ?? "")
            let kindP = rng.pick(PromotionKind.allCases)
            let weeks = rng.nextInt(in: 0...14)
            let intensity = rng.nextDouble(in: 0.05...0.65)
            _ = try? s.launchPromotion(kind: kindP, scope: scope, weeks: weeks, intensity: intensity)
        case 11:
            if let p = pickOpt(s.promotions) { _ = try? s.cancelPromotion(id: p.id) }
        case 12:
            let pk = rng.pick(PartnershipKind.allCases)
            if let c = pickOpt(live) { _ = try? s.signPartnership(code: c, kind: pk) }
        case 13:
            let platform = rng.pick(Platform.allCases)
            _ = try? s.startPlatform(platform)
        case 14:
            let region = rng.pick(Region.allCases)
            _ = try? s.buildDatacenter(region: region)
        case 15:
            if let dc = pickOpt(s.datacenters) { _ = try? s.upgradeDatacenter(id: dc.id) }
        case 16:
            let region = rng.pick(Region.allCases)
            _ = try? s.rentCloud(region: region)
        case 17:
            let region = rng.pick(Region.allCases)
            _ = try? s.releaseCloud(region: region)
        case 18, 19:
            if let cand = pickOpt(s.candidates) { _ = try? s.hire(candidateID: cand.id) }
        case 20:
            let dept = rng.pick(Department.allCases)
            _ = try? s.hire(dept)
        case 21:
            if rng.chance(0.5), let e = pickOpt(s.staff.employees) { _ = try? s.fire(employeeID: e.id) }
        case 22:
            let pay = rng.nextDouble(in: 0.4...1.8)
            if let e = pickOpt(s.staff.employees) { _ = try? s.setSalary(employeeID: e.id, pay: pay) }
        case 23:
            let dept = rng.pick(Department.allCases)
            let scale = rng.nextDouble(in: 0.4...1.8)
            _ = try? s.setPay(dept, scale: scale)
        case 24:
            let scale = rng.nextDouble(in: 0.4...1.8)
            _ = try? s.setStudioPay(scale: scale)
        case 25:
            if rng.chance(0.4) {
                let dept = rng.pick(Department.allCases)
                _ = try? s.reduceStaff(dept)
            }
        case 26:
            let genre = rng.pick(Genre.allCases)
            _ = try? s.foundStudio(specialty: genre)
        case 27:
            if let st = pickOpt(s.studios) { _ = try? s.upgradeStudio(id: st.id) }
        case 28:
            let sid: Int? = rng.chance(0.5) ? s.studios.first?.id : nil
            let kindT: TitleKind = rng.chance(0.5) ? .series : .movie
            let genre = rng.pick(Genre.allCases)
            let budget = rng.nextDouble(in: 1_000_000...20_000_000)
            let weeks = rng.nextInt(in: 5...30)
            _ = try? s.commissionOriginal(kind: kindT, genre: genre, language: .english, budget: budget, weeks: weeks, studioID: sid)
        case 29:
            let amount = rng.nextDouble(in: 100_000...60_000_000)
            let term = rng.pick([52, 104, 208, 13])
            _ = try? s.takeLoan(amount: amount, termWeeks: term)
        case 30:
            let frac = rng.nextDouble(in: 0.1...1.6)
            if let loan = pickOpt(s.loans) { _ = try? s.repayLoan(id: loan.id, amount: loan.balance * frac) }
        case 31:
            let pct = rng.nextDouble(in: 0.04...0.27)
            _ = try? s.raiseRound(percent: pct)
        case 32:
            _ = try? s.launchIPO()
        case 33:
            if rng.chance(0.5) {
                let pct = rng.nextDouble(in: 0.005...0.12)
                _ = try? s.buyBackShares(percent: pct)
            } else {
                _ = try? s.payDividend()
            }
        case 34, 35:
            let pct = rng.nextDouble(in: 0.003...0.27)
            if let r = pickOpt(s.rivals) { _ = try? s.buyShares(rivalID: r.id, percent: pct) }
        case 36:
            let pct = rng.nextDouble(in: 0.003...0.3)
            if let r = pickOpt(s.rivals) { _ = try? s.sellShares(rivalID: r.id, percent: pct) }
        case 37:
            let premium = rng.nextDouble(in: 0.05...1.05)
            if let r = pickOpt(s.rivals) { _ = try? s.launchTakeover(rivalID: r.id, premium: premium) }
        case 38, 39:
            // Bad outcomes only: the "good" outcomes of some policies add subscribers with no regard for the
            // country ceiling (see testBug_policySubscriberBoostIgnoresCeiling), which would blur the ceiling checks.
            let def = rng.pick(PolicyData.all)
            let opt = rng.pick(def.options)
            _ = try? s.setPolicy(def.id, option: opt.id, forcedBad: true)
        case 40:
            var scope = rng.chance(0.4) ? GameState.allScope : rng.pick(Region.allCases).rawValue
            if rng.chance(0.05) { scope = "bogus" }
            _ = try? s.setSignupsPaused(scope: scope, paused: rng.chance(0.45))
        case 41:
            let load = rng.nextDouble(in: 0.4...1.6)
            _ = try? s.setAdLoad(load)
        case 42:
            let f = rng.pick(ProductFeature.allCases)
            _ = try? s.buyFeature(f)
        case 43:
            if let o = pickOpt(s.acquisitionOffers) { _ = try? s.acceptAcquisition(id: o.id) }
        case 44:
            let premium = rng.nextDouble(in: 0.9...1.7)
            if let o = pickOpt(s.sportsOffers) { _ = try? s.bidForSports(offerID: o.id, premium: premium) }
        case 45:
            if s.curator == nil {
                let mode = rng.pick(CuratorMode.allCases)
                _ = try? s.hireCurator(mode: mode)
            } else if rng.chance(0.3) {
                s.fireCurator()
            }
        case 46:
            _ = try? s.renewAll(years: rng.nextInt(in: 1...5))
        default:
            // Pause and resume the brake and spend on infrastructure: the busiest region gets cloud first.
            if let region = s.busiestRegion, s.serverLoad(region) > 0.8 { _ = try? s.rentCloud(region: region) }
        }
    }

    // MARK: Invariants for a whole state

    func checkState(_ t: GameState) {
        finite(t.finances.cash, "cash")
        let f = t.finances.lastWeek
        finite(f.subscriptionRevenue, "subscriptionRevenue"); finite(f.adRevenue, "adRevenue")
        finite(f.licensing, "licensing"); finite(f.streaming, "streaming"); finite(f.staff, "staff")
        finite(f.marketing, "marketing"); finite(f.operations, "operations"); finite(f.originals, "originals")
        finite(f.interest, "interest"); finite(f.fines, "fines"); finite(f.other, "other"); finite(f.tech, "tech")
        finite(f.studios, "studios"); finite(f.policies, "policies"); finite(f.promotions, "promotions")
        finite(f.taxes, "taxes"); finite(f.profit, "profit")
        finite(t.valuation, "valuation")
        finite(t.earningsSentiment, "earningsSentiment")
        finite(t.totalSubscribers, "totalSubscribers")
        finite(t.platformReach, "platformReach")
        finite(t.brandTrust, "brandTrust"); finite(t.regulatoryHeat, "regulatoryHeat")
        expect(t.brandTrust >= 0 && t.brandTrust <= 100, "brandTrust out of range: \(t.brandTrust)")
        expect(t.regulatoryHeat >= 0 && t.regulatoryHeat <= 100, "regulatoryHeat out of range: \(t.regulatoryHeat)")
        expect(t.adLoad >= 0.5 && t.adLoad <= 1.5, "adLoad out of range: \(t.adLoad)")
        expect(t.equity.ownership >= 0 && t.equity.ownership <= 1.0000001, "ownership out of 0...1: \(t.equity.ownership)")
        for key in t.fx.keys.sorted() {
            let v = t.fx[key] ?? 1
            finite(v, "fx \(key)")
            expect(v >= 0.79 && v <= 1.21, "fx \(key) out of range: \(v)")
        }
        if t.outcome == .lost { expect(t.lossReason != nil, "lost without a lossReason") }

        // Markets
        for code in t.markets.keys.sorted() {
            guard let m = t.markets[code], let c = CountryData.country(code) else {
                expect(false, "market \(code) is not a known country")
                continue
            }
            for tier in Tier.allCases {
                finite(m.subs[tier], "subs \(code) \(tier.rawValue)")
                expect(m.subs[tier] >= 0, "negative subs \(code) \(tier.rawValue): \(m.subs[tier])")
                finite(m.prices[tier], "price \(code) \(tier.rawValue)")
                expect(m.prices[tier] >= 0 && m.prices[tier] <= 100, "price out of range \(code) \(tier.rawValue): \(m.prices[tier])")
            }
            finite(m.awareness, "awareness \(code)")
            expect(m.awareness >= 0 && m.awareness <= 1, "awareness out of 0...1 in \(code): \(m.awareness)")
            finite(m.marketingBudget, "marketingBudget \(code)")
            expect(m.marketingBudget >= 0, "negative marketing budget in \(code)")
            expect(m.piracy >= 0 && m.piracy <= 0.6000001, "piracy out of range in \(code): \(m.piracy)")
            expect(m.liveTiers.contains(.standard), "Standard tier missing from liveTiers in \(code)")
            expect(Set(m.liveTiers).count == m.liveTiers.count, "duplicate liveTiers in \(code)")
            for b in m.tierBuilds { expect(b.weeksLeft >= 1, "expired tier build in \(code)") }
            switch m.status {
            case .launching(let w):
                expect(w >= 1 && w <= Formulas.marketLaunchWeeks, "launching weeksLeft out of range in \(code): \(w)")
                expect(m.subs.total == 0, "subscribers in a market that is still launching: \(code)")
            case .notLaunched:
                expect(m.subs.total == 0, "subscribers in a market that is not launched: \(code)")
            case .live:
                break
            }
            let ceiling = c.subscriberCeiling
            expect(m.subs.total <= ceiling * 1.001 + 10, "your subs exceed the country ceiling in \(code): \(m.subs.total) vs \(ceiling)")
            var rivalTotal = 0.0
            for r in t.rivals { rivalTotal += r.subs[code] ?? 0 }
            // Enforced: your adds <= headroom, rival growth <= 95% of the ceiling. Not enforced: a rival's expansion
            // seed (0.5% of the ceiling per rival), so allow a few percent.
            expect(m.subs.total + rivalTotal <= ceiling * 1.06 + 100,
                   "players + rivals exceed ceiling in \(code): \(m.subs.total + rivalTotal) vs \(ceiling)")
        }

        // Rivals
        var seenRivals = Set<String>()
        for r in t.rivals {
            expect(!seenRivals.contains(r.id), "duplicate rival id \(r.id)")
            seenRivals.insert(r.id)
            finite(r.cash, "rival cash \(r.id)"); expect(r.cash >= 0, "negative rival cash \(r.id): \(r.cash)")
            finite(r.priceLevel, "rival priceLevel \(r.id)")
            expect(r.priceLevel >= 0.5 && r.priceLevel <= 1.2, "rival priceLevel out of range \(r.id): \(r.priceLevel)")
            finite(r.catalogStrength, "rival catalogStrength \(r.id)")
            expect(r.catalogStrength >= 0 && r.catalogStrength <= 100.0001, "rival catalogStrength out of range \(r.id)")
            finite(r.sentiment, "rival sentiment \(r.id)")
            expect(r.sentiment >= 0.59 && r.sentiment <= 1.61, "rival sentiment out of range \(r.id): \(r.sentiment)")
            for code in r.subs.keys.sorted() {
                let v = r.subs[code] ?? 0
                finite(v, "rival subs \(r.id) \(code)")
                expect(v >= 0, "negative rival subs \(r.id) \(code): \(v)")
            }
        }
        let rank = t.rank
        expect(rank >= 1 && rank <= t.rivals.count + 1, "rank out of range: \(rank)")

        // Servers
        for region in Region.allCases {
            let cap = t.serverCapacity(region)
            finite(cap, "capacity \(region.rawValue)")
            expect(cap > 0, "capacity <= 0 in \(region.rawValue)")
            finite(t.serverLoad(region), "serverLoad \(region.rawValue)")
            finite(t.effectiveLoad(region), "effectiveLoad \(region.rawValue)")
            expect(t.datacenters(in: region).count <= Formulas.maxDatacentersPerRegion, "more than \(Formulas.maxDatacentersPerRegion) datacenters in \(region.rawValue)")
            let cloud = t.cloudUnits[region.rawValue] ?? 0
            expect(cloud >= 0 && cloud <= 10, "cloud units out of range in \(region.rawValue): \(cloud)")
        }
        for dc in t.datacenters {
            expect(dc.level >= 1 && dc.level <= 5, "datacenter level out of range")
            expect(dc.weeksToBuild >= 0, "datacenter weeksToBuild negative")
        }
        for key in t.outages.keys.sorted() { expect((t.outages[key] ?? 0) > 0, "expired outage entry \(key)") }
        for key in t.surges.keys.sorted() { expect((t.surges[key] ?? 0) > 0, "expired surge entry \(key)") }
        expect(Set(t.platforms).count == t.platforms.count, "duplicate platforms")
        for b in t.builds {
            expect(!t.platforms.contains(b.platform), "platform \(b.platform.rawValue) is built and still building")
            expect(b.weeksLeft >= 1, "expired platform build")
        }

        // Money in / out
        for loan in t.loans {
            finite(loan.balance, "loan balance")
            expect(loan.balance >= 0.01, "loan with ~zero or negative balance was not removed: \(loan.balance)")
            expect(loan.weeklyPrincipal > 0, "loan without weekly principal")
        }
        expect(Set(t.loans.map(\.id)).count == t.loans.count, "duplicate loan ids")
        finite(t.outstandingDebt, "outstandingDebt")
        expect(t.finances.ledger.licenseIncome >= 0, "negative license income in ledger")

        // Caps and expiry of temporary things
        expect(t.promotions.count <= PromoMath.maxActive, "more than \(PromoMath.maxActive) promotions: \(t.promotions.count)")
        for p in t.promotions {
            expect(p.weeksLeft >= 1 && p.weeksLeft <= p.weeksTotal, "promotion with bad weeksLeft \(p.weeksLeft)/\(p.weeksTotal)")
            if !p.scope.isEmpty { expect(t.markets[p.scope]?.isLive == true, "promotion scoped to a market that is not live: \(p.scope)") }
        }
        for h in t.promoHangovers { expect(h.weeksLeft >= 1, "expired promo hangover") }
        expect(t.promoHistory.count <= 12, "promoHistory over cap")
        expect(t.partnerships.count <= GameState.maxPartnerships, "more than \(GameState.maxPartnerships) partnerships")
        var partnerCountries = Set<String>()
        for p in t.partnerships {
            expect(p.weeksLeft >= 1, "expired partnership")
            expect(!partnerCountries.contains(p.country), "two partnerships in \(p.country)")
            partnerCountries.insert(p.country)
            expect(t.markets[p.country]?.isLive == true, "partnership in a market that is not live: \(p.country)")
        }
        for sh in t.policyShocks { expect(sh.weeksLeft >= 1, "expired policy shock \(sh.policyID)") }
        expect(t.policyLog.count <= 30, "policyLog over cap")
        expect(t.news.count <= 150, "news over cap: \(t.news.count)")
        expect(t.reportHistory.count <= 26, "reportHistory over cap")
        expect(t.trend.count <= 520, "trend over cap")
        expect(t.finances.history.count <= 26, "finance history over cap")
        expect(t.finances.profitHistory.count <= 12, "profitHistory over cap")
        expect(t.finances.revenueHistory.count <= 52, "revenueHistory over cap")
        expect(t.quarterReports.count <= 12, "quarterReports over cap")
        expect(t.studios.count <= Formulas.maxStudios, "more studios than allowed")
        for st in t.studios { expect(st.level >= 1 && st.level <= 5, "studio level out of range"); finite(st.experience, "studio experience") }
        expect(t.acquisitionOffers.count <= 2, "more than 2 acquisition offers")
        for h in t.sportsHeld { expect(h.weeksLeft >= 1, "expired sports right") }
        expect(t.candidates.count <= GameState.candidatePoolSize, "candidate pool over size: \(t.candidates.count)")
        expect(Set(t.pausedSignups).count == t.pausedSignups.count, "duplicate pausedSignups")
        for scope in t.pausedSignups { expect(scope == GameState.allScope || Region(rawValue: scope) != nil, "invalid pausedSignups scope \(scope)") }

        // People
        var seenEmployees = Set<Int>()
        for e in t.staff.employees {
            expect(!seenEmployees.contains(e.id), "duplicate employee id \(e.id)")
            seenEmployees.insert(e.id)
            expect(e.skill >= 1 && e.skill <= 3, "employee skill out of range")
            expect(e.pay >= 0.59 && e.pay <= 1.61, "employee pay out of range: \(e.pay)")
        }
        expect(t.staff.studioPay >= 0.59 && t.staff.studioPay <= 1.61, "studio pay out of range")
        for dept in Department.allCases {
            finite(t.staff.effectiveLevel(dept), "effectiveLevel \(dept.rawValue)")
            expect(t.staff[dept] >= 0 && t.staff[dept] <= 5, "department level out of range")
        }

        // Catalog
        var seenTitles = Set<Int>()
        for title in t.catalog {
            expect(!seenTitles.contains(title.id), "duplicate title id \(title.id)")
            seenTitles.insert(title.id)
            expect(title.weeksRemaining == nil || (title.weeksRemaining ?? 0) > 0, "expired title still in catalog: \(title.name)")
        }
        for p in t.projects { expect(p.weeksLeft >= 1, "finished project still in projects") }

        // Investing
        for id in t.stakes.keys.sorted() {
            let v = t.stakes[id] ?? 0
            expect(v > 0 && v <= Formulas.openMarketLimit + 1e-9, "stake out of range in \(id): \(v)")
            expect(t.rivals.contains { $0.id == id }, "stake in a rival that no longer exists: \(id)")
        }
        for id in t.stakeBasis.keys.sorted() { expect(t.stakes[id] != nil, "stake basis without a stake: \(id)") }
        if let bid = t.takeover {
            expect(bid.weeksLeft >= 1 && bid.weeksLeft <= Formulas.takeoverWeeks, "takeover weeksLeft out of range")
            expect(t.rivals.contains { $0.id == bid.rivalID }, "takeover bid on a rival that no longer exists")
            expect(bid.escrow >= 0, "negative escrow")
        }
        for id in t.acquiredRivals { expect(!t.rivals.contains { $0.id == id }, "acquired rival is still a rival: \(id)") }
    }

    // MARK: Invariants for one simulated week

    func checkWeek(before: GameState, after: GameState) {
        checkState(after)
        expect(after.week == before.week + 1, "week did not advance by one")

        // Legal market status transitions.
        let acquiring = before.takeover != nil
        for code in before.markets.keys.sorted() {
            guard let a = before.markets[code]?.status, let b = after.markets[code]?.status else { continue }
            var ok = false
            switch a {
            case .notLaunched: ok = (b == .notLaunched) || (acquiring && b == .live)
            case .launching(let w):
                if w <= 1 { ok = (b == .live) } else { ok = (b == .launching(weeksLeft: w - 1)) || (acquiring && b == .live) }
            case .live: ok = (b == .live)
            }
            expect(ok, "illegal status transition in \(code): \(a) -> \(b)")
        }

        // Money: cash moves by profit + prepaid spend - principal, and nothing else (except takeover votes).
        let resolving = before.takeover.map { $0.weeksLeft <= 1 } ?? false
        if !resolving {
            var principal = 0.0
            for loan in before.loans { principal += min(loan.balance, loan.weeklyPrincipal) }
            let profit = after.finances.lastWeek.profit
            let expected = before.finances.cash - after.finances.ledger.total + profit
                + before.finances.ledger.total - principal - before.finances.ledger.licenseIncome
            let mag = max(abs(expected), abs(after.finances.cash), abs(profit), 1_000)
            expect(abs(expected - after.finances.cash) <= 1e-7 * mag + 0.05,
                   "cash is not conserved: expected \(expected), got \(after.finances.cash) (profit \(profit), prepaid \(before.finances.ledger.total), principal \(principal))")
        }
        expect(after.pendingPriceChanges.isEmpty, "pendingPriceChanges not cleared by the week")

        // Report and sign-up brake.
        if let report = after.lastReport {
            expect(abs(report.totalSubs - after.totalSubscribers) <= 1e-6 * max(1, after.totalSubscribers),
                   "report.totalSubs \(report.totalSubs) != state total \(after.totalSubscribers)")
            expect(Set(report.events.map(\.id)).count == report.events.count, "duplicate event ids in the weekly report")
            finite(report.newSubs, "report.newSubs"); finite(report.churned, "report.churned")
            for m in report.markets {
                finite(m.newSubs, "market newSubs \(m.id)"); finite(m.churned, "market churned \(m.id)")
                finite(m.revenue, "market revenue \(m.id)"); finite(m.costs, "market costs \(m.id)")
                expect(m.newSubs >= 0 && m.churned >= 0, "negative adds/churn in \(m.id)")
                guard let c = CountryData.country(m.id) else { continue }
                if before.signupsPaused(in: c.region) {
                    expect(m.newSubs == 0, "sign-ups are paused in \(c.region.rawValue) but \(m.id) reports \(m.newSubs) new subs")
                    if !acquiring, let b = before.markets[m.id], let a = after.markets[m.id], b.isLive {
                        expect(a.subs.total <= b.subs.total + 1e-6 * max(1, b.subs.total),
                               "subs grew in a paused region (\(m.id)): \(b.subs.total) -> \(a.subs.total)")
                    }
                }
            }
        }

        // Read-only helpers never crash and give unique ids.
        let reasons = PauseCheck.reasons(before: before, after: after)
        expect(Set(reasons.map(\.id)).count == reasons.count, "PauseCheck returned duplicate ids")
        let recs = after.recommendations()
        expect(Set(recs.map(\.id)).count == recs.count, "recommendations() returned duplicate ids: \(recs.map(\.id))")
        let adv = after.advice()
        expect(Set(adv.map(\.id)).count == adv.count, "advice() returned duplicate ids")
        let diag = after.diagnosis()
        expect(Set(diag.map(\.id)).count == diag.count, "diagnosis() returned duplicate ids")
        _ = after.costBreakdown()
        _ = after.losingMarkets()
        _ = after.leaderboard
    }
}

// MARK: - Tests

final class BotOperationsTests: XCTestCase {
    private static let runs: [(UInt64, String, Difficulty, Double?)] = [
        (101, "US", .medium, nil),
        (102, "IN", .hard, 5_000_000_000),
        (103, "SA", .easy, nil),
        (104, "JP", .medium, 5_000_000_000),
        (105, "IE", .hard, nil),
        (106, "DE", .easy, 2_000_000_000),
        (107, "BR", .medium, 300_000_000),
        (108, "NG", .hard, nil),
    ]

    private func play(_ range: Range<Int>, weeks: Int = 600) {
        for i in range {
            let r = BotOperationsTests.runs[i]
            let fuzz = Fuzz(seed: r.0, home: r.1, difficulty: r.2, cash: r.3)
            fuzz.run(weeks: weeks)
            XCTAssertEqual(fuzz.failures, 0, "seed \(r.0) (\(r.1), \(r.2.rawValue)) broke invariants")
        }
    }

    func testFuzzSeedsFirstHalf() { play(0..<4) }

    func testFuzzSeedsSecondHalf() { play(4..<8) }

    /// Starts nearly broke so overdraft, debt weeks and the loss path run under random play.
    func testFuzzWithVeryLittleCash() {
        for (seed, home, cash) in [(UInt64(201), "CA", 400_000.0), (UInt64(202), "US", 1_500_000.0)] {
            let fuzz = Fuzz(seed: seed, home: home, difficulty: .hard, cash: cash)
            fuzz.run(weeks: 400)
            XCTAssertEqual(fuzz.failures, 0, "seed \(seed) broke invariants")
        }
    }

    /// With no decisions at all an empty company must go bankrupt, and a finished game must be frozen.
    func testBankruptcyEndsTheGameAndFreezesIt() {
        var s = GameState.newGame(startCountry: "IE", companyName: "Broke Co", seed: 9, difficulty: .hard)
        s.eventsEnabled = false
        s.finances.cash = 100_000
        var guardCount = 0
        while s.outcome == .playing && guardCount < 600 {
            s = SimulationEngine.advanceWeek(s)
            guardCount += 1
        }
        XCTAssertEqual(s.outcome, .lost, "an empty company with $100K should go bankrupt")
        XCTAssertNotNil(s.lossReason)
        XCTAssertLessThan(guardCount, 120, "bankruptcy took suspiciously long")
        let frozen = SimulationEngine.advanceWeek(s)
        XCTAssertTrue(frozen == s, "advanceWeek must leave a finished game unchanged")
        XCTAssertThrowsError(try s.launchMarket(code: "CA"))
        XCTAssertThrowsError(try s.takeLoan(amount: 1_000_000, termWeeks: 52))
    }

    /// Two identical runs must end in identical states.
    func testDeterminismAcrossIdenticalRuns() {
        let a = Fuzz(seed: 301, home: "FR", difficulty: .medium, cash: 2_000_000_000, checks: false)
        let b = Fuzz(seed: 301, home: "FR", difficulty: .medium, cash: 2_000_000_000, checks: false)
        a.run(weeks: 260)
        b.run(weeks: 260)
        XCTAssertEqual(a.s.week, b.s.week)
        XCTAssertEqual(a.s.finances.cash, b.s.finances.cash, "cash diverged between identical runs")
        XCTAssertEqual(a.s.totalSubscribers, b.s.totalSubscribers, "subscribers diverged between identical runs")
        XCTAssertTrue(a.s == b.s, "identical runs ended in different states")
    }

    /// Switching only moves customers between you and rivals: nobody is created or destroyed.
    func testSwitchingConservesCustomers() throws {
        let country = try XCTUnwrap(CountryData.country("DE"))
        for appeal in [0.05, 0.5, 0.95] {
            for service in [0.3, 1.0] {
                for price in [1.0, 40.0] {
                    var s = GameState.newGame(startCountry: "DE", companyName: "T", seed: 5)
                    s.markets["DE"]?.subs = TierSet(ad: 10_000, standard: 400_000, premium: 90_000)
                    s.markets["DE"]?.awareness = 0.7
                    s.markets["DE"]?.prices = TierSet(ad: price, standard: price, premium: price)
                    func total(_ st: GameState) -> Double {
                        (st.markets["DE"]?.subs.total ?? 0) + st.rivals.reduce(0.0) { $0 + ($1.subs["DE"] ?? 0) }
                    }
                    let before = total(s)
                    let mine = s.markets["DE"]?.subs.total ?? 0
                    let flow = Switching.apply(&s, country: country, appeal: appeal, service: service)
                    XCTAssertEqual(total(s), before, accuracy: 1e-6 * before, "appeal \(appeal) service \(service) price \(price)")
                    let delta = (s.markets["DE"]?.subs.total ?? 0) - mine
                    XCTAssertEqual(delta, flow.gained - flow.lost, accuracy: 1e-6 * before + 1e-6)
                    for t in Tier.allCases { XCTAssertGreaterThanOrEqual(s.markets["DE"]?.subs[t] ?? -1, 0) }
                }
            }
        }
    }

    // MARK: Suspected bugs (each of these FAILS on the current code until the bug is fixed)

    private func rich(_ code: String, difficulty: Difficulty = .medium) -> GameState {
        var s = GameState.newGame(startCountry: code, companyName: "Bug Co", seed: 77, difficulty: difficulty)
        s.eventsEnabled = false
        return s
    }

    /// BUG: SimulationEngine.swift:266 books `policy.flatCost` without `costScale` (every other running cost is scaled).
    func testBug_policyRunningCostIgnoresDifficulty() {
        var easy = rich("IE", difficulty: .easy)
        var hard = rich("IE", difficulty: .hard)
        easy.policies["moderation"] = "strict"      // flatCost 8,000 a week, no revenue yet so no overhead share
        hard.policies["moderation"] = "strict"
        easy = SimulationEngine.advanceWeek(easy)
        hard = SimulationEngine.advanceWeek(hard)
        let e = easy.lastReport?.financials.policies ?? 0
        let h = hard.lastReport?.financials.policies ?? 0
        XCTAssertGreaterThan(e, 0)
        XCTAssertEqual(h / max(1, e), 1.4 / 0.75, accuracy: 0.01, "policy running cost must scale with difficulty (easy \(e), hard \(h))")
    }

    /// BUG: Investing.swift sellShares has no guard for a pending takeover of the same rival. The escrow was sized for
    /// the shares you did NOT own, so selling your stake mid-bid pockets its value and still absorbs 100% of the rival.
    func testBug_cannotSellStakeWhileTakeoverBidIsPending() throws {
        var s = rich("US")
        s.finances.cash = 1e13
        try s.buyShares(rivalID: "plume", percent: 0.25)
        try s.buyShares(rivalID: "plume", percent: 0.2)
        try s.launchTakeover(rivalID: "plume", premium: 0.1)
        XCTAssertThrowsError(try s.sellShares(rivalID: "plume", percent: 0.45),
                             "selling the stake during your own bid should be refused")
    }

    /// BUG: CEOActions.swift exitMarket (~line 142) charges the wind-down cost without checking cash,
    /// unlike every other paid action, so it can push cash negative.
    func testBug_exitMarketRequiresCash() {
        var s = rich("IE")
        s.markets["CA"]?.status = .live
        s.finances.cash = 0
        XCTAssertThrowsError(try s.exitMarket(code: "CA"), "exiting a market with no cash should throw insufficientFunds")
    }

    /// BUG (stale state): Investing.swift acquire() removes the rival but keeps a "bundle with a rival" partnership
    /// that no longer has a rival behind it, still paying +15% sign-ups.
    func testBug_rivalBundleEndsWhenTheOnlyRivalIsAcquired() {
        var s = rich("CA")
        s.rivals = s.rivals.filter { $0.id == "plume" }
        XCTAssertGreaterThan(s.rivals.first?.subs["CA"] ?? 0, 0)
        s.partnerships = [Partnership(id: 900, country: "CA", kind: .rivalBundle, weeksLeft: 40)]
        s.stakes["plume"] = 0.3
        s.takeover = TakeoverBid(rivalID: "plume", premium: 0.2, escrow: 1, weeksLeft: 1, startStake: 0.3)
        s.finishTakeover(success: true)
        XCTAssertTrue(s.rivals.isEmpty)
        XCTAssertTrue(s.partnerships.filter { $0.kind == .rivalBundle }.isEmpty,
                      "a rival bundle should end when no rival operates in the country")
    }

    /// BUG: Policies.swift apply() multiplies subscribers by (1 + subsPct) with no ceiling check, so a "good"
    /// outcome can push you past the country's subscription ceiling (creating customers out of thin air).
    func testBug_policySubscriberBoostIgnoresCeiling() throws {
        var s = rich("IE")
        let ceiling = CountryData.country("IE")!.subscriberCeiling
        for i in s.rivals.indices { s.rivals[i].subs["IE"] = 0 }
        s.markets["IE"]?.subs = TierSet(ad: 0, standard: ceiling * 0.99, premium: 0)
        try s.setPolicy("sharing", option: "strict", forcedBad: false)    // good outcome: +6% subscribers
        XCTAssertLessThanOrEqual(s.markets["IE"]?.subs.total ?? 0, ceiling + 1, "subscribers must not exceed the country ceiling")
    }

    /// BUG (design): Formulas.creditLimit counts half of your cash, and borrowed money is cash, so you can keep
    /// borrowing against your own loans: total debt reaches about twice the intended 3x annual revenue.
    func testBug_borrowingAgainstBorrowedCash() throws {
        var s = rich("IE")
        s.finances.revenueHistory = Array(repeating: 1_000_000.0, count: 52)
        s.finances.cash = 0
        let intended = s.creditLimit
        var loops = 0
        while s.creditRoom >= 250_000 && loops < 80 {
            loops += 1
            try s.takeLoan(amount: s.creditRoom, termWeeks: 52)
        }
        XCTAssertLessThanOrEqual(s.outstandingDebt, intended * 1.001, "debt \(s.outstandingDebt) exceeds the \(intended) limit lenders showed")
    }

    /// BUG (UI/engine mismatch): TechStaffView shows `cloudUnitPrice` / `datacenterUpkeepPrice`, but the weekly charge
    /// in weeklyTechCost also applies the engineering department's CDN discount.
    func testBug_cloudPriceShownMatchesWeeklyCharge() throws {
        var s = rich("IE")
        s.finances.cash = 1e9
        s.staff.engineering = 5
        let base = s.weeklyTechCost
        try s.rentCloud(region: .europe)
        XCTAssertEqual(s.weeklyTechCost - base, s.cloudUnitPrice, accuracy: 1, "the price on the button must equal what is charged")
    }
}
