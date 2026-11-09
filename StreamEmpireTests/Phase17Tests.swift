import XCTest
#if canImport(StreamEmpireCore)
@testable import StreamEmpireCore
#else
@testable import StreamEmpire
#endif

final class Phase17Tests: XCTestCase {
    private func newState() -> GameState {
        var s = GameState.newGame(startCountry: "IE", companyName: "Test Co", seed: 11)
        s.eventsEnabled = false
        s.finances.cash = 1e9
        s.markets["IE"]?.subs = TierSet(ad: 0, standard: 50_000, premium: 0)
        return s
    }

    private func license(id: Int, left: Int? = 100, quality: Int = 70) -> Title {
        Title(id: id, name: "T\(id)", kind: .series, genre: .drama, language: .english, quality: quality, popularity: 60,
              ageWeeks: 20, isOriginal: false, license: LicenseTerms(cost: 1_000_000, years: 2, regions: [], exclusive: false),
              weeksRemaining: left, listingWeeksLeft: 0, paidPrice: 1_000_000, invested: 1_000_000, popularityAtPurchase: 60)
    }

    func testBuyoutMakesRightsPermanent() throws {
        var s = newState()
        s.catalog = [license(id: 1)]
        let price = s.buyoutPrice(s.catalog[0])
        XCTAssertGreaterThan(price, 1_000_000)
        let cash = s.finances.cash
        try s.buyOutRights(titleID: 1)
        XCTAssertNil(s.catalog[0].weeksRemaining)
        XCTAssertEqual(s.finances.cash, cash - price, accuracy: 0.01)
        XCTAssertEqual(s.catalog[0].invested, 1_000_000 + price, accuracy: 0.01)
        XCTAssertThrowsError(try s.buyOutRights(titleID: 1))
        for _ in 0..<200 { s = SimulationEngine.advanceWeek(s) }
        XCTAssertEqual(s.catalog.count, 1, "never expires")
        XCTAssertTrue(s.expiringTitles.isEmpty)
    }

    func testLicensingOutPaysAndReturnsTheTitle() throws {
        var s = newState()
        s.catalog = [license(id: 1, left: nil)]
        let fee = s.sublicenseFee(s.catalog[0], weeks: 13)
        XCTAssertGreaterThan(fee, 0)
        XCTAssertGreaterThan(s.sublicenseFee(s.catalog[0], weeks: 26), fee)
        let cash = s.finances.cash
        try s.licenseOut(titleID: 1, weeks: 13)
        XCTAssertTrue(s.catalog.isEmpty)
        XCTAssertEqual(s.finances.cash, cash + fee, accuracy: 0.01)
        XCTAssertThrowsError(try s.licenseOut(titleID: 1, weeks: 13))

        s = SimulationEngine.advanceWeek(s)
        XCTAssertEqual(s.lastReport!.financials.licenseOutRevenue, fee, accuracy: 0.01)
        XCTAssertGreaterThanOrEqual(s.lastReport!.financials.revenue, fee)
        for _ in 0..<13 { s = SimulationEngine.advanceWeek(s) }
        XCTAssertEqual(s.catalog.count, 1, "comes back")
        XCTAssertTrue(s.loanedOut.isEmpty)
    }

    func testCashIsNotDoubleCountedForLicenseFees() throws {
        var a = newState(), b = newState()
        a.catalog = [license(id: 1, left: nil)]
        b.catalog = a.catalog
        try a.licenseOut(titleID: 1, weeks: 26)
        let fee = a.sublicenseFee(b.catalog[0], weeks: 26)
        a = SimulationEngine.advanceWeek(a)
        b = SimulationEngine.advanceWeek(b)
        // a loses the title's appeal for a week, so only check the fee isn't paid twice.
        XCTAssertLessThan(a.finances.cash, b.finances.cash + fee * 1.5)
    }

    func testTermLicensesCannotBeLoanedPastTheirRights() {
        var s = newState()
        s.catalog = [license(id: 1, left: 20)]
        XCTAssertThrowsError(try s.licenseOut(titleID: 1, weeks: 26))
        XCTAssertNoThrow(try s.licenseOut(titleID: 1, weeks: 13))
    }

    func testTitleStatsAccumulate() {
        var s = newState()
        s.catalog = [license(id: 1, left: nil), license(id: 2, left: nil, quality: 40)]
        for _ in 0..<5 { s = SimulationEngine.advanceWeek(s) }
        let a = s.stats(for: s.catalog[0]), b = s.stats(for: s.catalog[1])
        XCTAssertEqual(a.weeksLive, 5)
        XCTAssertGreaterThan(a.weeklyViewers, 0)
        XCTAssertGreaterThan(a.lifetimeRevenue, 0)
        XCTAssertGreaterThan(a.totalViews, a.weeklyViewers)
        XCTAssertGreaterThan(a.weeklyViewers, b.weeklyViewers, "better title gets more viewers")
        XCTAssertEqual(a.topMarket, "IE")
        // Revenue credited to titles adds up to the week's revenue.
        let credited = a.weeklyRevenue + b.weeklyRevenue
        XCTAssertEqual(credited, s.lastReport!.financials.revenue, accuracy: max(1, credited * 0.001))
    }

    func testStatsDropWhenALicenseExpires() {
        var s = newState()
        s.catalog = [license(id: 1, left: 2)]
        for _ in 0..<4 { s = SimulationEngine.advanceWeek(s) }
        XCTAssertNil(s.titleStats[1])
    }

    func testRoundTrips() throws {
        var s = newState()
        s.catalog = [license(id: 1, left: nil), license(id: 2, left: nil)]
        for _ in 0..<3 { s = SimulationEngine.advanceWeek(s) }
        try s.licenseOut(titleID: 2, weeks: 13)
        let loaded = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(s))
        XCTAssertEqual(loaded, s)
    }
}
