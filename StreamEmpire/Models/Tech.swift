import Foundation

enum Platform: String, Codable, CaseIterable, Identifiable {
    case web, ios, android, smartTV, consoles
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .web: return "Web"
        case .ios: return "iOS app"
        case .android: return "Android app"
        case .smartTV: return "Smart TV app"
        case .consoles: return "Game consoles"
        }
    }

    /// Added to the base reach of the web player.
    var reachBonus: Double {
        switch self {
        case .web: return 0
        case .ios, .android: return 0.10
        case .smartTV: return 0.07
        case .consoles: return 0.03
        }
    }
    var unlockCost: Double {
        switch self {
        case .web: return 0
        case .ios, .android: return 400_000
        case .smartTV: return 900_000
        case .consoles: return 1_200_000
        }
    }
    var buildWeeks: Int {
        switch self {
        case .web: return 0
        case .ios, .android: return 8
        case .smartTV: return 12
        case .consoles: return 16
        }
    }
    var weeklyUpkeep: Double {
        switch self {
        case .web: return 0
        case .ios, .android: return 8_000
        case .smartTV: return 12_000
        case .consoles: return 10_000
        }
    }
}

struct PlatformBuild: Codable, Equatable {
    var platform: Platform
    var weeksLeft: Int
}

enum Department: String, Codable, CaseIterable, Identifiable {
    case content, marketing, engineering, legal, finance
    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }

    var icon: String {
        switch self {
        case .content: return "film.stack"
        case .marketing: return "megaphone.fill"
        case .engineering: return "gearshape.2.fill"
        case .legal: return "building.columns.fill"
        case .finance: return "chart.line.uptrend.xyaxis"
        }
    }

    /// Plain-language description of what the team does for you.
    var summary: String {
        switch self {
        case .content: return "Finds better deals on shows and helps your own productions turn out better."
        case .marketing: return "Makes every marketing dollar bring in more subscribers."
        case .engineering: return "Builds apps faster and keeps your servers cheaper."
        case .legal: return "Keeps regulators happy so fines and compliance costs shrink."
        case .finance: return "Gets you cheaper loans and a higher company valuation."
        }
    }

    /// What this department gives you at a given (pay-adjusted) level.
    func benefit(at level: Double) -> String {
        func n(_ v: Double) -> String { String(format: "%.0f", v) }
        switch self {
        case .content: return "\(n(2 * level))% cheaper licenses, +\(n(2 * level)) original quality"
        case .marketing: return "+\(n(6 * level))% marketing power"
        case .engineering: return "Apps built \(n(level)) weeks faster, \(n(5 * level))% cheaper servers"
        case .legal: return "\(n(15 * level))% smaller fines, \(n(10 * level))% cheaper regulation costs"
        case .finance: return "\(String(format: "%.1f", 0.5 * level)) pts lower loan rates, +\(n(3 * level))% valuation"
        }
    }

    var effectText: String {
        switch self {
        case .content: return "-2% license prices and +2 original quality per level"
        case .marketing: return "+6% marketing effectiveness per level"
        case .engineering: return "-1 week platform build time and -5% CDN cost per level"
        case .legal: return "-15% quota fines, -10% regulation costs, better lobbying per level"
        case .finance: return "-0.5pt loan rates and +3% valuation per level"
        }
    }
}

/// Staff level (0...5) per department.
struct Staff: Codable, Equatable {
    var content = 0
    var marketing = 0
    var engineering = 0
    var legal = 0
    var finance = 0
    /// Pay relative to the market rate (1.0 = market) per department; missing = 1.0.
    var pay: [String: Double] = [:]
    /// Pay for in-house studio crews.
    var studioPay = 1.0

    func payScale(_ department: Department) -> Double { pay[department.rawValue] ?? 1.0 }

    mutating func setPay(_ department: Department, _ value: Double) { pay[department.rawValue] = value }

    /// Level adjusted for pay: well-paid teams outperform, underpaid ones don't.
    func effectiveLevel(_ department: Department) -> Double {
        Double(self[department]) * Formulas.payEffectiveness(payScale(department))
    }

    subscript(department: Department) -> Int {
        get {
            switch department {
            case .content: return content
            case .marketing: return marketing
            case .engineering: return engineering
            case .legal: return legal
            case .finance: return finance
            }
        }
        set {
            switch department {
            case .content: content = newValue
            case .marketing: marketing = newValue
            case .engineering: engineering = newValue
            case .legal: legal = newValue
            case .finance: finance = newValue
            }
        }
    }

    var totalLevels: Int { content + marketing + engineering + legal + finance }

    /// Weekly salary bill, scaled by each department's pay setting.
    var weeklySalaries: Double {
        Department.allCases.reduce(0) {
            $0 + Double(self[$1]) * Formulas.salaryPerLevelPerWeek * payScale($1)
        }
    }
}


/// Friendly pay presets shown instead of raw percentages.
enum PayLevel: String, CaseIterable, Identifiable {
    case low, fair, generous
    var id: String { rawValue }

    var scale: Double {
        switch self {
        case .low: return 0.8
        case .fair: return 1.0
        case .generous: return 1.3
        }
    }

    var title: String {
        switch self {
        case .low: return "Low"
        case .fair: return "Fair"
        case .generous: return "Generous"
        }
    }

    static func closest(to scale: Double) -> PayLevel {
        allCases.min { abs($0.scale - scale) < abs($1.scale - scale) } ?? .fair
    }
}
