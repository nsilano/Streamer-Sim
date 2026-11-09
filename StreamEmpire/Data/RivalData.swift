import Foundation

enum RivalData {
    /// Five fictional parody rivals. `legacySubs` stands in for markets not yet modeled.
    static func initialRivals() -> [Rival] {
        let defs: [(id: String, name: String, personality: RivalPersonality, legacyMillions: Double, growth: Double, strength: Double)] = [
            ("netflux", "Netflux", .globalExpander, 190, 0.0015, 85),
            ("disnay", "Disnay+", .originalsHeavy, 120, 0.0020, 80),
            ("primestream", "PrimeStream", .aggressiveBidder, 110, 0.0018, 75),
            ("maxstream", "MaxStream", .balanced, 70, 0.0012, 70),
            ("hulo", "Hulo", .priceCutter, 45, 0.0010, 55),
        ]
        return defs.map { def in
            var subs: [String: Double] = [:]
            for country in CountryData.all {
                if let share = country.rivalShares[def.id] {
                    subs[country.code] = share * country.subscriberCeiling
                }
            }
            return Rival(id: def.id, name: def.name, personality: def.personality,
                         cash: def.legacyMillions * 20_000_000, catalogStrength: def.strength,
                         subs: subs, legacySubs: def.legacyMillions * 1_000_000,
                         weeklyGrowth: def.growth)
        }
    }
}
