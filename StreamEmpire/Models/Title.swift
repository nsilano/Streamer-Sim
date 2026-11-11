import Foundation

struct LicenseTerms: Codable, Equatable {
    var cost: Double
    var years: Int                 // 1...5
    var regions: [String]          // country codes; empty = worldwide
    var exclusive: Bool
    var weeks: Int { years * 52 }
}

struct Title: Codable, Identifiable, Equatable {
    var id: Int
    var name: String
    var kind: TitleKind
    var genre: Genre
    var language: Language
    var quality: Int               // 0...100
    var popularity: Int            // 0...100
    var ageWeeks: Int              // weeks since release
    var isOriginal: Bool
    var license: LicenseTerms?     // nil for originals
    var weeksRemaining: Int?       // owned licenses: weeks until expiry (nil = forever)
    var listingWeeksLeft: Int      // licensing market: weeks the offer stays open
    var subtitles: [Language] = [] // languages with subtitles
    var dubs: [Language] = []      // languages with dubbing
    var sought = false             // a real-world-famous show: scarce, pricey, loved by audiences
    var paidPrice = 0.0            // what you paid for the current license term
    var invested = 0.0             // everything you have spent on it (license, renewals, production)
    var popularityAtPurchase = 0   // popularity when the term was signed (renewals get pricier if it jumped)

    var mature = false             // adult themes: strict countries block it until you pay for a local edit
    var controversial = false      // pulls an audience but can cause scandals
    var evergreen = false          // a classic that never fully goes stale
    var cleared: [String] = []     // strict countries where a local edit has been paid for
    var embargoWeeks = 0           // listing only: weeks until the rights can be bought
    var seasons = 1                // seasons (or installments) made
    var weeklyRelease = false      // released weekly instead of all at once
    var star: StarTier = .none
    var awards = 0
    var noAutoRenew = false        // you never want this one renewed automatically
    var talksBlockedUntil = 0      // listing only: the seller refuses counter-offers until this week

    /// Regional blocking (license territories, banned genres, local edits) was removed at the player's request:
    /// every title plays in every market you operate in. These stay so callers don't need to special-case it.
    func inTerritory(_ countryCode: String) -> Bool { true }
    func blockReason(in countryCode: String) -> String? { nil }
    func isAvailable(in countryCode: String) -> Bool { true }
}
