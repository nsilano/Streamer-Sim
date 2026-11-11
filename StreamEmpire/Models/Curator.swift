import Foundation

/// A hired licensing manager who buys titles for you every week, within the limits you set.
struct Curator: Codable, Equatable {
    var enabled = true                       // pause without firing
    var purchasesPerWeek = Curator.maxPurchasesPerWeek   // most titles signed in a week (presets set their own)
    var capMode: CatalogCapMode = .auto      // how big the manager lets your catalog grow
    var catalogCap = 100                     // used when capMode is .fixed
    var mode: CuratorMode = .custom          // presets size spending to your revenue and cash; custom uses the rules below
    var weeklyBudget = 2_000_000.0           // spending allowance added each week
    var budgetWeek = -1                      // week the weekly allowance was last granted
    var carryBudget = 0.0                    // unspent allowance carried over (up to 3 weeks' worth)
    var maxPricePerTitle = 3_000_000.0
    var minQuality = 55
    var targetCatalogSize = 30               // stop buying once your catalog is this big
    var cashReserve = 2_000_000.0            // never spend below this cash balance
    var allowExclusive = true
    var maxYears = 3                         // longest license they'll sign
    var allowMovies = true
    var allowSeries = true
    var genres: [Genre] = []                 // empty = any genre
    var onlyMyLanguages = true               // only titles in a language you serve (or English)
    var autoRenew = true                     // renew expiring titles automatically when the price is right
    var renewMaxPrice = 1_500_000.0          // most they'll pay for one renewal
    var renewYears = 2                       // renewal length

    static let hireCost = 300_000.0
    static let weeklySalary = 15_000.0
    static let maxPurchasesPerWeek = 3        // for Custom; presets buy more (see CuratorMode.purchasesPerWeek)
}

/// A tier being set up in a market.
struct TierBuild: Codable, Equatable {
    var tier: Tier
    var weeksLeft: Int
}

extension Curator {
    /// Why a listing fails your rules, or nil if it passes them all.
    func rejectReason(_ title: Title, languages: Set<Language>) -> String? {
        guard let license = title.license else { return "format" }
        if title.embargoWeeks > 0 { return "embargo" }
        if title.quality < minQuality { return "quality" }
        if license.years > maxYears { return "years" }
        if license.exclusive && !allowExclusive { return "exclusive" }
        if title.kind == .movie && !allowMovies { return "format" }
        if title.kind == .series && !allowSeries { return "format" }
        if !genres.isEmpty && !genres.contains(title.genre) { return "genre" }
        if onlyMyLanguages && !languages.contains(title.language) { return "language" }
        return nil
    }

    /// Does this listing pass every rule you set?
    func allows(_ title: Title, languages: Set<Language>) -> Bool {
        rejectReason(title, languages: languages) == nil
    }

    func describe(reason: String) -> String {
        switch reason {
        case "embargo": return "not on sale yet"
        case "quality": return "below quality \(minQuality)"
        case "years": return "licenses longer than \(maxYears) yr"
        case "exclusive": return "exclusive deals"
        case "format": return "a format you turned off"
        case "genre": return "outside your genres"
        case "language": return "in languages you don't serve"
        case "tooExpensive": return "above your max price"
        case "overBudget": return "over the budget available"
        case "reserve": return "would dip below your cash reserve"
        default: return reason
        }
    }
}

/// How hard the licensing manager shops. The presets scale with your revenue and cash, keep a safety
/// reserve and stop buying when your runway gets short, so they can't drain an early-game company.
enum CuratorMode: String, Codable, CaseIterable, Identifiable {
    case passive, moderate, aggressive, custom
    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    var blurb: String {
        switch self {
        case .passive: return "Picks up the odd good-value title. Spends about 5% of revenue plus a sliver of cash, keeps 12 weeks of costs in the bank, and stops if you have under 26 weeks of runway."
        case .moderate: return "Steady growth. About 15% of revenue plus a little cash, keeps 8 weeks of costs in the bank, stops under 16 weeks of runway."
        case .aggressive: return "Builds a big library fast. About 30% of revenue plus more cash, keeps 4 weeks of costs in the bank, stops under 8 weeks of runway."
        case .custom: return "You set every rule yourself."
        }
    }

    var revenueShare: Double { self == .passive ? 0.05 : self == .moderate ? 0.15 : 0.30 }
    var cashShare: Double { self == .passive ? 0.003 : self == .moderate ? 0.008 : 0.02 }
    var reserveWeeks: Double { self == .passive ? 12 : self == .moderate ? 8 : 4 }
    var minRunwayWeeks: Double { self == .passive ? 26 : self == .moderate ? 16 : 8 }
    var carryWeeks: Double { self == .passive ? 6 : self == .moderate ? 4 : 3 }
    var minQuality: Int { self == .passive ? 60 : self == .moderate ? 55 : 45 }
    var maxYears: Int { self == .aggressive ? 5 : 3 }
    /// Most titles the manager signs in one week.
    var purchasesPerWeek: Int { self == .passive ? 3 : self == .moderate ? 6 : self == .aggressive ? 15 : Curator.maxPurchasesPerWeek }
}

/// How freely expiring licenses are renewed without asking you. You're only stopped for the rest.
enum RenewalMode: String, Codable, CaseIterable, Identifiable {
    case off, careful, standard, generous
    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    /// Most a renewal may cost per year, relative to what you paid per year.
    var maxPriceRatio: Double {
        switch self { case .off: return 0; case .careful: return 1.0; case .standard: return 1.3; case .generous: return 2.0 }
    }

    /// Most a single renewal may cost as a share of your cash.
    var cashShare: Double {
        switch self { case .off: return 0; case .careful: return 0.02; case .standard: return 0.05; case .generous: return 0.12 }
    }

    var blurb: String {
        switch self {
        case .off: return "Nothing renews by itself; every license follows your expiry alert setting."
        case .careful: return "Renews when it costs no more per year than you paid and under 2% of your cash. Anything pricier is left to you."
        case .standard: return "Renews up to 1.3x what you paid per year and under 5% of your cash. Only unusually expensive renewals are left to you."
        case .generous: return "Renews up to 2x what you paid per year and under 12% of your cash. Only absurd prices are left to you."
        }
    }
}

/// Fine-tuning for automatic renewals, on top of the renewal style.
struct RenewalRules: Codable, Equatable {
    var years = 2                  // term of an automatic renewal (1...5)
    var minQuality = 0             // don't renew titles below this quality
    var dropWeakestShare = 0.0     // let the weakest share of your catalog (by viewers) lapse; 0 renews everything that passes
    var keepSought = true          // sought-after titles are always worth renewing (if the price is accepted)
}

/// What an expiring license that didn't auto-renew does to your game.
enum ExpiryAlerts: String, Codable, CaseIterable, Identifiable {
    case stop, show, ignore
    var id: String { rawValue }
    var title: String {
        switch self { case .stop: return "Stop the sim"; case .show: return "Just show it"; case .ignore: return "Ignore" }
    }
    var blurb: String {
        switch self {
        case .stop: return "Pauses at most once every 4 weeks, when a license hits 4 weeks left, with everything expiring soon in one list."
        case .show: return "Never pauses. Expiring titles show on the Dashboard and in the news; renew whenever you like."
        case .ignore: return "No reminders. Licenses your auto-renew style doesn't take simply end."
        }
    }
}

/// How the manager decides when your catalog is big enough.
enum CatalogCapMode: String, Codable, CaseIterable, Identifiable {
    case auto, fixed, none
    var id: String { rawValue }
    var title: String { self == .auto ? "Auto" : self == .fixed ? "Set a limit" : "No limit" }
}
