import XCTest
#if canImport(StreamEmpireCore)
@testable import StreamEmpireCore
#else
@testable import StreamEmpire
#endif

// MARK: - Playtest bot 3: systems and rival reactions
//
// A long-running "winner bot" (up to 30 simulated years per game, with a wall-clock safety valve so the whole
// class stays well under 90 seconds) plus abuse probes for rivals, switching, tech, brake, policies, pause logic,
// Chirp, scenarios and large catalogs. Grep the CI log for "PLAYTEST systems".
// The clock is used in the TEST only; it never touches the engine and nothing asserts on wall-clock time.

private func psNow() -> Double { Double(DispatchTime.now().uptimeNanoseconds) / 1_000_000_000 }

private func psInt(_ v: Double) -> Int { v.isFinite ? Int(max(-9e15, min(9e15, v))) : -1 }

private func psIsLaunching(_ m: MarketState) -> Bool {
    if case .launching = m.status { return true }
    return false
}

private func psFails(_ work: () throws -> Void) -> Bool {
    do { try work(); return false } catch { return true }
}

/// Adds `count` owned, long-running licenses to the catalog (for performance and probe setups).
private func psInjectCatalog(_ s: inout GameState, count: Int, seed: UInt64) {
    var trng = SeededRNG(seed: seed)
    var taken = Set(s.catalog.map(\.name) + s.licenseMarket.map(\.name))
    for _ in 0..<count {
        var t = TitleGenerator.generate(id: s.takeID(), rng: &trng, avoiding: taken)
        taken.insert(t.name)
        t.weeksRemaining = 400
        t.listingWeeksLeft = 0
        t.embargoWeeks = 0
        s.catalog.append(t)
    }
}

private struct PSPlan {
    var seed: UInt64
    var home: String
    var difficulty: Difficulty
    var scenario: Scenario = .sandbox
    var priceFactor = 1.0
    var freeAdTier = false
    var curatorMode: CuratorMode = .moderate
    var takeovers = true
    var maxWeeks = 1560
    var budgetSeconds = 15.0
}

private final class PSBot {
    let plan: PSPlan
    var s: GameState
    var rng: SeededRNG
    var failures = 0
    var bestRank = 99
    var priced = Set<String>()
    var stops = [0, 0, 0]               // weeks that would stop auto-advance at critical / important / everything
    var weeksPlayed = 0
    var maxOvershoot = 0.0              // worst (you + rivals) / ceiling in any country
    var duplicateNames = 0

    init(plan: PSPlan) {
        self.plan = plan
        var st = GameState.newGame(startCountry: plan.home, companyName: "Winner Bot", seed: plan.seed,
                                   difficulty: plan.difficulty, scenario: plan.scenario)
        st.eventsEnabled = false
        st.renewalMode = .standard
        st.expiryAlerts = .show
        st.autoScale = true
        st.pauseSensitivity = .critical
        self.s = st
        self.rng = SeededRNG(seed: plan.seed &* 31 &+ 7)
    }

    // MARK: Assertions

    func expect(_ ok: Bool, _ msg: @autoclosure () -> String) {
        if ok { return }
        failures += 1
        if failures <= 12 { XCTFail("[seed \(plan.seed) week \(s.week)] \(msg())") }
    }

    func finite(_ v: Double, _ what: @autoclosure () -> String) {
        if v.isFinite { return }
        failures += 1
        if failures <= 12 { XCTFail("[seed \(plan.seed) week \(s.week)] not finite: \(what()) = \(v)") }
    }

    // MARK: Running

    func run() {
        let t0 = psNow()
        while weeksPlayed < plan.maxWeeks, s.outcome == .playing, failures < 25 {
            if weeksPlayed % 8 == 0, psNow() - t0 > plan.budgetSeconds { break }
            step()
            let before = s
            let after = SimulationEngine.advanceWeek(before)
            weeksPlayed += 1
            observe(before: before, after: after)
            s = after
            if after.rank < bestRank {
                bestRank = after.rank
                print("PLAYTEST systems milestone week=\(after.week) rank=\(after.rank)")
            }
            if s.week % 100 == 0 { roundTrip() }
            if s.week % 50 == 0 { checkChirps(s); checkBookkeeping() }
        }
    }

    func observe(before: GameState, after: GameState) {
        let reasons = PauseCheck.reasons(before: before, after: after)
        for (i, sensitivity) in PauseSensitivity.allCases.enumerated()
        where reasons.contains(where: { sensitivity.stops($0.id) }) {
            stops[i] += 1
        }
        var mustStop = after.outcome != .playing || (before.finances.cash >= 0 && after.finances.cash < 0)
        for region in Region.allCases where before.effectiveLoad(region) < 1 && after.effectiveLoad(region) >= 1 {
            mustStop = true
        }
        if mustStop {
            expect(reasons.contains { PauseSensitivity.critical.stops($0.id) },
                   "a critical event (game over, cash below zero, servers full) did not stop critical-mode auto-advance")
        }
        check(after)
    }

    func roundTrip() {
        do {
            let data = try JSONEncoder().encode(s)
            let loaded = try JSONDecoder().decode(GameState.self, from: data)
            expect(loaded == s, "JSON round trip changed the state")
            let a = SimulationEngine.advanceWeek(s)
            let b = SimulationEngine.advanceWeek(loaded)
            expect(a == b, "a loaded save continued differently from the live game")
            s = loaded
        } catch {
            expect(false, "JSON round trip threw: \(error)")
        }
    }

    // MARK: Invariants

    func check(_ a: GameState) {
        finite(a.finances.cash, "cash")
        finite(a.totalSubscribers, "total subscribers")
        expect(a.totalSubscribers >= 0, "negative subscribers")
        finite(a.earningsSentiment, "earningsSentiment")
        expect(a.brandTrust >= 0 && a.brandTrust <= 100, "brandTrust \(a.brandTrust)")
        expect(a.regulatoryHeat >= 0 && a.regulatoryHeat <= 100, "regulatoryHeat \(a.regulatoryHeat)")
        expect(a.rank >= 1 && a.rank <= a.rivals.count + 1, "rank \(a.rank)")
        if a.outcome == .won, a.scenario == .sandbox || a.scenario == .dethrone {
            expect(a.rank == 1, "won without being #1")
        }
        for code in a.markets.keys.sorted() {
            guard let m = a.markets[code], let c = CountryData.country(code) else { continue }
            for tier in Tier.allCases {
                finite(m.subs[tier], "subs \(code) \(tier)")
                expect(m.subs[tier] >= 0, "negative subs \(code) \(tier)")
            }
            expect(m.awareness >= 0 && m.awareness <= 1, "awareness \(code) \(m.awareness)")
            expect(m.subs.total <= c.subscriberCeiling * 1.06 + 1, "\(code) over its ceiling: \(Int(m.subs.total)) vs \(Int(c.subscriberCeiling))")
            if !m.isLive { expect(m.subs.total == 0, "subscribers in \(code), which is not live") }
            var others = 0.0
            for r in a.rivals { others += r.subs[code] ?? 0 }
            maxOvershoot = max(maxOvershoot, (m.subs.total + others) / c.subscriberCeiling)
        }
        for r in a.rivals {
            finite(r.cash, "rival cash \(r.id)")
            expect(r.catalogStrength >= 0 && r.catalogStrength <= 100, "rival strength \(r.id) \(r.catalogStrength)")
            expect(r.priceLevel >= 0.55 && r.priceLevel <= 1.2, "rival price level \(r.id) \(r.priceLevel)")
            for code in r.subs.keys.sorted() {
                let v = r.subs[code] ?? 0
                finite(v, "rival subs \(r.id) \(code)")
                expect(v >= 0, "negative rival subs \(r.id) \(code)")
            }
            for code in CountryData.closedToRivals.sorted() where s.week < CountryData.closedMarketsOpenWeek {   // rivals may enter later
                expect((r.subs[code] ?? 0) == 0, "\(r.id) has subscribers in \(code), which is closed to rivals")
            }
        }
        for code in a.cloudUnits.keys.sorted() {
            let n = a.cloudUnits[code] ?? 0
            expect(n >= 0 && n <= Formulas.maxCloudUnits, "cloud units \(code) = \(n)")
        }
        finite(a.finances.lastWeek.profit, "weekly profit")
    }

    func checkBookkeeping() {
        expect(Set(s.catalog.map(\.id)).count == s.catalog.count, "duplicate catalog ids")
        expect(Set(s.news.map(\.id)).count == s.news.count, "duplicate news ids")
        expect(Set(s.datacenters.map(\.id)).count == s.datacenters.count, "duplicate datacenter ids")
        expect(Set(s.projects.map(\.id)).count == s.projects.count, "duplicate project ids")
        expect(Set(s.rivals.map(\.id)).count == s.rivals.count, "duplicate rival ids")
        expect(Set(s.staff.employees.map(\.id)).count == s.staff.employees.count, "duplicate employee ids")
        expect(s.news.count <= 150, "news is not capped: \(s.news.count)")
        expect(s.reportHistory.count <= 26, "reportHistory is not capped")
        expect(s.finances.history.count <= 26, "finance history is not capped")
        expect(s.trend.count <= 520, "trend is not capped")
        expect(s.policyLog.count <= 30, "policyLog is not capped")
        let names = s.catalog.map { $0.name.lowercased() }
        duplicateNames = max(duplicateNames, names.count - Set(names).count)
    }

    func checkChirps(_ st: GameState) {
        for item in st.news {
            let c = Chirp.make(item, state: st)
            expect(c.id == item.id && c.text == item.headline, "a chirp does not mirror its story")
            expect(!c.name.isEmpty && c.handle.hasPrefix("@") && c.handle.count > 1, "chirp author '\(c.name)' / '\(c.handle)'")
            expect(c.likes >= 0 && c.reposts >= 0 && c.replies >= 0, "negative chirp engagement")
            if let id = c.authorRivalID {
                expect(st.rivals.contains { $0.id == id && $0.name == c.name }, "chirp author is not the rival it names")
            }
            if item.kind == .you { expect(c.mine, "a story about you is not flagged as yours") }
        }
    }

    // MARK: The bot's decisions

    func step() {
        let w = s.week
        if w % 4 == 1 { fund() }
        if s.curator == nil {
            if w % 4 == 2, s.finances.cash > 1_500_000 { try? s.hireCurator(mode: plan.curatorMode) }
            shop()
        }
        if w % 3 == 0 { expand() }
        if w % 4 == 0 { price(); servers() }
        if w % 8 == 3 { marketing(); platforms() }
        if w % 13 == 5 { hiring() }
        if w % 20 == 7 { originals() }
        if plan.takeovers, w % 26 == 11 { takeovers() }
    }

    func fund() {
        if s.finances.cash < 10_000_000, s.loans.count < 4, s.creditRoom >= 1_000_000 {
            try? s.takeLoan(amount: min(s.creditRoom, 25_000_000).rounded(.down), termWeeks: 208)
        }
        if s.roundBlocker == nil, s.finances.cash < 50_000_000 { try? s.raiseRound(percent: 0.1) }
        if s.ipoBlocker == nil { try? s.launchIPO() }
    }

    func shop() {
        guard let home = CountryData.country(plan.home) else { return }
        let target = min(40, 10 + s.week / 6 + 3 * s.liveMarketCodes.count)
        var purchases = 0
        while s.catalog.count < target, purchases < 3 {
            purchases += 1
            let cash = s.finances.cash
            let affordable = s.licenseMarket.filter {
                let price = s.licensePrice($0)
                return $0.embargoWeeks == 0 && price < cash * 0.2 && price < cash - 2_000_000
            }
            func value(_ t: Title) -> Double {
                guard let license = t.license else { return 0 }
                return Formulas.titleAppeal(t, in: home) * Double(license.years).squareRoot() / max(1, s.licensePrice(t))
            }
            guard let best = affordable.max(by: { value($0) < value($1) }) else { break }
            try? s.buyLicense(titleID: best.id)
        }
    }

    func expand() {
        let launching = s.markets.values.filter { psIsLaunching($0) }.count
        guard launching < 2 else { return }
        let cash = s.finances.cash
        guard s.finances.recentWeeklyProfit > -200_000 || cash > 30_000_000 else { return }
        let options = CountryData.all.filter {
            s.markets[$0.code]?.status == .notLaunched && s.launchBlocker(code: $0.code) == nil
                && s.launchPrice($0) * 3 < cash
        }
        func score(_ c: Country) -> Double {
            c.households * min(1.5, c.priceTolerance / 8) / max(0.1, s.launchPrice(c) / 1_000_000)
        }
        guard let pick = options.max(by: { score($0) < score($1) }) else { return }
        try? s.launchMarket(code: pick.code)
    }

    func price() {
        for code in s.liveMarketCodes where !priced.contains(code) {
            guard let c = CountryData.country(code) else { continue }
            let base = CountryData.defaultPrices(for: c)
            let factor = plan.priceFactor
            func r(_ v: Double) -> Double { max(0.5, (v * factor * 2).rounded() / 2) }
            var p = TierSet(ad: r(base.ad), standard: r(base.standard), premium: r(base.premium))
            if plan.freeAdTier { p.ad = 0 }
            try? s.setPrices(code: code, prices: p)
            if plan.freeAdTier { try? s.launchTier(.ad, code: code) }
            priced.insert(code)
        }
    }

    func servers() {
        for region in Region.allCases {
            guard s.subscribers(in: region) > 0 else { continue }
            let dcs = s.datacenters(in: region)
            let building = dcs.contains { !$0.isOnline }
            let load = s.serverLoad(region)
            if !building, dcs.count < (load > 0.7 ? 4 : 2), load > 0.3 { try? s.buildDatacenter(region: region) }
            if load > 0.6, let dc = dcs.first(where: { s.datacenterUpgradePrice($0) != nil }) {
                try? s.upgradeDatacenter(id: dc.id)
            }
        }
    }

    func marketing() {
        for code in s.liveMarketCodes {
            guard let c = CountryData.country(code) else { continue }
            let budget = min(c.households * 6_000, max(0, s.finances.cash * 0.0015))
            try? s.setMarketing(code: code, weeklyBudget: budget)
        }
    }

    func platforms() {
        guard s.finances.cash > 5_000_000 else { return }
        for platform in [Platform.ios, .android, .smartTV, .consoles]
        where !s.platforms.contains(platform) && !s.builds.contains(where: { $0.platform == platform }) {
            try? s.startPlatform(platform)
            break
        }
    }

    func hiring() {
        guard s.finances.cash > 6_000_000 else { return }
        for department in Department.allCases { try? s.hire(department) }
    }

    func originals() {
        guard s.finances.cash > 60_000_000, s.projects.count < 2 else { return }
        let genre = rng.pick(Genre.allCases)
        try? s.commissionOriginal(kind: .series, genre: genre, language: .english, budget: 15_000_000, weeks: 40)
    }

    func takeovers() {
        guard s.takeover == nil, s.totalSubscribers > 5_000_000, s.finances.cash > 200_000_000 else { return }
        guard let target = s.rivals.min(by: { s.marketCap($0) < s.marketCap($1) }) else { return }
        if s.stake(in: target.id) < 0.05 {
            try? s.buyShares(rivalID: target.id, percent: 0.05)
        } else if s.takeoverCost(target, premium: 0.25) < s.finances.cash * 0.6 {
            try? s.launchTakeover(rivalID: target.id, premium: 0.25)
        }
    }

    // MARK: Reporting

    func report() {
        let result = s.outcome == .won ? "won" : (s.outcome == .lost ? "lost" : "playing")
        print("PLAYTEST systems seed=\(plan.seed) diff=\(plan.difficulty.rawValue) result=\(result) week=\(s.week) rank=\(s.rank) subs=\(psInt(s.totalSubscribers)) cash=\(psInt(s.finances.cash)) markets=\(s.liveMarketCodes.count) catalog=\(s.catalog.count)")
        let topRival = s.rivals.map(\.totalSubs).max() ?? 0
        print("PLAYTEST systems detail seed=\(plan.seed) scenario=\(plan.scenario.rawValue) topRivalSubs=\(psInt(topRival)) rivals=\(s.rivals.count) score=\(s.score) stopWeeks(critical/important/everything)=\(stops[0])/\(stops[1])/\(stops[2]) weeksPlayed=\(weeksPlayed) maxOvershoot=\(String(format: "%.3f", maxOvershoot)) duplicateCatalogNames=\(duplicateNames) failures=\(failures)")
        if let reason = s.lossReason { print("PLAYTEST systems lossReason seed=\(plan.seed) \(reason)") }
    }
}

// MARK: - Tests

final class PlaytestSystemsTests: XCTestCase {

    // MARK: Long games

    func testGameA_mediumCanadaBalancedPrices() {
        let bot = PSBot(plan: PSPlan(seed: 101, home: "CA", difficulty: .medium, priceFactor: 0.85,
                                     curatorMode: .moderate, budgetSeconds: 16))
        bot.run()
        bot.report()
        XCTAssertLessThan(bot.failures, 1, "invariants broke during game A")
    }

    func testGameB_easyUnitedStatesLandGrabWithFreeAdTier() {
        let bot = PSBot(plan: PSPlan(seed: 202, home: "US", difficulty: .easy, priceFactor: 0.6, freeAdTier: true,
                                     curatorMode: .aggressive, budgetSeconds: 12))
        bot.run()
        bot.report()
        XCTAssertLessThan(bot.failures, 1, "invariants broke during game B")
    }

    func testGameC_hardGermanyTenMillionChallengeHonoursItsDeadline() {
        let bot = PSBot(plan: PSPlan(seed: 303, home: "DE", difficulty: .hard, scenario: .tenMillion, priceFactor: 0.8,
                                     curatorMode: .aggressive, maxWeeks: 170, budgetSeconds: 8))
        bot.run()
        bot.report()
        let s = bot.s
        let deadline = Scenario.tenMillion.deadline ?? 156
        XCTAssertTrue(s.outcome != .playing || s.week <= deadline, "the challenge ran past its deadline (week \(s.week))")
        if s.outcome == .won { XCTAssertGreaterThanOrEqual(s.score, 0) }
        XCTAssertLessThan(bot.failures, 1, "invariants broke during game C")
    }

    func testSameSeedGivesTheSameGameTwice() {
        func play() -> GameState {
            let bot = PSBot(plan: PSPlan(seed: 404, home: "NL", difficulty: .medium, priceFactor: 0.9,
                                         maxWeeks: 80, budgetSeconds: 1_000_000))
            bot.run()
            return bot.s
        }
        let a = play()
        let b = play()
        XCTAssertEqual(a.week, b.week)
        XCTAssertTrue(a == b, "the same seed and the same decisions produced different games")
    }

    // MARK: Performance

    func testProbe_bigCatalogPerformance() {
        for count in [3_000, 8_000] {
            var s = GameState.newGame(startCountry: "CA", companyName: "Perf Co", seed: 9)
            s.eventsEnabled = false
            let big = CountryData.all.filter { !CountryData.closedToRivals.contains($0.code) }
                .sorted { $0.households > $1.households }
            for c in big.prefix(20) {
                s.markets[c.code]?.status = .live
                s.markets[c.code]?.subs.standard = c.subscriberCeiling * 0.01
            }
            psInjectCatalog(&s, count: count, seed: 99)
            XCTAssertEqual(s.catalog.count, count)
            let weeks = count > 5_000 ? 2 : 3
            let t0 = psNow()
            for _ in 0..<weeks { s = SimulationEngine.advanceWeek(s) }
            let seconds = psNow() - t0
            print("PLAYTEST systems perf catalog=\(count) weeks=\(weeks) seconds=\(String(format: "%.2f", seconds))")
            XCTAssertTrue(s.totalSubscribers.isFinite && s.finances.cash.isFinite)
            XCTAssertEqual(s.week, 1 + weeks)
        }
    }

    // MARK: Pause logic

    func testPauseSensitivityRules() {
        let critical = ["outcome", "cash", "load100-europe"]
        let notCritical = ["load90-europe", "runway", "crash-3", "alert-1", "expiring", "war-9", "recall-2", "expired-4"]
        for id in critical {
            for level in PauseSensitivity.allCases { XCTAssertTrue(level.stops(id), "\(level) must stop for \(id)") }
        }
        for id in notCritical {
            XCTAssertFalse(PauseSensitivity.critical.stops(id), "the default must not stop for \(id)")
            XCTAssertTrue(PauseSensitivity.everything.stops(id), "everything must stop for \(id)")
        }
        // Each level stops for a superset of the one below.
        for id in critical + notCritical {
            if PauseSensitivity.critical.stops(id) { XCTAssertTrue(PauseSensitivity.important.stops(id)) }
            if PauseSensitivity.important.stops(id) { XCTAssertTrue(PauseSensitivity.everything.stops(id)) }
        }
    }

    func testPauseCheckCatchesCashAndOverload() {
        var before = GameState.newGame(startCountry: "CA", companyName: "Pause Co", seed: 5)
        before.eventsEnabled = false
        var after = before
        before.finances.cash = 1_000_000
        after.finances.cash = -1_000_000
        let cash = PauseCheck.reasons(before: before, after: after)
        XCTAssertTrue(cash.contains { $0.id == "cash" })
        XCTAssertTrue(cash.contains { PauseSensitivity.critical.stops($0.id) })

        var low = GameState.newGame(startCountry: "CA", companyName: "Pause Co", seed: 5)
        low.eventsEnabled = false
        low.markets["CA"]?.subs = TierSet(ad: 0, standard: 400_000, premium: 0)      // 80% of the starter servers
        var full = low
        full.markets["CA"]?.subs = TierSet(ad: 0, standard: 600_000, premium: 0)     // 120%
        let over = PauseCheck.reasons(before: low, after: full)
        XCTAssertTrue(over.contains { $0.id == "load100-northAmerica" }, "crossing 100% load must be reported")
        XCTAssertTrue(over.contains { PauseSensitivity.critical.stops($0.id) })

        var near = low
        near.markets["CA"]?.subs = TierSet(ad: 0, standard: 475_000, premium: 0)     // 95%
        let warn = PauseCheck.reasons(before: low, after: near)
        XCTAssertTrue(warn.contains { $0.id == "load90-northAmerica" })
        XCTAssertFalse(warn.contains { PauseSensitivity.critical.stops($0.id) }, "a 90% warning must not stop the default setting")
        XCTAssertTrue(warn.contains { $0.region == Region.northAmerica.rawValue }, "the warning offers the one-tap brake")
    }

    // MARK: Brake

    func testSignupBrakeStopsNewCustomersButNotExistingOnes() {
        func week(paused scope: String?) -> (GameState, Double) {
            var s = GameState.newGame(startCountry: "CA", companyName: "Brake Co", seed: 17)
            s.eventsEnabled = false
            psInjectCatalog(&s, count: 50, seed: 3)
            s.markets["CA"]?.subs = TierSet(ad: 0, standard: 100_000, premium: 0)
            s.markets["CA"]?.awareness = 0.6
            if let scope = scope { try? s.setSignupsPaused(scope: scope, paused: true) }
            let after = SimulationEngine.advanceWeek(s)
            return (after, after.lastReport?.newSubs ?? -1)
        }
        let open = week(paused: nil)
        XCTAssertGreaterThan(open.1, 0, "setup: an open market should sign people up")
        let all = week(paused: "all")
        XCTAssertEqual(all.1, 0, "paused everywhere: nobody may join")
        XCTAssertLessThanOrEqual(all.0.totalSubscribers, 100_000 * (1 + 1e-9), "paused: the base can only shrink")
        let region = week(paused: Region.northAmerica.rawValue)
        XCTAssertEqual(region.1, 0, "paused in North America")
        let elsewhere = week(paused: Region.europe.rawValue)
        XCTAssertGreaterThan(elsewhere.1, 0, "pausing Europe must not stop Canada")
    }

    // MARK: Scenarios and game over

    func testScenarioDeadlinesEndTheGame() {
        for scenario in Scenario.allCases {
            guard let deadline = scenario.deadline else { continue }
            var s = GameState.newGame(startCountry: "CA", companyName: "Deadline Co", seed: 31, scenario: scenario)
            s.eventsEnabled = false
            s.week = deadline - 1
            s = SimulationEngine.advanceWeek(s)
            XCTAssertEqual(s.outcome, .playing, "\(scenario) must still be open one week before the deadline")
            s = SimulationEngine.advanceWeek(s)
            XCTAssertEqual(s.outcome, .lost, "\(scenario) must end at its deadline")
            XCTAssertNotNil(s.lossReason, "\(scenario) needs a reason")
            XCTAssertTrue(SimulationEngine.advanceWeek(s) == s, "a finished game must stay frozen")
        }
    }

    func testScenarioWinsAndScores() {
        var profit = GameState.newGame(startCountry: "CA", companyName: "Profit Co", seed: 33, scenario: .profitable)
        profit.eventsEnabled = false
        profit.markets["CA"]?.subs = TierSet(ad: 0, standard: 2_000_000, premium: 0)
        profit.finances.profitHistory = Array(repeating: 50_000.0, count: 7)
        profit = SimulationEngine.advanceWeek(profit)
        XCTAssertEqual(profit.outcome, .won, "eight profitable weeks with 500K+ subscribers should win")
        XCTAssertGreaterThan(profit.score, 0)
    }

    func testSandboxWinIsOnlyCheckedFromWeek52() {
        var s = GameState.newGame(startCountry: "CA", companyName: "Early Co", seed: 34)
        s.eventsEnabled = false
        for i in s.rivals.indices { s.rivals[i].subs = ["CA": 1_000] }
        s.markets["CA"]?.subs = TierSet(ad: 0, standard: 20_000_000, premium: 0)
        XCTAssertEqual(s.rank, 1)
        s.week = 51
        s = SimulationEngine.advanceWeek(s)
        XCTAssertEqual(s.outcome, .playing, "being #1 before week 52 must not win")
        s = SimulationEngine.advanceWeek(s)
        XCTAssertEqual(s.outcome, .won, "#1 at week 52 wins")
        XCTAssertGreaterThan(s.score, 0)
    }

    func testBankruptcyEndsAndFreezesTheGame() {
        var s = GameState.newGame(startCountry: "CA", companyName: "Broke Co", seed: 35)
        s.eventsEnabled = false
        s.finances.cash = -80_000_000
        s = SimulationEngine.advanceWeek(s)
        XCTAssertEqual(s.outcome, .lost)
        XCTAssertNotNil(s.lossReason)
        XCTAssertTrue(SimulationEngine.advanceWeek(s) == s)
        XCTAssertTrue(psFails { try s.launchMarket(code: "US") }, "actions must be refused after game over")
        XCTAssertTrue(psFails { try s.takeLoan(amount: 1_000_000, termWeeks: 52) })
    }

    // MARK: Rivals

    func testProbe_dominantPlayerFacesBoundedReactions() {
        var s = GameState.newGame(startCountry: "CA", companyName: "Dominant Co", seed: 21)
        s.eventsEnabled = false
        s.renewalMode = .off
        psInjectCatalog(&s, count: 60, seed: 5)
        guard let country = CountryData.country("CA") else { return XCTFail("CA missing") }
        for i in s.rivals.indices { s.rivals[i].subs["CA"] = i < 3 ? 5_000_000 : nil }
        s.markets["CA"]?.subs = TierSet(ad: 0, standard: 25_000_000, premium: 0)
        s.markets["CA"]?.awareness = 0.8
        s.markets["CA"]?.prices.standard = max(0.5, country.priceTolerance * 0.5)
        s.finances.cash = 2_000_000_000
        var minLevel = 9.0, warWeeks = 0, cheaperWeeks = 0
        var shareStart = 0.0, shareEnd = 0.0
        for week in 0..<100 {
            s = SimulationEngine.advanceWeek(s)
            if s.outcome != .playing { break }
            let own = s.markets["CA"]?.subs.total ?? 0
            var others = 0.0
            for r in s.rivals { others += r.subs["CA"] ?? 0 }
            if week == 0 { shareStart = own / max(1, own + others) }
            shareEnd = own / max(1, own + others)
            XCTAssertLessThanOrEqual(own + others, country.subscriberCeiling * 1.06, "week \(week): the country is over its ceiling")
            for r in s.rivals {
                minLevel = min(minLevel, r.priceLevel)
                XCTAssertTrue(r.priceLevel >= 0.59 && r.priceLevel <= 1.16, "rival price level \(r.priceLevel)")
                XCTAssertTrue(r.totalSubs.isFinite && r.cash.isFinite)
            }
            if s.lastReport?.events.contains(where: { $0.headline.contains("declares a price war") }) == true { warWeeks += 1 }
            if let m = s.markets["CA"], s.countryThreat("CA") > 0 {
                for r in s.rivals where (r.subs["CA"] ?? 0) > 0 && r.priceLevel < 0.95 {
                    let rivalPrice = Formulas.rivalPrice(country: country, priceFactor: r.priceFactor, priceLevel: r.priceLevel, tier: .standard)
                    if rivalPrice > m.prices.standard { cheaperWeeks += 1; break }
                }
            }
        }
        print("PLAYTEST systems dominance shareStart=\(String(format: "%.3f", shareStart)) shareEnd=\(String(format: "%.3f", shareEnd)) minRivalPriceLevel=\(String(format: "%.3f", minLevel)) priceWarWeeks=\(warWeeks) weeksRivalDiscountedYetCostMoreThanYou=\(cheaperWeeks)")
    }

    func testProbe_takeoverVersusUnlockRules() {
        var s = GameState.newGame(startCountry: "CA", companyName: "Raider Co", seed: 22)
        s.eventsEnabled = false
        s.finances.cash = 1_000_000_000_000
        let rival = s.rivals[0]
        s.rivals[0].subs["US"] = 1_000
        let blockedBefore = s.launchBlocker(code: "US") != nil
        try? s.buyShares(rivalID: rival.id, percent: 0.05)
        try? s.launchTakeover(rivalID: rival.id, premium: 0.3)
        let bidOpen = s.takeover != nil
        s.finishTakeover(success: true)
        let usLive = s.markets["US"]?.status == .live
        print("PLAYTEST systems exploit takeoverFreeLaunch blockedBefore=\(blockedBefore) bidOpen=\(bidOpen) usLiveAfterTakeover=\(usLive) rivalsLeft=\(s.rivals.count) usStillBlocked=\(s.launchBlocker(code: "US") != nil)")
        XCTAssertEqual(s.rivals.count, 11)
        XCTAssertTrue(s.totalSubscribers.isFinite)
    }

    // MARK: Staff and policies

    func testProbe_staffHiringPayAndAttrition() {
        var s = GameState.newGame(startCountry: "CA", companyName: "Staff Co", seed: 23)
        s.eventsEnabled = false
        for c in s.candidates { try? s.hire(candidateID: c.id) }
        XCTAssertFalse(s.staff.employees.isEmpty, "setup: hiring should work")
        let ids = s.staff.employees.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
        for id in ids {
            XCTAssertTrue(psFails { try s.setSalary(employeeID: id, pay: 0.5) }, "pay below 60% must be refused")
            XCTAssertTrue(psFails { try s.setSalary(employeeID: id, pay: 1.61) }, "pay above 160% must be refused")
            XCTAssertFalse(psFails { try s.setSalary(employeeID: id, pay: 1.6) })
        }
        var best = 0.0
        for d in Department.allCases { best = max(best, s.staff.effectiveLevel(d)) }
        print("PLAYTEST systems staff maxEffectiveLevelAtMaxPay=\(String(format: "%.2f", best)) (cap on skill is \(Formulas.maxDepartmentLevel))")
        for id in ids { try? s.setSalary(employeeID: id, pay: 0.6) }
        let hired = s.staff.employees.count
        for _ in 0..<80 { s = SimulationEngine.advanceWeek(s) }
        XCTAssertLessThanOrEqual(s.staff.employees.count, hired + 0, "underpaid staff should only leave")
        for d in Department.allCases {
            let level = s.staff.effectiveLevel(d)
            XCTAssertTrue(level.isFinite && level >= 0)
            XCTAssertLessThanOrEqual(s.staff[d], Formulas.maxDepartmentLevel)
        }
        XCTAssertEqual(Set(s.staff.employees.map(\.id)).count, s.staff.employees.count)
        XCTAssertTrue(psFails { try s.fire(employeeID: 987_654_321) })
        print("PLAYTEST systems staff hired=\(hired) afterEightyWeeksAtMinPay=\(s.staff.employees.count)")
    }

    func testProbe_policyChangesKeepReputationAndSubscribersSane() {
        var base = GameState.newGame(startCountry: "CA", companyName: "Policy Co", seed: 41)
        base.eventsEnabled = false
        base.markets["CA"]?.subs = TierSet(ad: 0, standard: 3_000_000, premium: 0)
        base.finances.cash = 500_000_000
        let ceiling = CountryData.country("CA")?.subscriberCeiling ?? 1e9
        var applied = 0
        for definition in PolicyData.all {
            for option in definition.options where option.id != definition.defaultOption {
                for forced in [true, false] {
                    var s = base
                    guard (try? s.setPolicy(definition.id, option: option.id, forcedBad: forced)) != nil else { continue }
                    applied += 1
                    XCTAssertTrue(s.brandTrust.isFinite && s.brandTrust >= 0 && s.brandTrust <= 100, "\(definition.id)/\(option.id) trust \(s.brandTrust)")
                    XCTAssertTrue(s.regulatoryHeat.isFinite && s.regulatoryHeat >= 0 && s.regulatoryHeat <= 100, "\(definition.id)/\(option.id) heat")
                    XCTAssertTrue(s.totalSubscribers.isFinite && s.totalSubscribers >= 0)
                    XCTAssertLessThanOrEqual(s.markets["CA"]?.subs.total ?? 0, ceiling * 1.06)
                    XCTAssertTrue(psFails { _ = try s.setPolicy(definition.id, option: definition.defaultOption) },
                                  "\(definition.id): changing it back at once must hit the cooldown")
                    XCTAssertLessThanOrEqual(s.policyLog.count, 30)
                }
            }
        }
        print("PLAYTEST systems policies applied=\(applied)")
        XCTAssertGreaterThan(applied, 20)
    }

    // MARK: Chirp

    func testChirpNeverCrashesOnAnyStoryKind() {
        var s = GameState.newGame(startCountry: "CA", companyName: "Chirp Co", seed: 51)
        s.eventsEnabled = false
        var id = 50_000
        for kind in NewsKind.allCases {
            var rivalIDs: [String?] = [nil]
            for r in s.rivals { rivalIDs.append(r.id) }
            for rival in rivalIDs {
                id += 1
                let item = NewsItem(id: id, week: 3, kind: kind, headline: "Test headline \(id)", body: "Body", rivalID: rival)
                let c = Chirp.make(item, state: s)
                XCTAssertFalse(c.name.isEmpty)
                XCTAssertTrue(c.handle.hasPrefix("@"))
                XCTAssertGreaterThanOrEqual(c.likes, 0)
            }
        }
        // An empty world still renders.
        s.rivals = []
        s.brandTrust = 0
        let lonely = Chirp.make(NewsItem(id: 1, week: 1, kind: .you, headline: "Alone", body: "", rivalID: "ghost"), state: s)
        XCTAssertTrue(lonely.mine)
        s.brandTrust = 100
        _ = Chirp.make(NewsItem(id: 2, week: 1, kind: .you, headline: "Loved", body: "", rivalID: nil), state: s)
    }

    // MARK: Definite bugs found by reading the code (these fail on current code)

    /// `Chirp.make` decides "mine" with `headline.contains(companyName)`: a company called "Prime" or "Max" has
    /// every PrimeStream / MaxStream story treated as its own (fan replies, wrong author scale).
    func testBug_chirpTreatsRivalStoriesAsYoursWhenTheCompanyNameIsPartOfARivalName() {
        var s = GameState.newGame(startCountry: "CA", companyName: "Placeholder", seed: 3)
        let rival = s.rivals[0]
        s.companyName = String(rival.name.prefix(3))
        let item = NewsItem(id: 9_999, week: 5, kind: .expansion,
                            headline: "\(rival.name) launches in Peru", body: "\(rival.name) opens in Peru.", rivalID: rival.id)
        let chirp = Chirp.make(item, state: s)
        XCTAssertFalse(chirp.mine, "a story about \(rival.name) is not about a company called \(s.companyName)")
    }

    /// Switching must be fair both ways: a mirrored offer (+0.4 vs -0.4 score, one rival, equal sizes) moves the same
    /// number of customers. Today a better offer wins 0.3% of the rival's base, a worse one loses only 0.15% of yours.
    func testBug_switchingIsSymmetricForMirroredOffers() {
        func flows(appeal: Double) -> (gained: Double, lost: Double) {
            var s = GameState.newGame(startCountry: "CA", companyName: "Mirror Co", seed: 11)
            s.eventsEnabled = false
            guard let country = CountryData.country("CA") else { return (0, 0) }
            for i in s.rivals.indices { s.rivals[i].subs["CA"] = nil }
            s.rivals[0].subs["CA"] = 1_000_000
            s.rivals[0].catalogStrength = 50
            s.rivals[0].priceLevel = 1.0
            s.markets["CA"]?.subs = TierSet(ad: 0, standard: 1_000_000, premium: 0)
            s.markets["CA"]?.awareness = 1.0
            s.markets["CA"]?.prices.standard = Formulas.rivalPrice(country: country, priceFactor: s.rivals[0].priceFactor,
                                                                   priceLevel: 1.0, tier: .standard)
            let flow = Switching.apply(&s, country: country, appeal: appeal, service: 1.0)
            return (flow.gained, flow.lost)
        }
        let better = flows(appeal: 0.9)
        let worse = flows(appeal: 0.1)
        XCTAssertGreaterThan(better.gained, 0)
        XCTAssertGreaterThan(worse.lost, 0)
        XCTAssertEqual(better.gained, worse.lost, accuracy: 1, "won \(better.gained) when better but lost only \(worse.lost) when equally worse")
    }

    /// Auto-scale rents a block at 85% load and gives one back below 45%, but with the starter 500K servers one
    /// block doubles the capacity: 88% becomes 44%, so it releases next week, rents again the week after, forever.
    func testBug_autoScaleFlapsRentingAndReleasingEveryWeek() {
        var s = GameState.newGame(startCountry: "CA", companyName: "Cloud Co", seed: 12)
        s.eventsEnabled = false
        s.autoScale = true
        s.markets["CA"]?.subs = TierSet(ad: 0, standard: 440_000, premium: 0)
        var units: [Int] = []
        for _ in 0..<4 {
            s.autoScaleCloud()
            units.append(s.cloudUnits[Region.northAmerica.rawValue] ?? 0)
        }
        XCTAssertEqual(units[2], units[3], "with constant subscribers the cloud should settle, got \(units)")
    }
}
