import Foundation

/// Twelve fictional rivals sized after real streaming services (paid subscriptions, spread over the modeled countries).
enum RivalData {
    private struct Def {
        let id: String
        let name: String
        let personality: RivalPersonality
        let totalMillions: Double                  // paid subscribers at game start
        let cashMillions: Double
        let weeklyGrowth: Double
        let strength: Double                       // catalog strength 0...100
        var priceFactor = 1.0                      // brand price level vs the country's fair price
        var regions: [Region: Double] = [:]        // footprint weight by region
        var countries: [String: Double] = [:]      // per-country weight (overrides the region weight)
    }

    private static let defs: [Def] = [
        Def(id: "netflux", name: "Netflux", personality: .globalExpander, totalMillions: 325, cashMillions: 6_000,
            weeklyGrowth: 0.0010, strength: 85, priceFactor: 1.1,
            regions: [.northAmerica: 1.0, .latinAmerica: 1.1, .europe: 1.0, .asiaPacific: 0.85, .middleEast: 0.8, .africa: 0.4]),
        Def(id: "primestream", name: "PrimeStream", personality: .aggressiveBidder, totalMillions: 215, cashMillions: 5_000,
            weeklyGrowth: 0.0010, strength: 78, priceFactor: 0.85,
            regions: [.northAmerica: 1.2, .latinAmerica: 0.7, .europe: 1.0, .asiaPacific: 0.7, .middleEast: 0.4, .africa: 0.2],
            countries: ["IN": 1.2, "JP": 1.1]),
        Def(id: "disnay", name: "Disnay+", personality: .originalsHeavy, totalMillions: 128, cashMillions: 4_000,
            weeklyGrowth: 0.0012, strength: 80, priceFactor: 0.95,
            regions: [.northAmerica: 1.0, .latinAmerica: 0.8, .europe: 0.9, .asiaPacific: 1.0, .middleEast: 0.4, .africa: 0.2],
            countries: ["IN": 0.3]),
        Def(id: "maxstream", name: "MaxStream", personality: .balanced, totalMillions: 125, cashMillions: 2_500,
            weeklyGrowth: 0.0009, strength: 72, priceFactor: 1.05,
            regions: [.northAmerica: 1.0, .latinAmerica: 1.0, .europe: 0.9, .asiaPacific: 0.4, .middleEast: 0.2, .africa: 0.1],
            countries: ["JP": 0.1]),
        Def(id: "parallax", name: "Parallax+", personality: .balanced, totalMillions: 78, cashMillions: 1_200,
            weeklyGrowth: 0.0010, strength: 65, priceFactor: 0.8,
            regions: [.northAmerica: 1.0, .latinAmerica: 0.8, .europe: 0.5, .asiaPacific: 0.4, .middleEast: 0.2, .africa: 0.1]),
        Def(id: "hulo", name: "Hulo", personality: .priceCutter, totalMillions: 52, cashMillions: 800,
            weeklyGrowth: 0.0007, strength: 55, priceFactor: 0.7,
            countries: ["US": 1.0, "JP": 0.12]),
        Def(id: "orchard", name: "Orchard TV", personality: .originalsHeavy, totalMillions: 45, cashMillions: 3_000,
            weeklyGrowth: 0.0012, strength: 82, priceFactor: 1.2,
            regions: [.northAmerica: 1.0, .europe: 0.9, .asiaPacific: 0.8, .latinAmerica: 0.3, .middleEast: 0.5, .africa: 0.05]),
        Def(id: "plume", name: "Plume TV", personality: .priceCutter, totalMillions: 41, cashMillions: 800,
            weeklyGrowth: 0.0008, strength: 55, priceFactor: 0.7,
            countries: ["US": 1.0, "CA": 0.15]),
        Def(id: "spark", name: "Spark Bharat", personality: .regionalChampion, totalMillions: 60, cashMillions: 900,
            weeklyGrowth: 0.0015, strength: 60, priceFactor: 0.5,
            countries: ["IN": 1.0, "US": 0.04, "CA": 0.05, "GB": 0.06, "AU": 0.05, "AE": 0.12, "SA": 0.06,
                        "NZ": 0.04, "ZA": 0.03]),
        Def(id: "eurovue", name: "Eurovue", personality: .regionalChampion, totalMillions: 25, cashMillions: 400,
            weeklyGrowth: 0.0008, strength: 50, priceFactor: 0.9,
            regions: [.europe: 1.0], countries: ["TR": 0.4, "GB": 0.5]),
        Def(id: "mundo", name: "Mundo Play", personality: .regionalChampion, totalMillions: 20, cashMillions: 300,
            weeklyGrowth: 0.0012, strength: 48, priceFactor: 0.6,
            regions: [.latinAmerica: 1.0], countries: ["ES": 0.2, "US": 0.03]),
        Def(id: "kaiju", name: "Kaiju Plus", personality: .nicheSpecialist, totalMillions: 17, cashMillions: 150,
            weeklyGrowth: 0.0020, strength: 60, priceFactor: 0.75,
            regions: [.asiaPacific: 1.2, .northAmerica: 0.8, .europe: 0.6, .latinAmerica: 1.0, .middleEast: 0.3, .africa: 0.1],
            countries: ["JP": 2.5, "KR": 1.2, "ID": 1.5, "TH": 1.5]),
    ]

    /// No single country starts more than this full of rival subscriptions.
    static let maxStartingFill = 0.85

    static func initialRivals() -> [Rival] {
        var rivals: [Rival] = defs.map { def in
            // Spread the rival's total over its footprint in proportion to country size x footprint weight.
            var weights: [String: Double] = [:]
            for country in CountryData.all {
                let weight = def.countries[country.code] ?? def.regions[country.region] ?? 0
                if weight > 0 { weights[country.code] = country.subscriberCeiling * weight }
            }
            let sum = CountryData.all.reduce(0.0) { $0 + (weights[$1.code] ?? 0) }
            var subs: [String: Double] = [:]
            for country in CountryData.all {
                if let w = weights[country.code], sum > 0 { subs[country.code] = def.totalMillions * 1_000_000 * w / sum }
            }
            return Rival(id: def.id, name: def.name, personality: def.personality,
                         cash: def.cashMillions * 1_000_000, catalogStrength: def.strength,
                         subs: subs, priceLevel: 1.0, weeklyGrowth: def.weeklyGrowth,
                         priceFactor: def.priceFactor)
        }

        // Keep every market playable: scale rivals back where together they'd fill too much of a country.
        for country in CountryData.all {
            let total = rivals.reduce(0.0) { $0 + ($1.subs[country.code] ?? 0) }
            let cap = country.subscriberCeiling * maxStartingFill
            if total > cap {
                let factor = cap / total
                for i in rivals.indices { rivals[i].subs[country.code] = (rivals[i].subs[country.code] ?? 0) * factor }
            }
        }
        return rivals
    }
}
