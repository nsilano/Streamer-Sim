import Foundation

/// One person on your payroll, in a fixed department.
struct Employee: Codable, Equatable, Identifiable {
    var id: Int
    var name: String
    var department: Department
    var skill: Int                  // 1...3
    var pay: Double                 // relative to the market rate (0.6...1.6)

    static let maxSkill = 3

    /// Weekly salary before difficulty scaling.
    var weeklySalary: Double { Double(skill) * Formulas.salaryPerLevelPerWeek * pay }

    /// What this person adds to the department's level.
    var output: Double { Double(skill) * Formulas.payEffectiveness(pay) }
}
