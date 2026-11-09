import Foundation

/// A hired licensing manager who buys titles for you every week, within the limits you set.
struct Curator: Codable, Equatable {
    var enabled = true                       // pause without firing
    var weeklyBudget = 500_000.0             // most they may spend per week
    var maxPricePerTitle = 2_000_000.0
    var minQuality = 60
    var targetCatalogSize = 25               // stop buying once your catalog is this big
    var cashReserve = 3_000_000.0            // never spend below this cash balance
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
    /// Does this listing pass every rule you set?
    func allows(_ title: Title, languages: Set<Language>) -> Bool {
        guard let license = title.license else { return false }
        if title.quality < minQuality { return false }
        if license.years > maxYears { return false }
        if license.exclusive && !allowExclusive { return false }
        if title.kind == .movie && !allowMovies { return false }
        if title.kind == .series && !allowSeries { return false }
        if !genres.isEmpty && !genres.contains(title.genre) { return false }
        if onlyMyLanguages && !languages.contains(title.language) { return false }
        return true
    }
}
