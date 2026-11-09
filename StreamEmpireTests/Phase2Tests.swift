import XCTest
#if canImport(StreamEmpireCore)
@testable import StreamEmpireCore
#else
@testable import StreamEmpire
#endif

final class Phase2Tests: XCTestCase {
    private func newState(seed: UInt64 = 42) -> GameState {
        var s = GameState.newGame(startCountry: "IE", companyName: "Test Co", seed: seed)
        s.eventsEnabled = false
        return s
    }

    private func filler(_ n: Int) -> [Title] {
        (0..<n).map {
            Title(id: 5000 + $0, name: "F\($0)", kind: .movie, genre: .drama, language: .english,
                  quality: 50, popularity: 50, ageWeeks: 0, isOriginal: true,
                  license: nil, weeksRemaining: nil, listingWeeksLeft: 0)
        }
    }

    // MARK: Country table

    func testThirtyCountriesInSixRegions() {
        XCTAssertEqual(CountryData.all.count, 30)
        XCTAssertEqual(Set(CountryData.all.map(\.code)).count, 30)
        for region in Region.allCases {
            XCTAssertFalse(CountryData.all.filter { $0.region == region }.isEmpty, "\(region) is empty")
        }
    }

    func testCountryDataIsSane() {
        for c in CountryData.all {
            XCTAssertGreaterThan(c.households, 0, c.code)
            XCTAssertGreaterThan(c.priceTolerance, 0, c.code)
            XCTAssertGreaterThan(c.launchCost, 0, c.code)
            XCTAssertTrue((0...1).contains(c.adStrength), c.code)
            XCTAssertTrue((0...1).contains(c.regulatoryRisk), c.code)
            XCTAssertEqual(c.genreTaste.count, Genre.allCases.count, c.code)
            XCTAssertLessThan(c.rivalShares.values.reduce(0, +), 0.9, c.code)
        }
    }

    func testStarterPicksAndBigMarketUnlocks() {
        XCTAssertEqual(CountryData.starters.count, 30, "any country can be your starting market")
        for code in ["US", "IN", "JP"] {
            XCTAssertNotNil(CountryData.country(code)?.unlock, code)
        }
        XCTAssertNil(CountryData.country("IE")?.unlock)
    }

    func testTasteOverridesApply() {
        XCTAssertEqual(CountryData.country("JP")!.taste(.anime), 1.9, accuracy: 1e-9)
        XCTAssertGreaterThan(CountryData.country("JP")!.taste(.anime), CountryData.country("IE")!.taste(.anime))
    }

    // MARK: Rivals at start

    func testRivalsStartWithPerCountrySubsOnly() {
        let rivals = RivalData.initialRivals()
        XCTAssertEqual(rivals.count, 5)
        for r in rivals { XCTAssertGreaterThan(r.totalSubs, 0, r.id) }
        let hulo = rivals.first { $0.id == "hulo" }!
        XCTAssertEqual(Set(hulo.subs.keys), ["US", "CA", "JP"])
        let netflux = rivals.first { $0.id == "netflux" }!
        XCTAssertEqual(netflux.countryCount, 30)
    }

    func testNoMarketStartsOverfull() {
        let s = newState()
        for c in CountryData.all {
            let rivalSubs = s.rivals.reduce(0) { $0 + ($1.subs[c.code] ?? 0) }
            XCTAssertLessThan(rivalSubs, c.subscriberCeiling, c.code)
        }
    }

    // MARK: Unlock rules

    func testBigMarketLockedAtStart() {
        var s = newState()
        XCTAssertNotNil(s.launchBlocker(code: "US"))
        XCTAssertThrowsError(try s.launchMarket(code: "US")) { error in
            guard case ActionError.locked = error else { return XCTFail("expected locked, got \(error)") }
        }
        XCTAssertNil(s.launchBlocker(code: "CA"))
    }

    func testUnlockByCatalogSizeOrSubscribers() throws {
        var s = newState()
        s.catalog = filler(40)
        XCTAssertNil(s.launchBlocker(code: "US"))
        s.finances.cash = 100_000_000
        try s.launchMarket(code: "US")
        XCTAssertEqual(s.markets["US"]?.status, .launching(weeksLeft: 4))

        var t = newState()
        t.markets["IE"]?.subs = TierSet(ad: 0, standard: 1_200_000, premium: 0)
        XCTAssertNil(t.launchBlocker(code: "IN"))   // 1M subs
        XCTAssertNotNil(t.launchBlocker(code: "JP")) // needs 1.5M
    }

    // MARK: Rival pressure & AI math

    func testRivalPressureWeightsStrengthAndPriceCuts() {
        XCTAssertEqual(Formulas.rivalPressure([]).effectiveShare, 0)
        let calm = Formulas.rivalPressure([.init(share: 0.2, strength: 50, priceLevel: 1.0)])
        let strong = Formulas.rivalPressure([.init(share: 0.2, strength: 100, priceLevel: 1.0)])
        let cutting = Formulas.rivalPressure([.init(share: 0.2, strength: 50, priceLevel: 0.8)])
        XCTAssertGreaterThan(strong.effectiveShare, calm.effectiveShare)
        XCTAssertEqual(calm.heat, 0, accuracy: 1e-9)
        XCTAssertGreaterThan(cutting.heat, 0)
        XCTAssertLessThanOrEqual(cutting.heat, 1)
    }

    func testPriceCutsRaiseChurnAndStrongRivalsLowerSignups() {
        let base = Formulas.churnRate(appeal: 0.5, price: 10, tolerance: 10, serviceQuality: 1, rivalHeat: 0)
        let hot = Formulas.churnRate(appeal: 0.5, price: 10, tolerance: 10, serviceQuality: 1, rivalHeat: 0.8)
        XCTAssertGreaterThan(hot, base)
        XCTAssertLessThan(Formulas.rivalFactor(rivalShare: 0.6), Formulas.rivalFactor(rivalShare: 0.2))
    }

    func testBidChanceFavorsAggressiveBiddersAndQuality() {
        XCTAssertGreaterThan(Formulas.bidChance(personality: .aggressiveBidder, quality: 60),
                             Formulas.bidChance(personality: .priceCutter, quality: 60))
        XCTAssertGreaterThan(Formulas.bidChance(personality: .balanced, quality: 90),
                             Formulas.bidChance(personality: .balanced, quality: 30))
    }

    // MARK: Rival behavior over time

    func testRivalsExpandAndStayWithinBounds() {
        var s = newState()
        let before = s.rivals.first { $0.id == "hulo" }!.countryCount
        for _ in 0..<400 { s = SimulationEngine.advanceWeek(s) }
        let hulo = s.rivals.first { $0.id == "hulo" }!
        XCTAssertGreaterThan(hulo.countryCount, before)
        for r in s.rivals {
            XCTAssertTrue((0.7...1.15).contains(r.priceLevel), "\(r.id) price \(r.priceLevel)")
            XCTAssertLessThanOrEqual(r.catalogStrength, 100)
        }
    }

    func testRivalsNeverOverfillMarkets() {
        var s = newState()
        for _ in 0..<150 { s = SimulationEngine.advanceWeek(s) }
        for c in CountryData.all {
            let rivals = s.rivals.reduce(0) { $0 + ($1.subs[c.code] ?? 0) }
            let own = s.markets[c.code]?.subs.total ?? 0
            // Initial seeding can exceed the 95% growth cap only if it started there; it never starts above 90%.
            XCTAssertLessThanOrEqual(rivals + own, c.subscriberCeiling, c.code)
        }
    }

    func testRivalsPayForExpansionFromCash() {
        var s = newState()
        for i in s.rivals.indices { s.rivals[i].cash = 0; s.rivals[i].subs = ["IE": 1] }
        // With no cash, income is tiny; expansion needs half the launch cost, so none can afford big markets early.
        s = SimulationEngine.advanceWeek(s)
        for r in s.rivals { XCTAssertLessThanOrEqual(r.countryCount, 2) }
    }

    func testPreviousSubsTrackLastWeek() {
        var s = newState()
        let startNetflux = s.rivals.first { $0.id == "netflux" }!.totalSubs
        s = SimulationEngine.advanceWeek(s)
        XCTAssertEqual(s.previousSubs["netflux"] ?? -1, startNetflux, accuracy: 1e-6)
        XCTAssertNotNil(s.previousSubs["player"])
    }

    func testPlayerCanBeatRivalsOnceAhead() {
        var s = newState()
        s.week = 60
        for i in s.rivals.indices { s.rivals[i].subs = ["IE": 10] }
        s.markets["IE"]?.subs = TierSet(ad: 0, standard: 100_000, premium: 0)
        s = SimulationEngine.advanceWeek(s)
        XCTAssertEqual(s.outcome, .won)
    }

    // MARK: Persistence

    func testOldSaveVersionIsRejected() throws {
        var s = newState()
        s.version = 1
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("se-old-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        try SaveManager.save(s, to: url)
        XCTAssertNil(SaveManager.load(from: url))
    }

    // MARK: Multi-market

    func testSecondMarketGoesLiveAndEarnsRevenue() throws {
        var s = newState()
        try s.launchMarket(code: "NZ")
        for _ in 0..<4 { s = SimulationEngine.advanceWeek(s) }
        XCTAssertTrue(s.markets["NZ"]!.isLive)
        s.markets["NZ"]?.subs = TierSet(ad: 0, standard: 1_000, premium: 0)
        s = SimulationEngine.advanceWeek(s)
        let nz = s.lastReport!.markets.first { $0.id == "NZ" }
        XCTAssertNotNil(nz)
        XCTAssertGreaterThan(nz!.revenue, 0)
    }
}
