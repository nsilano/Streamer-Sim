import XCTest
#if canImport(StreamEmpireCore)
@testable import StreamEmpireCore
#else
@testable import StreamEmpire
#endif

final class Phase16Tests: XCTestCase {
    private func newState() -> GameState {
        var s = GameState.newGame(startCountry: "IE", companyName: "Test Co", seed: 7)
        s.eventsEnabled = false
        s.finances.cash = 1e9
        return s
    }

    private func owned(id: Int = 1, left: Int, paid: Double = 1_000_000, years: Int = 2, popularity: Int = 60,
                       sought: Bool = false, quality: Int = 70) -> Title {
        Title(id: id, name: "Owned \(id)", kind: .series, genre: .drama, language: .english, quality: quality,
              popularity: popularity, ageWeeks: 10, isOriginal: false,
              license: LicenseTerms(cost: paid, years: years, regions: [], exclusive: false),
              weeksRemaining: left, listingWeeksLeft: 0, sought: sought, paidPrice: paid, popularityAtPurchase: 60)
    }

    func testRenewalIsCheaperThanTheOriginalDeal() {
        var s = newState()
        s.catalog = [owned(left: 10)]
        let renew = s.renewalPrice(s.catalog[0], years: 2)
        XCTAssertLessThan(renew, 1_000_000)
        XCTAssertGreaterThan(renew, 0)
    }

    func testPopularityJumpAndFameRaiseTheRenewalPrice() {
        var s = newState()
        s.catalog = [owned(id: 1, left: 10), owned(id: 2, left: 10, popularity: 90), owned(id: 3, left: 10, sought: true)]
        let base = s.renewalPrice(s.catalog[0], years: 2)
        XCTAssertGreaterThan(s.renewalPrice(s.catalog[1], years: 2), base)
        XCTAssertGreaterThan(s.renewalPrice(s.catalog[2], years: 2), base)
        XCTAssertTrue(s.hasPopularityJump(s.catalog[1]))
        XCTAssertFalse(s.hasPopularityJump(s.catalog[0]))
    }

    func testRenewExtendsAndCharges() throws {
        var s = newState()
        s.catalog = [owned(left: 10)]
        let price = s.renewalPrice(s.catalog[0], years: 3)
        let cash = s.finances.cash
        try s.renewLicense(titleID: 1, years: 3)
        XCTAssertEqual(s.catalog[0].weeksRemaining, 10 + 156)
        XCTAssertEqual(s.finances.cash, cash - price, accuracy: 0.01)
        XCTAssertEqual(s.finances.ledger.licensing, price, accuracy: 0.01)
        XCTAssertEqual(s.catalog[0].paidPrice, price, accuracy: 0.01)
    }

    func testRenewRules() {
        var s = newState()
        s.catalog = [owned(left: 100)]
        XCTAssertThrowsError(try s.renewLicense(titleID: 1, years: 2), "too early")
        s.catalog[0].weeksRemaining = 10
        XCTAssertThrowsError(try s.renewLicense(titleID: 1, years: 9))
        XCTAssertThrowsError(try s.renewLicense(titleID: 99, years: 2))
        s.finances.cash = 10
        XCTAssertThrowsError(try s.renewLicense(titleID: 1, years: 2))
    }

    func testExpiryWarningsAndAdvice() {
        var s = newState()
        s.catalog = [owned(left: 13)]
        s = SimulationEngine.advanceWeek(s)
        XCTAssertTrue(s.news.contains { $0.headline.contains("expires in 12 weeks") })
        XCTAssertTrue(s.advice().contains { $0.id == "expiring" })
        XCTAssertEqual(s.expiringTitles.count, 1)
        XCTAssertTrue(s.lastReport!.events.contains { $0.headline == "License expiring in 12 weeks" },
                      "the weekly report warns at 12 weeks too")
    }

    func testBoughtTitlesRememberWhatYouPaid() throws {
        var s = newState()
        let id = s.licenseMarket[0].id
        let price = s.licensePrice(s.licenseMarket[0])
        try s.buyLicense(titleID: id)
        let bought = s.catalog.first { $0.id == id }!
        XCTAssertEqual(bought.paidPrice, price, accuracy: 0.01)
        XCTAssertEqual(bought.popularityAtPurchase, bought.popularity)
    }

    func testSoughtAfterTitlesExistAndCostMore() {
        var rng = SeededRNG(seed: 99)
        var sought: [Title] = [], normal: [Title] = []
        for i in 0..<1_500 {
            let t = TitleGenerator.generate(id: i, rng: &rng)
            if t.sought { sought.append(t) } else { normal.append(t) }
        }
        XCTAssertFalse(sought.isEmpty)
        XCTAssertLessThan(Double(sought.count) / 1_500, 0.35, "famous titles stay scarce")
        XCTAssertTrue(sought.allSatisfy { $0.quality >= 70 && $0.popularity >= 70 })
        let avg = { (ts: [Title]) in ts.map { $0.license!.cost }.reduce(0, +) / Double(ts.count) }
        XCTAssertGreaterThan(avg(sought), avg(normal) * 1.5)
    }

    func testCuratorAutoRenewsWhenPriceIsLow() throws {
        var s = newState()
        try s.hireCurator()
        s.catalog = [owned(left: 6)]
        var c = s.curator!
        c.autoRenew = true; c.renewMaxPrice = 5_000_000; c.renewYears = 2; c.cashReserve = 0
        s.curator = c
        _ = s.curatorShop()
        XCTAssertGreaterThan(s.catalog[0].weeksRemaining ?? 0, 100)
    }

    func testCuratorSkipsPriceyOrDisabledRenewals() throws {
        var s = newState()
        try s.hireCurator()
        s.catalog = [owned(left: 6)]
        var c = s.curator!
        c.renewMaxPrice = 1_000
        s.curator = c
        _ = s.curatorShop()
        XCTAssertEqual(s.catalog[0].weeksRemaining, 6)
        c.renewMaxPrice = 5_000_000; c.autoRenew = false
        s.curator = c
        _ = s.curatorShop()
        XCTAssertEqual(s.catalog[0].weeksRemaining, 6)
    }

    func testSurvivesSaves() throws {
        var s = newState()
        s.catalog = [owned(left: 10, sought: true)]
        let loaded = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(s))
        XCTAssertEqual(loaded, s)
    }
}
