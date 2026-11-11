import XCTest
#if canImport(StreamEmpireCore)
@testable import StreamEmpireCore
#else
@testable import StreamEmpire
#endif

final class Phase32Tests: XCTestCase {
    private func newState() -> GameState {
        var s = GameState.newGame(startCountry: "IE", companyName: "Test Co", seed: 14)
        s.eventsEnabled = false
        s.finances.cash = 1e9
        s.markets["IE"]?.subs = TierSet(ad: 0, standard: 20_000, premium: 0)
        s.markets["IE"]?.awareness = 0.5
        s.catalog = (0..<30).map {
            Title(id: 800 + $0, name: "K\($0)", kind: .series, genre: .drama, language: .english, quality: 85, popularity: 85,
                  ageWeeks: 2, isOriginal: true, license: nil, weeksRemaining: nil, listingWeeksLeft: 0)
        }
        return s
    }

    func testPausingSignupsStopsNewSubscribersButKeepsRevenue() throws {
        var open = newState(), shut = newState()
        try shut.setSignupsPaused(scope: GameState.allScope, paused: true)
        open = SimulationEngine.advanceWeek(open)
        shut = SimulationEngine.advanceWeek(shut)
        XCTAssertGreaterThan(open.lastReport!.newSubs, 0)
        XCTAssertEqual(shut.lastReport!.newSubs, 0)
        XCTAssertGreaterThan(shut.lastReport!.financials.revenue, 0, "current subscribers still pay")
        XCTAssertLessThan(shut.markets["IE"]!.subs.total, 20_000, "churn continues, nobody joins")
    }

    func testRegionalPauseOnlyAffectsThatRegion() throws {
        var s = newState()
        try s.setSignupsPaused(scope: Region.asiaPacific.rawValue, paused: true)
        XCTAssertTrue(s.signupsPaused(in: .asiaPacific))
        XCTAssertFalse(s.signupsPaused(in: .europe))
        s = SimulationEngine.advanceWeek(s)
        XCTAssertGreaterThan(s.lastReport!.newSubs, 0, "Europe (Ireland) is still open")
        try s.setSignupsPaused(scope: Region.europe.rawValue, paused: true)
        s = SimulationEngine.advanceWeek(s)
        XCTAssertEqual(s.lastReport!.newSubs, 0)
    }

    func testSwitchingInIsAlsoShutWhilePaused() throws {
        var s = newState()
        s.catalog = (0..<60).map {
            Title(id: 900 + $0, name: "C\($0)", kind: .series, genre: .drama, language: .english, quality: 98, popularity: 98,
                  ageWeeks: 2, isOriginal: true, license: nil, weeksRemaining: nil, listingWeeksLeft: 0)
        }
        let country = CountryData.country("IE")!
        let appeal = Formulas.catalogAppeal(s.catalog, in: country)
        s.markets["IE"]?.status = .live
        s.rivals[0].subs["IE"] = 500_000
        var open = s
        XCTAssertGreaterThan(Switching.apply(&open, country: country, appeal: appeal, service: 1).gained, 0)
        try s.setSignupsPaused(scope: GameState.allScope, paused: true)
        XCTAssertEqual(Switching.apply(&s, country: country, appeal: appeal, service: 1).gained, 0)
    }

    func testToggleIsReversibleAndValidated() throws {
        var s = newState()
        try s.setSignupsPaused(scope: GameState.allScope, paused: true)
        XCTAssertTrue(s.anySignupsPaused)
        XCTAssertEqual(s.pausedSignupsText, "everywhere")
        try s.setSignupsPaused(scope: GameState.allScope, paused: true)
        XCTAssertEqual(s.pausedSignups.count, 1, "no duplicates")
        try s.setSignupsPaused(scope: GameState.allScope, paused: false)
        XCTAssertFalse(s.anySignupsPaused)
        XCTAssertThrowsError(try s.setSignupsPaused(scope: "mars", paused: true))
        XCTAssertTrue(s.news.contains { $0.headline.contains("reopens sign-ups") })
    }

    func testOverloadPauseReasonOffersTheBrakeAndAdvisorReminds() throws {
        let before = newState()
        var after = before
        after.markets["IE"]?.subs = TierSet(ad: 0, standard: before.serverCapacity(.europe) * 1.2, premium: 0)
        let reasons = PauseCheck.reasons(before: before, after: after)
        XCTAssertEqual(reasons.first { $0.id == "load100-europe" }?.region, "europe")
        try after.setSignupsPaused(scope: Region.europe.rawValue, paused: true)
        XCTAssertTrue(after.recommendations().contains { $0.id == "rec-signups" })
    }

    func testBrakeSurvivesSaves() throws {
        var s = newState()
        try s.setSignupsPaused(scope: Region.europe.rawValue, paused: true)
        let loaded = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(s))
        XCTAssertEqual(loaded.pausedSignups, ["europe"])
    }
}
