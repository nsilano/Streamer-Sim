import Foundation

/// The 30-country table (6 regions).
enum CountryData {
    // MARK: Genre taste profiles

    private static func profile(_ d: Double, _ c: Double, _ a: Double, _ k: Double,
                                _ an: Double, _ r: Double, _ doc: Double, _ l: Double) -> [Genre: Double] {
        [.drama: d, .comedy: c, .action: a, .kids: k, .anime: an, .reality: r, .docs: doc, .local: l]
    }

    private static func regionTaste(_ region: Region) -> [Genre: Double] {
        switch region {
        case .northAmerica: return profile(1.1, 1.1, 1.1, 1.0, 0.7, 1.0, 0.9, 0.8)
        case .latinAmerica: return profile(1.2, 1.1, 1.0, 1.0, 0.9, 1.0, 0.8, 1.3)
        case .europe:       return profile(1.1, 1.0, 0.95, 0.9, 0.6, 0.95, 1.15, 1.1)
        case .asiaPacific:  return profile(1.0, 0.9, 1.1, 1.0, 1.2, 0.9, 0.9, 1.2)
        case .middleEast:   return profile(1.2, 0.9, 1.1, 1.0, 0.7, 0.9, 0.9, 1.2)
        case .africa:       return profile(1.0, 1.1, 1.1, 0.9, 0.7, 1.0, 0.8, 1.3)
        }
    }

    // MARK: Rival starting strength

    /// Share of a country's subscriber ceiling each rival holds at game start, by region.
    private static let regionalRivalShare: [String: [Region: Double]] = [
        "netflux": [.northAmerica: 0.22, .latinAmerica: 0.25, .europe: 0.20, .asiaPacific: 0.15, .middleEast: 0.15, .africa: 0.08],
        "disnay": [.northAmerica: 0.14, .latinAmerica: 0.10, .europe: 0.10, .asiaPacific: 0.08, .middleEast: 0.06, .africa: 0.03],
        "primestream": [.northAmerica: 0.16, .latinAmerica: 0.06, .europe: 0.12, .asiaPacific: 0.06, .middleEast: 0.03, .africa: 0.02],
        "maxstream": [.northAmerica: 0.08, .latinAmerica: 0.05, .europe: 0.06, .asiaPacific: 0.03, .middleEast: 0.02, .africa: 0.01],
    ]
    /// Hulo is a regional player.
    private static let huloShare: [String: Double] = ["US": 0.10, "CA": 0.06, "JP": 0.08]

    private static func rivalShares(code: String, region: Region, adStrength: Double) -> [String: Double] {
        var shares: [String: Double] = [:]
        for (rival, byRegion) in regionalRivalShare {
            if let base = byRegion[region], base > 0 {
                shares[rival] = base * (0.8 + 0.4 * adStrength)
            }
        }
        if let hulo = huloShare[code] { shares["hulo"] = hulo }
        return shares
    }

    // MARK: Table

    private static func make(_ code: String, _ name: String, _ flag: String, _ region: Region,
                             households: Double, tolerance: Double, ads: Double,
                             language: Language, quota: Double, launchMillions: Double, risk: Double,
                             unlock: UnlockRequirement? = nil, starter: Bool = false,
                             taste: [Genre: Double] = [:]) -> Country {
        Country(id: code, name: name, flag: flag, region: region,
                households: households, priceTolerance: tolerance, adStrength: ads,
                genreTaste: regionTaste(region).merging(taste) { _, override in override },
                language: language, localQuota: quota,
                rivalShares: rivalShares(code: code, region: region, adStrength: ads),
                launchCost: launchMillions * 1_000_000, regulatoryRisk: risk,
                unlock: unlock, isStarterPick: starter)
    }

    static let all: [Country] = [
        // North America
        make("US", "United States", "🇺🇸", .northAmerica, households: 100, tolerance: 15, ads: 1.0,
             language: .english, quota: 0.10, launchMillions: 30, risk: 0.10,
             unlock: UnlockRequirement(minGlobalSubs: 2_000_000, minCatalogSize: 40)),
        make("CA", "Canada", "🇨🇦", .northAmerica, households: 14, tolerance: 12, ads: 0.9,
             language: .english, quota: 0.30, launchMillions: 4, risk: 0.10, starter: true),
        // Latin America
        make("MX", "Mexico", "🇲🇽", .latinAmerica, households: 25, tolerance: 6, ads: 0.5,
             language: .spanish, quota: 0.25, launchMillions: 5, risk: 0.25),
        make("BR", "Brazil", "🇧🇷", .latinAmerica, households: 50, tolerance: 5, ads: 0.55,
             language: .portuguese, quota: 0.30, launchMillions: 8, risk: 0.30),
        make("AR", "Argentina", "🇦🇷", .latinAmerica, households: 10, tolerance: 4, ads: 0.4,
             language: .spanish, quota: 0.25, launchMillions: 2, risk: 0.35),
        make("CO", "Colombia", "🇨🇴", .latinAmerica, households: 9, tolerance: 4.5, ads: 0.4,
             language: .spanish, quota: 0.20, launchMillions: 1.8, risk: 0.25),
        make("CL", "Chile", "🇨🇱", .latinAmerica, households: 5, tolerance: 6, ads: 0.45,
             language: .spanish, quota: 0.20, launchMillions: 1.3, risk: 0.15),
        // Europe
        make("GB", "United Kingdom", "🇬🇧", .europe, households: 27, tolerance: 12, ads: 0.9,
             language: .english, quota: 0.25, launchMillions: 9, risk: 0.10),
        make("IE", "Ireland", "🇮🇪", .europe, households: 1.5, tolerance: 11, ads: 0.6,
             language: .english, quota: 0.15, launchMillions: 1.2, risk: 0.10, starter: true,
             taste: [.comedy: 1.2, .local: 1.2]),
        make("NL", "Netherlands", "🇳🇱", .europe, households: 7, tolerance: 11, ads: 0.8,
             language: .dutch, quota: 0.20, launchMillions: 2.5, risk: 0.12, starter: true,
             taste: [.comedy: 1.1, .docs: 1.3]),
        make("DE", "Germany", "🇩🇪", .europe, households: 38, tolerance: 11, ads: 0.85,
             language: .german, quota: 0.25, launchMillions: 11, risk: 0.12),
        make("FR", "France", "🇫🇷", .europe, households: 28, tolerance: 10, ads: 0.8,
             language: .french, quota: 0.40, launchMillions: 9, risk: 0.15),
        make("ES", "Spain", "🇪🇸", .europe, households: 16, tolerance: 9, ads: 0.6,
             language: .spanish, quota: 0.30, launchMillions: 5, risk: 0.15),
        make("IT", "Italy", "🇮🇹", .europe, households: 20, tolerance: 9, ads: 0.6,
             language: .italian, quota: 0.30, launchMillions: 6, risk: 0.18),
        make("SE", "Sweden", "🇸🇪", .europe, households: 4.5, tolerance: 12, ads: 0.8,
             language: .swedish, quota: 0.20, launchMillions: 2, risk: 0.08),
        make("PL", "Poland", "🇵🇱", .europe, households: 13, tolerance: 6, ads: 0.5,
             language: .polish, quota: 0.30, launchMillions: 3, risk: 0.15),
        make("TR", "Turkey", "🇹🇷", .europe, households: 20, tolerance: 4, ads: 0.45,
             language: .turkish, quota: 0.30, launchMillions: 4, risk: 0.35),
        // Asia-Pacific
        make("JP", "Japan", "🇯🇵", .asiaPacific, households: 50, tolerance: 9, ads: 0.8,
             language: .japanese, quota: 0.40, launchMillions: 20, risk: 0.12,
             unlock: UnlockRequirement(minGlobalSubs: 1_500_000, minCatalogSize: 35),
             taste: [.anime: 1.9, .local: 1.4]),
        make("KR", "South Korea", "🇰🇷", .asiaPacific, households: 20, tolerance: 9, ads: 0.7,
             language: .korean, quota: 0.40, launchMillions: 7, risk: 0.15,
             taste: [.drama: 1.3, .local: 1.4]),
        make("IN", "India", "🇮🇳", .asiaPacific, households: 80, tolerance: 3, ads: 0.5,
             language: .hindi, quota: 0.35, launchMillions: 15, risk: 0.30,
             unlock: UnlockRequirement(minGlobalSubs: 1_000_000, minCatalogSize: 30),
             taste: [.action: 1.3, .local: 1.4]),
        make("AU", "Australia", "🇦🇺", .asiaPacific, households: 9, tolerance: 12, ads: 0.85,
             language: .english, quota: 0.25, launchMillions: 4, risk: 0.08),
        make("NZ", "New Zealand", "🇳🇿", .asiaPacific, households: 1.7, tolerance: 10, ads: 0.55,
             language: .english, quota: 0.10, launchMillions: 1.0, risk: 0.08, starter: true,
             taste: [.reality: 1.1, .docs: 1.1]),
        make("ID", "Indonesia", "🇮🇩", .asiaPacific, households: 25, tolerance: 3.5, ads: 0.4,
             language: .indonesian, quota: 0.30, launchMillions: 4, risk: 0.30),
        make("TH", "Thailand", "🇹🇭", .asiaPacific, households: 15, tolerance: 5, ads: 0.45,
             language: .thai, quota: 0.30, launchMillions: 3, risk: 0.25),
        // Middle East
        make("AE", "United Arab Emirates", "🇦🇪", .middleEast, households: 2.5, tolerance: 10, ads: 0.7,
             language: .arabic, quota: 0.20, launchMillions: 2, risk: 0.15),
        make("SA", "Saudi Arabia", "🇸🇦", .middleEast, households: 6, tolerance: 9, ads: 0.65,
             language: .arabic, quota: 0.30, launchMillions: 3, risk: 0.30),
        // Africa
        make("ZA", "South Africa", "🇿🇦", .africa, households: 6, tolerance: 6, ads: 0.45,
             language: .english, quota: 0.30, launchMillions: 2, risk: 0.20),
        make("NG", "Nigeria", "🇳🇬", .africa, households: 5, tolerance: 3, ads: 0.3,
             language: .english, quota: 0.30, launchMillions: 1.5, risk: 0.35),
        make("EG", "Egypt", "🇪🇬", .africa, households: 12, tolerance: 3, ads: 0.3,
             language: .arabic, quota: 0.30, launchMillions: 2.5, risk: 0.35),
        make("KE", "Kenya", "🇰🇪", .africa, households: 2, tolerance: 3, ads: 0.25,
             language: .english, quota: 0.30, launchMillions: 0.8, risk: 0.30),
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
