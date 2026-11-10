import XCTest
#if canImport(StreamEmpireCore)
@testable import StreamEmpireCore
#else
@testable import StreamEmpire
#endif

final class Phase21Tests: XCTestCase {
    private func newState(_ scenario: Scenario = .sandbox) -> GameState {
        var s = GameState.newGame(startCountry: "IE", companyName: "Test Co", seed: 9, scenario: scenario)
        s.eventsEnabled = false
        s.finances.cash = 1e9
        return s
    }

    func testScenarioDefaultsAndDeadlines() {
        XCTAssertEqual(newState().scenario, .sandbox)
        XCTAssertNil(Scenario.sandbox.deadline)
        XCTAssertEqual(Scenario.tenMillion.deadline, 156)
        XCTAssertEqual(newState(.profitable).scenario, .profitable)
        XCTAssertEqual(newState(.dethrone).restarted(sameWorld: true, newSeed: 1).scenario, .dethrone)
    }

    func testReachingTenMillionWinsTheChallengeWithAScore() {
        var s = newState(.tenMillion)
        s.markets["IE"]?.subs = TierSet(ad: 0, standard: 10_500_000, premium: 0)
        s = SimulationEngine.advanceWeek(s)
        XCTAssertEqual(s.outcome, .won)
        XCTAssertGreaterThan(s.score, 0)
    }

    func testMissingTheDeadlineLoses() {
        var s = newState(.tenMillion)
        s.week = 156
        s = SimulationEngine.advanceWeek(s)
        XCTAssertEqual(s.outcome, .lost)
        XCTAssertTrue(s.lossReason?.contains("Time ran out") == true)
    }

    func testProfitChallengeNeedsEightProfitableWeeksAndAnAudience() {
        var s = newState(.profitable)
        s.finances.profitHistory = Array(repeating: 100_000, count: 8)
        XCTAssertNil(Scenarios.verdict(s, totalSubs: 100_000), "audience too small")
        XCTAssertEqual(Scenarios.verdict(s, totalSubs: 600_000)?.won, true)
        s.finances.profitHistory = Array(repeating: 100_000, count: 7) + [-1]
        XCTAssertNil(Scenarios.verdict(s, totalSubs: 600_000))
    }

    func testSandboxHasNoDeadline() {
        var s = newState(.sandbox)
        s.week = 500
        s = SimulationEngine.advanceWeek(s)
        XCTAssertEqual(s.outcome, .playing)
    }

    func testDethroneHasADeadline() {
        var s = newState(.dethrone)
        s.week = 416
        s = SimulationEngine.advanceWeek(s)
        XCTAssertEqual(s.outcome, .lost)
    }

    func testScoreRewardsSpeedAndAudience() {
        var fast = newState(.tenMillion), slow = newState(.tenMillion)
        fast.week = 60; slow.week = 150
        fast.markets["IE"]?.subs = TierSet(ad: 0, standard: 10_000_000, premium: 0)
        slow.markets["IE"]?.subs = TierSet(ad: 0, standard: 10_000_000, premium: 0)
        XCTAssertGreaterThan(Scenarios.score(fast), Scenarios.score(slow))
    }

    func testAdvisorSuggestsMarketsAndCatalogGrowth() {
        let s = newState()
        let recs = s.recommendations()
        XCTAssertTrue(recs.contains { $0.id.hasPrefix("rec-launch-") }, "a rich new company should be told to expand")
        XCTAssertTrue(recs.contains { $0.id == "rec-catalog" || $0.id == "catalog" })
        XCTAssertEqual(Set(recs.map(\.id)).count, recs.count, "no duplicates")
    }

    func testAdvisorPutsUrgentThingsFirstAndFlagsOffers() {
        var s = newState()
        s.finances.cash = -1_000_000
        s.sportsOffers = [SportsOffer(id: 1, name: "Premier Footy League", region: .europe, askPrice: 1, weeksLeft: 3)]
        let recs = s.recommendations()
        XCTAssertTrue(recs.first?.urgent == true)
        XCTAssertTrue(recs.contains { $0.id == "rec-sports" })
        let firstNonUrgent = recs.firstIndex { !$0.urgent } ?? recs.count
        XCTAssertFalse(recs[firstNonUrgent...].contains { $0.urgent })
    }

    func testAdvisorWarnsAboutPiracyAndExpiry() {
        var s = newState()
        s.markets["IE"]?.piracy = 0.3
        var t = Title(id: 1, name: "Old", kind: .series, genre: .drama, language: .english, quality: 70, popularity: 60,
                      ageWeeks: 10, isOriginal: false,
                      license: LicenseTerms(cost: 1, years: 1, regions: [], exclusive: false),
                      weeksRemaining: 5, listingWeeksLeft: 0)
        t.paidPrice = 1
        s.catalog = [t]
        let ids = s.recommendations().map(\.id)
        XCTAssertTrue(ids.contains("rec-piracy-IE"))
        XCTAssertTrue(ids.contains("expiring"))
    }

    func testScenarioStateRoundTrips() throws {
        var s = newState(.profitable)
        s = SimulationEngine.advanceWeek(s)
        let loaded = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(s))
        XCTAssertEqual(loaded, s)
        XCTAssertEqual(loaded.scenario, .profitable)
    }
}
