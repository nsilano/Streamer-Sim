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
}
