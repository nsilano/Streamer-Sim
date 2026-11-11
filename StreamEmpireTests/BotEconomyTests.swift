import XCTest
#if canImport(StreamEmpireCore)
@testable import StreamEmpireCore
#else
@testable import StreamEmpire
#endif

/// "Playtest Bot 1": a randomized economy and licensing fuzzer. Every week it throws random (legal and illegal)
/// licensing, curator, pricing and funding actions at the game, advances the week, and asserts invariants.
/// All bot randomness comes from its own `SeededRNG`, so runs are reproducible.
///
/// Methods named `testBug_*` are focused deterministic repros of suspected engine bugs. THEY ARE EXPECTED TO FAIL
/// on the current code until the bug is fixed.
final class BotEconomyTests: XCTestCase {

    // MARK: Failure collector (one message per invariant tag, so a systematic bug doesn't spam thousands of lines)

    private final class Report {
        var messages: [String] = []
        var seen: Set<String> = []
        func check(_ ok: Bool, _ tag: String, _ message: @autoclosure () -> String) {
            if ok { return }
            if seen.contains(tag) { return }
            seen.insert(tag)
            messages.append("[\(tag)] \(message())")
        }
    }

    // MARK: The bot

    private struct Bot {
        var rng: SeededRNG

        init(seed: UInt64) { rng = SeededRNG(seed: seed &* 7919 &+ 13) }

        mutating func roll(_ p: Double) -> Bool { rng.chance(p) }
        mutating func double(_ lo: Double, _ hi: Double) -> Double { rng.nextDouble(in: lo...hi) }
        mutating func int(_ lo: Int, _ hi: Int) -> Int { rng.nextInt(in: lo...hi) }
        /// A random index below `count` (count must be > 0).
        mutating func index(_ count: Int) -> Int { rng.nextInt(in: 0...(count - 1)) }

        mutating func configure(_ c: inout Curator) {
            c.enabled = roll(0.9)
            c.purchasesPerWeek = int(0, 20)
            let caps = CatalogCapMode.allCases
            c.capMode = caps[index(caps.count)]
            c.catalogCap = int(0, 400)
            let modes = CuratorMode.allCases
            c.mode = modes[index(modes.count)]
            c.weeklyBudget = double(0, 4_000_000)
            c.maxPricePerTitle = double(0, 6_000_000)
            c.minQuality = int(0, 90)
            c.targetCatalogSize = int(0, 300)
            c.cashReserve = double(0, 5_000_000)
            c.allowExclusive = roll(0.6)
            c.maxYears = roll(0.03) ? 0 : int(1, 5)
            c.allowMovies = roll(0.9)
            c.allowSeries = roll(0.9)
            c.genres = roll(0.2) ? [Genre.drama, Genre.comedy] : []
            c.onlyMyLanguages = roll(0.5)
            c.autoRenew = roll(0.7)
            c.renewMaxPrice = double(0, 4_000_000)
            c.renewYears = int(1, 5)
        }

        mutating func act(_ s: inout GameState) {
            let big = s.catalog.count > 900

            // Buying and negotiating from the listings.
            if roll(0.6), !big, !s.licenseMarket.isEmpty {
                let id = roll(0.05) ? 999_999 : s.licenseMarket[index(s.licenseMarket.count)].id
                _ = try? s.buyLicense(titleID: id)
            }
            if roll(0.3), !big, !s.licenseMarket.isEmpty {
                let id = s.licenseMarket[index(s.licenseMarket.count)].id
                let offer = double(0.45, 1.0)
                let years = int(0, 6)
                let exclusive = roll(0.5)
                _ = try? s.negotiate(titleID: id, offer: offer, years: years, exclusive: exclusive)
            }

            // Renewals.
            if roll(0.35), !s.catalog.isEmpty {
                let pool = s.expiringTitles
                let id = (!pool.isEmpty && roll(0.6)) ? pool[index(pool.count)].id : s.catalog[index(s.catalog.count)].id
                _ = try? s.renewLicense(titleID: id, years: int(0, 6))
            }
            if roll(0.15) { _ = try? s.renewAll(years: int(1, 5)) }

            // Catalog moves on titles you own.
            if roll(0.06), !s.catalog.isEmpty {
                _ = try? s.buyOutRights(titleID: s.catalog[index(s.catalog.count)].id)
            }
            if roll(0.1), !s.catalog.isEmpty {
                let weeksOptions = [7, 13, 26, 52, 104]
                let id = s.catalog[index(s.catalog.count)].id
                let weeks = weeksOptions[index(weeksOptions.count)]
                _ = try? s.licenseOut(titleID: id, weeks: weeks)
            }

            // Listing market controls.
            if roll(0.04) { _ = try? s.refreshListings() }
            if roll(0.03) { _ = try? s.expandListings() }

            // Licensing manager.
            if s.curator == nil {
                if roll(0.15) {
                    let modes = CuratorMode.allCases
                    _ = try? s.hireCurator(mode: modes[index(modes.count)])
                }
            } else if var c = s.curator {
                var changed = false
                if roll(0.2) { configure(&c); changed = true }
                if s.catalog.count > 900 { c.enabled = false; changed = true }
                if changed { _ = try? s.updateCurator(c) }
                if roll(0.04) { s.fireCurator() }
            }
            if roll(0.15) { _ = try? s.shopNow() }

            // Renewal style and alerts.
            if roll(0.08) {
                let modes = RenewalMode.allCases
                s.renewalMode = modes[index(modes.count)]
            }
            if roll(0.08) {
                let alerts = ExpiryAlerts.allCases
                s.expiryAlerts = alerts[index(alerts.count)]
            }

            // Pricing.
            let live = s.liveMarketCodes
            if roll(0.1), !live.isEmpty {
                let code = live[index(live.count)]
                let prices = TierSet(ad: double(0, 20), standard: double(0, 30), premium: double(0, 40))
                _ = try? s.setPrices(code: code, prices: prices)
            }
            if roll(0.05) { _ = try? s.applyPriceLevel(double(0.3, 2.1)) }

            // Growth and funding (only as they affect cash).
            if roll(0.04) {
                let code = CountryData.all[index(CountryData.all.count)].code
                _ = try? s.launchMarket(code: code)
            }
            if roll(0.03) {
                let terms = [52, 104, 208]
                _ = try? s.takeLoan(amount: double(250_000, 50_000_000), termWeeks: terms[index(terms.count)])
            }
            if roll(0.02) { _ = try? s.raiseRound(percent: double(0.04, 0.26)) }
            if roll(0.01) { _ = try? s.launchIPO() }
            if roll(0.03), let loan = s.loans.first {
                _ = try? s.repayLoan(id: loan.id, amount: double(100_000, 10_000_000))
            }
        }
    }

    // MARK: Invariants

    private func fields(_ f: WeeklyFinancials) -> [(String, Double)] {
        [("subscriptionRevenue", f.subscriptionRevenue), ("adRevenue", f.adRevenue), ("licensing", f.licensing),
         ("streaming", f.streaming), ("staff", f.staff), ("marketing", f.marketing), ("operations", f.operations),
         ("launch", f.launch), ("originals", f.originals), ("localization", f.localization),
         ("interest", f.interest), ("fines", f.fines), ("other", f.other), ("tech", f.tech),
         ("studios", f.studios), ("policies", f.policies), ("promotions", f.promotions),
         ("licenseOutRevenue", f.licenseOutRevenue), ("taxes", f.taxes)]
    }

    private func checkWeek(old: GameState, new: GameState, seed: UInt64, report: Report) {
        let ctx = "seed \(seed) week \(old.week)"
        let f = new.finances.lastWeek

        // Finite numbers everywhere.
        report.check(new.finances.cash.isFinite, "cashFinite", "\(ctx): cash is \(new.finances.cash)")
        report.check(new.totalSubscribers.isFinite, "subsFinite", "\(ctx): total subscribers \(new.totalSubscribers)")
        for code in new.markets.keys.sorted() {
            let subs = new.markets[code]?.subs ?? TierSet.zero
            let ok = subs.ad.isFinite && subs.standard.isFinite && subs.premium.isFinite
                && subs.ad >= 0 && subs.standard >= 0 && subs.premium >= 0
            report.check(ok, "marketSubs", "\(ctx): market \(code) subs \(subs)")
        }
        for (name, value) in fields(f) {
            report.check(value.isFinite, "fin.\(name).finite", "\(ctx): WeeklyFinancials.\(name) = \(value)")
        }
        for id in new.titleStats.keys.sorted() {
            let t = new.titleStats[id] ?? TitleStats()
            let ok = t.weeklyViewers.isFinite && t.weeklyRevenue.isFinite && t.peakViewers.isFinite
                && t.totalViews.isFinite && t.lifetimeRevenue.isFinite && t.licenseIncome.isFinite
                && t.topMarketViewers.isFinite
            report.check(ok, "titleStatsFinite", "\(ctx): titleStats[\(id)] = \(t)")
        }
        for rival in new.rivals {
            var ok = rival.cash.isFinite && rival.catalogStrength.isFinite && rival.priceLevel.isFinite
            for code in rival.subs.keys.sorted() {
                let v = rival.subs[code] ?? 0
                if !v.isFinite || v < 0 { ok = false }
            }
            report.check(ok, "rivalFinite", "\(ctx): rival \(rival.id) has non-finite or negative values")
        }
        let ledger = new.finances.ledger
        report.check(ledger.licensing.isFinite && ledger.launch.isFinite && ledger.localization.isFinite
                     && ledger.other.isFinite && ledger.promotions.isFinite && ledger.licenseIncome.isFinite,
                     "ledgerFinite", "\(ctx): ledger \(ledger)")

        // Sign rules.
        report.check(f.revenue >= -1e-6, "revenueNonNegative", "\(ctx): revenue \(f.revenue)")
        for (name, value) in fields(f) where name != "licensing" {
            report.check(value >= -1e-6, "fin.\(name).nonNegative", "\(ctx): WeeklyFinancials.\(name) = \(value)")
        }

        // Catalog hygiene.
        let catalogIDs = new.catalog.map { $0.id }
        report.check(Set(catalogIDs).count == catalogIDs.count, "catalogIDsUnique", "\(ctx): duplicate ids in catalog")
        report.check(new.catalog.allSatisfy { ($0.weeksRemaining ?? 1) > 0 }, "expiredStillInCatalog",
                     "\(ctx): a title with weeksRemaining <= 0 is still in the catalog: "
                     + new.catalog.filter { ($0.weeksRemaining ?? 1) <= 0 }.map { $0.name }.joined(separator: ", "))
        let marketIDs = new.licenseMarket.map { $0.id }
        report.check(Set(marketIDs).count == marketIDs.count, "marketIDsUnique", "\(ctx): duplicate ids in licenseMarket")
        report.check(Set(marketIDs).isDisjoint(with: Set(catalogIDs)), "marketCatalogOverlap",
                     "\(ctx): a title is both on the market and in the catalog")
        let loanIDs = new.loanedOut.map { $0.title.id }
        report.check(Set(loanIDs).isDisjoint(with: Set(catalogIDs)), "loanCatalogOverlap",
                     "\(ctx): a title is both loaned out and in the catalog")
        report.check(new.loanedOut.allSatisfy { $0.weeksLeft > 0 && ($0.title.weeksRemaining ?? 1) > 0 }, "loanState",
                     "\(ctx): a loan has no weeks left or its rights ran out but it is still listed")

        // What the report books equals what was prepaid in the ledger.
        let oldLedger = old.finances.ledger
        let tol = 1e-6 * max(1, abs(old.finances.cash)) + 0.5
        report.check(abs(f.launch - oldLedger.launch) <= tol, "fin.launchMatchesLedger", "\(ctx): launch \(f.launch) vs ledger \(oldLedger.launch)")
        report.check(abs(f.localization - oldLedger.localization) <= tol, "fin.localizationMatchesLedger",
                     "\(ctx): localization \(f.localization) vs ledger \(oldLedger.localization)")
        report.check(abs(f.other - oldLedger.other) <= tol, "fin.otherMatchesLedger", "\(ctx): other \(f.other) vs ledger \(oldLedger.other)")
        report.check(abs(f.promotions - oldLedger.promotions) <= tol, "fin.promotionsMatchesLedger",
                     "\(ctx): promotions \(f.promotions) vs ledger \(oldLedger.promotions)")
        report.check(abs(f.licenseOutRevenue - oldLedger.licenseIncome) <= tol, "fin.licenseOutMatchesLedger",
                     "\(ctx): licenseOutRevenue \(f.licenseOutRevenue) vs ledger \(oldLedger.licenseIncome)")

        // The ledger is emptied at the start of the week; only spending that happened DURING the week
        // (licensing manager, auto-renew, rival recalls) may sit in it afterwards, never launch/promo/income.
        report.check(ledger.licenseIncome == 0, "ledgerIncomeReset", "\(ctx): ledger.licenseIncome = \(ledger.licenseIncome) after the week")
        report.check(ledger.launch == 0 && ledger.promotions == 0 && ledger.localization == 0, "ledgerNotReset",
                     "\(ctx): ledger still holds launch/promotions/localization after the week: \(ledger)")

        // Cash identity: cash moves by profit, plus what was already deducted (so costs don't double count),
        // minus principal repaid (not P&L), minus license-out income (already in cash), minus whatever the manager,
        // auto-renew and recalls booked into the fresh ledger during the week (deducted when paid).
        let principal = old.loans.reduce(0.0) { $0 + min($1.balance, $1.weeklyPrincipal) }
        let expected = f.profit + oldLedger.total - principal - oldLedger.licenseIncome - ledger.total
        let actual = new.finances.cash - old.finances.cash
        report.check(abs(actual - expected) <= tol + 1e-9 * abs(f.profit), "cashIdentity",
                     "\(ctx): cash moved \(actual) but accounting says \(expected) (profit \(f.profit), prepaid \(oldLedger.total), principal \(principal), licenseIncome \(oldLedger.licenseIncome), newLedger \(ledger.total))")
    }

    private func checkPrices(_ s: GameState, seed: UInt64, report: Report) {
        let ctx = "seed \(seed) week \(s.week)"
        let sample = Array(s.catalog.prefix(30)) + Array(s.licenseMarket.prefix(30))
        for t in sample {
            let values: [(String, Double)] = [
                ("licensePrice", s.licensePrice(t)),
                ("renewalPrice", s.renewalPrice(t, years: 2)),
                ("buyoutPrice", s.buyoutPrice(t)),
                ("sublicenseFee", s.sublicenseFee(t, weeks: 13)),
                ("askingPrice", s.askingPrice(t, years: 2, exclusive: false))]
            for (name, value) in values {
                report.check(value.isFinite && value >= 0, "price.\(name)", "\(ctx): \(name)(\(t.name)) = \(value)")
            }
        }
        for (name, value) in [("refresh", s.refreshListingsPrice()), ("expand", s.expandListingsPrice()),
                              ("outputFee", s.outputDealFee())] {
            report.check(value.isFinite && value >= 0, "price.\(name)", "\(ctx): \(name) price = \(value)")
        }
    }

    // MARK: Runner

    private struct RunResult {
        var state: GameState
        var cashTrace: [Double]
    }

    private func runBot(seed: UInt64, weeks: Int, cash: Double?, country: String, subs: Double,
                        report: Report, roundTripEvery: Int = 50) -> RunResult {
        var s = GameState.newGame(startCountry: country, companyName: "Bot \(seed)", seed: seed)
        s.eventsEnabled = false
        if let cash = cash { s.finances.cash = cash }
        if subs > 0 {
            s.markets[country]?.subs = TierSet(ad: 0, standard: subs, premium: 0)
            s.markets[country]?.awareness = 0.5
        }
        var bot = Bot(seed: seed)
        var trace: [Double] = []
        for _ in 0..<weeks {
            guard s.outcome == .playing else { break }
            bot.act(&s)
            let before = s
            let after = SimulationEngine.advanceWeek(before)
            checkWeek(old: before, new: after, seed: seed, report: report)
            if before.week % 10 == 0 { checkPrices(after, seed: seed, report: report) }
            if before.week % roundTripEvery == 0 {
                let data = try? JSONEncoder().encode(after)
                let loaded = data.flatMap { try? JSONDecoder().decode(GameState.self, from: $0) }
                report.check(data != nil, "jsonEncode", "seed \(seed) week \(before.week): state failed to encode")
                report.check(loaded == after, "jsonRoundTrip", "seed \(seed) week \(before.week): JSON round trip changed the state")
            }
            trace.append(after.finances.cash)
            s = after
        }
        return RunResult(state: s, cashTrace: trace)
    }

    private func assertClean(_ report: Report, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(report.messages.isEmpty, "Bot found invariant violations:\n" + report.messages.joined(separator: "\n"),
                      file: file, line: line)
    }

    // MARK: Fuzz tests

    func testBotRichSeeds() {
        let setups: [(UInt64, String)] = [(101, "GB"), (202, "IE"), (303, "CA"), (404, "DE"), (505, "FR"), (606, "AU")]
        for (seed, country) in setups {
            let report = Report()
            let result = runBot(seed: seed, weeks: 600, cash: 300_000_000, country: country, subs: 200_000, report: report)
            XCTAssertGreaterThan(result.cashTrace.count, 100, "seed \(seed): rich bot should survive a good while")
            assertClean(report)
        }
    }

    func testBotPoorSeed() {
        let report = Report()
        _ = runBot(seed: 777, weeks: 600, cash: nil, country: "IE", subs: 0, report: report)
        assertClean(report)
        let second = Report()
        _ = runBot(seed: 778, weeks: 600, cash: 40_000_000, country: "NL", subs: 0, report: second)
        assertClean(second)
    }

    func testBotIsDeterministic() {
        let a = runBot(seed: 909, weeks: 200, cash: 200_000_000, country: "GB", subs: 100_000, report: Report())
        let b = runBot(seed: 909, weeks: 200, cash: 200_000_000, country: "GB", subs: 100_000, report: Report())
        XCTAssertEqual(a.cashTrace.count, b.cashTrace.count, "same seed, same number of weeks played")
        for i in 0..<min(a.cashTrace.count, b.cashTrace.count) where a.cashTrace[i] != b.cashTrace[i] {
            XCTFail("cash diverged at week \(i + 1): \(a.cashTrace[i]) vs \(b.cashTrace[i])")
            break
        }
        XCTAssertEqual(a.state, b.state, "same seed and same bot decisions must give identical states")
    }

    func testCatalogSizePriceFactorIsMonotonicAndSane() {
        var last = Formulas.catalogSizePriceFactor(count: 0)
        XCTAssertEqual(last, 1.0)
        for n in stride(from: 1, through: 20_000, by: 7) {
            let v = Formulas.catalogSizePriceFactor(count: n)
            XCTAssertTrue(v.isFinite, "factor at \(n) is \(v)")
            XCTAssertGreaterThanOrEqual(v, last, "factor must never fall as the catalog grows (n=\(n))")
            XCTAssertGreaterThanOrEqual(v, 1.0)
            last = v
        }
        XCTAssertEqual(Formulas.catalogSizePriceFactor(count: 300), 1.0)
    }

    // MARK: Suspected bugs (EXPECTED TO FAIL on the current code)

    /// BUG (Curating.swift `shopNow` / `curatorShop`): `shopNow` hands the manager a fresh `weeklyBudget` every
    /// time it is pressed, with no record of what was already spent this week. Spamming "Shop now" therefore
    /// multiplies the weekly allowance. EXPECTED TO FAIL until the budget is tracked per week.
    func testBug_shopNowStacksTheWeeklyBudget() throws {
        var s = GameState.newGame(startCountry: "GB", companyName: "Test Co", seed: 5)
        s.eventsEnabled = false
        s.finances.cash = 1e10
        try s.expandListings()
        try s.expandListings()
        try s.expandListings()
        try s.hireCurator(mode: .custom)
        var c = s.curator!
        c.enabled = true
        c.mode = .custom
        c.capMode = .auto
        c.weeklyBudget = 1_000_000
        c.carryBudget = 0
        c.purchasesPerWeek = 50
        c.maxPricePerTitle = 1e9
        c.minQuality = 0
        c.targetCatalogSize = 1_000
        c.cashReserve = 0
        c.allowExclusive = true
        c.maxYears = 5
        c.onlyMyLanguages = false
        c.autoRenew = false
        try s.updateCurator(c)
        let start = s.finances.ledger.licensing
        for _ in 0..<6 { try s.shopNow() }
        let spent = s.finances.ledger.licensing - start
        XCTAssertLessThanOrEqual(spent, 1_000_000 + 1,
                                 "six Shop-now presses in one week spent \(spent) against a 1,000,000 weekly budget")
    }

    /// BUG (CatalogGrowth.swift `progressLoans` + SimulationEngine `ageCatalog`): a title loaned out for W weeks
    /// loses W weeks of rights while away, then is appended to the catalog and aged AGAIN in the same
    /// `advanceWeek` (progressLoans runs before ageCatalog), so it loses W+1 weeks (and ages W+1 weeks).
    /// EXPECTED TO FAIL until the returning title skips that week's aging.
    func testBug_licensedOutTitleLosesAnExtraWeekOfRights() throws {
        var s = GameState.newGame(startCountry: "GB", companyName: "Test Co", seed: 21)
        s.eventsEnabled = false
        s.finances.cash = 1e10
        var title = Title(id: 9_000, name: "Loan Test", kind: .series, genre: .drama, language: .english, quality: 70,
                          popularity: 50, ageWeeks: 2, isOriginal: false,
                          license: LicenseTerms(cost: 100_000, years: 5, regions: [], exclusive: false),
                          weeksRemaining: 200, listingWeeksLeft: 0)
        title.paidPrice = 100_000
        title.invested = 100_000
        s.catalog.append(title)
        try s.licenseOut(titleID: 9_000, weeks: 13)
        XCTAssertEqual(s.loanedOut.count, 1)
        for _ in 0..<13 { s = SimulationEngine.advanceWeek(s) }
        guard let back = s.catalog.first(where: { $0.id == 9_000 }) else {
            XCTFail("the title should be back in the catalog after 13 weeks")
            return
        }
        XCTAssertEqual(back.weeksRemaining, 187, "200 weeks of rights minus 13 weeks that passed")
        XCTAssertEqual(back.ageWeeks, 15, "2 weeks old plus 13 weeks that passed")
    }
}
