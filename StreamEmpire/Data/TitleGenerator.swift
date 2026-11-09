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

    /// Generates one licensable title (a fresh market listing).
    static func generate(id: Int, rng: inout SeededRNG) -> Title {
        let genre = rng.pickWeighted(genreWeights)
        let kind: TitleKind = rng.chance(0.55) ? .movie : .series

        let language: Language
        switch genre {
        case .anime: language = .japanese
        case .local: language = rng.pick(localLanguages)
        default: language = rng.pickWeighted(languageWeights)
        }

        let u1 = rng.nextDouble(), u2 = rng.nextDouble(), u3 = rng.nextDouble()
        let quality = Int(25 + 70 * (u1 + u2 + u3) / 3)
        let qualityShare = Double(quality - 25) / 70
        let popularity = min(100, max(5, Int(15 + 80 * (0.5 * qualityShare + 0.5 * rng.nextDouble()))))

        let age = rng.chance(0.25) ? rng.nextInt(in: 0...8) : rng.nextInt(in: 0...300)
        let years = rng.pickWeighted([(1, 25.0), (2, 30.0), (3, 25.0), (4, 12.0), (5, 8.0)])
        let exclusive = rng.chance(0.2)
        let cost = Formulas.licenseCost(kind: kind, quality: quality, popularity: popularity,
                                        years: years, ageWeeks: age, exclusive: exclusive)
        return Title(
            id: id,
            name: makeName(genre: genre, rng: &rng),
            kind: kind, genre: genre, language: language,
            quality: quality, popularity: popularity, ageWeeks: age,
            isOriginal: false,
            license: LicenseTerms(cost: cost, years: years, regions: [], exclusive: exclusive),
            weeksRemaining: nil,
            listingWeeksLeft: rng.nextInt(in: 4...10)
        )
    }
}
