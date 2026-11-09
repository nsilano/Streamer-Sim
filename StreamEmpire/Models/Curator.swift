import Foundation

/// A hired licensing manager who buys titles for you every week, within the limits you set.
struct Curator: Codable, Equatable {
    var enabled = true                       // pause without firing
    var weeklyBudget = 2_000_000.0           // spending allowance added each week
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

    static let hireCost = 300_000.0
    static let weeklySalary = 15_000.0
    static let maxPurchasesPerWeek = 3
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
