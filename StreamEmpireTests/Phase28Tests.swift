import XCTest
#if canImport(StreamEmpireCore)
@testable import StreamEmpireCore
#else
@testable import StreamEmpire
#endif

final class Phase28Tests: XCTestCase {
    func testTheCalendarStartsInJanuary2026AndAdvancesAWeekPerTurn() {
        XCTAssertEqual(GameCalendar.dateText(week: 1), "Jan 5, 2026")
        XCTAssertEqual(GameCalendar.dateText(week: 2), "Jan 12, 2026")
        XCTAssertEqual(GameCalendar.dateText(week: 53), "Jan 4, 2027")
        XCTAssertEqual(Format.stamp(week: 12), "Week 12 · Mar 23, 2026")
    }

    func testCompanyAge() {
        XCTAssertEqual(GameCalendar.companyYear(week: 1), 1)
        XCTAssertEqual(GameCalendar.companyYear(week: 52), 1)
        XCTAssertEqual(GameCalendar.companyYear(week: 53), 2)
    }

    func testTrendKeepsAWeeklyHistoryForTheCharts() {
        var s = GameState.newGame(startCountry: "IE", companyName: "Test Co", seed: 2)
        s.eventsEnabled = false
        s.finances.cash = 1e9
        for _ in 0..<60 { s = SimulationEngine.advanceWeek(s) }
        XCTAssertEqual(s.trend.count, 60, "a full year and more, not just the last 26 reports")
        XCTAssertEqual(s.trend.first?.week, 1)
        XCTAssertEqual(s.trend.last?.cash ?? 0, s.lastReport!.cashEnd, accuracy: 0.01)
    }
}
