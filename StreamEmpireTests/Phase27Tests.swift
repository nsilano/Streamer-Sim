import XCTest
#if canImport(StreamEmpireCore)
@testable import StreamEmpireCore
#else
@testable import StreamEmpire
#endif

final class Phase27Tests: XCTestCase {
    private func newState() -> GameState {
        var s = GameState.newGame(startCountry: "IE", companyName: "Test Co", seed: 4)
        s.eventsEnabled = false
        s.finances.cash = 1e9
        return s
    }

    func testQuietWeeksDontPause() {
        let s = newState()
        let next = SimulationEngine.advanceWeek(s)
        XCTAssertTrue(PauseCheck.reasons(before: s, after: next).isEmpty)
    }

    func testExpiringLicensesPause() {
        var s = newState()
        s.catalog = [Title(id: 1, name: "Soon", kind: .series, genre: .drama, language: .english, quality: 70, popularity: 60,
                           ageWeeks: 10, isOriginal: false, license: LicenseTerms(cost: 1, years: 1, regions: [], exclusive: false),
                           weeksRemaining: 13, listingWeeksLeft: 0)]
        let next = SimulationEngine.advanceWeek(s)
        XCTAssertTrue(PauseCheck.reasons(before: s, after: next).contains { $0.id == "expiring" })
    }

    func testServersApproachingCapacityPause() {
        let s = newState()
        var busy = s
        let capacity = busy.serverCapacity(.europe)
        busy.markets["IE"]?.subs = TierSet(ad: 0, standard: capacity * 0.95, premium: 0)
        let reasons = PauseCheck.reasons(before: s, after: busy)
        XCTAssertTrue(reasons.contains { $0.id == "load90-europe" })
        var overloaded = s
        overloaded.markets["IE"]?.subs = TierSet(ad: 0, standard: capacity * 1.2, premium: 0)
        XCTAssertTrue(PauseCheck.reasons(before: s, after: overloaded).contains { $0.id == "load100-europe" })
        XCTAssertFalse(PauseCheck.reasons(before: busy, after: busy).contains { $0.id.hasPrefix("load") }, "only when crossing")
    }

    func testRunningOutOfCashPauses() {
        let s = newState()
        var broke = s
        broke.finances.cash = -10
        XCTAssertTrue(PauseCheck.reasons(before: s, after: broke).contains { $0.id == "cash" })
    }

    func testCrashesPriceWarsRecallsAndLostLicensesPause() {
        let s = newState()
        var after = s
        let events = [
            GameEvent(id: 1, week: 1, kind: .warning, headline: "Servers crashed in Europe", detail: "x"),
            GameEvent(id: 2, week: 1, kind: .warning, headline: "Netflux declares a price war", detail: "x"),
            GameEvent(id: 3, week: 1, kind: .licenseLost, headline: "\"X\" pulled by Netflux", detail: "x"),
            GameEvent(id: 4, week: 1, kind: .licenseExpired, headline: "License expired", detail: "x"),
        ]
        after.lastReport = WeeklyReport(week: 1, newSubs: 0, churned: 0, totalSubs: 0, financials: WeeklyFinancials(),
                                        cashEnd: 0, rank: 1, markets: [], events: events)
        let ids = PauseCheck.reasons(before: s, after: after).map(\.id)
        XCTAssertTrue(ids.contains("crash-1"))
        XCTAssertTrue(ids.contains("war-2"))
        XCTAssertTrue(ids.contains("recall-3"))
        XCTAssertTrue(ids.contains("expired-4"))
    }
}
