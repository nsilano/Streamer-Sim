import Foundation

/// Local content rules: some countries ban whole genres, and strict ones need mature titles edited first.
enum CountryRules {
    /// Countries at or above this strictness block mature titles until you pay for a local edit.
    static let matureThreshold = 0.7

    static func bannedGenres(_ code: String) -> Set<Genre> {
        switch code {
        case "SA", "AE", "EG", "ID": return [.reality]
        default: return []
        }
    }

    static func strictness(_ code: String) -> Double {
        switch code {
        case "SA": return 0.9
        case "AE": return 0.85
        case "EG": return 0.8
        case "ID": return 0.75
        case "IN": return 0.7
        case "TH": return 0.7
        case "TR": return 0.6
        case "NG", "KE": return 0.55
        case "PL": return 0.45
        case "KR", "JP": return 0.4
        default: return 0.2
        }
    }

    /// Digital services tax on a country's revenue.
    static func taxRate(_ code: String) -> Double {
        switch code {
        case "FR", "ES", "IT", "GB": return 0.03
        case "TR": return 0.075
        case "IN", "ID", "KE", "NG": return 0.02
        case "PL", "AT", "DE": return 0.015
        default: return 0
        }
    }

    static func isStrict(_ code: String) -> Bool { strictness(code) >= matureThreshold }

    /// How tempting piracy is: higher where prices bite harder.
    static func pirateRisk(tolerance: Double) -> Double { min(0.85, max(0.15, 1 - tolerance / 12)) }

    /// Plain-English summary for the country sheet.
    static func summary(_ code: String) -> String? {
        let banned = bannedGenres(code).map(\.displayName).sorted()
        var parts: [String] = []
        if !banned.isEmpty { parts.append("\(banned.joined(separator: ", ")) is banned") }
        if isStrict(code) { parts.append("mature titles need a local edit") }
        return parts.isEmpty ? nil : parts.joined(separator: "; ").capitalizedFirst
    }

    static func codes(in regions: [Region]) -> [String] {
        CountryData.all.filter { regions.contains($0.region) }.map(\.code)
    }
}

private extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}

/// Slow-moving industry shifts that make later years harder.
enum Trends {
    struct Effects { var arpu = 1.0, ads = 1.0, churn = 1.0, adds = 1.0 }
    static let steps: [(week: Int, headline: String, body: String)] = [
        (52, "Password sharing spreads", "Households share logins more and more. Revenue per account slips a little everywhere."),
        (104, "Ad tiers go mainstream", "Advertisers pour money into streaming. Ad revenue rises across the industry."),
        (156, "Viewers expect 4K", "People now expect sharp picture and fast apps. Churn creeps up for services that fall behind."),
        (208, "Streaming fatigue", "Households cut back on subscriptions. Sign-ups get harder to win."),
    ]

    static func effects(week: Int) -> Effects {
        var e = Effects()
        if week >= 52 { e.arpu = 0.98 }
        if week >= 104 { e.ads = 1.06 }
        if week >= 156 { e.churn = 1.02 }
        if week >= 208 { e.adds = 0.95 }
        return e
    }

    static func announce(_ s: inout GameState) {
        for step in steps where step.week == s.week {
            s.addNews(.industry, step.headline, step.body)
        }
    }
}
