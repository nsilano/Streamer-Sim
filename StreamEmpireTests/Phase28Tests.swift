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
}
