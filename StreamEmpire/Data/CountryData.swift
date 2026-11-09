import Foundation

/// Country table. Phase 1 ships the four starter markets; Phase 2 expands to all 30.
enum CountryData {
    private static func taste(drama: Double, comedy: Double, action: Double, kids: Double,
                              anime: Double, reality: Double, docs: Double, local: Double) -> [Genre: Double] {
        [.drama: drama, .comedy: comedy, .action: action, .kids: kids,
         .anime: anime, .reality: reality, .docs: docs, .local: local]
    }

    static let all: [Country] = [
        Country(id: "IE", name: "Ireland", flag: "🇮🇪", region: .europe,
                households: 1.5, priceTolerance: 11, adStrength: 0.6,
                genreTaste: taste(drama: 1.1, comedy: 1.2, action: 0.9, kids: 0.8, anime: 0.5, reality: 1.0, docs: 1.0, local: 1.2),
                language: .english, localQuota: 0.15,
                rivalShares: ["netflux": 0.18, "disnay": 0.08, "primestream": 0.10, "hulo": 0.01, "maxstream": 0.04],
                launchCost: 1_200_000, regulatoryRisk: 0.10, unlock: nil, isStarterPick: true),
        Country(id: "NZ", name: "New Zealand", flag: "🇳🇿", region: .asiaPacific,
                households: 1.7, priceTolerance: 10, adStrength: 0.55,
                genreTaste: taste(drama: 1.0, comedy: 1.1, action: 1.0, kids: 0.9, anime: 0.6, reality: 1.1, docs: 1.1, local: 1.1),
                language: .english, localQuota: 0.10,
                rivalShares: ["netflux": 0.20, "disnay": 0.10, "primestream": 0.08, "hulo": 0.02, "maxstream": 0.03],
                launchCost: 1_000_000, regulatoryRisk: 0.08, unlock: nil, isStarterPick: true),
        Country(id: "NL", name: "Netherlands", flag: "🇳🇱", region: .europe,
                households: 7.0, priceTolerance: 11, adStrength: 0.8,
                genreTaste: taste(drama: 1.0, comedy: 1.1, action: 1.0, kids: 0.9, anime: 0.7, reality: 0.9, docs: 1.3, local: 1.0),
                language: .dutch, localQuota: 0.20,
                rivalShares: ["netflux": 0.22, "disnay": 0.10, "primestream": 0.12, "hulo": 0.02, "maxstream": 0.06],
                launchCost: 2_500_000, regulatoryRisk: 0.12, unlock: nil, isStarterPick: true),
        Country(id: "CA", name: "Canada", flag: "🇨🇦", region: .northAmerica,
                households: 14.0, priceTolerance: 12, adStrength: 0.9,
                genreTaste: taste(drama: 1.1, comedy: 1.1, action: 1.1, kids: 1.0, anime: 0.7, reality: 1.0, docs: 0.9, local: 0.8),
                language: .english, localQuota: 0.30,
                rivalShares: ["netflux": 0.22, "disnay": 0.10, "primestream": 0.12, "hulo": 0.04, "maxstream": 0.05],
                launchCost: 4_000_000, regulatoryRisk: 0.10, unlock: nil, isStarterPick: true),
    ]

    static let byCode: [String: Country] = Dictionary(uniqueKeysWithValues: all.map { ($0.code, $0) })

    static func country(_ code: String) -> Country? { byCode[code] }

    static var starters: [Country] { all.filter { $0.isStarterPick } }

    /// Sensible opening prices, rounded to the nearest 50 cents.
    static func defaultPrices(for country: Country) -> TierSet {
        func round(_ v: Double) -> Double { (v * 2).rounded() / 2 }
        let t = country.priceTolerance
        return TierSet(ad: round(t * 0.45), standard: round(t), premium: round(t * 1.5))
    }
}
