import XCTest
#if canImport(StreamEmpireCore)
@testable import StreamEmpireCore
#else
@testable import StreamEmpire
#endif

// Playtest bot 2 ("growth"): plays the CONTENT + EXPANSION game as well as a simple script can (licensing manager,
// renewals, localization, originals, seasons, studios, platforms, datacenters, tiers, promotions, funding, all 132
// markets with the closed ones first) and tries to reach #1. Plus abuse probes and a few `testBug_` tests that
// pin suspected bugs found by reading the code (they are EXPECTED TO FAIL on current code).
//
// Log lines (grep "PLAYTEST growth"):
//   PLAYTEST growth seed=.. diff=.. result=.. week=.. rank=.. subs=.. cash=.. markets=.. catalog=..
//   PLAYTEST growth milestone week=.. rank=..
//   PLAYTEST growth timing weeks=.. seconds=..
//   PLAYTEST growth probe ...   (numbers for the report)
// The bot's own randomness comes from SeededRNG; the clock is used only in this test, never in the engine.

// MARK: - Helpers

private func whole(_ x: Double) -> Int {
    guard x.isFinite else { return -1 }
    return Int(max(-9e15, min(9e15, x)))
}

private func nowSeconds() -> Double { Double(DispatchTime.now().uptimeNanoseconds) / 1_000_000_000 }

// MARK: - The bot

private struct GrowthBot {
    var rng: SeededRNG
    let mode: CuratorMode
    let cap: Int
    var priced = Set<String>()
    var platformRotation = 0

    init(seed: UInt64, mode: CuratorMode, cap: Int) {
        rng = SeededRNG(seed: seed &* 104_729 &+ 3)
        self.mode = mode
        self.cap = cap
    }

    mutating func setup(_ s: inout GameState) {
        s.expiryAlerts = .ignore
        s.renewalMode = .standard
        s.autoScale = true
        s.localization.subtitles = .all
        s.localization.dubs = .top
        s.localization.topCount = 20
        s.localization.weeklyBudget = 250_000
        _ = try? s.hireCurator(mode: mode)
        if var c = s.curator {
            c.capMode = .fixed
            c.catalogCap = cap
            _ = try? s.updateCurator(c)
        }
    }

    mutating func play(_ s: inout GameState) {
        guard s.outcome == .playing else { return }
        if s.week == 1 { setup(&s) }
        let w = s.week
        let tight = (s.finances.runwayWeeks ?? 999) < 20
        buyStarters(&s)
        if tight {
            if w % 4 == 0 { funding(&s) }
            return
        }
        if w % 4 == 0 { launchMarkets(&s) }
        if w % 6 == 1 { pricing(&s) }
        if w % 6 == 3 { marketing(&s) }
        if w % 8 == 2 { originals(&s) }
        if w % 26 == 10 { seasons(&s) }
        if w % 10 == 3 { infrastructure(&s) }
        if w % 12 == 5 { promotions(&s) }
        if w % 13 == 7 { funding(&s) }
        if w % 52 == 20 { widenListings(&s) }
    }

    private func reserve(_ s: GameState) -> Double {
        max(3_000_000, 8 * max(s.finances.lastWeek.costs, 100_000))
    }

    private mutating func buyStarters(_ s: inout GameState) {
        guard s.catalog.count < 20 else { return }
        var options: [Title] = []
        for t in s.licenseMarket where t.embargoWeeks == 0 && t.talksBlockedUntil <= s.week { options.append(t) }
        options.sort { $0.quality != $1.quality ? $0.quality > $1.quality : $0.id < $1.id }
        var bought = 0
        for t in options {
            if bought >= 3 { break }
            let price = s.licensePrice(t)
            if price > s.finances.cash * 0.08 { continue }
            if (try? s.buyLicense(titleID: t.id)) != nil { bought += 1 }
        }
    }

    private mutating func launchMarkets(_ s: inout GameState) {
        if s.catalog.count < 8 { return }
        var launching = 0
        for code in s.markets.keys.sorted() {
            guard let st = s.markets[code]?.status else { continue }
            if case .launching = st { launching += 1 }
        }
        var options: [(code: String, score: Double)] = []
        for country in CountryData.all {
            guard let m = s.markets[country.code], m.status == .notLaunched else { continue }
            if s.launchBlocker(code: country.code) != nil { continue }
            var score = country.subscriberCeiling / max(1, s.launchPrice(country))
            if CountryData.closedToRivals.contains(country.code) { score *= 3 }
            options.append((code: country.code, score: score))
        }
        options.sort { $0.score != $1.score ? $0.score > $1.score : $0.code < $1.code }
        let floor = reserve(s)
        var now = 0
        for option in options {
            if launching + now >= 10 || now >= 3 { break }
            guard let country = CountryData.country(option.code) else { continue }
            if s.finances.cash - s.launchPrice(country) < floor { continue }
            if (try? s.launchMarket(code: option.code)) != nil { now += 1 }
        }
    }

    private mutating func pricing(_ s: inout GameState) {
        for code in s.liveMarketCodes where !priced.contains(code) {
            guard let country = CountryData.country(code) else { continue }
            _ = try? s.setPrices(code: code, prices: Formulas.prices(for: country, level: 0.85))
            priced.insert(code)
        }
    }

    private mutating func marketing(_ s: inout GameState) {
        let live = s.liveMarketCodes
        var households = 0.0
        for code in live { households += CountryData.country(code)?.households ?? 0 }
        guard households > 0 else { return }
        let pool = max(0, s.finances.cash - reserve(s)) * 0.01
        for code in live {
            guard let country = CountryData.country(code) else { continue }
            let share = pool * country.households / households
            let limit = country.households * 30_000
            _ = try? s.setMarketing(code: code, weeklyBudget: min(share, limit))
        }
        // Ad tiers where advertisers pay, a few per visit.
        guard s.finances.cash > 2 * reserve(s) else { return }
        var launched = 0
        for code in live {
            if launched >= 4 { break }
            guard let country = CountryData.country(code), let m = s.markets[code] else { continue }
            if country.adStrength >= 0.3, !m.liveTiers.contains(.ad), !m.tierBuilds.contains(where: { $0.tier == .ad }) {
                if (try? s.launchTier(.ad, code: code)) != nil { launched += 1 }
            }
        }
    }

    private mutating func originals(_ s: inout GameState) {
        let live = s.liveMarketCodes
        guard !live.isEmpty else { return }
        let floor = reserve(s)
        if s.studios.isEmpty, s.finances.cash > 60_000_000 + floor { _ = try? s.foundStudio(specialty: .drama) }
        let outsourced = s.projects.filter { $0.studioID == nil }.count
        var studioID: Int? = nil
        for studio in s.studios where s.freeSlots(at: studio) > 0 { studioID = studio.id; break }
        if studioID == nil, outsourced >= 3 { return }
        let kind: TitleKind = rng.chance(0.6) ? .series : .movie
        let rich = s.finances.cash > 150_000_000
        let budget: Double = kind == .series ? (rich ? 40_000_000 : 12_000_000) : (rich ? 10_000_000 : 4_000_000)
        if s.finances.cash - floor < budget * 0.5 { return }
        var language = Language.english
        var genre = Genre.allCases[rng.nextInt(in: 0...(Genre.allCases.count - 2))]   // the last case is .local
        if rng.chance(0.3) {
            let code = live[rng.nextInt(in: 0...(live.count - 1))]
            if let l = CountryData.country(code)?.language, l != .english { language = l; genre = .local }
        }
        if genre == .local && language == .english { genre = .drama }
        let star: StarTier = rich ? .rising : .none
        _ = try? s.commissionOriginal(kind: kind, genre: genre, language: language, budget: budget,
                                      weeks: kind == .series ? 40 : 26, studioID: studioID,
                                      release: rng.chance(0.5) ? .weekly : .binge, star: star)
    }

    private mutating func seasons(_ s: inout GameState) {
        var best: Title? = nil
        for t in s.catalog where t.isOriginal && s.canContinue(t) == nil {
            if best == nil || t.quality > (best?.quality ?? 0) { best = t }
        }
        guard let pick = best, s.finances.cash > 3 * reserve(s) else { return }
        let budget: Double = pick.kind == .series ? 25_000_000 : 8_000_000
        _ = try? s.orderSeason(titleID: pick.id, budget: budget, weeks: pick.kind == .series ? 40 : 26,
                               studioID: nil, release: .weekly, star: .none)
    }

    private mutating func infrastructure(_ s: inout GameState) {
        let cash = s.finances.cash
        for p in [Platform.ios, .android, .smartTV, .consoles] {
            if s.platforms.contains(p) || s.builds.contains(where: { $0.platform == p }) { continue }
            if cash > 10 * s.platformPrice(p) + reserve(s) { _ = try? s.startPlatform(p) }
            break
        }
        for region in Region.allCases {
            let load = s.serverLoad(region)
            let building = s.datacenters.contains { $0.region == region && $0.weeksToBuild > 0 }
            if load > 0.5, !building, s.datacenters(in: region).count < Formulas.maxDatacentersPerRegion,
               cash > 5 * s.datacenterBuildPrice {
                _ = try? s.buildDatacenter(region: region)
            }
            if load > 0.8 {
                for dc in s.datacenters(in: region) where dc.isOnline {
                    if let price = s.datacenterUpgradePrice(dc), cash > 4 * price {
                        _ = try? s.upgradeDatacenter(id: dc.id)
                        break
                    }
                }
            }
        }
        for dept in [Department.content, .marketing, .engineering] {
            if s.staff[dept] < Formulas.maxDepartmentLevel, cash > 40 * s.hirePrice(dept) + reserve(s) {
                _ = try? s.hire(dept)
            }
        }
    }

    private mutating func promotions(_ s: inout GameState) {
        guard s.promotions.count < 2, !s.liveMarketCodes.isEmpty else { return }
        let kinds: [PromotionKind] = [.winback, .blitz, .freeTrial]
        let kind = kinds[rng.nextInt(in: 0...(kinds.count - 1))]
        let quote = s.promotionQuote(kind: kind, scope: "", weeks: 8, intensity: 0)
        if quote.cost > 0.2 * max(0, s.finances.cash - reserve(s)) { return }
        _ = try? s.launchPromotion(kind: kind, scope: "", weeks: 8)
    }

    private mutating func funding(_ s: inout GameState) {
        if (s.finances.runwayWeeks ?? 999) < 30 || s.finances.cash < 5_000_000 {
            let amount = min(s.creditRoom * 0.6, 50_000_000)
            if amount >= 250_000 { _ = try? s.takeLoan(amount: amount, termWeeks: 208) }
        }
        if s.roundBlocker == nil { _ = try? s.raiseRound(percent: 0.1) }
        if s.ipoBlocker == nil { _ = try? s.launchIPO() }
    }

    private mutating func widenListings(_ s: inout GameState) {
        guard s.listingReach < 3 else { return }
        if s.finances.cash > 20 * s.expandListingsPrice() { _ = try? s.expandListings() }
    }
}

// MARK: - Tests

final class PlaytestGrowthTests: XCTestCase {

    // MARK: Shared checks

    private func newState(seed: UInt64, home: String = "IE") -> GameState {
        var s = GameState.newGame(startCountry: home, companyName: "Playtest", seed: seed)
        s.eventsEnabled = false
        s.finances.cash = 1e12
        return s
    }

    /// Appends `count` generated titles that never expire.
    private func inject(_ s: inout GameState, count: Int) {
        var taken = Set<String>()
        for t in s.catalog { taken.insert(t.name) }
        for t in s.licenseMarket { taken.insert(t.name) }
        for _ in 0..<count {
            let id = s.takeID()
            var t = TitleGenerator.generate(id: id, rng: &s.rng, avoiding: taken)
            taken.insert(t.name)
            t.weeksRemaining = nil
            t.listingWeeksLeft = 0
            t.embargoWeeks = 0
            s.catalog.append(t)
        }
    }

    private func cheapProblems(_ s: GameState) -> [String] {
        var out: [String] = []
        if !s.finances.cash.isFinite { out.append("non-finite cash") }
        let subs = s.totalSubscribers
        if !subs.isFinite || subs < 0 { out.append("bad total subscribers \(subs)") }
        if let r = s.lastReport {
            if !r.financials.profit.isFinite { out.append("non-finite weekly profit") }
            if !r.financials.revenue.isFinite { out.append("non-finite weekly revenue") }
            if !r.financials.costs.isFinite { out.append("non-finite weekly costs") }
        }
        if !s.brandTrust.isFinite { out.append("non-finite brand trust") }
        return out
    }

    private func deepProblems(_ s: GameState) -> [String] {
        var out: [String] = []
        for code in s.markets.keys.sorted() {
            guard let m = s.markets[code], let c = CountryData.country(code) else { continue }
            let total = m.subs.total
            if !total.isFinite || total < 0 { out.append("bad subs \(total) in \(code)") }
            if total > c.subscriberCeiling * 1.06 {
                out.append("\(code): own subs \(whole(total)) over 1.06 x ceiling \(whole(c.subscriberCeiling))")
            }
            if !m.awareness.isFinite || m.awareness < 0 || m.awareness > 1 { out.append("awareness \(m.awareness) in \(code)") }
            if !m.marketingBudget.isFinite || m.marketingBudget < 0 { out.append("marketing budget \(m.marketingBudget) in \(code)") }
        }
        for r in s.rivals {
            for code in r.subs.keys.sorted() {
                let v = r.subs[code] ?? 0
                if !v.isFinite || v < 0 { out.append("rival \(r.id) bad subs \(v) in \(code)") }
                if v > 0, CountryData.closedToRivals.contains(code) { out.append("rival \(r.id) entered closed market \(code)") }
            }
        }
        var ids: [Int] = s.catalog.map(\.id)
        ids += s.licenseMarket.map(\.id)
        ids += s.projects.map(\.id)
        ids += s.loanedOut.map { $0.title.id }
        if Set(ids).count != ids.count { out.append("duplicate ids among catalog/listings/projects/loans") }
        return out
    }

    private func report(_ tag: String, _ problems: [String]) {
        for p in problems.prefix(25) { XCTFail("\(tag): \(p)") }
    }

    // MARK: The winner bot

    private func playGame(seed: UInt64, home: String, diff: Difficulty, mode: CuratorMode, cap: Int, timeBudget: Double) {
        var s = GameState.newGame(startCountry: home, companyName: "Growth \(seed)", seed: seed,
                                  difficulty: diff, scenario: .sandbox)
        s.eventsEnabled = false
        var bot = GrowthBot(seed: seed, mode: mode, cap: cap)
        var problems: [String] = []
        var bestRank = Int.max
        var played = 0
        let start = nowSeconds()

        while s.outcome == .playing && s.week <= 1560 {
            bot.play(&s)
            s = SimulationEngine.advanceWeek(s)
            played += 1

            problems += cheapProblems(s)
            if s.finances.ledger.localization > s.localization.weeklyBudget + 0.01 {
                problems.append("week \(s.week): auto localization spent \(whole(s.finances.ledger.localization)) over its budget \(whole(s.localization.weeklyBudget))")
            }
            if played % 13 == 0 { problems += deepProblems(s) }
            if problems.count > 40 { break }

            let rank = s.rank
            if rank < bestRank {
                bestRank = rank
                print("PLAYTEST growth milestone week=\(s.week) rank=\(rank)")
            }
            if played % 8 == 0, nowSeconds() - start > timeBudget { break }
        }

        problems += deepProblems(s)
        let elapsed = nowSeconds() - start
        print("PLAYTEST growth seed=\(seed) diff=\(diff.rawValue) result=\(s.outcome.rawValue) week=\(s.week) rank=\(s.rank) subs=\(whole(s.totalSubscribers)) cash=\(whole(s.finances.cash)) markets=\(s.liveMarketCodes.count) catalog=\(s.catalog.count)")
        print("PLAYTEST growth timing weeks=\(played) seconds=\(String(format: "%.2f", elapsed))")
        report("seed \(seed)", problems)
    }

    func testGrowthBot_game1_medium() {
        playGame(seed: 11, home: "CA", diff: .medium, mode: .moderate, cap: 250, timeBudget: 18)
    }

    func testGrowthBot_game2_easyAggressive() {
        playGame(seed: 12, home: "GB", diff: .easy, mode: .aggressive, cap: 400, timeBudget: 18)
    }

    func testGrowthBot_game3_hardPassive() {
        playGame(seed: 13, home: "IE", diff: .hard, mode: .passive, cap: 150, timeBudget: 18)
    }

    // MARK: Probes

    /// Closed markets (CN, IR, CU): rivals never enter, so the whole ceiling is uncontested.
    func testProbe_closedMarketsAreUncontested() {
        var s = newState(seed: 301, home: "CA")
        inject(&s, count: 40)
        var codes = ["IR", "CU", "CN"]
        var comparison = ""
        for c in CountryData.all where !CountryData.closedToRivals.contains(c.code) && c.code != "CA" {
            if abs(c.households - 15) < 3 { comparison = c.code; break }
        }
        if !comparison.isEmpty { codes.append(comparison) }
        for code in codes {
            s.markets[code]?.status = .live
            s.markets[code]?.awareness = 0.2
        }
        for r in Region.allCases { s.cloudUnits[r.rawValue] = Formulas.maxCloudUnits }
        var problems: [String] = []
        var line = ""
        for week in 1...104 {
            s.finances.cash = 1e12
            s = SimulationEngine.advanceWeek(s)
            problems += cheapProblems(s)
            if week == 52 || week == 104 {
                problems += deepProblems(s)
                var parts: [String] = []
                for code in codes {
                    let ceiling = CountryData.country(code)?.subscriberCeiling ?? 1
                    let rivalSubs = s.rivals.reduce(0.0) { $0 + ($1.subs[code] ?? 0) }
                    parts.append("\(code)=\(String(format: "%.3f", (s.markets[code]?.subs.total ?? 0) / ceiling)) rivalShare=\(String(format: "%.3f", rivalSubs / ceiling))")
                }
                line += " w\(week)[\(parts.joined(separator: " "))]"
            }
        }
        print("PLAYTEST growth probe closedMarketPenetration\(line)")
        report("closed markets", problems)
    }

    /// Does a $0 plan win subscribers AND make money through ads?
    private func runPriced(_ prices: TierSet, weeks: Int) -> (subs: Double, profit: Double, problems: [String]) {
        var s = newState(seed: 302, home: "US")
        inject(&s, count: 40)
        s.markets["US"]?.liveTiers = [.ad, .standard, .premium]
        _ = try? s.setPrices(code: "US", prices: prices)
        for r in Region.allCases { s.cloudUnits[r.rawValue] = Formulas.maxCloudUnits }
        var problems: [String] = []
        for _ in 0..<weeks {
            s.finances.cash = 1e12
            s = SimulationEngine.advanceWeek(s)
            problems += cheapProblems(s)
        }
        return (s.totalSubscribers, s.finances.lastWeek.profit, problems)
    }

    func testProbe_freePlansAreAMoneyMachine() {
        guard let us = CountryData.country("US") else { return XCTFail("no US") }
        let fair = CountryData.defaultPrices(for: us)
        let normal = runPriced(fair, weeks: 78)
        let free = runPriced(TierSet(ad: 0, standard: 0, premium: 0), weeks: 78)
        print("PLAYTEST growth probe freePrice fairSubs=\(whole(normal.subs)) fairProfit=\(whole(normal.profit)) freeSubs=\(whole(free.subs)) freeProfit=\(whole(free.profit))")
        report("fair pricing", normal.problems)
        report("free pricing", free.problems)
    }

    func testProbe_catalogAppealSaturates() {
        guard let ca = CountryData.country("CA") else { return XCTFail("no CA") }
        let t = Title(id: 1, name: "Sample", kind: .series, genre: .drama, language: .english, quality: 75,
                      popularity: 70, ageWeeks: 50, isOriginal: true, license: nil, weeksRemaining: nil, listingWeeksLeft: 0)
        var last = 0.0
        var parts: [String] = []
        for n in [5, 10, 25, 50, 100, 300, 1000] {
            let a = Formulas.catalogAppeal(Array(repeating: t, count: n), in: ca)
            XCTAssertTrue(a.isFinite && a >= last - 1e-12 && a <= 1.0, "appeal at \(n) titles: \(a)")
            last = a
            parts.append("\(n)=\(String(format: "%.3f", a))")
        }
        print("PLAYTEST growth probe appealByCatalogSize \(parts.joined(separator: " "))")
    }

    func testInvariant_catalogSizePriceFactorIsMonotoneAndReachable() {
        var last = 1.0
        for n in stride(from: 0, through: 12_000, by: 100) {
            let f = Formulas.catalogSizePriceFactor(count: n)
            XCTAssertTrue(f.isFinite && f >= last - 1e-12, "factor at \(n): \(f)")
            last = f
        }
        XCTAssertEqual(Formulas.catalogSizePriceFactor(count: 300), 1.0, accuracy: 1e-9)
        let at8000 = Formulas.catalogSizePriceFactor(count: 8_000)
        XCTAssertTrue(at8000 > 20 && at8000 < 35, "x\(at8000) at 8,000 titles")
    }

    /// Buy-out prices come from what you PAID (at a small audience); sublicense fees come from today's audience.
    func testProbe_buyoutThenSublicenseRoi() {
        var s = newState(seed: 304)
        guard let listing = s.licenseMarket.first(where: { $0.embargoWeeks == 0 && $0.license != nil }) else { return XCTFail("no listing") }
        guard (try? s.buyLicense(titleID: listing.id)) != nil else { return XCTFail("could not buy") }
        s.markets["IE"]?.subs = TierSet(ad: 0, standard: 10_000_000, premium: 0)     // a 10M-subscriber company
        guard let owned = s.catalog.first(where: { $0.id == listing.id }) else { return XCTFail("title missing") }
        let buyout = s.buyoutPrice(owned)
        let fee104 = s.sublicenseFee(owned, weeks: 104)
        XCTAssertTrue(buyout.isFinite && fee104.isFinite)
        let cashBefore = s.finances.cash
        _ = try? s.buyOutRights(titleID: owned.id)
        _ = try? s.licenseOut(titleID: owned.id, weeks: 104)
        let net = s.finances.cash - cashBefore
        print("PLAYTEST growth probe buyoutThenSublicense buyout=\(whole(buyout)) fee104=\(whole(fee104)) netAfterOneCycle=\(whole(net)) paybackCycles=\(String(format: "%.2f", buyout / max(1, fee104)))")
    }

    func testProbe_promotionStackingAndFlatCost() {
        let a = PromoMath.effects(kind: .winback, intensity: 0, strength: 1)
        let b = PromoMath.effects(kind: .blitz, intensity: 0, strength: 1)
        let c = PromoMath.effects(kind: .freeTrial, intensity: 0, strength: 1)
        let stacked = a.adds * b.adds * c.adds
        let global = PromoMath.cost(kind: .blitz, weeks: 12, markets: 132, costScale: 1)
        print("PLAYTEST growth probe promoStack addsMultiplier=\(String(format: "%.2f", stacked)) globalBlitz12wCost=\(whole(global))")
        XCTAssertTrue(stacked.isFinite && global.isFinite && global > 0)
    }

    func testProbe_worldCeilingsVersusRivalsAndServers() {
        var total = 0.0, closed = 0.0
        var byRegion: [Region: Double] = [:]
        for c in CountryData.all {
            total += c.subscriberCeiling
            if CountryData.closedToRivals.contains(c.code) { closed += c.subscriberCeiling }
            byRegion[c.region, default: 0] += c.subscriberCeiling
        }
        let rivals = RivalData.initialRivals()
        var rivalTotal = 0.0, biggest = 0.0
        for r in rivals { rivalTotal += r.totalSubs; biggest = max(biggest, r.totalSubs) }
        let serverCap = Formulas.baseServerCapacity
            + Double(Formulas.maxDatacentersPerRegion) * Formulas.datacenterCapacity(level: Formulas.maxDatacenterLevel)
            + Double(Formulas.maxCloudUnits) * Formulas.cloudUnitCapacity
        var parts: [String] = []
        for r in Region.allCases { parts.append("\(r.rawValue)=\(whole((byRegion[r] ?? 0) / 1e6))M") }
        print("PLAYTEST growth probe world ceilingM=\(whole(total / 1e6)) closedM=\(whole(closed / 1e6)) rivalStartM=\(whole(rivalTotal / 1e6)) biggestRivalM=\(whole(biggest / 1e6)) maxServersPerRegionM=\(whole(serverCap / 1e6)) regions[\(parts.joined(separator: " "))]")
        XCTAssertTrue(total.isFinite && closed > 0)
    }

    func testProbe_expandListingsKeepsListingsUniqueAndBounded() {
        var s = newState(seed: 309)
        inject(&s, count: 200)
        let before = s.finances.ledger.other
        for _ in 0..<GameState.maxListingReach { _ = try? s.expandListings() }
        XCTAssertEqual(s.listingReach, GameState.maxListingReach)
        XCTAssertLessThanOrEqual(s.licenseMarket.count, s.listingTarget)
        let names = s.licenseMarket.map { $0.name.lowercased() } + s.catalog.map { $0.name.lowercased() }
        XCTAssertEqual(Set(names).count, names.count, "listing names must not collide with each other or the catalog")
        print("PLAYTEST growth probe expandListings totalCost=\(whole(s.finances.ledger.other - before)) listings=\(s.licenseMarket.count)")
    }

    /// Auto localization must never spend more than its weekly budget and never double-list a language.
    func testInvariant_autoLocalizationRespectsBudgetAndNeverDuplicates() {
        var s = newState(seed: 307)
        inject(&s, count: 60)
        for code in ["DE", "FR", "ES", "IT", "BR", "JP"] where CountryData.country(code) != nil {
            s.markets[code]?.status = .live
        }
        s.localization.subtitles = .all
        s.localization.dubs = .all
        s.localization.weeklyBudget = 300_000
        var spentTotal = 0.0
        var problems: [String] = []
        for _ in 0..<12 {
            s.finances.cash = 1e12
            s = SimulationEngine.advanceWeek(s)
            let spent = s.finances.ledger.localization
            spentTotal += spent
            if spent > s.localization.weeklyBudget + 0.01 { problems.append("localization spent \(whole(spent)) over budget") }
            problems += cheapProblems(s)
        }
        for t in s.catalog {
            if Set(t.subtitles).count != t.subtitles.count { problems.append("\(t.name): duplicate subtitle language") }
            if Set(t.dubs).count != t.dubs.count { problems.append("\(t.name): duplicate dub language") }
            if t.subtitles.contains(t.language) || t.dubs.contains(t.language) { problems.append("\(t.name): localized into its own language") }
        }
        XCTAssertGreaterThan(spentTotal, 0, "automatic localization never did anything")
        report("auto localization", problems)
    }

    /// Everything at once: launch all 131 other markets, check the goal fires and nothing explodes.
    func testProbe_launchEveryMarketAtOnce() {
        var s = newState(seed: 308)
        s.finances.cash = 1e13
        inject(&s, count: 80)
        for r in Region.allCases { s.cloudUnits[r.rawValue] = Formulas.maxCloudUnits }
        var launched = 0
        var cost = 0.0
        for c in CountryData.all {
            let price = s.launchPrice(c)
            if (try? s.launchMarket(code: c.code)) != nil { launched += 1; cost += price }
        }
        XCTAssertEqual(launched, CountryData.all.count - 1, "every market except the home market should be launchable with 80 titles and unlimited cash")
        var problems: [String] = []
        for _ in 0..<26 {
            s.finances.cash = 1e13
            s = SimulationEngine.advanceWeek(s)
            problems += cheapProblems(s)
        }
        problems += deepProblems(s)
        XCTAssertEqual(s.liveMarketCodes.count, CountryData.all.count)
        XCTAssertTrue(s.goals.contains("allMarkets"), "the all-markets goal should have fired")
        print("PLAYTEST growth probe allMarkets launchCostM=\(whole(cost / 1e6)) subs=\(whole(s.totalSubscribers)) rank=\(s.rank) live=\(s.liveMarketCodes.count)")
        report("all markets", problems)
    }

    /// 3,000 titles and 20 markets: how long does a simulated week take? (log only)
    func testProbe_bigCatalogWeekTiming() {
        var s = newState(seed: 310)
        inject(&s, count: 3_000)
        var n = 0
        for c in CountryData.all where c.code != "IE" && !CountryData.closedToRivals.contains(c.code) && c.unlock == nil {
            s.markets[c.code]?.status = .live
            n += 1
            if n >= 20 { break }
        }
        for r in Region.allCases { s.cloudUnits[r.rawValue] = Formulas.maxCloudUnits }
        _ = try? s.hireCurator(mode: .aggressive)
        if var cur = s.curator { cur.capMode = .none; _ = try? s.updateCurator(cur) }
        s.renewalMode = .standard
        s.localization.subtitles = .all
        s.localization.dubs = .top
        let weeks = 6
        var problems: [String] = []
        let start = nowSeconds()
        for _ in 0..<weeks {
            s.finances.cash = 1e12
            s = SimulationEngine.advanceWeek(s)
            problems += cheapProblems(s)
        }
        let elapsed = nowSeconds() - start
        print("PLAYTEST growth probe bigCatalog titles=\(s.catalog.count) markets=\(s.liveMarketCodes.count) weeks=\(weeks) secondsPerWeek=\(String(format: "%.3f", elapsed / Double(weeks)))")
        report("big catalog", problems)
    }

    // MARK: Suspected bugs (expected to FAIL on current code)

    /// Renewal prices are built from the price you paid LAST time, and every renewal re-bases `paidPrice`, so each
    /// 5-year renewal is ~30% cheaper per year than the previous one (0.8 x 0.88): after a few cycles a license is
    /// nearly free, whatever the audience or catalog size (Renewals.swift renewLicense / Formulas.renewalPrice).
    func testBug_renewalPricePerYearNeverDecaysForTheSameTitle() {
        var s = newState(seed: 305)
        guard let listing = s.licenseMarket.first(where: { $0.embargoWeeks == 0 && $0.license != nil }) else { return XCTFail("no listing") }
        guard (try? s.buyLicense(titleID: listing.id)) != nil else { return XCTFail("could not buy") }
        guard let i = s.catalog.firstIndex(where: { $0.id == listing.id }) else { return XCTFail("title missing") }
        s.catalog[i].sought = false
        let originalPerYear = s.catalog[i].paidPrice / Double(max(1, s.catalog[i].license?.years ?? 1))
        var perYear: [Double] = []
        for _ in 0..<6 {
            s.finances.cash = 1e12
            s.catalog[i].weeksRemaining = 20
            do { try s.renewLicense(titleID: listing.id, years: 5) } catch { return XCTFail("renewal failed: \(error)") }
            perYear.append(s.catalog[i].paidPrice / 5)
        }
        XCTAssertGreaterThanOrEqual(perYear[1], perYear[0] * 0.95,
                                    "second renewal is \(whole(perYear[1])) a year vs \(whole(perYear[0])) for the first, with no popularity change")
        XCTAssertGreaterThanOrEqual(perYear[5], originalPerYear * 0.3,
                                    "after six renewals the license costs \(whole(perYear[5])) a year vs \(whole(originalPerYear)) originally")
    }

    /// A season ordered while the show is in the catalog finishes while the parent is licensed out: the production
    /// code can't find the parent, so it appends a SECOND title with the same name (SimulationEngine.produceOriginals,
    /// `else { s.catalog.append(title) }`). When the parent returns, the player owns two copies of the same series.
    func testBug_seasonFinishingWhileParentIsLicensedOutDoesNotDuplicateTheShow() {
        var s = newState(seed: 306)
        inject(&s, count: 12)
        let id = s.takeID()
        s.catalog.append(Title(id: id, name: "Parent Show", kind: .series, genre: .drama, language: .english,
                               quality: 80, popularity: 70, ageWeeks: 20, isOriginal: true, license: nil,
                               weeksRemaining: nil, listingWeeksLeft: 0))
        do { try s.orderSeason(titleID: id, budget: 5_000_000, weeks: 6) } catch { return XCTFail("orderSeason: \(error)") }
        do { try s.licenseOut(titleID: id, weeks: 13) } catch { return XCTFail("licenseOut: \(error)") }
        for _ in 0..<8 {
            s.finances.cash = 1e12
            s = SimulationEngine.advanceWeek(s)
        }
        var names: [String] = s.catalog.map { $0.name }
        names += s.loanedOut.map { $0.title.name }
        XCTAssertEqual(Set(names).count, names.count, "\"Parent Show\" exists twice: the new season became a separate title")
    }
}
