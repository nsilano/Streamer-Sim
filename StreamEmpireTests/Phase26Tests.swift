import XCTest
#if canImport(StreamEmpireCore)
@testable import StreamEmpireCore
#else
@testable import StreamEmpire
#endif

final class Phase26Tests: XCTestCase {
    private func newState() -> GameState {
        var s = GameState.newGame(startCountry: "IE", companyName: "Test Co", seed: 8)
        s.eventsEnabled = false
        s.finances.cash = 1e9
        return s
    }

    private func owned(id: Int, left: Int, paid: Double = 1_000_000) -> Title {
        Title(id: id, name: "Owned \(id)", kind: .series, genre: .drama, language: .english, quality: 70,
              popularity: 60, ageWeeks: 10, isOriginal: false,
              license: LicenseTerms(cost: paid, years: 2, regions: [], exclusive: false),
              weeksRemaining: left, listingWeeksLeft: 0, paidPrice: paid, popularityAtPurchase: 60)
    }

    func testTitlesCrossingTheWarningLinesAreFlagged() {
        var s = newState()
        s.catalog = [owned(id: 1, left: 13), owned(id: 2, left: 5), owned(id: 3, left: 30)]
        s = SimulationEngine.advanceWeek(s)
        XCTAssertEqual(Set(s.newlyExpiring.map(\.id)), [1, 2])
        s = SimulationEngine.advanceWeek(s)
        XCTAssertTrue(s.newlyExpiring.isEmpty, "each line triggers once")
    }

    func testRenewAllKeepsEverythingYouCanAfford() throws {
        var s = newState()
        s.catalog = [owned(id: 1, left: 10), owned(id: 2, left: 6)]
        let total = s.renewAllPrice(years: 2)
        let cash = s.finances.cash
        XCTAssertEqual(try s.renewAll(years: 2), 2)
        XCTAssertEqual(s.finances.cash, cash - total, accuracy: 0.01)
        XCTAssertTrue(s.expiringTitles.isEmpty)
        XCTAssertThrowsError(try s.renewAll(years: 2), "nothing left to renew")
    }

    func testRenewAllWithLimitedCashRenewsTheCheapestFirst() throws {
        var s = newState()
        s.catalog = [owned(id: 1, left: 10, paid: 4_000_000), owned(id: 2, left: 6, paid: 500_000)]
        s.finances.cash = s.renewalPrice(s.catalog[1], years: 2) + 1
        XCTAssertEqual(try s.renewAll(years: 2), 1)
        XCTAssertGreaterThan(s.catalog.first { $0.id == 2 }!.weeksRemaining!, 100)
        XCTAssertEqual(s.catalog.first { $0.id == 1 }!.weeksRemaining, 10)
    }

    func testAlwaysAutoRenewKeepsTheCatalogGrowing() {
        var s = newState()
        s.autoRenewAll = true
        s.catalog = [owned(id: 1, left: 5)]
        for _ in 0..<10 { s = SimulationEngine.advanceWeek(s) }
        XCTAssertEqual(s.catalog.count, 1, "renewed instead of expiring")
        XCTAssertGreaterThan(s.catalog[0].weeksRemaining ?? 0, 90)
        var off = newState()
        off.catalog = [owned(id: 1, left: 5)]
        for _ in 0..<10 { off = SimulationEngine.advanceWeek(off) }
        XCTAssertTrue(off.catalog.isEmpty, "without it, licenses still lapse")
    }

    func testAutoRenewSkipsWhatYouCantAfford() {
        var s = newState()
        s.autoRenewAll = true
        s.finances.cash = 10
        s.catalog = [owned(id: 1, left: 2)]
        var events: [GameEvent] = []
        s.autoRenewEverything(events: &events)
        XCTAssertEqual(s.catalog[0].weeksRemaining, 2)
        XCTAssertTrue(events.isEmpty)
    }
}
