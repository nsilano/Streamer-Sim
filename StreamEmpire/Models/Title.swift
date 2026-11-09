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

    func isAvailable(in countryCode: String) -> Bool {
        guard let license = license else { return true }
        return license.regions.isEmpty || license.regions.contains(countryCode)
    }
}
