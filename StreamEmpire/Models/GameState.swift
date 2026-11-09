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
    static let currentVersion = 2

    var version: Int = GameState.currentVersion
    var companyName: String
    var week: Int = 1
    var rng: SeededRNG
    var nextID: Int = 1
    var outcome: GameOutcome = .playing
    var markets: [String: MarketState]
    var catalog: [Title] = []
    var licenseMarket: [Title] = []
    var rivals: [Rival]
    var finances: Finances
    var lastReport: WeeklyReport?
    var reportHistory: [WeeklyReport] = []     // last 26 weeks
    var previousSubs: [String: Double] = [:]   // leaderboard subs a week ago ("player" or rival id)

    // Placeholders until Phase 4 (tech & infrastructure).
    var platformReach: Double = 0.8            // 0...1+, from unlocked platforms
    var serviceQuality: Double = 1.0           // 0...1, from CDN capacity

    static let startingCash: Double = 25_000_000
    static let targetListings = 14

    /// Summed in sorted key order so floating-point results don't depend on dictionary ordering.
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

    mutating func takeID() -> Int {
        defer { nextID += 1 }
        return nextID
    }

    mutating func makeEvent(_ kind: EventKind, _ headline: String, _ detail: String) -> GameEvent {
        GameEvent(id: takeID(), week: week, kind: kind, headline: headline, detail: detail)
    }

    /// Fresh game: pick one starting country, $25M seed cash, empty catalog.
    static func newGame(startCountry: String, companyName: String, seed: UInt64) -> GameState {
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
        // Seed the licensing market.
        while state.licenseMarket.count < GameState.targetListings {
            let id = state.takeID()
            state.licenseMarket.append(TitleGenerator.generate(id: id, rng: &state.rng))
        }
        return state
    }
}
