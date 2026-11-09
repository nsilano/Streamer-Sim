import XCTest
#if canImport(StreamEmpireCore)
@testable import StreamEmpireCore
#else
@testable import StreamEmpire
#endif

final class Phase8Tests: XCTestCase {
    private func newState(country: String = "IE", seed: UInt64 = 42) -> GameState {
        var s = GameState.newGame(startCountry: country, companyName: "Test Co", seed: seed)
        s.eventsEnabled = false
        return s
    }

    // MARK: Bankruptcy cutoff

    func testBankruptcyFloorScalesWithRevenue() {
        XCTAssertEqual(Formulas.bankruptcyFloor(annualRevenue: 0), -5_000_000)
        XCTAssertEqual(Formulas.bankruptcyFloor(annualRevenue: 400_000_000), -105_000_000)
        XCTAssertLessThan(Formulas.bankruptcyFloor(annualRevenue: 1e9), Formulas.bankruptcyFloor(annualRevenue: 1e6))
        var s = newState()
        XCTAssertEqual(s.overdraftLimit, 5_000_000)
        s.finances.revenueHistory = Array(repeating: 1_000_000, count: 52)
        XCTAssertEqual(s.overdraftLimit, 5_000_000 + 0.25 * 52_000_000, accuracy: 1)
    }

    func testDebtPastTheLimitIsImmediateBankruptcy() {
        var s = newState()
        s.finances.cash = -6_000_000
        s = SimulationEngine.advanceWeek(s)
        XCTAssertEqual(s.outcome, .lost)
        XCTAssertNotNil(s.lossReason)
        XCTAssertTrue(s.lossReason!.contains("lenders would tolerate"))
        let event = s.lastReport!.events.first { $0.headline == "Bankrupt" }
        XCTAssertNotNil(event)
        // A finished game stays finished.
        let frozen = SimulationEngine.advanceWeek(s)
        XCTAssertEqual(frozen, s)
    }

    func testDebtWithinTheLimitKeepsPlayingWithAWarning() {
        var s = newState()
        s.finances.cash = -3_000_000
        s = SimulationEngine.advanceWeek(s)
        XCTAssertEqual(s.outcome, .playing)
        XCTAssertNil(s.lossReason)
        XCTAssertTrue(s.lastReport!.events.contains { $0.headline.contains("% of your credit limit") })
        XCTAssertTrue(s.advice().contains { $0.id == "cash" && $0.title.contains("limit") })
    }

    func testBiggerCompaniesCanCarryMoreDebt() {
        var s = newState()
        s.finances.revenueHistory = Array(repeating: 10_000_000, count: 52)   // $520M a year
        s.finances.cash = -50_000_000
        s = SimulationEngine.advanceWeek(s)
        XCTAssertEqual(s.outcome, .playing, "$50M of debt is fine at $520M revenue")
        s.finances.cash = -200_000_000
        s = SimulationEngine.advanceWeek(s)
        XCTAssertEqual(s.outcome, .lost)
    }

    func testSpendingCanNeverRunDebtForever() {
        // A company that only loses money must hit the wall within a bounded time.
        var s = newState()
        s.finances.cash = 1_000_000
        s.staff.finance = 5
        var weeks = 0
        while s.outcome == .playing, weeks < 300 {
            s = SimulationEngine.advanceWeek(s)
            weeks += 1
        }
        XCTAssertEqual(s.outcome, .lost)
        XCTAssertLessThan(weeks, 300)
        XCTAssertNotNil(s.lossReason)
    }

    func testLossReasonSurvivesSaves() throws {
        var s = newState()
        s.finances.cash = -9_000_000
        s = SimulationEngine.advanceWeek(s)
        let loaded = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(s))
        XCTAssertEqual(loaded.lossReason, s.lossReason)
        XCTAssertEqual(loaded.outcome, .lost)
    }

    // MARK: Realistic subscriber counts

    func testWorldIsBigEnoughForRealisticSubscriberNumbers() {
        let ceiling = CountryData.all.reduce(0.0) { $0 + $1.subscriberCeiling }
        XCTAssertGreaterThan(ceiling, 1_500_000_000, "streaming subscriptions are counted per service, so the world holds ~1.5-2B")
        XCTAssertLessThan(ceiling, 2_500_000_000)
        XCTAssertEqual(CountryData.country("US")!.subscriptionsPerHousehold, 4.2, accuracy: 1e-9)
        XCTAssertGreaterThan(CountryData.country("US")!.subscriptionsPerHousehold,
                             CountryData.country("IN")!.subscriptionsPerHousehold, "richer homes hold more services")
        XCTAssertGreaterThanOrEqual(CountryData.all.map(\.subscriptionsPerHousehold).min()!, 1.0)
        XCTAssertLessThanOrEqual(CountryData.all.map(\.subscriptionsPerHousehold).max()!, 4.5)
    }

    func testRivalsStartNearRealWorldSizes() {
        let rivals = RivalData.initialRivals()
        func millions(_ id: String) -> Double { rivals.first { $0.id == id }!.totalSubs / 1_000_000 }
        XCTAssertEqual(rivals.count, 12)
        XCTAssertEqual(Set(rivals.map(\.id)).count, 12)
        // Netflux is ~325M paid subscribers (a few percent is shaved where markets would overfill).
        XCTAssertGreaterThan(millions("netflux"), 300)
        XCTAssertLessThan(millions("netflux"), 326)
        XCTAssertGreaterThan(millions("primestream"), 190)
        XCTAssertGreaterThan(millions("disnay"), 110)
        XCTAssertGreaterThan(millions("maxstream"), 110)
        XCTAssertLessThan(millions("kaiju"), 20)
        XCTAssertEqual(rivals.sorted { $0.totalSubs > $1.totalSubs }.first?.id, "netflux")
    }

    func testRegionalRivalsStayAtHome() {
        let rivals = RivalData.initialRivals()
        func keys(_ id: String) -> Set<String> { Set(rivals.first { $0.id == id }!.subs.keys) }
        XCTAssertEqual(keys("hulo"), ["US", "JP"])
        XCTAssertEqual(keys("plume"), ["US", "CA"])
        XCTAssertTrue(keys("mundo").isSuperset(of: ["BR", "MX", "AR", "CO", "CL"]))
        let eurovue = rivals.first { $0.id == "eurovue" }!
        XCTAssertGreaterThan(eurovue.subs["DE"] ?? 0, 10 * (eurovue.subs["TR"] ?? 1) / 10)
        let spark = rivals.first { $0.id == "spark" }!
        XCTAssertGreaterThan(spark.subs["IN"]!, 0.6 * spark.totalSubs, "Spark Bharat is mostly India")
        XCTAssertEqual(rivals.first { $0.id == "netflux" }!.countryCount, 30)
    }

    func testNoCountryStartsOverfullAndYouHaveRoomToGrow() {
        let s = newState(country: "US")
        for country in CountryData.all {
            let rivals = s.rivals.reduce(0.0) { $0 + ($1.subs[country.code] ?? 0) }
            XCTAssertLessThanOrEqual(rivals, country.subscriberCeiling * RivalData.maxStartingFill + 1, country.code)
        }
        let us = CountryData.country("US")!
        let usRivals = s.rivals.reduce(0.0) { $0 + ($1.subs["US"] ?? 0) }
        XCTAssertGreaterThan(us.subscriberCeiling - usRivals, 40_000_000, "the US starts with real headroom")
    }

    func testNewPersonalitiesBehave() {
        XCTAssertEqual(RivalPersonality.regionalChampion.displayName, "Regional champion")
        XCTAssertEqual(RivalPersonality.nicheSpecialist.displayName, "Niche specialist")
        XCTAssertLessThan(Formulas.expansionChance(personality: .regionalChampion),
                          Formulas.expansionChance(personality: .globalExpander))
        for p in [RivalPersonality.regionalChampion, .nicheSpecialist] {
            XCTAssertGreaterThan(Formulas.bidChance(personality: p, quality: 70), 0)
        }
        let personalities = Set(RivalData.initialRivals().map(\.personality))
        XCTAssertTrue(personalities.contains(.regionalChampion) && personalities.contains(.nicheSpecialist))
    }

    func testAllTwelveRivalsSimulateWithoutBlowingUp() {
        var s = newState()
        for _ in 0..<150 { s = SimulationEngine.advanceWeek(s) }
        for r in s.rivals {
            XCTAssertTrue(r.totalSubs.isFinite && r.totalSubs > 0, r.id)
            XCTAssertTrue((0.6...1.15).contains(r.priceLevel), "\(r.id) \(r.priceLevel)")
        }
        for c in CountryData.all {
            let rivals = s.rivals.reduce(0.0) { $0 + ($1.subs[c.code] ?? 0) }
            XCTAssertLessThanOrEqual(rivals + (s.markets[c.code]?.subs.total ?? 0), c.subscriberCeiling + 1, c.code)
        }
        XCTAssertEqual(s.leaderboard.count, 13)
    }
}
