import Foundation

enum Genre: String, Codable, CaseIterable, Identifiable {
    case drama, comedy, action, kids, anime, reality, docs, local
    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
}

enum Language: String, Codable, CaseIterable {
    case english, spanish, french, german, portuguese, italian, dutch, polish, turkish
    case arabic, hindi, japanese, korean, mandarin, indonesian, thai, swedish
    case danish, norwegian, finnish, czech, greek, romanian, hebrew, vietnamese
    case hungarian, slovak, slovenian, croatian, serbian, bulgarian, ukrainian, russian, lithuanian, latvian, estonian
    case albanian, macedonian, georgian, armenian, azerbaijani, persian, bengali, sinhala, nepali, kazakh, uzbek
    case mongolian, khmer, lao, burmese, amharic, swahili
    var displayName: String { rawValue.capitalized }
}

enum Region: String, Codable, CaseIterable, Identifiable {
    case northAmerica, latinAmerica, europe, asiaPacific, middleEast, africa
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .northAmerica: return "North America"
        case .latinAmerica: return "Latin America"
        case .europe: return "Europe"
        case .asiaPacific: return "Asia-Pacific"
        case .middleEast: return "Middle East"
        case .africa: return "Africa"
        }
    }
}

enum Tier: String, Codable, CaseIterable, Identifiable {
    case ad, standard, premium
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .ad: return "Ad-supported"
        case .standard: return "Standard"
        case .premium: return "Premium"
        }
    }
}

enum TitleKind: String, Codable {
    case movie, series
    var displayName: String { rawValue.capitalized }
}

/// One Double per pricing tier. Used for both prices and subscriber counts.
struct TierSet: Codable, Equatable {
    var ad: Double
    var standard: Double
    var premium: Double

    static let zero = TierSet(ad: 0, standard: 0, premium: 0)

    subscript(tier: Tier) -> Double {
        get {
            switch tier {
            case .ad: return ad
            case .standard: return standard
            case .premium: return premium
            }
        }
        set {
            switch tier {
            case .ad: ad = newValue
            case .standard: standard = newValue
            case .premium: premium = newValue
            }
        }
    }

    var total: Double { ad + standard + premium }
}
