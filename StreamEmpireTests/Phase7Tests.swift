import XCTest
#if canImport(StreamEmpireCore)
@testable import StreamEmpireCore
#else
@testable import StreamEmpire
#endif

final class Phase7Tests: XCTestCase {
    private func newState(country: String = "CA", seed: UInt64 = 42) -> GameState {
        var s = GameState.newGame(startCountry: country, companyName: "Test Co", seed: seed)
        s.eventsEnabled = false
        s.finances.cash = 1e12
        return s
    }

    private func titles(_ n: Int) -> [Title] {
        (0..<n).map {
            Title(id: 8000 + $0, name: "S\($0)", kind: .movie, genre: .drama, language: .english,
                  quality: 70, popularity: 70, ageWeeks: 0, isOriginal: true,
                  license: nil, weeksRemaining: nil, listingWeeksLeft: 0)
        }
    }

    // MARK: Capacity

    func testCapacityComposesFromStarterDatacentersAndCloud() throws {
        var s = newState()
        let base = Formulas.baseServerCapacity
        XCTAssertEqual(s.serverCapacity(.northAmerica), base)
        try s.buildDatacenter(region: .northAmerica)
        XCTAssertEqual(s.serverCapacity(.northAmerica), base, "not online until built")
        s.datacenters[0].weeksToBuild = 0
        let withDC = base + Formulas.datacenterCapacity(level: 1)
        XCTAssertEqual(s.serverCapacity(.northAmerica), withDC)
        try s.rentCloud(region: .northAmerica)
        XCTAssertEqual(s.serverCapacity(.northAmerica), withDC + Formulas.cloudUnitCapacity)
        XCTAssertEqual(s.serverCapacity(.europe), base, "other regions unaffected")
        XCTAssertEqual(Formulas.datacenterCapacity(level: 5), 50_000_000)
        XCTAssertGreaterThan(Formulas.datacenterCapacity(level: 3), Formulas.datacenterCapacity(level: 2))
    }

    func testBuildingDatacentersTakesTimeAndMoney() throws {
        var s = newState()
        let cash = s.finances.cash
        try s.buildDatacenter(region: .northAmerica)
        XCTAssertEqual(s.finances.cash, cash - Formulas.datacenterBuildCost, accuracy: 0.01)
        let dc = s.datacenters[0]
        XCTAssertEqual(dc.weeksToBuild, Formulas.datacenterBuildWeeks)
        XCTAssertFalse(dc.isOnline)
        XCTAssertEqual(dc.name, "Virginia DC")

        for _ in 0..<(Formulas.datacenterBuildWeeks - 1) { s = SimulationEngine.advanceWeek(s) }
        XCTAssertFalse(s.datacenters[0].isOnline)
        s = SimulationEngine.advanceWeek(s)
        XCTAssertTrue(s.datacenters[0].isOnline)
        XCTAssertTrue(s.lastReport!.events.contains { $0.headline.contains("is online") })
        s = SimulationEngine.advanceWeek(s)
        XCTAssertEqual(s.lastReport!.financials.tech, Formulas.datacenterUpkeep(level: 1), accuracy: 0.01)
    }

    func testEngineeringSpeedsDatacenters() throws {
        var s = newState()
        s.staff.engineering = 3
        try s.buildDatacenter(region: .europe)
        XCTAssertEqual(s.datacenters[0].weeksToBuild, 60, "72 weeks minus 4 per engineering level")
    }

    func testDatacenterLimitsAndUpgrades() throws {
        var s = newState()
        for _ in 0..<Formulas.maxDatacentersPerRegion { try s.buildDatacenter(region: .europe) }
        XCTAssertThrowsError(try s.buildDatacenter(region: .europe))
        XCTAssertEqual(Set(s.datacenters.map(\.name)).count, Formulas.maxDatacentersPerRegion, "each gets its own site name")

        let id = s.datacenters[0].id
        XCTAssertThrowsError(try s.upgradeDatacenter(id: id), "can't upgrade while under construction")
        s.datacenters[0].weeksToBuild = 0
        let cash = s.finances.cash
        try s.upgradeDatacenter(id: id)
        XCTAssertEqual(s.datacenters[0].level, 2)
        XCTAssertEqual(s.finances.cash, cash - Formulas.datacenterUpgradeCost(currentLevel: 1), accuracy: 0.01)
        for _ in 0..<3 { try s.upgradeDatacenter(id: id) }
        XCTAssertEqual(s.datacenters[0].level, Formulas.maxDatacenterLevel)
        XCTAssertThrowsError(try s.upgradeDatacenter(id: id))
        XCTAssertNil(s.datacenterUpgradePrice(s.datacenters[0]))
    }

    func testCloudRentAndRelease() throws {
        var s = newState()
        try s.rentCloud(region: .asiaPacific)
        try s.rentCloud(region: .asiaPacific)
        XCTAssertEqual(s.cloudUnits[Region.asiaPacific.rawValue], 2)
        XCTAssertEqual(s.weeklyTechCost, 2 * Formulas.cloudUnitCostPerWeek, accuracy: 0.01)
        try s.releaseCloud(region: .asiaPacific)
        XCTAssertEqual(s.cloudUnits[Region.asiaPacific.rawValue], 1)
        try s.releaseCloud(region: .asiaPacific)
        XCTAssertThrowsError(try s.releaseCloud(region: .asiaPacific))
        for _ in 0..<Formulas.maxCloudUnits { try s.rentCloud(region: .africa) }
        XCTAssertThrowsError(try s.rentCloud(region: .africa))
        // Cloud costs far more per viewer than owning.
        XCTAssertGreaterThan(Formulas.cloudUnitCostPerWeek / Formulas.cloudUnitCapacity,
                             5 * Formulas.datacenterUpkeep(level: 1) / Formulas.datacenterCapacity(level: 1))
    }

    func testNotEnoughCashBlocksBuilds() {
        var s = newState()
        s.finances.cash = 100_000
        XCTAssertThrowsError(try s.buildDatacenter(region: .europe))
    }

    // MARK: Strain

    func testQualityZones() {
        XCTAssertEqual(Formulas.serviceQuality(load: 0.8), 1.0)
        XCTAssertLessThan(Formulas.serviceQuality(load: 0.97), 1.0)
        XCTAssertGreaterThan(Formulas.serviceQuality(load: 0.97), 0.95)
        XCTAssertLessThan(Formulas.serviceQuality(load: 1.2), 0.95)
        XCTAssertEqual(Formulas.serviceQuality(load: 9), 0.3, accuracy: 1e-9)
    }

    func testCrashMath() {
        XCTAssertEqual(Formulas.crashChance(load: 1.0, datacenters: 0, engineeringLevel: 0), 0)
        XCTAssertEqual(Formulas.crashChance(load: 1.05, datacenters: 0, engineeringLevel: 0), 0)
        let single = Formulas.crashChance(load: 1.5, datacenters: 1, engineeringLevel: 0)
        XCTAssertEqual(single, 0.36, accuracy: 1e-9)
        XCTAssertEqual(Formulas.crashChance(load: 1.5, datacenters: 2, engineeringLevel: 0), single * 0.7, accuracy: 1e-9, "redundancy")
        XCTAssertLessThan(Formulas.crashChance(load: 1.5, datacenters: 1, engineeringLevel: 4), single)
        XCTAssertLessThanOrEqual(Formulas.crashChance(load: 9, datacenters: 0, engineeringLevel: 0), 0.6)
        XCTAssertEqual(Formulas.crashLoss(load: 1.1), 0.04, accuracy: 1e-9)
        XCTAssertEqual(Formulas.crashLoss(load: 5), 0.12)
    }

    func testOverloadedRegionEventuallyCrashesAndLosesSubscribers() {
        var s = newState()
        s.catalog = titles(15)
        s.markets["CA"]?.subs = TierSet(ad: 0, standard: 2_000_000, premium: 0)   // 4x capacity
        var crashed = false
        for _ in 0..<40 {
            let before = s.subscribers(in: .northAmerica)
            s = SimulationEngine.advanceWeek(s)
            if s.lastReport!.events.contains(where: { $0.headline.contains("crashed") }) {
                crashed = true
                XCTAssertLessThan(s.subscribers(in: .northAmerica), before * 0.99, "a crash costs subscribers")
                XCTAssertEqual(s.outages[Region.northAmerica.rawValue], 2)
                break
            }
        }
        XCTAssertTrue(crashed, "servers at 400% of capacity must crash within 40 weeks")
    }

    func testHealthyServersNeverCrash() {
        var s = newState()
        s.catalog = titles(15)
        s.cloudUnits[Region.northAmerica.rawValue] = 10
        s.markets["CA"]?.subs = TierSet(ad: 0, standard: 300_000, premium: 0)    // ~5% load
        for _ in 0..<60 {
            s = SimulationEngine.advanceWeek(s)
            XCTAssertFalse(s.lastReport!.events.contains { $0.headline.contains("crashed") })
            s.cloudUnits[Region.northAmerica.rawValue] = 10
        }
    }

    func testOutageDegradesServiceThenRecovers() {
        func report(outage: Bool) -> WeeklyReport {
            var s = newState()
            s.catalog = titles(15)
            s.cloudUnits[Region.northAmerica.rawValue] = 10
            s.markets["CA"]?.awareness = 0.4
            s.markets["CA"]?.subs = TierSet(ad: 0, standard: 100_000, premium: 0)
            if outage { s.outages[Region.northAmerica.rawValue] = 2 }
            return SimulationEngine.advanceWeek(s).lastReport!
        }
        XCTAssertLessThan(report(outage: true).newSubs, report(outage: false).newSubs)
        XCTAssertGreaterThan(report(outage: true).churned, report(outage: false).churned)

        var s = newState()
        s.outages[Region.europe.rawValue] = 2
        s = SimulationEngine.advanceWeek(s)
        XCTAssertEqual(s.outages[Region.europe.rawValue], 1)
        s = SimulationEngine.advanceWeek(s)
        XCTAssertNil(s.outages[Region.europe.rawValue], "recovered")
    }

    func testTrafficSurgesRaiseLoad() {
        var s = newState()
        s.cloudUnits[Region.northAmerica.rawValue] = 0
        s.markets["CA"]?.subs = TierSet(ad: 0, standard: 400_000, premium: 0)     // 80% of 500k
        XCTAssertEqual(s.effectiveLoad(.northAmerica), 0.8, accuracy: 1e-9)
        s.surges[Region.northAmerica.rawValue] = 2
        XCTAssertEqual(s.effectiveLoad(.northAmerica), 0.8 * Formulas.surgeLoadMultiplier, accuracy: 1e-9)
        XCTAssertEqual(s.busiestRegion, .northAmerica)
        s = SimulationEngine.advanceWeek(s)
        XCTAssertEqual(s.surges[Region.northAmerica.rawValue], 1)
        s = SimulationEngine.advanceWeek(s)
        XCTAssertNil(s.surges[Region.northAmerica.rawValue])
    }

    func testViralHitCausesSurgeInBusiestRegion() {
        var s = newState()
        s.catalog = titles(1)
        s.markets["CA"]?.subs = TierSet(ad: 0, standard: 50_000, premium: 0)
        _ = RandomEvents.create("viral", &s)
        XCTAssertEqual(s.surges[Region.northAmerica.rawValue], 2)
    }

    func testLagWarningAndAdvice() {
        var s = newState()
        s.markets["CA"]?.subs = TierSet(ad: 0, standard: 460_000, premium: 0)     // 92% load
        s.week = 4
        s = SimulationEngine.advanceWeek(s)
        XCTAssertTrue(s.lastReport!.events.contains { $0.headline.contains("Lag") })
        XCTAssertTrue(s.advice().contains { $0.id == "servers-northAmerica" })
    }

    func testDatacenterNames() {
        XCTAssertEqual(DatacenterNames.name(region: .europe, index: 0), "Dublin DC")
        XCTAssertEqual(DatacenterNames.name(region: .europe, index: 4), "Dublin DC 2")
    }

    func testRealisticGrowthPlanKeepsServersHealthy() throws {
        // A player who builds ahead of demand stays below the lag zone.
        var s = newState()
        s.catalog = titles(15)
        s.markets["CA"]?.subs = TierSet(ad: 0, standard: 450_000, premium: 0)
        try s.buildDatacenter(region: .northAmerica)
        try s.buildDatacenter(region: .northAmerica)
        for _ in 0..<Formulas.datacenterBuildWeeks { s = SimulationEngine.advanceWeek(s) }
        XCTAssertLessThan(s.serverLoad(.northAmerica), 0.9)
    }

    func testPhase7StateRoundTrips() throws {
        var s = newState()
        try s.buildDatacenter(region: .europe)
        try s.rentCloud(region: .europe)
        s.outages[Region.europe.rawValue] = 1
        s.surges[Region.europe.rawValue] = 2
        let loaded = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(s))
        XCTAssertEqual(loaded, s)
    }
}
