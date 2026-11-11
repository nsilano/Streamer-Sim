import Foundation

/// Viewing follows the calendar: long winter nights and the holidays mean more sign-ups and less churn,
/// summers are slow. Week 1 is early January. Latin America runs half a year behind; the tropics barely swing.
enum Seasons {
    struct Effects { var adds = 1.0, churn = 1.0 }

    /// How strongly a region follows the northern-hemisphere seasons (negative = opposite seasons).
    static func strength(_ region: Region) -> Double {
        switch region {
        case .northAmerica, .europe: return 1.0
        case .asiaPacific, .middleEast: return 0.6
        case .latinAmerica: return -0.5
        case .africa: return 0.3
        }
    }

    /// -1 (deep summer) ... +1 (deep winter), by week of the year.
    static func winterness(week: Int) -> Double {
        cos(2 * Double.pi * Double(((week - 1) % 52) - 1) / 52)
    }

    static func isHolidayWeek(_ week: Int) -> Bool { (50...52).contains(((week - 1) % 52) + 1) }

    static func effects(week: Int, region: Region) -> Effects {
        let k = strength(region)
        var adds = 1 + 0.10 * k * winterness(week: week)
        if isHolidayWeek(week), k > 0 { adds += 0.06 * k }
        let churn = 1 - 0.05 * k * winterness(week: week)
        return Effects(adds: adds, churn: churn)
    }

    static func name(week: Int) -> String {
        let w = ((week - 1) % 52) + 1
        switch w {
        case 50...52: return "Holiday season"
        case 1...9: return "Winter"
        case 10...22: return "Spring"
        case 23...35: return "Summer"
        default: return "Autumn"
        }
    }

    /// One line of news when a season turns.
    static func announce(_ s: inout GameState) {
        let w = ((s.week - 1) % 52) + 1
        switch w {
        case 46: s.addNews(.industry, "Holiday season is coming", "Viewing and sign-ups usually jump from now until early January. Good time for promotions and fresh releases.")
        case 24: s.addNews(.industry, "Summer slowdown", "People are outside. Sign-ups soften until autumn, and churn creeps up in the northern hemisphere.")
        case 36: s.addNews(.industry, "Back indoors", "Viewing picks up again as the evenings get longer.")
        default: break
        }
    }
}
