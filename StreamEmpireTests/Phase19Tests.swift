import XCTest
#if canImport(StreamEmpireCore)
@testable import StreamEmpireCore
#else
@testable import StreamEmpire
#endif

final class Phase19Tests: XCTestCase {
    private func newState() -> GameState {
        var s = GameState.newGame(startCountry: "IE", companyName: "Test Co", seed: 21)
        s.eventsEnabled = false
        s.finances.cash = 1e9
        s.markets["IE"]?.subs = TierSet(ad: 0, standard: 50_000, premium: 0)
        return s
    }

    private func original(id: Int = 1, kind: TitleKind = .series, quality: Int = 70, popularity: Int = 60) -> Title {
        Title(id: id, name: "Show \(id)", kind: kind, genre: .drama, language: .english, quality: quality,
              popularity: popularity, ageWeeks: 40, isOriginal: true, license: nil, weeksRemaining: nil,
              listingWeeksLeft: 0, invested: 10_000_000)
    }

    private func finish(_ s: GameState) -> GameState {
        var s = s
        for _ in 0..<60 where !s.projects.isEmpty { s = SimulationEngine.advanceWeek(s) }
        return s
    }

    func testNextSeasonRefreshesTheSameSeries() throws {
        var s = newState()
        s.catalog = [original()]
        try s.orderSeason(titleID: 1, budget: 10_000_000, weeks: 10)
        XCTAssertEqual(s.projects.count, 1)
        XCTAssertEqual(s.projects[0].name, "Show 1")
        XCTAssertThrowsError(try s.orderSeason(titleID: 1, budget: 10_000_000, weeks: 10), "one season at a time")
        s = finish(s)
        XCTAssertEqual(s.catalog.count, 1, "same show, not a new title")
        XCTAssertEqual(s.catalog[0].seasons, 2)
        XCTAssertLessThan(s.catalog[0].ageWeeks, 40, "a new season counts as fresh")
        XCTAssertEqual(s.catalog[0].invested, 20_000_000, accuracy: 1)
    }

    func testMovieSequelIsANewTitleWithCarriedPopularity() throws {
        var s = newState()
        s.catalog = [original(kind: .movie, quality: 70, popularity: 90)]
        try s.orderSeason(titleID: 1, budget: 5_000_000, weeks: 10)
        XCTAssertEqual(s.projects[0].name, "Show 1 II")
        s = finish(s)
        XCTAssertEqual(s.catalog.count, 2)
        let sequel = s.catalog.first { $0.id != 1 }!
        XCTAssertEqual(sequel.seasons, 2)
        XCTAssertGreaterThanOrEqual(sequel.popularity, 80, "fans carry over")
    }

    func testLaterSeasonsCostMore() throws {
        var a = newState(), b = newState()
        var t = original(); t.seasons = 1
        a.catalog = [t]
        t.seasons = 4
        b.catalog = [t]
        try a.orderSeason(titleID: 1, budget: 10_000_000, weeks: 10)
        try b.orderSeason(titleID: 1, budget: 10_000_000, weeks: 10)
        XCTAssertGreaterThan(b.projects[0].weeklyCost, a.projects[0].weeklyCost)
        var done = original(); done.seasons = 8
        a.projects = []
        a.catalog = [done]
        XCTAssertThrowsError(try a.orderSeason(titleID: 1, budget: 10_000_000, weeks: 10))
        var licensed = original(); licensed.isOriginal = false
        a.catalog = [licensed]
        XCTAssertThrowsError(try a.orderSeason(titleID: 1, budget: 10_000_000, weeks: 10))
    }

    func testStarsCostMoreAndLiftQuality() throws {
        var plain = newState(), starry = newState()
        try plain.commissionOriginal(kind: .series, genre: .drama, language: .english, budget: 10_000_000, weeks: 20)
        try starry.commissionOriginal(kind: .series, genre: .drama, language: .english, budget: 10_000_000, weeks: 20,
                                      star: .aList)
        XCTAssertEqual(starry.projects[0].weeklyCost / plain.projects[0].weeklyCost, StarTier.aList.costFactor, accuracy: 1e-9)
        var qPlain = 0.0, qStar = 0.0
        for seed in 1...8 {
            var a = plain, b = starry
            a.rng = SeededRNG(seed: UInt64(seed)); b.rng = SeededRNG(seed: UInt64(seed))
            a = finish(a); b = finish(b)
            qPlain += Double(a.catalog.first { $0.isOriginal }?.quality ?? 0)
            qStar += Double(b.catalog.first { $0.isOriginal }?.quality ?? 0)
        }
        XCTAssertGreaterThan(qStar, qPlain)
    }

    func testStarTakesACutOfRevenue() {
        var s = newState()
        var t = original(); t.star = .aList
        s.catalog = [t]
        for _ in 0..<3 { s = SimulationEngine.advanceWeek(s) }
        let revenue = s.stats(for: s.catalog[0]).weeklyRevenue
        XCTAssertGreaterThan(revenue, 0)
        XCTAssertEqual(s.talentShares(), revenue * StarTier.aList.profitShare, accuracy: 1e-6)
        var plain = newState()
        plain.catalog = [original()]
        for _ in 0..<3 { plain = SimulationEngine.advanceWeek(plain) }
        XCTAssertEqual(plain.talentShares(), 0)
    }

    func testWeeklyReleasesLastLonger() {
        let ie = CountryData.country("IE")!
        var binge = original(); binge.ageWeeks = 2
        var weekly = binge; weekly.weeklyRelease = true
        XCTAssertGreaterThan(Formulas.titleAppeal(binge, in: ie), Formulas.titleAppeal(weekly, in: ie), "binge launches bigger")
        binge.ageWeeks = 120; weekly.ageWeeks = 120
        XCTAssertGreaterThan(Formulas.titleAppeal(weekly, in: ie), Formulas.titleAppeal(binge, in: ie), "weekly lasts longer")
    }

    func testAwardsSeasonRewardsStrongOriginals() {
        var s = newState()
        s.catalog = [original(quality: 95, popularity: 80)]
        var events: [GameEvent] = []
        let trust = s.brandTrust
        for _ in 0..<50 where s.catalog[0].awards == 0 { Awards.season(&s, events: &events) }
        XCTAssertGreaterThan(s.catalog[0].awards, 0)
        XCTAssertGreaterThan(s.brandTrust, trust)
        XCTAssertTrue(s.news.contains { $0.headline.contains("awards season") })
        // Licensed titles never compete.
        var licensed = original(); licensed.isOriginal = false
        s.catalog = [licensed]
        Awards.season(&s, events: &events)
        XCTAssertEqual(s.catalog[0].awards, 0)
    }

    func testAwardsHappenOnSchedule() {
        var s = newState()
        s.catalog = [original(quality: 100, popularity: 100)]
        s.week = 44
        var plays = 0
        for i in 0..<40 {
            var copy = s
            copy.rng = SeededRNG(seed: UInt64(100 + i))
            copy = SimulationEngine.advanceWeek(copy)
            if copy.catalog[0].awards > 0 { plays += 1 }
        }
        XCTAssertGreaterThan(plays, 10)
    }

    func testBatchTwoStateRoundTrips() throws {
        var s = newState()
        s.catalog = [original()]
        try s.orderSeason(titleID: 1, budget: 10_000_000, weeks: 10, release: .weekly, star: .rising)
        let loaded = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(s))
        XCTAssertEqual(loaded, s)
        XCTAssertEqual(loaded.projects[0].star, .rising)
    }
}
