import XCTest
#if canImport(StreamEmpireCore)
@testable import StreamEmpireCore
#else
@testable import StreamEmpire
#endif

final class SimulationTests: XCTestCase {
    // MARK: Helpers

    private func newState(seed: UInt64 = 42) -> GameState {
        GameState.newGame(startCountry: "IE", companyName: "Test Co", seed: seed)
    }

    private func title(quality: Int = 80, popularity: Int = 70, genre: Genre = .drama,
                       language: Language = .english, age: Int = 0, id: Int = 1000) -> Title {
        Title(id: id, name: "T\(id)", kind: .series, genre: genre, language: language,
              quality: quality, popularity: popularity, ageWeeks: age, isOriginal: true,
              license: nil, weeksRemaining: nil, listingWeeksLeft: 0)
    }

    private func ireland() -> Country { CountryData.country("IE")! }

    // MARK: RNG & determinism

    func testSeededRNGIsReproducible() {
        var a = SeededRNG(seed: 7), b = SeededRNG(seed: 7), c = SeededRNG(seed: 8)
        let xs = (0..<10).map { _ in a.next() }
        let ys = (0..<10).map { _ in b.next() }
        let zs = (0..<10).map { _ in c.next() }
        XCTAssertEqual(xs, ys)
        XCTAssertNotEqual(xs, zs)
    }

    func testAdvanceWeekIsDeterministic() {
        var a = newState(), b = newState()
        for _ in 0..<20 {
            a = SimulationEngine.advanceWeek(a)
            b = SimulationEngine.advanceWeek(b)
        }
        XCTAssertEqual(a, b)
    }

    func testDifferentSeedsGiveDifferentLicenseMarkets() {
        XCTAssertNotEqual(newState(seed: 1).licenseMarket.map(\.name),
                          newState(seed: 2).licenseMarket.map(\.name))
    }

    // MARK: New game

    func testNewGameStartConditions() {
        let s = newState()
        XCTAssertEqual(s.finances.cash, 25_000_000)
        XCTAssertTrue(s.catalog.isEmpty)
        XCTAssertEqual(s.liveMarketCodes, ["IE"])
        XCTAssertEqual(s.licenseMarket.count, GameState.targetListings)
        XCTAssertEqual(s.rivals.count, 5)
        XCTAssertEqual(s.week, 1)
    }

    // MARK: Content math

    func testFreshnessDecaysWithAge() {
        XCTAssertEqual(Formulas.freshness(ageWeeks: 0), 1.0, accuracy: 1e-9)
        XCTAssertLessThan(Formulas.freshness(ageWeeks: 104), Formulas.freshness(ageWeeks: 52))
        XCTAssertGreaterThanOrEqual(Formulas.freshness(ageWeeks: 5000), 0.25)
    }

    func testReleaseBoostOnlyForNewTitles() {
        XCTAssertGreaterThan(Formulas.releaseBoost(ageWeeks: 0), 1.0)
        XCTAssertEqual(Formulas.releaseBoost(ageWeeks: 10), 1.0)
    }

    func testAppealRisesWithQualityAndLanguageMatch() {
        let c = ireland()
        XCTAssertGreaterThan(Formulas.titleAppeal(title(quality: 90), in: c),
                             Formulas.titleAppeal(title(quality: 40), in: c))
        XCTAssertGreaterThan(Formulas.titleAppeal(title(language: .english), in: c),
                             Formulas.titleAppeal(title(language: .korean), in: c))
    }

    func testCatalogAppealHasDiminishingReturns() {
        let c = ireland()
        let one = Formulas.catalogAppeal([title(id: 1)], in: c)
        let ten = Formulas.catalogAppeal((0..<10).map { title(id: $0) }, in: c)
        let twenty = Formulas.catalogAppeal((0..<20).map { title(id: $0) }, in: c)
        XCTAssertGreaterThan(ten, one)
        XCTAssertGreaterThan(twenty, ten)
        XCTAssertLessThan(twenty, 1.0)
        XCTAssertLessThan(twenty - ten, ten - one)
        XCTAssertEqual(Formulas.catalogAppeal([], in: c), 0, accuracy: 1e-12)
    }

    func testLicenseCostScalesWithQualityAndDuration() {
        func cost(_ q: Int, _ years: Int) -> Double {
            Formulas.licenseCost(kind: .movie, quality: q, popularity: 50, years: years, ageWeeks: 0, exclusive: false)
        }
        XCTAssertGreaterThan(cost(90, 2), cost(40, 2))
        XCTAssertGreaterThan(cost(60, 5), cost(60, 1))
        XCTAssertGreaterThan(Formulas.licenseCost(kind: .movie, quality: 60, popularity: 50, years: 2, ageWeeks: 0, exclusive: true),
                             cost(60, 2))
    }

    // MARK: Pricing & subscriber math

    func testPriceFactorDropsAsPriceRises() {
        XCTAssertEqual(Formulas.priceFactor(price: 10, tolerance: 10), 1.0, accuracy: 1e-9)
        XCTAssertGreaterThan(Formulas.priceFactor(price: 5, tolerance: 10), 1.0)
        XCTAssertLessThan(Formulas.priceFactor(price: 20, tolerance: 10), 0.5)
    }

    func testTierSplitSumsToOne() {
        let split = Formulas.tierSplit(prices: TierSet(ad: 5, standard: 11, premium: 16))
        XCTAssertEqual(split.total, 1.0, accuracy: 1e-9)
        XCTAssertGreaterThan(split.ad, split.premium)
    }

    func testGrossAddsRespondToEachDriver() {
        func adds(appeal: Double = 0.5, awareness: Double = 0.5, marketing: Double = 1, rival: Double = 1) -> Double {
            Formulas.grossAdds(headroom: 100_000, appeal: appeal, priceFactor: 1, awareness: awareness,
                               marketingFactor: marketing, wordOfMouth: 1, rivalFactor: rival, reach: 1, noise: 1)
        }
        XCTAssertGreaterThan(adds(appeal: 0.8), adds(appeal: 0.4))
        XCTAssertGreaterThan(adds(awareness: 0.9), adds(awareness: 0.1))
        XCTAssertGreaterThan(adds(marketing: 1.5), adds(marketing: 1.0))
        XCTAssertGreaterThan(adds(rival: 1.0), adds(rival: 0.5))
        XCTAssertEqual(adds(appeal: 0), 0, accuracy: 1e-12)
    }

    func testChurnRisesWithWeakContentHighPriceAndBadService() {
        let base = Formulas.churnRate(appeal: 0.5, price: 10, tolerance: 10, serviceQuality: 1)
        XCTAssertGreaterThan(Formulas.churnRate(appeal: 0.1, price: 10, tolerance: 10, serviceQuality: 1), base)
        XCTAssertGreaterThan(Formulas.churnRate(appeal: 0.5, price: 20, tolerance: 10, serviceQuality: 1), base)
        XCTAssertGreaterThan(Formulas.churnRate(appeal: 0.5, price: 10, tolerance: 10, serviceQuality: 0.5), base)
        XCTAssertGreaterThan(Formulas.churnRate(appeal: 0.5, price: 10, tolerance: 10, serviceQuality: 1, rivalHeat: 1), base)
    }

    func testAwarenessGrowsWithMarketingAndStaysInRange() {
        let none = Formulas.nextAwareness(awareness: 0.1, spend: 0, households: 1.5, penetration: 0)
        let spend = Formulas.nextAwareness(awareness: 0.1, spend: 50_000, households: 1.5, penetration: 0)
        XCTAssertLessThan(none, 0.1)
        XCTAssertGreaterThan(spend, 0.1)
        XCTAssertLessThanOrEqual(Formulas.nextAwareness(awareness: 1, spend: 1e9, households: 1, penetration: 1), 1)
    }

    // MARK: Engine: subscribers

    func testEmptyCatalogGainsNoSubscribers() {
        var s = newState()
        for _ in 0..<5 { s = SimulationEngine.advanceWeek(s) }
        XCTAssertEqual(s.totalSubscribers, 0, accuracy: 1e-9)
    }

    func testCatalogAndMarketingGrowSubscribers() throws {
        var s = newState()
        for t in s.licenseMarket.prefix(6) { s.finances.cash += 50_000_000; try s.buyLicense(titleID: t.id) }
        try s.setMarketing(code: "IE", weeklyBudget: 50_000)
        for _ in 0..<12 { s = SimulationEngine.advanceWeek(s) }
        XCTAssertGreaterThan(s.totalSubscribers, 1_000)
        let report = try XCTUnwrap(s.lastReport)
        XCTAssertGreaterThan(report.newSubs, 0)
    }

    func testSubscribersNeverExceedCeiling() {
        var s = newState()
        s.markets["IE"]?.subs = TierSet(ad: 400_000, standard: 300_000, premium: 100_000)
        s.catalog = (0..<40).map { title(id: $0) }
        for _ in 0..<30 { s = SimulationEngine.advanceWeek(s) }
        XCTAssertLessThanOrEqual(s.totalSubscribers, ireland().subscriberCeiling)
    }

    func testChurnWithEmptyCatalogShrinksBase() {
        var s = newState()
        s.markets["IE"]?.subs = TierSet(ad: 10_000, standard: 5_000, premium: 1_000)
        s = SimulationEngine.advanceWeek(s)
        let report = s.lastReport!
        XCTAssertEqual(report.newSubs, 0, accuracy: 1e-9)
        XCTAssertGreaterThan(report.churned, 0)
        XCTAssertLessThan(s.totalSubscribers, 16_000)
    }

    // MARK: Engine: money

    func testRevenueMatchesSubscribersAndPrices() {
        var s = newState()
        s.markets["IE"]?.subs = TierSet(ad: 0, standard: 1_000, premium: 0)
        s.markets["IE"]?.prices = TierSet(ad: 5, standard: 10, premium: 15)
        s = SimulationEngine.advanceWeek(s)
        let fin = s.lastReport!.financials
        XCTAssertEqual(fin.subscriptionRevenue, 1_000 * 10 * 12 / 52, accuracy: 0.01)
        XCTAssertEqual(fin.adRevenue, 0, accuracy: 1e-9)
    }

    func testAdRevenueUsesAdTierAndMarketStrength() {
        var s = newState()
        s.markets["IE"]?.subs = TierSet(ad: 10_000, standard: 0, premium: 0)
        s.markets["IE"]?.prices = TierSet(ad: 0, standard: 10, premium: 15)
        s = SimulationEngine.advanceWeek(s)
        let expected = 10_000 * 4.0 * ireland().adStrength / (52.0 / 12.0)
        XCTAssertEqual(s.lastReport!.financials.adRevenue, expected, accuracy: 0.01)
    }

    func testCostsAreComputedFromSubsStaffMarketingAndOperations() {
        var s = newState()
        s.markets["IE"]?.subs = TierSet(ad: 0, standard: 2_000, premium: 0)
        s.markets["IE"]?.marketingBudget = 12_345
        s = SimulationEngine.advanceWeek(s)
        let fin = s.lastReport!.financials
        XCTAssertEqual(fin.streaming, 2_000 * Formulas.streamingCostPerSubWeek, accuracy: 0.01)
        XCTAssertEqual(fin.staff, Formulas.baseStaffCostPerWeek, accuracy: 0.01)
        XCTAssertEqual(fin.marketing, 12_345, accuracy: 0.01)
        XCTAssertEqual(fin.operations, Formulas.operatingCost(for: ireland()), accuracy: 0.01)
    }

    func testCashChangeEqualsProfitPlusPrepaidSpend() throws {
        var s = newState()
        let id = s.licenseMarket[0].id
        let cost = s.licenseMarket[0].license!.cost
        try s.buyLicense(titleID: id)
        let cashAfterPurchase = s.finances.cash
        XCTAssertEqual(cashAfterPurchase, 25_000_000 - cost, accuracy: 0.01)
        s = SimulationEngine.advanceWeek(s)
        let fin = s.lastReport!.financials
        XCTAssertEqual(fin.licensing, cost, accuracy: 0.01)
        // Licensing was already paid, so only the rest of the week's profit moves cash.
        XCTAssertEqual(s.finances.cash, cashAfterPurchase + fin.profit + fin.licensing, accuracy: 0.01)
        XCTAssertEqual(s.finances.ledger, SpendLedger())
    }

    func testRunwayOnlyWhenLosingMoney() {
        var f = Finances(cash: 1_000_000)
        f.profitHistory = [-100_000, -100_000]
        XCTAssertEqual(f.runwayWeeks ?? 0, 10, accuracy: 1e-9)
        f.profitHistory = [50_000]
        XCTAssertNil(f.runwayWeeks)
    }

    // MARK: Actions

    func testBuyLicenseMovesTitleToCatalog() throws {
        var s = newState()
        let t = s.licenseMarket[0]
        try s.buyLicense(titleID: t.id)
        XCTAssertEqual(s.catalog.count, 1)
        XCTAssertEqual(s.catalog[0].weeksRemaining, t.license!.weeks)
        XCTAssertFalse(s.licenseMarket.contains { $0.id == t.id })
    }

    func testBuyLicenseFailsWithoutFunds() {
        var s = newState()
        s.finances.cash = 10
        XCTAssertThrowsError(try s.buyLicense(titleID: s.licenseMarket[0].id))
        XCTAssertTrue(s.catalog.isEmpty)
    }

    func testLicenseExpiresAndLeavesCatalog() throws {
        var s = newState()
        try s.buyLicense(titleID: s.licenseMarket[0].id)
        s.catalog[0].weeksRemaining = 1
        s = SimulationEngine.advanceWeek(s)
        XCTAssertTrue(s.catalog.isEmpty)
        XCTAssertTrue(s.lastReport!.events.contains { $0.kind == .licenseExpired })
    }

    func testLaunchMarketTakesFourWeeks() throws {
        var s = newState()
        try s.launchMarket(code: "NZ")
        XCTAssertEqual(s.markets["NZ"]?.status, .launching(weeksLeft: 4))
        XCTAssertEqual(s.finances.cash, 25_000_000 - CountryData.country("NZ")!.launchCost, accuracy: 0.01)
        XCTAssertThrowsError(try s.launchMarket(code: "NZ"))
        for _ in 0..<3 { s = SimulationEngine.advanceWeek(s) }
        XCTAssertNotEqual(s.markets["NZ"]?.status, .live)
        s = SimulationEngine.advanceWeek(s)
        XCTAssertEqual(s.markets["NZ"]?.status, .live)
    }

    func testSetPricesRejectsInvalid() {
        var s = newState()
        XCTAssertThrowsError(try s.setPrices(code: "IE", prices: TierSet(ad: -1, standard: 10, premium: 15)))
        XCTAssertNoThrow(try s.setPrices(code: "IE", prices: TierSet(ad: 4, standard: 9, premium: 14)))
    }

    // MARK: Win / lose

    func testEightWeeksInDebtLoses() {
        var s = newState()
        s.finances.cash = -1_000_000
        for _ in 0..<7 { s = SimulationEngine.advanceWeek(s) }
        XCTAssertEqual(s.outcome, .playing)
        s = SimulationEngine.advanceWeek(s)
        XCTAssertEqual(s.outcome, .lost)
    }

    func testClimbingOutOfDebtResetsCounter() {
        var s = newState()
        s.finances.cash = -10
        s.finances.weeksInDebt = 5
        s.finances.cash = 1_000_000
        s = SimulationEngine.advanceWeek(s)
        XCTAssertEqual(s.finances.weeksInDebt, 0)
    }

    func testGameOverStateDoesNotAdvance() {
        var s = newState()
        s.outcome = .lost
        XCTAssertEqual(SimulationEngine.advanceWeek(s), s)
    }

    // MARK: Persistence

    func testSaveLoadRoundTrip() throws {
        var s = newState()
        try s.buyLicense(titleID: s.licenseMarket[0].id)
        for _ in 0..<5 { s = SimulationEngine.advanceWeek(s) }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("se-test-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        try SaveManager.save(s, to: url)
        let loaded = try XCTUnwrap(SaveManager.load(from: url))
        XCTAssertEqual(loaded, s)
        // The loaded game continues identically (RNG state restored).
        XCTAssertEqual(SimulationEngine.advanceWeek(loaded), SimulationEngine.advanceWeek(s))
    }

    func testLoadMissingFileReturnsNil() {
        XCTAssertNil(SaveManager.load(from: FileManager.default.temporaryDirectory.appendingPathComponent("nope-\(UUID().uuidString).json")))
    }

    // MARK: Leaderboard

    func testLeaderboardRanksPlayerLastAtStart() {
        let s = newState()
        XCTAssertEqual(s.rank, 6)
        XCTAssertEqual(s.leaderboard.count, 6)
    }
}
