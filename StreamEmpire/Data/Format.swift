import Foundation

/// Display formatting shared by UI and error messages.
enum Format {
    static func money(_ value: Double) -> String {
        let magnitude = abs(value)
        let sign = value < 0 ? "-" : ""
        switch magnitude {
        case 1_000_000_000...: return sign + String(format: "$%.2fB", magnitude / 1_000_000_000)
        case 1_000_000...: return sign + String(format: "$%.2fM", magnitude / 1_000_000)
        case 10_000...: return sign + String(format: "$%.0fK", magnitude / 1_000)
        default: return sign + String(format: "$%.0f", magnitude)
        }
    }

    static func count(_ value: Double) -> String {
        switch value {
        case 1_000_000_000...: return String(format: "%.2fB", value / 1_000_000_000)
        case 1_000_000...: return String(format: "%.2fM", value / 1_000_000)
        case 10_000...: return String(format: "%.0fK", value / 1_000)
        case 1_000...: return String(format: "%.1fK", value / 1_000)
        default: return String(format: "%.0f", value)
        }
    }

    static func percent(_ value: Double) -> String { String(format: "%.0f%%", value * 100) }
    static func percent1(_ value: Double) -> String { String(format: "%.1f%%", value * 100) }
}

/// The in-game calendar: week 1 starts on Monday, January 5, 2026, and every turn is one week.
enum GameCalendar {
    private static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()
    private static let start = calendar.date(from: DateComponents(year: 2026, month: 1, day: 5))!
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "MMM d, yyyy"
        return f
    }()

    static func date(week: Int) -> Date {
        calendar.date(byAdding: .day, value: (max(1, week) - 1) * 7, to: start)!
    }

    /// "Mar 23, 2026"
    static func dateText(week: Int) -> String { formatter.string(from: date(week: week)) }

    /// Your company's age in years (week 1-52 is year 1).
    static func companyYear(week: Int) -> Int { (max(1, week) - 1) / 52 + 1 }
}

extension Format {
    /// "Week 12 · Mar 23, 2026"
    static func stamp(week: Int) -> String { "Week \(week) · \(GameCalendar.dateText(week: week))" }
}
