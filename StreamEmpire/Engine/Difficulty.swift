import Foundation

enum Difficulty: String, Codable, CaseIterable, Identifiable {
    case easy, medium, hard
    var id: String { rawValue }

    var title: String {
        switch self {
        case .easy: return "Easy"
        case .medium: return "Medium"
        case .hard: return "Hard"
        }
    }

    var blurb: String {
        switch self {
        case .easy: return "Costs 25% lower and rivals grow a little slower. A gentle start."
        case .medium: return "The standard challenge."
        case .hard: return "Costs 40% higher and rivals grow faster. Every dollar counts."
        }
    }

    /// Multiplies what things cost: purchases, builds, hiring and running costs. (Not marketing budgets you set.)
    var costMultiplier: Double {
        switch self {
        case .easy: return 0.75
        case .medium: return 1.0
        case .hard: return 1.4
        }
    }

    var rivalGrowthMultiplier: Double {
        switch self {
        case .easy: return 0.85
        case .medium: return 1.0
        case .hard: return 1.2
        }
    }
}

/// Difficulty-adjusted prices. The UI shows these, and the actions charge them, so they always match.
extension GameState {
    var costScale: Double { difficulty.costMultiplier }

    func scaled(_ amount: Double) -> Double { amount * costScale }

    func launchPrice(_ country: Country) -> Double { scaled(country.launchCost) }

    func platformPrice(_ platform: Platform) -> Double { scaled(platform.unlockCost) }

    func hirePrice(_ department: Department) -> Double { scaled(Formulas.hireCost(currentLevel: staff[department])) }

    var studioFoundingPrice: Double { scaled(Formulas.studioFoundingCost) }

    func studioUpgradePrice(_ studio: Studio) -> Double { scaled(Formulas.studioUpgradeCost(currentLevel: studio.level)) }

    var curatorHirePrice: Double { scaled(Curator.hireCost) }

    var curatorSalary: Double { scaled(Curator.weeklySalary) }

    func localizationPrice(kind: TitleKind, dub: Bool) -> Double {
        scaled(dub ? Formulas.dubCost(kind) : Formulas.subtitleCost(kind))
    }

    func policyPrice(_ option: PolicyOption) -> Double { scaled(option.cost) }

    func datacenterUpkeepPrice(level: Int) -> Double { scaled(Formulas.datacenterUpkeep(level: level)) }

    var cloudUnitPrice: Double { scaled(Formulas.cloudUnitCostPerWeek) }

    func studioUpkeepPrice(_ studio: Studio) -> Double { scaled(Formulas.studioUpkeep(level: studio.level)) * staff.studioPay }
}
