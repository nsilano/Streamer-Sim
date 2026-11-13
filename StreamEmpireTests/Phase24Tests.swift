import XCTest
#if canImport(StreamEmpireCore)
@testable import StreamEmpireCore
#else
@testable import StreamEmpire
#endif

final class Phase24Tests: XCTestCase {
    private func newState() -> GameState {
        var s = GameState.newGame(startCountry: "GB", companyName: "Test Co", seed: 55)
        s.eventsEnabled = false
        s.finances.cash = 1e10
        s.markets["GB"]?.subs = TierSet(ad: 0, standard: 1_000_000, premium: 0)
        s.markets["GB"]?.awareness = 0.6
        return s
    }

    private func catalog(quality: Int, count: Int) -> [Title] {
        (0..<count).map {
            Title(id: 9_000 + $0, name: "C\($0)", kind: .series, genre: .drama, language: .english, quality: quality,
                  popularity: quality, ageWeeks: 2, isOriginal: true, license: nil, weeksRemaining: nil, listingWeeksLeft: 0)
        }
    }

    func testScoreRewardsCatalogPriceAndService() {
        let base = Formulas.switchScore(yourAppeal: 0.7, rivalStrength: 70, yourPrice: 10, rivalPrice: 10, service: 1)
        XCTAssertEqual(base, 0, accuracy: 1e-9)
        XCTAssertGreaterThan(Formulas.switchScore(yourAppeal: 0.9, rivalStrength: 70, yourPrice: 10, rivalPrice: 10, service: 1), 0)
        XCTAssertGreaterThan(Formulas.switchScore(yourAppeal: 0.7, rivalStrength: 70, yourPrice: 8, rivalPrice: 10, service: 1), 0)
        XCTAssertLessThan(Formulas.switchScore(yourAppeal: 0.7, rivalStrength: 70, yourPrice: 10, rivalPrice: 10, service: 0.8), 0)
    }

    func testRatesAreCappedAndNeedAwareness() {
        XCTAssertEqual(Formulas.switchRate(score: 5, awareness: 1), Formulas.maxSwitchInRate, accuracy: 1e-12)
        XCTAssertEqual(Formulas.switchRate(score: -5, awareness: 1), -Formulas.maxSwitchInRate, accuracy: 1e-12)
        XCTAssertLessThan(Formulas.switchRate(score: 0.1, awareness: 0), Formulas.switchRate(score: 0.1, awareness: 0.8))
    }

    func testAStrongCatalogWinsRivalCustomers() {
        var s = newState()
        s.catalog = catalog(quality: 98, count: 400)
        let rivalsBefore = s.rivals.reduce(0.0) { $0 + ($1.subs["GB"] ?? 0) }
        let country = CountryData.country("GB")!
        let appeal = Formulas.catalogAppeal(s.catalog, in: country)
        let flow = Switching.apply(&s, country: country, appeal: appeal, service: 1)
        XCTAssertGreaterThan(flow.gained, 0)
        let rivalsAfter = s.rivals.reduce(0.0) { $0 + ($1.subs["GB"] ?? 0) }
        XCTAssertEqual(s.markets["GB"]!.subs.total, 1_000_000 + flow.gained - flow.lost, accuracy: 1)
        XCTAssertEqual(rivalsAfter, rivalsBefore - flow.gained + flow.lost, accuracy: 1, "customers move, they don't vanish")
    }

    func testAWeakCatalogLosesCustomersButOnlySlowly() {
        var s = newState()
        s.catalog = []
        let country = CountryData.country("GB")!
        let flow = Switching.apply(&s, country: country, appeal: 0, service: 1)
        XCTAssertGreaterThan(flow.lost, 0)
        XCTAssertEqual(flow.gained, 0)
        XCTAssertLessThanOrEqual(flow.lost, 1_000_000 * Formulas.maxSwitchOutRate + 1)
    }

    func testOverAYearRivalsShrinkWhereYouAreBetter() {
        var s = newState()
        s.catalog = catalog(quality: 98, count: 400)
        s.cloudUnits[Region.europe.rawValue] = 500
        let netflux = s.rivals.firstIndex { $0.id == "netflux" }!
        let before = s.rivals[netflux].subs["GB"] ?? 0
        for _ in 0..<52 { s = SimulationEngine.advanceWeek(s) }
        XCTAssertLessThan(s.rivals[netflux].subs["GB"] ?? 0, before, "a much better service takes Netflux customers")
        XCTAssertTrue(s.news.contains { $0.headline.contains("switch from") })
    }

    func testOutlookShowsTheDirection() {
        var s = newState()
        s.catalog = catalog(quality: 98, count: 60)
        let outlook = s.switchOutlook(code: "GB")
        XCTAssertFalse(outlook.isEmpty)
        XCTAssertTrue(outlook.contains { $0.score > 0 })
        XCTAssertTrue(s.switchOutlook(code: "JP").isEmpty, "only live markets")
    }

    func testSwitchingIsDeterministic() {
        var a = newState(), b = newState()
        a.catalog = catalog(quality: 90, count: 40); b.catalog = a.catalog
        for _ in 0..<10 { a = SimulationEngine.advanceWeek(a); b = SimulationEngine.advanceWeek(b) }
        XCTAssertEqual(a, b)
    }
}
