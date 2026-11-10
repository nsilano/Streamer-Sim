import XCTest
#if canImport(StreamEmpireCore)
@testable import StreamEmpireCore
#else
@testable import StreamEmpire
#endif

final class Phase23Tests: XCTestCase {
    private func newState() -> GameState {
        var s = GameState.newGame(startCountry: "IE", companyName: "Test Co", seed: 123)
        s.eventsEnabled = false
        s.finances.cash = 1e9
        return s
    }

    private func listing(id: Int = 500, sought: Bool = false) -> Title {
        Title(id: id, name: "Listing \(id)", kind: .series, genre: .drama, language: .english, quality: 70, popularity: 60,
              ageWeeks: 20, isOriginal: false, license: LicenseTerms(cost: 1_000_000, years: 2, regions: [], exclusive: false),
              weeksRemaining: nil, listingWeeksLeft: 8, sought: sought)
    }

    // MARK: Negotiation

    func testAskingPriceFollowsTheTerms() {
        let s = newState()
        let t = listing()
        XCTAssertEqual(s.askingPrice(t, years: 2, exclusive: false), s.licensePrice(t), accuracy: 1)
        XCTAssertGreaterThan(s.askingPrice(t, years: 4, exclusive: false), s.licensePrice(t))
        XCTAssertGreaterThan(s.askingPrice(t, years: 2, exclusive: true), s.licensePrice(t))
    }

    func testLowballsAreRiskierThanFairOffers() {
        let s = newState()
        let t = listing()
        XCTAssertGreaterThan(s.acceptChance(t, offer: 0.95), s.acceptChance(t, offer: 0.6))
        XCTAssertLessThan(s.acceptChance(listing(sought: true), offer: 0.9), s.acceptChance(t, offer: 0.9))
    }

    func testAcceptedOffersBuyOnYourTerms() throws {
        var accepted = false
        for seed in 1...30 where !accepted {
            var s = newState()
            s.rng = SeededRNG(seed: UInt64(seed))
            s.licenseMarket = [listing()]
            let price = s.askingPrice(s.licenseMarket[0], years: 4, exclusive: true) * 0.95
            let cash = s.finances.cash
            if try s.negotiate(titleID: 500, offer: 0.95, years: 4, exclusive: true) {
                accepted = true
                let t = s.catalog.first { $0.id == 500 }!
                XCTAssertEqual(t.license?.years, 4)
                XCTAssertEqual(t.license?.exclusive, true)
                XCTAssertEqual(t.weeksRemaining, 208)
                XCTAssertEqual(s.finances.cash, cash - price, accuracy: 0.01)
                XCTAssertEqual(s.finances.ledger.licensing, price, accuracy: 0.01)
            }
        }
        XCTAssertTrue(accepted)
    }

    func testRejectionBlocksTalksAndRaisesThePrice() throws {
        var rejected = false
        for seed in 1...30 where !rejected {
            var s = newState()
            s.rng = SeededRNG(seed: UInt64(seed))
            s.licenseMarket = [listing()]
            let before = s.licenseMarket[0].license!.cost
            if try !s.negotiate(titleID: 500, offer: 0.5, years: 2, exclusive: false) {
                rejected = true
                XCTAssertEqual(s.licenseMarket[0].license!.cost, before * 1.05, accuracy: 0.01)
                XCTAssertThrowsError(try s.negotiate(titleID: 500, offer: 1.0, years: 2, exclusive: false))
                XCTAssertTrue(s.catalog.isEmpty)
            }
        }
        XCTAssertTrue(rejected)
    }

    // MARK: Output deals

    func testOutputDealsDeliverTitlesAndChargeFees() throws {
        var s = newState()
        try s.signOutputDeal(genre: .anime)
        try s.signOutputDeal(genre: .anime)
        XCTAssertThrowsError(try s.signOutputDeal(genre: .anime), "two at most")
        XCTAssertEqual(s.outputDeals.count, GameState.maxOutputDeals)
        s.outputDeals.removeLast()
        let fee = s.outputDeals[0].weeklyFee
        for _ in 0..<GameState.outputDeliveryEvery { s = SimulationEngine.advanceWeek(s) }
        let delivered = s.catalog.filter { $0.genre == .anime && $0.license?.exclusive == true }
        XCTAssertEqual(delivered.count, 1)
        XCTAssertTrue((155...156).contains(delivered[0].weeksRemaining ?? 0), "a 3-year license (it ages in the week it arrives)")
        XCTAssertGreaterThanOrEqual(s.lastReport!.financials.licensing, fee - 0.01)
    }

    func testEndingAnOutputDealEarlyCostsAPenalty() throws {
        var s = newState()
        try s.signOutputDeal(genre: .drama)
        let id = s.outputDeals[0].id
        let cash = s.finances.cash
        let penalty = s.outputDeals[0].weeklyFee * 8
        try s.cancelOutputDeal(id: id)
        XCTAssertTrue(s.outputDeals.isEmpty)
        XCTAssertEqual(s.finances.cash, cash - penalty, accuracy: 0.01)
    }

    // MARK: Markets, productions, titles

    func testExitingAMarketWipesItsSubscribers() throws {
        var s = newState()
        s.markets["GB"]?.status = .live
        s.markets["GB"]?.subs = TierSet(ad: 0, standard: 50_000, premium: 0)
        try s.exitMarket(code: "GB")
        XCTAssertEqual(s.markets["GB"]?.status, .notLaunched)
        XCTAssertEqual(s.markets["GB"]?.subs.total, 0)
        XCTAssertThrowsError(try s.exitMarket(code: "IE"), "can't leave your only live market")
        XCTAssertThrowsError(try s.exitMarket(code: "US"), "never launched")
    }

    func testCancellingAProductionStopsItsCosts() throws {
        var s = newState()
        try s.commissionOriginal(kind: .series, genre: .drama, language: .english, budget: 10_000_000, weeks: 20)
        try s.cancelProduction(id: s.projects[0].id)
        XCTAssertTrue(s.projects.isEmpty)
        let fin = SimulationEngine.advanceWeek(s).lastReport!.financials
        XCTAssertEqual(fin.originals, 0, accuracy: 0.01)
    }

    func testPullingAndWritingOffTitles() throws {
        var s = newState()
        var licensed = listing(id: 1); licensed.weeksRemaining = 50
        var original = listing(id: 2); original.isOriginal = true; original.license = nil; original.invested = 10_000_000
        s.catalog = [licensed, original]
        let cash = s.finances.cash
        try s.removeTitle(titleID: 1)
        XCTAssertEqual(s.finances.cash, cash)
        try s.removeTitle(titleID: 2)
        XCTAssertEqual(s.finances.cash, cash + 1_000_000, accuracy: 0.01)
        XCTAssertTrue(s.catalog.isEmpty)
        XCTAssertThrowsError(try s.removeTitle(titleID: 2))
    }

    // MARK: Corporate

    func testRenameCompany() throws {
        var s = newState()
        try s.renameCompany("  Flixie  ")
        XCTAssertEqual(s.companyName, "Flixie")
        XCTAssertThrowsError(try s.renameCompany("x"))
    }

    func testBuybacksAndDividendsNeedAnIPO() throws {
        var s = newState()
        XCTAssertThrowsError(try s.buyBackShares(percent: 0.05))
        XCTAssertThrowsError(try s.payDividend())
        s.equity.ipoDone = true
        s.equity.ownership = 0.6
        try s.buyBackShares(percent: 0.05)
        XCTAssertEqual(s.equity.ownership, 0.65, accuracy: 1e-9)
        let mood = s.earningsSentiment
        try s.payDividend()
        XCTAssertGreaterThan(s.earningsSentiment, mood)
        XCTAssertThrowsError(try s.payDividend(), "once a quarter")
    }

    func testToolkitStateRoundTrips() throws {
        var s = newState()
        try s.signOutputDeal(genre: .comedy)
        s.licenseMarket[0].talksBlockedUntil = 9
        s = SimulationEngine.advanceWeek(s)
        let loaded = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(s))
        XCTAssertEqual(loaded, s)
    }
}
