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

    func testOneStopCoversAWholeBatchAtFourWeeksLeft() {
        var s = newState()
        s.expiryAlerts = .stop
        s.catalog = [owned(id: 1, left: 13), owned(id: 2, left: 5), owned(id: 3, left: 9), owned(id: 4, left: 30)]
        s = SimulationEngine.advanceWeek(s)
        XCTAssertEqual(Set(s.newlyExpiring.map(\.id)), [2, 3], "title 2 hit 4 weeks; title 3 (8 weeks) joins the same stop")
        s.lastExpiryStopWeek = s.week
        for _ in 0..<3 {
            s = SimulationEngine.advanceWeek(s)
            XCTAssertTrue(s.newlyExpiring.isEmpty, "no second stop within 4 weeks")
        }
    }

    func testShowAndIgnoreNeverStopTheSim() {
        for mode in [ExpiryAlerts.show, .ignore] {
            var s = newState()
            s.expiryAlerts = mode
            s.catalog = [owned(id: 1, left: 5)]
            s = SimulationEngine.advanceWeek(s)
            XCTAssertTrue(s.newlyExpiring.isEmpty, "\(mode)")
        }
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

    func testAutoRenewKeepsReasonablyPricedTitlesWithoutStoppingYou() {
        var s = newState()
        s.renewalMode = .standard
        var kept = owned(id: 1, left: 14)
        kept.license?.exclusive = true          // rivals can't recall exclusives, so only renewal matters here
        s.catalog = [kept]
        for _ in 0..<5 { s = SimulationEngine.advanceWeek(s) }
        XCTAssertEqual(s.catalog.count, 1)
        XCTAssertGreaterThan(s.catalog.first?.weeksRemaining ?? 0, 100, "renewed before the 12-week warning")
        var off = newState()
        off.catalog = [owned(id: 1, left: 5)]
        for _ in 0..<10 { off = SimulationEngine.advanceWeek(off) }
        XCTAssertTrue(off.catalog.isEmpty, "with auto-renew off, licenses still lapse")
    }

    func testOnlyAbsurdRenewalsReachYou() {
        var s = newState()
        s.renewalMode = .standard
        var hot = owned(id: 2, left: 13)
        hot.popularity = 100            // popularity jumped 40 points since you signed: renewal is far pricier
        hot.weeksRemaining = 5
        s.catalog = [owned(id: 1, left: 5), hot]
        XCTAssertNil(s.renewalBlock(s.catalog[0]))
        XCTAssertNotNil(s.renewalBlock(s.catalog[1]))
        s.expiryAlerts = .stop
        s = SimulationEngine.advanceWeek(s)
        XCTAssertEqual(s.newlyExpiring.map(\.id), [2], "only the absurd one stops the sim")
    }

    func testStylesAreOrderedAndOffBlocksEverything() {
        var s = newState()
        let t = owned(id: 1, left: 10)
        s.catalog = [t]
        s.renewalMode = .off
        XCTAssertNotNil(s.renewalBlock(t))
        XCTAssertLessThan(RenewalMode.careful.maxPriceRatio, RenewalMode.standard.maxPriceRatio)
        XCTAssertLessThan(RenewalMode.standard.maxPriceRatio, RenewalMode.generous.maxPriceRatio)
        XCTAssertLessThan(RenewalMode.careful.cashShare, RenewalMode.generous.cashShare)
    }

    func testAutoRenewSkipsWhatYouCantAfford() {
        var s = newState()
        s.renewalMode = .generous
        s.finances.cash = 10
        s.catalog = [owned(id: 1, left: 2)]
        var events: [GameEvent] = []
        s.autoRenewEverything(events: &events)
        XCTAssertEqual(s.catalog[0].weeksRemaining, 2)
        XCTAssertTrue(events.isEmpty)
        XCTAssertNotNil(s.renewalBlock(s.catalog[0]))
    }
}
