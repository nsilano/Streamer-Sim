import Foundation

/// Procedural, fictional title generator.
enum TitleGenerator {
    private static let adjectives = [
        "Crimson", "Silent", "Broken", "Golden", "Midnight", "Hidden", "Electric", "Frozen", "Wild", "Last",
        "Hollow", "Velvet", "Burning", "Paper", "Neon", "Lonely", "Iron", "Gentle", "Savage", "Distant",
        "Rusty", "Cosmic", "Quiet", "Bitter", "Lucky", "Scarlet", "Wandering", "Stolen", "Sunny", "Foggy",
        "Amber", "Ashen", "Azure", "Barren", "Bashful", "Blazing", "Bleak", "Blind", "Blue", "Bold",
        "Brave", "Brazen", "Bright", "Brittle", "Bronze", "Burnt", "Calm", "Careless", "Chilled", "Clever",
        "Cloudy", "Cobalt", "Cold", "Copper", "Coral", "Crooked", "Cruel", "Crystal", "Curious", "Dark",
        "Dawn", "Dazzling", "Deadly", "Deep", "Defiant", "Dizzy", "Dusty", "Eager", "Eastern", "Ebony",
        "Emerald", "Empty", "Endless", "Fading", "Fallen", "Fearless", "Feral", "Fierce", "Fiery", "Flaming",
        "Fleeting", "Flickering", "Floating", "Forbidden", "Forgotten", "Fragile", "Frantic", "Frosty", "Furious", "Gilded",
        "Glass", "Gleaming", "Glimmering", "Gloomy", "Glorious", "Grand", "Gray", "Greedy", "Green", "Grim",
        "Hasty", "Haunted", "Heavy", "Hesitant", "Hushed", "Icy", "Idle", "Indigo", "Ivory", "Jade",
        "Jaded", "Jolly", "Keen", "Kind", "Lavender", "Lazy", "Leaden", "Liquid", "Little", "Lofty",
        "Loud", "Lucid", "Lunar", "Magic", "Marble", "Meek", "Mellow", "Mercury", "Mighty", "Misty",
        "Modest", "Molten", "Mossy", "Muted", "Mystic", "Naked", "Narrow", "Noble", "Northern", "Obsidian",
        "Odd", "Olive", "Opal", "Orange", "Pale", "Patient", "Pearl", "Phantom", "Pink", "Plain",
        "Polar", "Proud", "Purple", "Quick", "Radiant", "Rapid", "Raven", "Reckless", "Restless", "Rogue",
        "Rose", "Royal", "Ruby", "Sable", "Sacred", "Sandy", "Sapphire", "Secret", "Shadow", "Sharp",
        "Shattered", "Shimmering", "Shiny", "Silver", "Sleepy", "Slender", "Slow", "Smoky", "Solar", "Solemn",
        "Somber", "Southern", "Spare", "Spicy", "Spiral", "Splendid", "Stark", "Steady", "Steel", "Stormy",
        "Strange", "Sweet", "Swift", "Tangled", "Tender", "Thorny", "Thunder", "Tidal", "Timid", "Tiny",
        "Topaz", "Twilight", "Ultra", "Umber", "Unbroken", "Unseen", "Urban", "Vacant", "Vagrant", "Vast",
        "Verdant", "Vermilion", "Violet", "Vivid", "Wicked", "Windy", "Winter", "Wistful", "Woven", "Yellow",
        "Young", "Zesty", "Zinc", "Amber-Eyed", "Brave-Hearted", "Half-Moon", "Hard-Boiled", "Long-Lost", "Moonlit", "Sunlit",
        "Starlit", "Salt-Stained", "Sun-Baked", "Tough", "Loyal", "Nameless", "Painted", "Patchwork", "Perfect", "Pocket",
        "Prickly", "Rowdy", "Sassy", "Scruffy", "Shabby", "Spooky", "Sticky", "Stubborn", "Sulky", "Sunburnt",
        "Thrifty", "Tipsy", "Wobbly",
    ]
    private static let nouns = [
        "Harbor", "Orchard", "Empire", "Signal", "Garden", "Kingdom", "Letters", "Horizon", "Tide", "Archive",
        "Circus", "Frontier", "Lighthouse", "Promise", "Mirage", "Station", "Carnival", "Compass", "River", "District",
        "Atlas", "Bakery", "Cabin", "Engine", "Valley", "Parade", "Vault", "Summit", "Thread", "Echo",
        "Abbey", "Alley", "Anchor", "Arcade", "Arrow", "Aviary", "Balcony", "Banner", "Barn", "Basin",
        "Beacon", "Bell", "Bench", "Blossom", "Boulevard", "Bridge", "Brook", "Cafe", "Canal", "Canyon",
        "Cargo", "Castle", "Cathedral", "Cave", "Chapel", "Chateau", "Chimney", "Cinder", "Citadel", "Clock",
        "Cloud", "Cobbler", "Comet", "Cottage", "Crater", "Crossing", "Crown", "Current", "Dagger", "Dawn",
        "Delta", "Desert", "Diner", "Dock", "Dome", "Dragon", "Drift", "Dune", "Dynasty", "Eclipse",
        "Embassy", "Ember", "Estate", "Fable", "Factory", "Falcon", "Fathom", "Ferry", "Fjord", "Flame",
        "Flight", "Forest", "Fortress", "Fountain", "Fox", "Furnace", "Gallery", "Gate", "Gazette", "Glacier",
        "Glade", "Grove", "Guild", "Gulf", "Hamlet", "Hangar", "Harvest", "Haven", "Heath", "Heron",
        "Hideout", "Highway", "Hill", "Hive", "Hotel", "Hourglass", "Island", "Jungle", "Junction", "Kennel",
        "Key", "Kitchen", "Knight", "Ladder", "Lagoon", "Lake", "Lantern", "Lattice", "Ledger", "Legend",
        "Library", "Lodge", "Loft", "Lotus", "Manor", "Marsh", "Meadow", "Mill", "Mine", "Monastery",
        "Monument", "Moon", "Motel", "Mountain", "Museum", "Nest", "Night", "Oasis", "Observatory", "Ocean",
        "Orbit", "Outpost", "Palace", "Pantry", "Paradise", "Pasture", "Pavilion", "Peak", "Pier", "Pilgrim",
        "Pillar", "Pirate", "Plaza", "Pond", "Port", "Portal", "Prairie", "Prism", "Prophet", "Quarry",
        "Quartet", "Quest", "Rail", "Rampart", "Reef", "Refuge", "Relic", "Ridge", "Rocket", "Roost",
        "Sail", "Salon", "Sanctuary", "Scholar", "Seaside", "Shipyard", "Shore", "Shrine", "Skyline", "Smithy",
        "Snowfall", "Sparrow", "Spire", "Spring", "Stable", "Stage", "Stairway", "Star", "Storm", "Street",
        "Studio", "Sunrise", "Sunset", "Swan", "Tavern", "Temple", "Terrace", "Theater", "Throne", "Tower",
        "Trail", "Treasure", "Tribe", "Tunnel", "Twin", "Vineyard", "Voyage", "Wagon", "Warden", "Warehouse",
        "Watchtower", "Waterfall", "Wharf", "Whisper", "Willow", "Windmill", "Wolf", "Workshop", "Yard", "Zenith",
        "Zephyr", "Zoo", "Alibi", "Ambush", "Anthem", "Apprentice", "Bandit", "Bargain", "Bounty", "Brawl",
        "Brigade", "Cadet", "Cannon", "Caper", "Chase", "Clue", "Codex", "Conspiracy", "Courier", "Detour",
        "Diplomat", "Disguise", "Duel", "Escape", "Exile", "Fugitive", "Gambit", "Getaway", "Heist", "Hostage",
        "Hunter", "Impostor", "Informant", "Intruder", "Jackpot", "Labyrinth", "Locksmith", "Manifesto", "Maverick", "Mercenary",
        "Mission", "Mutiny", "Negotiator", "Nomad", "Outlaw", "Pursuit", "Quarrel", "Rebel", "Rival", "Rogue",
        "Saboteur", "Sentinel", "Showdown", "Smuggler", "Sniper", "Stakeout", "Syndicate", "Tactician", "Thief", "Traitor",
        "Trap", "Vendetta", "Vigilante", "Warrant",
    ]
    private static let templates: [Genre: [String]] = [
        .drama: ["The {A} {N}", "{N} of the {A}", "Beyond the {N}", "{A} Hearts", "The Last {N}", "{A} Waters", "Under the {A} {N}",
                 "Letters to a {N}", "The {N} Years", "A {A} {N}", "{N} Road", "The {A} Hour", "What the {N} Knew", "{A} Season"],
        .comedy: ["Awkward {N}", "Dad's {A} {N}", "The {N} Club", "Totally {A}", "My {A} {N}", "{A} Neighbors", "Not Another {N}",
                  "Oops, {N}!", "The {A} Roommates", "Mom vs. the {N}", "{N} Night", "Friends with a {N}", "{A} Business"],
        .action: ["{A} Strike", "Operation {N}", "Code {N}", "The {A} Protocol", "{N} Force", "Last {N} Standing", "Fast {N}",
                  "{A} Vengeance", "{N} Down", "Rogue {N}", "The {A} Contract", "Mission: {N}", "{A} Fury"],
        .kids: ["Captain {N}", "{N} Pals", "The Little {N}", "Bubbles and the {A} {N}", "{N} Adventures", "Super {N}", "{A} Friends",
                "The {N} Squad", "Detective {N}", "Hello, {N}!", "{N} Town", "The {A} Little {N}", "Professor {N}'s Lab"],
        .anime: ["{A} Blade Chronicles", "Spirit of the {N}", "Star {N} Academy", "{N} Rider Z", "Legend of the {A} {N}",
                 "{A} Knight {N}", "Beyond the {A} {N}", "The {N} Alchemist", "{A} Moon {N}", "Hero of the {N}", "{N} Tactics"],
        .reality: ["Love on the {N}", "Survive the {N}", "The {A} Challenge", "Swipe Right Island", "Race to the {N}", "{A} Wives of {N}",
                   "The {N} Showdown", "Kitchen {N}", "Dating on the {N}", "{A} Housemates", "Chef vs. {N}", "The {N} Games"],
        .docs: ["Inside the {A} {N}", "The Secret Life of {N}s", "Rise of the {N}", "Planet {A}", "Chasing the {N}", "The {A} Files",
                "Anatomy of a {N}", "Inside {N} City", "The Last {N}", "Hunting the {A} {N}", "{N}: A History", "The Truth About {N}s"],
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
        var name = template
            .replacingOccurrences(of: "{A}", with: adjective)
            .replacingOccurrences(of: "{N}", with: noun)
        // "{N}s" plurals: Library -> Libraries, Fox -> Foxes
        for wrong in ["\(noun)s"] where name.contains(wrong) && (noun.hasSuffix("y") || noun.hasSuffix("s") || noun.hasSuffix("x")) {
            let plural = noun.hasSuffix("y") ? String(noun.dropLast()) + "ies" : (noun.hasSuffix("s") ? noun : noun + "es")
            name = name.replacingOccurrences(of: wrong, with: plural)
        }
        return name
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
        var name = ""
        var kind: TitleKind = .series
        var found = false
        for _ in 0..<60 {
            if let pun = PunTitles.make(genre: genre, rng: &rng), !avoiding.contains(pun.name) {
                name = pun.name; kind = pun.kind; found = true
                break
            }
        }
        if !found {
            name = makeName(genre: genre, rng: &rng)
            kind = rng.chance(0.3) ? .movie : .series
            if avoiding.contains(name) {
                for suffix in romanSuffixes where !avoiding.contains("\(name) \(suffix)") { name = "\(name) \(suffix)"; break }
            }
        }
        return ParodyTitle(name: name, kind: kind, genre: genre, language: genre == .anime ? .japanese : .english)
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
