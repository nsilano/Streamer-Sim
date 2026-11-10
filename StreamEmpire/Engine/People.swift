import Foundation

/// Hiring named people, setting their pay, letting them go, and how they change week to week.
extension GameState {
    static let candidatePoolSize = 6

    /// Recruiting fee for a candidate.
    func hirePrice(_ candidate: Employee) -> Double { scaled(80_000 + 120_000 * Double(candidate.skill)) }

    /// Severance: four weeks of salary.
    func severancePrice(_ employee: Employee) -> Double { scaled(employee.weeklySalary * 4) }

    /// Weekly salary after difficulty scaling.
    func salaryPrice(_ employee: Employee) -> Double { scaled(employee.weeklySalary) }

    mutating func hire(candidateID: Int) throws {
        guard outcome == .playing else { throw ActionError.gameOver }
        guard let index = candidates.firstIndex(where: { $0.id == candidateID }) else { throw ActionError.invalidAmount }
        let person = candidates[index]
        guard staff[person.department] < Formulas.maxDepartmentLevel else {
            throw ActionError.invalidProject("\(person.department.displayName) is full (level \(Formulas.maxDepartmentLevel)). Let someone go first.")
        }
        let fee = hirePrice(person)
        guard finances.cash >= fee else { throw ActionError.insufficientFunds(needed: fee) }
        finances.cash -= fee
        finances.ledger.other += fee
        candidates.remove(at: index)
        var hired = person
        hired.morale = 60
        hired.weeksEmployed = 0
        staff.employees.append(hired)
    }

    mutating func fire(employeeID: Int) throws {
        guard let index = staff.employees.firstIndex(where: { $0.id == employeeID }) else { throw ActionError.invalidAmount }
        let person = staff.employees[index]
        let severance = severancePrice(person)
        finances.cash -= severance
        finances.ledger.other += severance
        staff.employees.remove(at: index)
        // Colleagues notice.
        for i in staff.employees.indices where staff.employees[i].department == person.department {
            staff.employees[i].morale = max(0, staff.employees[i].morale - 5)
        }
    }

    mutating func setSalary(employeeID: Int, pay: Double) throws {
        guard Formulas.payRange.contains(pay) else { throw ActionError.invalidAmount }
        guard let index = staff.employees.firstIndex(where: { $0.id == employeeID }) else { throw ActionError.invalidAmount }
        staff.employees[index].pay = (pay * 100).rounded() / 100
    }

    /// A fresh job seeker with a skill, a trait and an asking salary.
    mutating func makeCandidate() -> Employee {
        let department = rng.pick(Department.allCases)
        let trait = rng.pickWeighted([(EmployeeTrait.steady, 35.0), (.rookie, 15), (.prodigy, 8), (.ambitious, 15),
                                      (.frugal, 12), (.veteran, 15)])
        var skill = rng.pickWeighted([(1, 55.0), (2, 35), (3, 10)])
        if trait == .rookie { skill = 1 }
        if trait == .veteran { skill = max(2, skill) }
        var asking = rng.nextDouble(in: 0.9...1.2)
        if trait == .prodigy { asking += 0.15 }
        if trait == .frugal { asking -= 0.1 }
        let taken = Set(staff.employees.map(\.name) + candidates.map(\.name))
        return Employee(id: takeID(), name: PersonNames.make(rng: &rng, avoiding: taken), department: department,
                        skill: skill, pay: (Formulas.clamp(asking, 0.8, 1.4) * 100).rounded() / 100, trait: trait)
    }

    /// Every 4 weeks two candidates move on and new ones apply.
    mutating func refreshCandidates() {
        if week % 4 == 0, !candidates.isEmpty { candidates.removeFirst(min(2, candidates.count)) }
        while candidates.count < Self.candidatePoolSize { candidates.append(makeCandidate()) }
    }
}

enum People {
    /// Morale drifts with pay; unhappy or underpaid people may quit; long service builds skill.
    static func weekly(_ s: inout GameState, events: inout [GameEvent]) {
        var leavers: [Int] = []
        for i in s.staff.employees.indices {
            var person = s.staff.employees[i]
            person.morale += (person.moraleTarget - person.morale) * 0.15
            person.weeksEmployed += 1
            if person.weeksEmployed % person.trait.growthWeeks == 0, person.skill < Employee.maxSkill {
                person.skill += 1
                s.addNews(.you, "\(person.name) is promoted", "Years in \(person.department.displayName) paid off: skill \(person.skill) of \(Employee.maxSkill).")
            }
            s.staff.employees[i] = person
            let chance = (Formulas.attritionChance(pay: person.pay) + (person.morale < 30 ? 0.01 : 0)) * person.trait.quitFactor
            if chance > 0, s.rng.chance(chance) { leavers.append(person.id) }
        }
        for id in leavers {
            guard let index = s.staff.employees.firstIndex(where: { $0.id == id }) else { continue }
            let person = s.staff.employees.remove(at: index)
            events.append(s.makeEvent(.warning, "\(person.name) quit",
                                      "\(person.department.displayName) lost a skill-\(person.skill) \(person.trait.displayName.lowercased()). Low pay or morale drove them out. \(person.department.displayName) is now level \(s.staff[person.department])."))
        }
        s.refreshCandidates()
    }
}
