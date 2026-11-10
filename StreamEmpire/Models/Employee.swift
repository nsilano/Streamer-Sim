import Foundation

/// A personality quirk that shapes how an employee works, what they cost and how loyal they are.
enum EmployeeTrait: String, Codable, CaseIterable, Identifiable {
    case steady, prodigy, ambitious, frugal, veteran, rookie
    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }

    var blurb: String {
        switch self {
        case .steady: return "Reliable. Rarely quits."
        case .prodigy: return "Brilliant (+15% output) and knows it (+20% salary)."
        case .ambitious: return "Works hard (+5%) but leaves quickly if underpaid."
        case .frugal: return "Happy with less: 15% cheaper."
        case .veteran: return "Seasoned (+10% output), costs 10% more."
        case .rookie: return "Green (-10% output) and cheap (-20%), but learns fast."
        }
    }

    var effectiveness: Double {
        switch self {
        case .steady, .frugal: return 1.0
        case .prodigy: return 1.15
        case .ambitious: return 1.05
        case .veteran: return 1.10
        case .rookie: return 0.90
        }
    }

    var salaryFactor: Double {
        switch self {
        case .steady, .ambitious: return 1.0
        case .prodigy: return 1.2
        case .frugal: return 0.85
        case .veteran: return 1.1
        case .rookie: return 0.8
        }
    }

    var quitFactor: Double {
        switch self {
        case .steady: return 0.5
        case .ambitious: return 2.0
        case .prodigy: return 1.3
        default: return 1.0
        }
    }

    /// Weeks of service per skill gain (rookies learn twice as fast).
    var growthWeeks: Int { self == .rookie ? 52 : 104 }
}

/// One person on your payroll. They belong to a fixed department; no assigning needed.
struct Employee: Codable, Equatable, Identifiable {
    var id: Int
    var name: String
    var department: Department
    var skill: Int                  // 1...3
    var pay: Double                 // relative to the market rate (0.6...1.6)
    var trait: EmployeeTrait = .steady
    var morale = 50.0               // 0...100; 50 is content
    var weeksEmployed = 0

    static let maxSkill = 3

    /// Weekly salary before difficulty scaling.
    var weeklySalary: Double { Double(skill) * Formulas.salaryPerLevelPerWeek * pay * trait.salaryFactor }

    /// 0.85 when miserable, 1.0 when content, 1.15 when delighted.
    var moraleFactor: Double { 0.85 + 0.3 * morale / 100 }

    /// What this person adds to the department's level.
    var output: Double { Double(skill) * Formulas.payEffectiveness(pay) * trait.effectiveness * moraleFactor }

    /// Morale drifts toward this: fair pay keeps people content, generous pay delights them.
    var moraleTarget: Double {
        Formulas.clamp(50 + 100 * (pay - 1) - (trait == .ambitious ? 10 : 0), 0, 100)
    }
}
