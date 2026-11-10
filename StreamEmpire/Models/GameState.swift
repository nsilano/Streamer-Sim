import Foundation

enum MarketStatus: Codable, Equatable {
    case notLaunched
    case launching(weeksLeft: Int)
    case live
}

/// Player-side state for one country.
struct MarketState: Codable, Equatable {
    var status: MarketStatus = .notLaunched
    var prices: TierSet
    var subs: TierSet = .zero
    var awareness: Double = 0.02          // 0...1 brand awareness
    var marketingBudget: Double = 0       // $ per week
    var liveTiers: [Tier] = [.standard]   // tiers open for sign-up (existing subscribers keep paying either way)
    var tierBuilds: [TierBuild] = []      // tiers being set up
    var piracy = 0.0                      // 0...0.6: share of would-be customers lost to piracy (last week)

    var isLive: Bool { status == .live }
}

enum GameOutcome: String, Codable {
    case playing, won, lost
}

struct LeaderboardEntry: Identifiable, Equatable {
    var id: String
    var name: String
    var subs: Double
    var isPlayer: Bool
}

struct GameState: Codable, Equatable {
    static let currentVersion = 18

    var version: Int = GameState.currentVersion
    var companyName: String
    var difficulty: Difficulty = .medium       // how costly everything is
    var startCountry = ""                     // for restarting the same playthrough
    var startSeedText = "1"                   // the seed as text (JSON-safe)
    var week: Int = 1
    var rng: SeededRNG
    var nextID: Int = 1
    var outcome: GameOutcome = .playing
    var lossReason: String?                    // why the game ended in a loss (shown to the player)
    var markets: [String: MarketState]
    var catalog: [Title] = []
    var quarterReports: [QuarterReport] = []
    var earningsSentiment = 1.0                // investors' mood after earnings (0.7...1.35); moves your valuation
    var fx: [String: Double] = [:]             // region -> currency strength against the dollar
    var adLoad = 1.0                           // ads per hour: more ad revenue, more irritated viewers
    var features: [String: Int] = [:]          // product features built (name -> level)
    var sportsOffers: [SportsOffer] = []
    var sportsHeld: [SportsRight] = []
    var partnerships: [Partnership] = []
    var acquisitionOffers: [AcquisitionOffer] = []
    var lastSportsResult = ""
    var loanedOut: [LoanedTitle] = []          // titles licensed out to others for a fee
    var titleStats: [Int: TitleStats] = [:]    // per-title viewers and revenue (keyed by title id)
    var licenseMarket: [Title] = []
    var rivals: [Rival]
    var finances: Finances
    var lastReport: WeeklyReport?
    var reportHistory: [WeeklyReport] = []     // last 26 weeks
    var projects: [OriginalProject] = []       // originals in production
    var loans: [Loan] = []
    var equity = Equity()
    var pendingEvent: GameEvent?               // a decision the player must make before advancing
    var queuedEvents: [GameEvent] = []         // outcomes to show in the next report
    var recessionWeeksLeft: Int = 0
    var goals: [String] = []                   // bonus goals achieved: "ipo", "revenue10B", "allMarkets"
    var eventsEnabled = true                   // tests switch random events off
    var previousSubs: [String: Double] = [:]   // leaderboard subs a week ago ("player" or rival id)

    // Tech & operations
    var platforms: [Platform] = [.web]
    var builds: [PlatformBuild] = []
    var datacenters: [Datacenter] = []
    var cloudUnits: [String: Int] = [:]        // Region.rawValue -> rented cloud blocks (100k viewers each)
    var outages: [String: Int] = [:]           // Region.rawValue -> weeks of degraded service after a crash
    var surges: [String: Int] = [:]            // Region.rawValue -> weeks of extra traffic (viral shows, premieres)
    var staff = Staff()
    var studios: [Studio] = []
    var curator: Curator?                      // hired licensing manager (nil = not hired)
    var curatorStatus: String?                 // what the manager did (or why nothing) the last time they shopped
    var news: [NewsItem] = []                  // newest first
    var newsSeenThrough = 0                    // highest news id the player has seen
    var policies: [String: String] = [:]       // policy id -> chosen option id (missing = the default)
    var policyChangedWeek: [String: Int] = [:] // policy id -> week it last changed
    var policyShocks: [PolicyShock] = []       // temporary reactions to recent changes
    var policyLog: [PolicyReaction] = []       // newest first
    var brandTrust = 60.0                      // 0...100: customers' faith in you
    var regulatoryHeat = 0.0                   // 0...100: how closely regulators are watching
    var promotions: [Promotion] = []           // temporary campaigns running now
    var promoHangovers: [PromoHangover] = []   // churn spikes after campaigns end
    var promoHistory: [PromoResult] = []       // newest first
    var promoLastEnded: [String: Int] = [:]    // kind -> week it last ended (for fatigue)
    var pendingPriceChanges: [String: TierSet] = [:]   // country -> prices at the start of the week's edits
    var stakes: [String: Double] = [:]         // rival id -> share of the company you own (0...1)
    var stakeBasis: [String: Double] = [:]     // rival id -> what you paid for those shares
    var takeover: TakeoverBid?                 // hostile bid in progress (one at a time)
    var acquiredRivals: [String] = []          // rivals you have taken over
    var quotaWarned: [String] = []             // countries already warned about the local-content quota
    var lastEventWeek = -100                   // when the last random event happened
    var lastRegulationWeek = -100              // when the last regulation event happened
    var milestonesReached: [String] = []       // rival milestones already reported ("netflux-subs-300")
    var previousRanking: [String] = []         // leaderboard order last week, for "overtakes" stories

    /// Reach multiplier from the platforms you ship on (web only = 0.70, everything = 1.0).
    var platformReach: Double { Formulas.platformReach(platforms) }

    /// How many viewers a region's servers can stream at once: starter hosting + datacenters + rented cloud.
    func serverCapacity(_ region: Region) -> Double {
        let owned = datacenters.filter { $0.region == region }.reduce(0.0) { $0 + $1.capacity }
        let cloud = Double(cloudUnits[region.rawValue] ?? 0) * Formulas.cloudUnitCapacity
        return Formulas.baseServerCapacity + owned + cloud
    }

    /// Player subscribers in a region.
    func subscribers(in region: Region) -> Double {
        var total = 0.0
        for code in markets.keys.sorted() where CountryData.country(code)?.region == region {
            total += markets[code]?.subs.total ?? 0
        }
        return total
    }

    /// Subscribers / capacity. Above 90% viewers notice lag; above 100% they buffer; far above, servers crash.
    func serverLoad(_ region: Region) -> Double { subscribers(in: region) / serverCapacity(region) }

    /// Load including temporary traffic surges.
    func effectiveLoad(_ region: Region) -> Double {
        serverLoad(region) * ((surges[region.rawValue] ?? 0) > 0 ? Formulas.surgeLoadMultiplier : 1.0)
    }

    /// The region where you have the most subscribers (nil before you have any).
    var busiestRegion: Region? {
        var best: (Region, Double)?
        for region in Region.allCases {
            let subs = subscribers(in: region)
            if subs > 0, subs > (best?.1 ?? 0) { best = (region, subs) }
        }
        return best?.0
    }

    static let startingCash: Double = 25_000_000
    static let targetListings = 14

    /// Summed in sorted key order so floating-point results don't depend on dictionary ordering.
    /// How far into the red cash may go before lenders cut you off (a positive number).
    var overdraftLimit: Double { -Formulas.bankruptcyFloor(annualRevenue: finances.annualizedRevenue) }

    var totalSubscribers: Double { markets.keys.sorted().reduce(0) { $0 + (markets[$1]?.subs.total ?? 0) } }

    var liveMarketCodes: [String] {
        markets.filter { $0.value.isLive }.map { $0.key }.sorted()
    }

    /// Player + rivals, sorted by global subscribers (descending).
    var leaderboard: [LeaderboardEntry] {
        var entries = rivals.map {
            LeaderboardEntry(id: $0.id, name: $0.name, subs: $0.totalSubs, isPlayer: false)
        }
        entries.append(LeaderboardEntry(id: "player", name: companyName,
                                        subs: totalSubscribers, isPlayer: true))
        return entries.sorted { $0.subs > $1.subs }
    }

    var rank: Int {
        (leaderboard.firstIndex { $0.isPlayer } ?? 0) + 1
    }

    /// Publishes a story to the news feed (kept to the latest 150).
    mutating func addNews(_ kind: NewsKind, _ headline: String, _ body: String, rival: String? = nil) {
        news.insert(NewsItem(id: takeID(), week: week, kind: kind, headline: headline, body: body, rivalID: rival), at: 0)
        if news.count > 150 { news.removeLast(news.count - 150) }
    }

    var unreadNewsCount: Int { news.filter { $0.id > newsSeenThrough }.count }

    mutating func markNewsRead() { newsSeenThrough = news.first?.id ?? newsSeenThrough }

    mutating func takeID() -> Int {
        defer { nextID += 1 }
        return nextID
    }

    mutating func makeEvent(_ kind: EventKind, _ headline: String, _ detail: String) -> GameEvent {
        GameEvent(id: takeID(), week: week, kind: kind, headline: headline, detail: detail)
    }

    /// Fresh game: pick one starting country, $25M seed cash, empty catalog.
    static func newGame(startCountry: String, companyName: String, seed: UInt64,
                        difficulty: Difficulty = .medium) -> GameState {
        var markets: [String: MarketState] = [:]
        for country in CountryData.all {
            markets[country.code] = MarketState(prices: CountryData.defaultPrices(for: country))
        }
        markets[startCountry]?.status = .live

        var state = GameState(
            companyName: companyName,
            rng: SeededRNG(seed: seed),
            markets: markets,
            rivals: RivalData.initialRivals(),
            finances: Finances(cash: GameState.startingCash)
        )
        state.difficulty = difficulty
        state.startCountry = startCountry
        state.startSeedText = String(seed)
        NewsEngine.seed(&state)
        // Seed the licensing market.
        while state.licenseMarket.count < GameState.targetListings {
            let id = state.takeID()
            let taken = Set(state.licenseMarket.map(\.name))
            state.licenseMarket.append(TitleGenerator.generate(id: id, rng: &state.rng, avoiding: taken))
        }
        state.previousRanking = state.leaderboard.map { $0.id }
        state.addNews(.industry, "The streaming wars begin",
                      "\(state.rivals.count) services already fight for viewers, led by \(state.rivals.first?.name ?? "the incumbents"). Watch this feed for their moves.")
        state.markNewsRead()
        return state
    }
}
