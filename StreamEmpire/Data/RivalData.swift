import Foundation

enum RivalData {
    /// Five fictional parody rivals with starting subscribers in every country they operate in.
    static func initialRivals() -> [Rival] {
        let defs: [(id: String, name: String, personality: RivalPersonality, cashMillions: Double, growth: Double, strength: Double)] = [
            ("netflux", "Netflux", .globalExpander, 4_000, 0.0015, 85),
            ("disnay", "Disnay+", .originalsHeavy, 3_000, 0.0020, 80),
            ("primestream", "PrimeStream", .aggressiveBidder, 3_500, 0.0018, 75),
            ("maxstream", "MaxStream", .balanced, 1_500, 0.0012, 70),
            ("hulo", "Hulo", .priceCutter, 800, 0.0010, 55),
        ]
        return defs.map { def in
            var subs: [String: Double] = [:]
            for country in CountryData.all {
                if let share = country.rivalShares[def.id] {
                    subs[country.code] = share * country.subscriberCeiling
                }
            }
            return Rival(id: def.id, name: def.name, personality: def.personality,
                         cash: def.cashMillions * 1_000_000, catalogStrength: def.strength,
                         subs: subs, priceLevel: 1.0, weeklyGrowth: def.growth)
        }
    }
}
