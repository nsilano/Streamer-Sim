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
