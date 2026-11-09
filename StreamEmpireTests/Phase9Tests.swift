import XCTest
#if canImport(StreamEmpireCore)
@testable import StreamEmpireCore
#else
@testable import StreamEmpire
#endif

final class Phase9Tests: XCTestCase {
    private func newState(country: String = "IE", seed: UInt64 = 42) -> GameState {
        var s = GameState.newGame(startCountry: country, companyName: "Test Co", seed: seed)
        s.eventsEnabled = false
        return s
    }

    private func listing(id: Int, quality: Int = 80, years: Int = 2, exclusive: Bool = false, kind: TitleKind = .movie,
                         genre: Genre = .drama, language: Language = .english, cost: Double = 200_000) -> Title {
        Title(id: id, name: "L\(id)", kind: kind, genre: genre, language: language, quality: quality, popularity: 70,
              ageWeeks: 10, isOriginal: false,
              license: LicenseTerms(cost: cost, years: years, regions: [], exclusive: exclusive),
              weeksRemaining: nil, listingWeeksLeft: 8)
    }

    // MARK: Restart

    func testGameRemembersHowItStarted() {
        let s = newState(country: "NL", seed: 1234)
        XCTAssertEqual(s.startCountry, "NL")
        XCTAssertEqual(s.startSeed, 1234)
        let same = s.restarted(sameWorld: true, newSeed: 99)
        XCTAssertEqual(same.liveMarketCodes, ["NL"])
        XCTAssertEqual(same.licenseMarket.map(\.name), s.licenseMarket.map(\.name), "same seed = same world")
        XCTAssertEqual(same.companyName, "Test Co")
        let fresh = s.restarted(sameWorld: false, newSeed: 99)
        XCTAssertEqual(fresh.liveMarketCodes, ["NL"])
        XCTAssertNotEqual(fresh.licenseMarket.map(\.name), s.licenseMarket.map(\.name))
        XCTAssertEqual(fresh.week, 1)
        XCTAssertEqual(fresh.finances.cash, GameState.startingCash)
    }

    func testRestartAfterProgressWipesIt() throws {
        var s = newState()
        for _ in 0..<10 { s = SimulationEngine.advanceWeek(s) }
        let again = s.restarted(sameWorld: true, newSeed: 1)
        XCTAssertEqual(again.week, 1)
        XCTAssertTrue(again.catalog.isEmpty)
        XCTAssertNil(again.lastReport)
    }

    // MARK: Tiers

    func testNewGamesStartWithStandardOnly() {
        let s = newState()
        XCTAssertEqual(s.markets["IE"]!.liveTiers, [.standard])
        XCTAssertTrue(s.markets["IE"]!.tierBuilds.isEmpty)
    }

    func testTierSplitOnlyUsesLiveTiers() {
        let prices = TierSet(ad: 5, standard: 11, premium: 16)
        let standardOnly = Formulas.tierSplit(prices: prices, tiers: [.standard])
        XCTAssertEqual(standardOnly.standard, 1, accuracy: 1e-9)
        XCTAssertEqual(standardOnly.ad, 0)
        let two = Formulas.tierSplit(prices: prices, tiers: [.ad, .standard])
        XCTAssertEqual(two.total, 1, accuracy: 1e-9)
        XCTAssertEqual(two.premium, 0)
        XCTAssertGreaterThan(two.ad, two.standard)
        XCTAssertEqual(Formulas.tierSplit(prices: prices, tiers: []).standard, 1, "never empty")
        XCTAssertEqual(Formulas.tierSplit(prices: prices).total, 1, accuracy: 1e-9)
    }

    func testBlendedPriceOnlyCountsLiveTiers() {
        let prices = TierSet(ad: 5, standard: 11, premium: 16)
        XCTAssertEqual(Formulas.blendedPrice(prices, tiers: [.standard]), 11, accuracy: 1e-9)
        XCTAssertEqual(Formulas.blendedPrice(prices), 0.3 * 5 + 0.5 * 11 + 0.2 * 16, accuracy: 1e-9)
        XCTAssertLessThan(Formulas.blendedPrice(prices, tiers: [.ad, .standard]), 11)
        XCTAssertGreaterThan(Formulas.blendedPrice(prices, tiers: [.standard, .premium]), 11)
    }

    func testLaunchingATierCostsMoneyAndTakesTime() throws {
        var s = newState()
        let ie = CountryData.country("IE")!
        let cost = Formulas.tierLaunchCost(.ad, in: ie)
        XCTAssertEqual(cost, 100_000 + 1.5 * 40_000, accuracy: 1)
        let cash = s.finances.cash
        try s.launchTier(.ad, code: "IE")
        XCTAssertEqual(s.finances.cash, cash - cost, accuracy: 0.01)
        XCTAssertEqual(s.markets["IE"]!.tierBuilds, [TierBuild(tier: .ad, weeksLeft: 3)])
        XCTAssertThrowsError(try s.launchTier(.ad, code: "IE"), "already in progress")
        XCTAssertThrowsError(try s.launchTier(.standard, code: "IE"), "always live")
        XCTAssertThrowsError(try s.launchTier(.premium, code: "NZ"), "market not live")

        for _ in 0..<2 { s = SimulationEngine.advanceWeek(s) }
        XCTAssertFalse(s.markets["IE"]!.liveTiers.contains(.ad))
        s = SimulationEngine.advanceWeek(s)
        XCTAssertTrue(s.markets["IE"]!.liveTiers.contains(.ad))
        XCTAssertTrue(s.lastReport!.events.contains { $0.headline.contains("Ad-supported tier live") })
        XCTAssertEqual(s.lastReport!.financials.launch, 0, accuracy: 0.01, "paid in week 1's report, not again")
    }

    func testTierLaunchCostIsInTheNextReport() throws {
        var s = newState()
        try s.launchTier(.premium, code: "IE")
        s = SimulationEngine.advanceWeek(s)
        XCTAssertEqual(s.lastReport!.financials.launch, Formulas.tierLaunchCost(.premium, in: CountryData.country("IE")!), accuracy: 0.01)
    }

    func testNewSignupsOnlyLandInLiveTiers() {
        var s = newState()
        s.catalog = (0..<15).map { listing(id: 500 + $0).asOriginal() }
        s.markets["IE"]?.awareness = 0.4
        for _ in 0..<6 { s = SimulationEngine.advanceWeek(s) }
        let subs = s.markets["IE"]!.subs
        XCTAssertGreaterThan(subs.standard, 0)
        XCTAssertEqual(subs.ad, 0)
        XCTAssertEqual(subs.premium, 0)
    }

    func testExistingSubscribersKeepPayingWhenTheirTierIsNotLive() {
        var s = newState()
        s.markets["IE"]?.subs = TierSet(ad: 10_000, standard: 0, premium: 0)
        let fin = SimulationEngine.advanceWeek(s).lastReport!.financials
        XCTAssertGreaterThan(fin.adRevenue, 0)
        XCTAssertGreaterThan(fin.subscriptionRevenue, 0)
    }

    // MARK: Licensing manager

    func testHiringTheManager() throws {
        var s = newState()
        XCTAssertNil(s.curator)
        let cash = s.finances.cash
        try s.hireCurator()
        XCTAssertNotNil(s.curator)
        XCTAssertEqual(s.finances.cash, cash - Curator.hireCost, accuracy: 0.01)
        XCTAssertThrowsError(try s.hireCurator())
        XCTAssertEqual(s.weeklySalaries, Curator.weeklySalary)
        let week = SimulationEngine.advanceWeek(s).lastReport!.financials
        XCTAssertEqual(week.staff, Formulas.baseStaffCostPerWeek + Curator.weeklySalary + Formulas.overheadRate * week.revenue, accuracy: 0.01)
        s.fireCurator()
        XCTAssertNil(s.curator)
        XCTAssertEqual(s.weeklySalaries, 0)
    }

    func testManagerBuysWithinLimits() throws {
        var s = newState()
        try s.hireCurator()
        s.finances.cash = 50_000_000
        s.licenseMarket = [
            listing(id: 1, quality: 85, cost: 300_000),                              // fine
            listing(id: 2, quality: 40, cost: 100_000),                              // too low quality
            listing(id: 3, quality: 90, years: 5, cost: 300_000),                    // license too long
            listing(id: 4, quality: 90, cost: 5_000_000),                            // too expensive
            listing(id: 5, quality: 90, exclusive: true, cost: 300_000),             // exclusives off
            listing(id: 6, quality: 90, language: .korean, cost: 300_000),           // language not served
        ]
        var c = s.curator!
        c.allowExclusive = false
        c.maxPricePerTitle = 1_000_000
        try s.updateCurator(c)
        s.licenseMarket[0].listingWeeksLeft = 99
        for i in s.licenseMarket.indices { s.licenseMarket[i].listingWeeksLeft = 99 }
        s = SimulationEngine.advanceWeek(s)
        XCTAssertEqual(s.catalog.map(\.id), [1], "only the title that passes every rule")
        XCTAssertTrue(s.lastReport!.events.contains { $0.headline.contains("Licensing manager signed 1 title") })
    }

    func testManagerRespectsBudgetReserveTargetAndPause() throws {
        func run(_ tweak: (inout Curator) -> Void, cash: Double = 50_000_000) throws -> GameState {
            var s = newState()
            try s.hireCurator()
            s.finances.cash = cash
            s.licenseMarket = (1...6).map { listing(id: $0, quality: 80, cost: 400_000) }
            for i in s.licenseMarket.indices { s.licenseMarket[i].listingWeeksLeft = 99 }
            var c = s.curator!
            tweak(&c)
            try s.updateCurator(c)
            return SimulationEngine.advanceWeek(s)
        }
        XCTAssertEqual(try run { _ in }.catalog.count, 3, "at most 3 purchases a week")
        XCTAssertEqual(try run { $0.weeklyBudget = 900_000 }.catalog.count, 2, "weekly budget")
        XCTAssertEqual(try run({ _ in }, cash: 3_500_000).catalog.count, 0, "cash reserve")
        XCTAssertEqual(try run { $0.targetCatalogSize = 1 }.catalog.count, 1, "target catalog size")
        XCTAssertEqual(try run { $0.enabled = false }.catalog.count, 0, "paused")
        XCTAssertEqual(try run { $0.allowMovies = false }.catalog.count, 0, "movies off")
        XCTAssertEqual(try run { $0.genres = [.comedy] }.catalog.count, 0, "genre filter")
        XCTAssertEqual(try run { $0.genres = [.drama] }.catalog.count, 3)
    }

    func testManagerPicksTheBestValue() throws {
        var s = newState()
        try s.hireCurator()
        s.finances.cash = 50_000_000
        var c = s.curator!
        c.targetCatalogSize = 1
        try s.updateCurator(c)
        s.licenseMarket = [listing(id: 1, quality: 62, cost: 900_000), listing(id: 2, quality: 90, cost: 200_000)]
        for i in s.licenseMarket.indices { s.licenseMarket[i].listingWeeksLeft = 99 }
        s = SimulationEngine.advanceWeek(s)
        XCTAssertEqual(s.catalog.map(\.id), [2], "the better and cheaper title wins")
    }

    func testCuratorSettingsAreValidated() throws {
        var s = newState()
        var c = Curator()
        XCTAssertThrowsError(try s.updateCurator(c), "not hired yet")
        try s.hireCurator()
        c.minQuality = 150
        XCTAssertThrowsError(try s.updateCurator(c))
        c.minQuality = 70; c.maxYears = 9
        XCTAssertThrowsError(try s.updateCurator(c))
        c.maxYears = 4; c.weeklyBudget = -1
        XCTAssertThrowsError(try s.updateCurator(c))
        c.weeklyBudget = 1_000_000
        XCTAssertNoThrow(try s.updateCurator(c))
    }

    func testPhase9StateRoundTrips() throws {
        var s = newState()
        try s.hireCurator()
        var c = s.curator!
        c.genres = [.anime, .drama]
        try s.updateCurator(c)
        try s.launchTier(.premium, code: "IE")
        let loaded = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(s))
        XCTAssertEqual(loaded, s)
        XCTAssertEqual(loaded.curator?.genres, [.anime, .drama])
        XCTAssertEqual(loaded.startCountry, "IE")
    }
}

private extension Title {
    func asOriginal() -> Title {
        var t = self
        t.isOriginal = true
        t.license = nil
        return t
    }
}
