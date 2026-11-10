import XCTest
#if canImport(StreamEmpireCore)
@testable import StreamEmpireCore
#else
@testable import StreamEmpire
#endif

final class Phase22Tests: XCTestCase {
    private func newState() -> GameState {
        var s = GameState.newGame(startCountry: "IE", companyName: "Test Co", seed: 77)
        s.eventsEnabled = false
        s.finances.cash = 1e9
        return s
    }

    private func person(id: Int, _ department: Department = .content, skill: Int = 2, pay: Double = 1.0,
                        trait: EmployeeTrait = .steady) -> Employee {
        Employee(id: id, name: "Person \(id)", department: department, skill: skill, pay: pay, trait: trait)
    }

    func testANewGameHasAJobBoardOfNamedCandidates() {
        let s = newState()
        XCTAssertEqual(s.candidates.count, GameState.candidatePoolSize)
        XCTAssertTrue(s.candidates.allSatisfy { !$0.name.isEmpty && (1...3).contains($0.skill) && Formulas.payRange.contains($0.pay) })
        XCTAssertEqual(Set(s.candidates.map(\.name)).count, s.candidates.count, "unique names")
        XCTAssertTrue(s.staff.employees.isEmpty)
    }

    func testHiringACandidateChargesAFeeAndAddsThemToTheirDepartment() throws {
        var s = newState()
        let candidate = s.candidates[0]
        let fee = s.hirePrice(candidate)
        let cash = s.finances.cash
        try s.hire(candidateID: candidate.id)
        XCTAssertEqual(s.finances.cash, cash - fee, accuracy: 0.01)
        XCTAssertFalse(s.candidates.contains { $0.id == candidate.id })
        XCTAssertEqual(s.staff.members(candidate.department).map(\.name), [candidate.name])
        XCTAssertEqual(s.staff[candidate.department], candidate.skill)
        XCTAssertThrowsError(try s.hire(candidateID: candidate.id), "already hired")
    }

    func testAFullDepartmentCannotHire() {
        var s = newState()
        s.staff.employees = [person(id: 1, skill: 3), person(id: 2, skill: 2)]
        s.candidates = [person(id: 3, skill: 1)]
        XCTAssertEqual(s.staff[.content], 5)
        XCTAssertThrowsError(try s.hire(candidateID: 3))
    }

    func testDepartmentLevelIsCombinedSkillCappedAtFive() {
        var staff = Staff()
        staff.employees = [person(id: 1, skill: 3), person(id: 2, skill: 3)]
        XCTAssertEqual(staff[.content], 5)
        XCTAssertEqual(staff.effectiveLevel(.content), 5, accuracy: 1e-9, "output is scaled down over the cap")
        staff.employees = [person(id: 1, skill: 2)]
        XCTAssertEqual(staff.effectiveLevel(.content), 2, accuracy: 1e-9)
    }

    func testTraitsPayAndMoraleShapeOutputAndCost() {
        let base = person(id: 1)
        XCTAssertGreaterThan(person(id: 2, trait: .prodigy).output, base.output)
        XCTAssertGreaterThan(person(id: 2, trait: .prodigy).weeklySalary, base.weeklySalary)
        XCTAssertLessThan(person(id: 2, trait: .frugal).weeklySalary, base.weeklySalary)
        XCTAssertGreaterThan(person(id: 2, pay: 1.4).output, base.output)
        var gloomy = base; gloomy.morale = 10
        var happy = base; happy.morale = 95
        XCTAssertLessThan(gloomy.output, base.output)
        XCTAssertGreaterThan(happy.output, base.output)
        XCTAssertEqual(base.moraleFactor, 1.0, accuracy: 1e-9, "content staff work at face value")
    }

    func testYouSetEachPersonsSalary() throws {
        var s = newState()
        s.staff.employees = [person(id: 1)]
        let before = s.staff.weeklySalaries
        try s.setSalary(employeeID: 1, pay: 1.5)
        XCTAssertEqual(s.staff.weeklySalaries, before * 1.5, accuracy: 1e-6)
        XCTAssertThrowsError(try s.setSalary(employeeID: 1, pay: 2.0))
        XCTAssertThrowsError(try s.setSalary(employeeID: 99, pay: 1.0))
        let fin = SimulationEngine.advanceWeek(s).lastReport!.financials
        XCTAssertGreaterThan(fin.staff, Formulas.baseStaffCostPerWeek + before)
    }

    func testMoraleFollowsPay() {
        var s = newState()
        s.staff.employees = [person(id: 1, pay: 1.4), person(id: 2, pay: 0.8, trait: .steady)]
        for _ in 0..<30 { s = SimulationEngine.advanceWeek(s) }
        let happy = s.staff.employees.first { $0.id == 1 }
        XCTAssertNotNil(happy)
        XCTAssertGreaterThan(happy!.morale, 75)
        if let low = s.staff.employees.first(where: { $0.id == 2 }) { XCTAssertLessThan(low.morale, 40) }
    }

    func testUnderpaidPeopleQuitByName() {
        var s = newState()
        s.staff.employees = [person(id: 1, pay: 0.6, trait: .ambitious)]
        var quitEvent: GameEvent?
        for _ in 0..<500 where !s.staff.employees.isEmpty {
            s = SimulationEngine.advanceWeek(s)
            quitEvent = s.lastReport?.events.first { $0.headline == "Person 1 quit" } ?? quitEvent
        }
        XCTAssertTrue(s.staff.employees.isEmpty)
        XCTAssertNotNil(quitEvent)
    }

    func testFairlyPaidSteadyStaffStay() {
        var s = newState()
        s.staff.employees = [person(id: 1)]
        for _ in 0..<100 { s = SimulationEngine.advanceWeek(s) }
        XCTAssertEqual(s.staff.employees.count, 1)
    }

    func testLongServiceBuildsSkill() {
        var s = newState()
        s.staff.employees = [person(id: 1, skill: 1, trait: .rookie)]
        for _ in 0..<52 { s = SimulationEngine.advanceWeek(s) }
        XCTAssertEqual(s.staff.employees.first?.skill, 2, "rookies learn in a year")
        XCTAssertTrue(s.news.contains { $0.headline == "Person 1 is promoted" })
    }

    func testLettingSomeoneGoCostsSeveranceAndDentsMorale() throws {
        var s = newState()
        s.staff.employees = [person(id: 1), person(id: 2)]
        let cash = s.finances.cash
        let severance = s.severancePrice(s.staff.employees[0])
        try s.fire(employeeID: 1)
        XCTAssertEqual(s.finances.cash, cash - severance, accuracy: 0.01)
        XCTAssertEqual(s.staff.employees.map(\.id), [2])
        XCTAssertLessThan(s.staff.employees[0].morale, 50)
    }

    func testTheJobBoardRefreshes() {
        var s = newState()
        let first = Set(s.candidates.map(\.id))
        for _ in 0..<8 { s = SimulationEngine.advanceWeek(s) }
        XCTAssertEqual(s.candidates.count, GameState.candidatePoolSize)
        XCTAssertNotEqual(Set(s.candidates.map(\.id)), first)
    }

    func testDepartmentEffectsComeFromPeople() throws {
        var s = newState()
        let listing = s.licenseMarket.first { $0.embargoWeeks == 0 }!
        let before = s.licensePrice(listing)
        s.staff.employees = [person(id: 1, .content, skill: 3, trait: .prodigy)]
        XCTAssertLessThan(s.licensePrice(listing), before)
    }

    func testPeopleSurviveSaves() throws {
        var s = newState()
        try s.hire(candidateID: s.candidates[0].id)
        s = SimulationEngine.advanceWeek(s)
        let loaded = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(s))
        XCTAssertEqual(loaded, s)
    }
}
