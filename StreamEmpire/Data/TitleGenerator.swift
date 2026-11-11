import Foundation

/// Procedural, fictional title generator.
enum TitleGenerator {
    private static let adjectives = [
        "Crimson", "Silent", "Broken", "Golden", "Midnight", "Hidden", "Electric", "Frozen", "Wild", "Last",
        "Hollow", "Velvet", "Burning", "Paper", "Neon", "Lonely", "Iron", "Gentle", "Savage", "Distant",
        "Rusty", "Cosmic", "Quiet", "Bitter", "Lucky", "Scarlet", "Wandering", "Stolen", "Sunny", "Foggy",
    ]
    private static let nouns = [
        "Harbor", "Orchard", "Empire", "Signal", "Garden", "Kingdom", "Letters", "Horizon", "Tide", "Archive",
        "Circus", "Frontier", "Lighthouse", "Promise", "Mirage", "Station", "Carnival", "Compass", "River", "District",
        "Atlas", "Bakery", "Cabin", "Engine", "Valley", "Parade", "Vault", "Summit", "Thread", "Echo",
    ]
    private static let templates: [Genre: [String]] = [
        .drama: ["The {A} {N}", "{N} of the {A}", "Beyond the {N}", "{A} Hearts"],
        .comedy: ["Awkward {N}", "Dad's {A} {N}", "The {N} Club", "Totally {A}"],
        .action: ["{A} Strike", "Operation {N}", "Code {N}", "The {A} Protocol"],
        .kids: ["Captain {N}", "{N} Pals", "The Little {N}", "Bubbles and the {A} {N}"],
        .anime: ["{A} Blade Chronicles", "Spirit of the {N}", "Star {N} Academy", "{N} Rider Z"],
        .reality: ["Love on the {N}", "Survive the {N}", "The {A} Challenge", "Swipe Right Island"],
        .docs: ["Inside the {A} {N}", "The Secret Life of {N}s", "Rise of the {N}", "Planet {A}"],
        .local: ["{A} {N}", "Tales of the {N}", "Family {N}"],
    ]
    private static let genreWeights: [(Genre, Double)] = [
        (.drama, 22), (.comedy, 18), (.action, 16), (.kids, 10), (.anime, 8), (.reality, 10), (.docs, 8), (.local, 8),
    ]
    private static let languageWeights: [(Language, Double)] = [
        (.english, 70), (.spanish, 6), (.french, 5), (.german, 4), (.dutch, 3), (.portuguese, 3),
        (.italian, 2), (.japanese, 3), (.korean, 2), (.hindi, 2),
    ]
    private static let localLanguages: [Language] = [
        .spanish, .french, .german, .dutch, .portuguese, .italian, .hindi, .korean, .japanese,
    ]

    static func makeName(genre: Genre, rng: inout SeededRNG) -> String {
        let template = rng.pick(templates[genre] ?? ["{A} {N}"])
        let adjective = rng.pick(adjectives)
        let noun = rng.pick(nouns)
        return template
            .replacingOccurrences(of: "{A}", with: adjective)
            .replacingOccurrences(of: "{N}", with: noun)
    }

    private static let romanSuffixes = ["II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"]

    /// Picks a parody for the genre that isn't already on the market or in a catalog. When the library
    /// runs dry it reuses a name with a sequel number ("Pulp Friction II").
    static func pickParody(genre: Genre, rng: inout SeededRNG, avoiding: Set<String>) -> ParodyTitle {
        let pool = ParodyLibrary.byGenre[genre] ?? []
        let fresh = pool.filter { !avoiding.contains($0.name) }
        if !fresh.isEmpty { return rng.pick(fresh) }
        var base = rng.pick(pool)
        for suffix in romanSuffixes {
            let candidate = "\(base.name) \(suffix)"
            if !avoiding.contains(candidate) {
                base.name = candidate
                return base
            }
        }
        return base
    }

    /// An original-sounding title (not a parody of anything) for very large catalogs. Never repeats a taken name.
    static func inventedTitle(genre: Genre, rng: inout SeededRNG, avoiding: Set<String>) -> ParodyTitle {
        var name = makeName(genre: genre, rng: &rng)
        var tries = 0
        while avoiding.contains(name), tries < 40 {
            name = makeName(genre: genre, rng: &rng)
            tries += 1
        }
        if avoiding.contains(name) {
            for suffix in romanSuffixes where !avoiding.contains("\(name) \(suffix)") { name = "\(name) \(suffix)"; break }
        }
        let movieShare: Double = [.drama: 0.35, .comedy: 0.4, .action: 0.55, .kids: 0.35, .anime: 0.2, .reality: 0.0, .docs: 0.4][genre] ?? 0.3
        return ParodyTitle(name: name, kind: rng.chance(movieShare) ? .movie : .series, genre: genre,
                           language: genre == .anime ? .japanese : .english)
    }

    /// Generates one licensable title (a fresh market listing), a parody of a real show or movie.
    static func generate(id: Int, rng: inout SeededRNG, avoiding: Set<String> = []) -> Title {
        let genre = rng.pickWeighted(genreWeights)
        var parody = pickParody(genre: genre, rng: &rng, avoiding: avoiding)
        // Once most of a genre's parodies are in use (huge catalogs), invent original-sounding names instead of
        // reusing parodies with sequel numbers.
        if genre != .local {
            let pool = ParodyLibrary.byGenre[genre]?.count ?? 0
            let taken = avoiding.count
            if pool > 0, taken * 8 > pool, rng.chance(min(0.9, Double(taken) / Double(pool))) {
                parody = inventedTitle(genre: genre, rng: &rng, avoiding: avoiding)
            }
        }
        let kind = parody.kind
        let language = parody.language

        let u1 = rng.nextDouble(), u2 = rng.nextDouble(), u3 = rng.nextDouble()
        let quality = Int(25 + 70 * (u1 + u2 + u3) / 3)
        let qualityShare = Double(quality - 25) / 70
        let popularity = min(100, max(5, Int(15 + 80 * (0.5 * qualityShare + 0.5 * rng.nextDouble()))))

        let age = rng.chance(0.25) ? rng.nextInt(in: 0...8) : rng.nextInt(in: 0...300)
        let years = rng.pickWeighted([(1, 25.0), (2, 30.0), (3, 25.0), (4, 12.0), (5, 8.0)])
        let exclusive = rng.chance(0.2)
        let iconic = ParodyLibrary.iconicNames.contains(parody.name)
        let sought = iconic || (quality >= 70 && rng.chance(0.12))
        let quality2 = sought ? max(quality, 78) : quality
        let popularity2 = sought ? max(popularity, 85) : popularity
        let baseCost = Formulas.licenseCost(kind: kind, quality: quality2, popularity: popularity2,
                                            years: years, ageWeeks: age, exclusive: exclusive)
        var cost = sought ? baseCost * Formulas.soughtPremium : baseCost
        // Rights are often sold by territory: cheaper, but only some regions.
        var regions: [String] = []
        if rng.chance(0.25) {
            let count = rng.chance(0.5) ? 1 : 2
            var picked: [Region] = []
            while picked.count < count { let r = rng.pick(Region.allCases); if !picked.contains(r) { picked.append(r) } }
            regions = CountryRules.codes(in: picked)
            let share = Double(regions.count) / Double(CountryData.all.count)
            cost *= Formulas.territoryPriceFactor(share: share)
        }
        let mature = rng.chance(Formulas.matureChance(genre))
        let controversial = rng.chance(0.08)
        let evergreen = rng.chance(0.1)
        let embargo = rng.chance(0.15) ? rng.nextInt(in: 2...6) : 0
        return Title(
            id: id,
            name: parody.name,
            kind: kind, genre: genre, language: language,
            quality: quality2, popularity: popularity2, ageWeeks: age,
            isOriginal: false,
            license: LicenseTerms(cost: cost, years: years, regions: regions, exclusive: exclusive),
            weeksRemaining: nil,
            listingWeeksLeft: embargo + rng.nextInt(in: 4...10),
            sought: sought,
            mature: mature, controversial: controversial, evergreen: evergreen, embargoWeeks: embargo
        )
    }
}
