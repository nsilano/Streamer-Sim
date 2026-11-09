import XCTest
#if canImport(StreamEmpireCore)
@testable import StreamEmpireCore
#else
@testable import StreamEmpire
#endif

final class Phase4Tests: XCTestCase {
    private func newState(country: String = "IE", seed: UInt64 = 42) -> GameState {
        var s = GameState.newGame(startCountry: country, companyName: "Test Co", seed: seed)
        s.eventsEnabled = false
        return s
    }

    private func titles(_ n: Int) -> [Title] {
        (0..<n).map {
            Title(id: 9000 + $0, name: "P\($0)", kind: .movie, genre: .drama, language: .english,
                  quality: 70, popularity: 70, ageWeeks: 0, isOriginal: true,
                  license: nil, weeksRemaining: nil, listingWeeksLeft: 0)
        }
    }

    // MARK: Platforms

    func testPlatformReachAddsUp() {
        XCTAssertEqual(Formulas.platformReach([.web]), 0.70, accuracy: 1e-9)
        XCTAssertEqual(Formulas.platformReach(Platform.allCases), 1.0, accuracy: 1e-9)
        XCTAssertGreaterThan(Formulas.platformReach([.web, .ios]), Formulas.platformReach([.web]))
        XCTAssertEqual(newState().platformReach, 0.70, accuracy: 1e-9)
    }

    func testPlatformBuildTakesTimeCostsMoneyAndRaisesReach() throws {
        var s = newState()
        let cash = s.finances.cash
        try s.startPlatform(.ios)
        XCTAssertEqual(s.finances.cash, cash - Platform.ios.unlockCost, accuracy: 0.01)
        XCTAssertEqual(s.builds, [PlatformBuild(platform: .ios, weeksLeft: 8)])
        XCTAssertThrowsError(try s.startPlatform(.ios), "already in development")
        XCTAssertThrowsError(try s.startPlatform(.web), "already built")

        for _ in 0..<7 { s = SimulationEngine.advanceWeek(s) }
        XCTAssertFalse(s.platforms.contains(.ios))
        s = SimulationEngine.advanceWeek(s)
        XCTAssertTrue(s.platforms.contains(.ios))
        XCTAssertTrue(s.builds.isEmpty)
        XCTAssertEqual(s.platformReach, 0.80, accuracy: 1e-9)
        XCTAssertTrue(s.lastReport!.events.contains { $0.headline.contains("launched") })
        // Upkeep starts once shipped.
        s = SimulationEngine.advanceWeek(s)
        XCTAssertEqual(s.lastReport!.financials.tech, Platform.ios.weeklyUpkeep, accuracy: 0.01)
    }

    func testEngineeringSpeedsBuilds() throws {
        var s = newState()
        s.staff.engineering = 3
        try s.startPlatform(.smartTV)
        XCTAssertEqual(s.builds[0].weeksLeft, 9)
        XCTAssertEqual(Formulas.buildWeeks(base: 8, engineeringLevel: 5), 3)
        XCTAssertEqual(Formulas.buildWeeks(base: 8, engineeringLevel: 99), 2, "never instant")
    }

    func testMoreReachMeansMoreSignups() {
        func adds(_ platforms: [Platform]) -> Double {
            var s = newState()
            s.eventsEnabled = false
            s.platforms = platforms
            s.catalog = titles(15)
            s.markets["IE"]?.awareness = 0.4
            return SimulationEngine.advanceWeek(s).lastReport!.newSubs
        }
        XCTAssertGreaterThan(adds(Platform.allCases), adds([.web]))
    }

    // MARK: Servers

    func testServiceQualityDegradesPastCapacity() {
        XCTAssertEqual(Formulas.serviceQuality(load: 0.5), 1.0)
        XCTAssertEqual(Formulas.serviceQuality(load: 0.9), 1.0)
        XCTAssertEqual(Formulas.serviceQuality(load: 1.0), 0.95, accuracy: 1e-9, "a little lag at full load")
        XCTAssertLessThan(Formulas.serviceQuality(load: 1.3), 1.0)
        XCTAssertLessThan(Formulas.serviceQuality(load: 1.6), Formulas.serviceQuality(load: 1.3))
        XCTAssertEqual(Formulas.serviceQuality(load: 50), 0.3, accuracy: 1e-9)
    }

    func testOverloadedServersCutSignupsAndRaiseChurn() {
        func week(cloudBlocks: Int) -> WeeklyReport {
            var s = newState(country: "CA")
            s.catalog = titles(15)
            s.markets["CA"]?.awareness = 0.4
            s.markets["CA"]?.subs = TierSet(ad: 0, standard: 2_000_000, premium: 0)
            s.cloudUnits[Region.northAmerica.rawValue] = cloudBlocks
            return SimulationEngine.advanceWeek(s).lastReport!
        }
        let overloaded = week(cloudBlocks: 0), healthy = week(cloudBlocks: 10)
        XCTAssertLessThan(overloaded.newSubs, healthy.newSubs)
        XCTAssertGreaterThan(overloaded.churned, healthy.churned)
    }

    func testBufferingWarningAppearsInOverloadedRegion() {
        var s = newState(country: "CA")
        s.markets["CA"]?.subs = TierSet(ad: 0, standard: 2_000_000, premium: 0)
        s.week = 4
        s = SimulationEngine.advanceWeek(s)
        XCTAssertTrue(s.lastReport!.events.contains { $0.headline.contains("Buffering") })
    }

    func testTechCostCombinesPlatformsDatacentersAndCloud() {
        var s = newState()
        XCTAssertEqual(s.weeklyTechCost, 0)
        s.platforms = [.web, .ios]
        s.datacenters = [Datacenter(id: 1, name: "Dublin DC", region: .europe, level: 2, weeksToBuild: 0),
                         Datacenter(id: 2, name: "Frankfurt DC", region: .europe, level: 1, weeksToBuild: 5)]
        s.cloudUnits = [Region.europe.rawValue: 2]
        // iOS 8k + level-2 DC (the one still under construction costs nothing yet) + 2 cloud blocks.
        let dc = Formulas.datacenterUpkeep(level: 2)
        XCTAssertEqual(s.weeklyTechCost, 8_000 + dc + 2 * Formulas.cloudUnitCostPerWeek, accuracy: 0.01)
        s.staff.engineering = 2
        XCTAssertEqual(s.weeklyTechCost, 8_000 + (dc + 2 * Formulas.cloudUnitCostPerWeek) * 0.9, accuracy: 0.01)
        XCTAssertEqual(s.datacenterBuildPrice, Formulas.datacenterBuildCost * 0.9, accuracy: 0.01)
    }

    // MARK: Staff

    func testHiringCostsMoneyAndSalaries() throws {
        var s = newState()
        let cash = s.finances.cash
        try s.hire(.legal)
        XCTAssertEqual(s.staff.legal, 1)
        XCTAssertEqual(s.finances.cash, cash - Formulas.hireCost(currentLevel: 0), accuracy: 0.01)
        try s.hire(.legal)
        XCTAssertEqual(s.staff.legal, 2)
        XCTAssertGreaterThan(Formulas.hireCost(currentLevel: 2), Formulas.hireCost(currentLevel: 1))
        XCTAssertEqual(s.weeklySalaries, 2 * Formulas.salaryPerLevelPerWeek)

        s = SimulationEngine.advanceWeek(s)
        XCTAssertEqual(s.lastReport!.financials.staff,
                       Formulas.baseStaffCostPerWeek + 2 * Formulas.salaryPerLevelPerWeek, accuracy: 0.01)

        try s.reduceStaff(.legal)
        XCTAssertEqual(s.staff.legal, 1)
        XCTAssertThrowsError(try s.reduceStaff(.content), "nobody to cut")
    }

    func testDepartmentLevelsCapAtFive() throws {
        var s = newState()
        s.finances.cash = 100_000_000
        for _ in 0..<Formulas.maxDepartmentLevel { try s.hire(.finance) }
        XCTAssertThrowsError(try s.hire(.finance))
        XCTAssertEqual(s.staff.finance, 5)
    }

    func testContentDepartmentDiscountsLicenses() throws {
        var s = newState()
        s.staff.content = 5
        let title = s.licenseMarket[0]
        let list = title.license!.cost
        XCTAssertEqual(s.licensePrice(title), list * 0.90, accuracy: 0.01)
        let cash = s.finances.cash
        try s.buyLicense(titleID: title.id)
        XCTAssertEqual(s.finances.cash, cash - list * 0.90, accuracy: 0.01)
        XCTAssertEqual(Formulas.originalQualityBonus(contentLevel: 5), 10)
    }

    func testMarketingDepartmentBoostsAwareness() {
        func awareness(level: Int) -> Double {
            var s = newState()
            s.staff.marketing = level
            s.markets["IE"]?.marketingBudget = 40_000
            return SimulationEngine.advanceWeek(s).markets["IE"]!.awareness
        }
        XCTAssertGreaterThan(awareness(level: 5), awareness(level: 0))
    }

    func testLegalDepartmentCutsFinesAndEventCosts() {
        func fines(level: Int) -> Double {
            var s = newState()
            s.staff.legal = level
            s.markets["NL"]?.status = .live
            s.markets["NL"]?.subs = TierSet(ad: 0, standard: 10_000, premium: 0)
            s.catalog = titles(10)               // all English: NL quota unmet
            return SimulationEngine.advanceWeek(s).lastReport!.financials.fines
        }
        let base = fines(level: 0)
        XCTAssertGreaterThan(base, 0)
        XCTAssertEqual(fines(level: 2), base * 0.7, accuracy: base * 0.001)
        XCTAssertEqual(Formulas.regulationCostMultiplier(legalLevel: 5), 0.5, accuracy: 1e-9)
        XCTAssertGreaterThan(Formulas.lobbySuccessChance(legalLevel: 5), Formulas.lobbySuccessChance(legalLevel: 0))
    }

    func testFinanceDepartmentLowersRatesAndLiftsValuation() {
        var s = newState()
        s.finances.revenueHistory = Array(repeating: 1_000_000, count: 52)
        let rate = s.loanRate, value = s.valuation
        s.staff.finance = 4
        XCTAssertEqual(s.loanRate, rate - 0.02, accuracy: 1e-9)
        XCTAssertEqual(s.valuation, value * 1.12, accuracy: 1)
        XCTAssertGreaterThanOrEqual(s.loanRate, 0.04)
    }

    // MARK: Economy scaling

    func testLicensePricesScaleWithAudience() {
        XCTAssertEqual(Formulas.licenseAudienceScale(totalSubscribers: 0), 1.0)
        XCTAssertEqual(Formulas.licenseAudienceScale(totalSubscribers: 1_000_000), 3.0, accuracy: 1e-9)
        XCTAssertEqual(Formulas.licenseAudienceScale(totalSubscribers: 1e12), 100)
        var s = newState()
        let title = s.licenseMarket[0]
        let small = s.licensePrice(title)
        s.markets["IE"]?.subs = TierSet(ad: 0, standard: 1_000_000, premium: 0)
        XCTAssertEqual(s.licensePrice(title), small * 3.0, accuracy: 0.01)
    }

    func testOverheadAndAppStoreFeesGrowWithRevenue() {
        var s = newState()
        s.markets["IE"]?.subs = TierSet(ad: 0, standard: 10_000, premium: 0)
        s.platforms = [.web, .ios, .android]
        let fin = SimulationEngine.advanceWeek(s).lastReport!.financials
        XCTAssertEqual(fin.staff, Formulas.baseStaffCostPerWeek + Formulas.overheadRate * fin.revenue, accuracy: 0.01)
        let upkeep = Platform.ios.weeklyUpkeep + Platform.android.weeklyUpkeep
        XCTAssertEqual(fin.tech, upkeep + 2 * Formulas.appStoreFeeRate * fin.subscriptionRevenue, accuracy: 0.01)
    }

    // MARK: Persistence

    func testPhase4StateRoundTrips() throws {
        var s = newState()
        s.finances.cash = 50_000_000
        try s.startPlatform(.android)
        try s.buildDatacenter(region: .europe)
        try s.rentCloud(region: .asiaPacific)
        try s.hire(.engineering)
        let loaded = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(s))
        XCTAssertEqual(loaded, s)
        XCTAssertEqual(loaded.datacenters.count, 1)
        XCTAssertEqual(loaded.cloudUnits[Region.asiaPacific.rawValue], 1)
        XCTAssertEqual(loaded.staff.engineering, 1)
    }
}
