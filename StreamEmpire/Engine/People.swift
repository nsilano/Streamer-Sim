import Foundation

/// Hiring named people, setting their pay and letting them go.
extension GameState {
    static let candidatePoolSize = 6

    /// Recruiting fee for a candidate.
    func hirePrice(_ candidate: Employee) -> Double { scaled(80_000 + 120_000 * Double(candidate.skill)) }

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
        staff.employees.append(person)
    }

    mutating func fire(employeeID: Int) throws {
        guard let index = staff.employees.firstIndex(where: { $0.id == employeeID }) else { throw ActionError.invalidAmount }
        staff.employees.remove(at: index)
    }

    mutating func setSalary(employeeID: Int, pay: Double) throws {
        guard Formulas.payRange.contains(pay) else { throw ActionError.invalidAmount }
        guard let index = staff.employees.firstIndex(where: { $0.id == employeeID }) else { throw ActionError.invalidAmount }
        staff.employees[index].pay = (pay * 100).rounded() / 100
    }

    /// A fresh job seeker with a skill and an asking salary.
    mutating func makeCandidate() -> Employee {
        let department = rng.pick(Department.allCases)
        let skill = rng.pickWeighted([(1, 55.0), (2, 35), (3, 10)])
        let asking = rng.nextDouble(in: 0.9...1.2)
        let taken = Set(staff.employees.map(\.name) + candidates.map(\.name))
        return Employee(id: takeID(), name: PersonNames.make(rng: &rng, avoiding: taken), department: department,
                        skill: skill, pay: (asking * 100).rounded() / 100)
    }

    /// Every 4 weeks two candidates move on and new ones apply.
    mutating func refreshCandidates() {
        if week % 4 == 0, !candidates.isEmpty { candidates.removeFirst(min(2, candidates.count)) }
        while candidates.count < Self.candidatePoolSize { candidates.append(makeCandidate()) }
    }
}

enum People {
    /// Underpaid people may quit; the job board refreshes.
    static func weekly(_ s: inout GameState, events: inout [GameEvent]) {
        var leavers: [Int] = []
        for person in s.staff.employees {
            let chance = Formulas.attritionChance(pay: person.pay)
            if chance > 0, s.rng.chance(chance) { leavers.append(person.id) }
        }
        for id in leavers {
            guard let index = s.staff.employees.firstIndex(where: { $0.id == id }) else { continue }
            let person = s.staff.employees.remove(at: index)
            events.append(s.makeEvent(.warning, "\(person.name) quit",
                                      "Low pay drove them out of \(person.department.displayName), which is now level \(s.staff[person.department])."))
        }
        s.refreshCandidates()
    }
}
