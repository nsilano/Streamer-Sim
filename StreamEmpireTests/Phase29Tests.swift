import XCTest
#if canImport(StreamEmpireCore)
@testable import StreamEmpireCore
#else
@testable import StreamEmpire
#endif

final class Phase29Tests: XCTestCase {
    private func newState(cash: Double = 25_000_000) -> GameState {
        var s = GameState.newGame(startCountry: "IE", companyName: "Test Co", seed: 12)
        s.eventsEnabled = false
        s.finances.cash = cash
        return s
    }

    func testPresetBudgetsScaleWithCashAndRevenue() throws {
        var s = newState()
        try s.hireCurator(mode: .moderate)
        let small = s.effectiveCurator()!.weeklyBudget
        s.finances.cash = 250_000_000
        XCTAssertGreaterThan(s.effectiveCurator()!.weeklyBudget, small * 5, "richer company, bigger budget")
        s.finances.lastWeek.subscriptionRevenue = 5_000_000
        XCTAssertGreaterThan(s.effectiveCurator()!.weeklyBudget, 250_000_000 * CuratorMode.moderate.cashShare)
    }

    func testStylesAreOrderedFromCarefulToBold() throws {
        var budgets: [Double] = []
        for mode in [CuratorMode.passive, .moderate, .aggressive] {
            var s = newState()
            try s.hireCurator(mode: mode)
            budgets.append(s.effectiveCurator()!.weeklyBudget)
            XCTAssertGreaterThanOrEqual(s.effectiveCurator()!.cashReserve, 2_000_000)
        }
        XCTAssertLessThan(budgets[0], budgets[1])
        XCTAssertLessThan(budgets[1], budgets[2])
    }

    func testPresetsStopWhenRunwayIsShort() throws {
        var s = newState(cash: 3_000_000)
        try s.hireCurator(mode: .moderate)
        s.finances.profitHistory = Array(repeating: -1_000_000, count: 4)
        XCTAssertNotNil(s.curatorRunwayBlock)
        let catalog = s.catalog.count
        let run = s.curatorShop()
        XCTAssertTrue(run?.note.contains("Holding off") == true)
        XCTAssertEqual(s.catalog.count, catalog)
    }

    func testCustomKeepsYourOwnRules() throws {
        var s = newState()
        try s.hireCurator()
        XCTAssertEqual(s.curator?.mode, .custom)
        XCTAssertEqual(s.effectiveCurator(), s.curator)
        s.finances.profitHistory = Array(repeating: -1_000_000, count: 4)
        XCTAssertNil(s.curatorRunwayBlock, "custom is never second-guessed")
    }

    func testPassiveSpendsLessThanAggressiveOverAYear() throws {
        func spend(_ mode: CuratorMode) throws -> Double {
            var s = newState()
            try s.hireCurator(mode: mode)
            let start = s.finances.cash
            var licensing = 0.0
            for _ in 0..<52 {
                s = SimulationEngine.advanceWeek(s)
                licensing += s.lastReport!.financials.licensing
            }
            XCTAssertGreaterThan(s.finances.cash, 0, "\(mode): never drains the company (start \(start))")
            return licensing
        }
        let passive = try spend(.passive), aggressive = try spend(.aggressive)
        XCTAssertLessThan(passive, aggressive)
    }

    func testModeSurvivesSaves() throws {
        var s = newState()
        try s.hireCurator(mode: .aggressive)
        let loaded = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(s))
        XCTAssertEqual(loaded.curator?.mode, .aggressive)
    }
}
