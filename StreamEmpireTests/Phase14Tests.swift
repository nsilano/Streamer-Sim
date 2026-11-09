import XCTest
#if canImport(StreamEmpireCore)
@testable import StreamEmpireCore
#else
@testable import StreamEmpire
#endif

final class Phase14Tests: XCTestCase {
    private func newState(seed: UInt64 = 42) -> GameState {
        var s = GameState.newGame(startCountry: "IE", companyName: "Test Co", seed: seed)
        s.eventsEnabled = false
        s.finances.cash = 1e12
        return s
    }

    private func headlines(_ s: GameState) -> [String] { s.news.map(\.headline) }

    // MARK: Your price changes

    func testPriceChangesBecomeOneStoryWithRealDollars() throws {
        var s = newState()
        let before = s.markets["IE"]!.prices
        try s.setPrices(code: "IE", prices: TierSet(ad: before.ad, standard: 12.99, premium: before.premium))
        XCTAssertFalse(headlines(s).contains { $0.contains("raises prices") }, "published at the end of the week, not instantly")
        s = SimulationEngine.advanceWeek(s)
        let story = s.news.first { $0.headline == "Test Co raises prices in Ireland" }
        XCTAssertNotNil(story)
        XCTAssertEqual(story?.kind, .pricing)
        XCTAssertNil(story?.rivalID)
        XCTAssertTrue(story!.body.contains("Standard $11.00 → $12.99"), story!.body)
        XCTAssertFalse(story!.body.contains("Ad-supported"), "only changed tiers are listed")
        XCTAssertTrue(s.pendingPriceChanges.isEmpty)
    }

    func testManyEditsInAWeekCollapseToTheNetChange() throws {
        var s = newState()
        let start = s.markets["IE"]!.prices
        for step in 1...6 {
            var p = start
            p.standard = start.standard + Double(step) * 0.5
            try s.setPrices(code: "IE", prices: p)
        }
        s = SimulationEngine.advanceWeek(s)
        let stories = s.news.filter { $0.headline.contains("prices in Ireland") }
        XCTAssertEqual(stories.count, 1)
        XCTAssertTrue(stories[0].body.contains("→ $14.00"), stories[0].body)
    }

    func testGoingBackToWhereYouStartedIsNotNews() throws {
        var s = newState()
        let start = s.markets["IE"]!.prices
        var changed = start
        changed.standard += 3
        try s.setPrices(code: "IE", prices: changed)
        try s.setPrices(code: "IE", prices: start)
        s = SimulationEngine.advanceWeek(s)
        XCTAssertFalse(headlines(s).contains { $0.contains("prices in Ireland") })
    }

    func testCutsAndShufflesAreWordedCorrectly() throws {
        var s = newState()
        let start = s.markets["IE"]!.prices
        try s.setPrices(code: "IE", prices: TierSet(ad: start.ad, standard: 8.99, premium: start.premium))
        s = SimulationEngine.advanceWeek(s)
        XCTAssertTrue(headlines(s).contains("Test Co cuts prices in Ireland"))
        let now = s.markets["IE"]!.prices
        try s.setPrices(code: "IE", prices: TierSet(ad: now.ad + 1, standard: now.standard - 1, premium: now.premium))
        s = SimulationEngine.advanceWeek(s)
        XCTAssertTrue(headlines(s).contains("Test Co reshuffles its plans in Ireland"))
    }

    func testBulkPriceToolsAreReportedToo() throws {
        var s = newState()
        try s.launchMarket(code: "NZ")
        try s.applyPrices(TierSet(ad: 3.99, standard: 7.99, premium: 11.99))
        s = SimulationEngine.advanceWeek(s)
        XCTAssertTrue(headlines(s).contains("Test Co cuts prices in Ireland"))
        XCTAssertTrue(headlines(s).contains { $0.contains("prices in New Zealand") })

        var many = newState()
        for code in ["NZ", "NL", "CA", "GB"] { many.markets[code]?.status = .live }
        try many.applyPriceLevel(1.5)
        many = SimulationEngine.advanceWeek(many)
        let summary = many.news.first { $0.headline.contains("changes prices in") }
        XCTAssertNotNil(summary, "more than three markets collapse into one story")
        XCTAssertTrue(summary!.headline.contains("5 markets"))
        XCTAssertFalse(many.news.contains { $0.headline == "Test Co raises prices in Ireland" })

        var matched = newState()
        try matched.matchRival(id: "netflux", in: "IE", undercutBy: 1)
        matched = SimulationEngine.advanceWeek(matched)
        XCTAssertTrue(matched.news.contains { $0.kind == .pricing && $0.rivalID == nil })
    }

    func testRivalPriceStoriesShowDollars() {
        var s = newState()
        s.markets["IE"]?.subs = TierSet(ad: 0, standard: 1_500_000, premium: 0)
        for i in s.rivals.indices { s.rivals[i].subs = ["IE": 20_000] }
        s.cloudUnits[Region.europe.rawValue] = 10
        var found = false
        for _ in 0..<300 where !found {
            s = SimulationEngine.advanceWeek(s)
            s.markets["IE"]?.subs = TierSet(ad: 0, standard: 1_500_000, premium: 0)
            found = s.news.contains { $0.rivalID != nil && $0.kind == .pricing && $0.body.contains("Standard in Ireland: $") }
        }
        XCTAssertTrue(found, "rival price moves quote the actual dollar change")
        let example = NewsEngine.priceExample(s.rivals[0], before: 1.0, after: 0.8)
        XCTAssertTrue(example.contains("→"))
        XCTAssertTrue(NewsEngine.priceExample(Rival(id: "x", name: "X", personality: .balanced, cash: 0, catalogStrength: 1, subs: [:], priceLevel: 1, weeklyGrowth: 0), before: 1, after: 0.9).isEmpty)
    }

    // MARK: Your other moves

    func testLaunchesAndBuildsAreNews() throws {
        var s = newState()
        try s.launchMarket(code: "NZ")
        XCTAssertTrue(headlines(s).contains("Test Co begins launching in New Zealand"))
        try s.launchTier(.ad, code: "IE")
        XCTAssertTrue(headlines(s).contains("Test Co is launching a Ad-supported plan in Ireland"))
        try s.startPlatform(.ios)
        XCTAssertTrue(headlines(s).contains("Test Co starts building its iOS app"))
        try s.buildDatacenter(region: .europe)
        try s.foundStudio(specialty: .drama)
        XCTAssertTrue(s.news.contains { $0.headline.contains("founds") })
        try s.upgradeStudio(id: s.studios[0].id)
        XCTAssertTrue(s.news.contains { $0.headline.contains("expands") })
        try s.hireCurator()
        XCTAssertTrue(headlines(s).contains("Test Co hires a licensing manager"))

        for _ in 0..<12 { s = SimulationEngine.advanceWeek(s) }
        XCTAssertTrue(headlines(s).contains("Test Co goes live in New Zealand"))
        XCTAssertTrue(headlines(s).contains("Test Co adds a Ad-supported plan in Ireland"))
        XCTAssertTrue(headlines(s).contains("Test Co launches its iOS app"))
        XCTAssertTrue(s.news.contains { $0.headline.contains("comes online") })
        XCTAssertTrue(s.news.filter { [$0.headline.contains("goes live"), $0.headline.contains("adds a")].contains(true) }.allSatisfy { $0.kind == .you })
    }

    func testProductionsAreNews() throws {
        var s = newState()
        try s.commissionOriginal(kind: .series, genre: .drama, language: .english, budget: 5_000_000, weeks: 6)
        XCTAssertTrue(s.news.first!.headline.contains("greenlights"))
        let name = s.projects[0].name
        for _ in 0..<6 { s = SimulationEngine.advanceWeek(s) }
        XCTAssertTrue(s.news.contains { $0.headline == "\"\(name)\" premieres on Test Co" && $0.kind == .you })
    }

    func testBigLicensesFundingAndEventsAreNews() throws {
        var s = newState()
        var title = s.licenseMarket[0]
        title.quality = 92
        s.licenseMarket[0] = title
        try s.buyLicense(titleID: title.id)
        XCTAssertTrue(s.news.first!.headline.contains("licenses \"\(title.name)\""))

        var cheap = newState()
        var small = cheap.licenseMarket[0]
        small.quality = 50
        small.license?.cost = 100_000
        cheap.licenseMarket[0] = small
        let count = cheap.news.count
        try cheap.buyLicense(titleID: small.id)
        XCTAssertEqual(cheap.news.count, count, "routine small licenses stay out of the feed")

        var funded = newState()
        funded.finances.revenueHistory = Array(repeating: 1_000_000, count: 52)
        try funded.takeLoan(amount: 2_000_000, termWeeks: 104)
        XCTAssertTrue(funded.news.first!.headline.contains("borrows"))
        try funded.raiseRound(percent: 0.1)
        XCTAssertTrue(funded.news.first!.headline.contains("raises"))
        funded.markets["IE"]?.subs = TierSet(ad: 0, standard: 6_000_000, premium: 0)
        funded.finances.revenueHistory = Array(repeating: 10_000_000, count: 52)
        try funded.launchIPO()
        XCTAssertTrue(funded.news.first!.headline.contains("goes public"))

        var event = newState()
        _ = RandomEvents.create("outage", &event)
        try event.resolveEvent(choiceID: "fix")
        XCTAssertTrue(event.news.first!.headline == "Outage fixed")
    }

    func testServerCrashesAreNews() {
        var s = newState()
        s.markets["IE"]?.subs = TierSet(ad: 0, standard: 4_000_000, premium: 0)
        for _ in 0..<30 where !headlines(s).contains(where: { $0.contains("servers crash") }) {
            s = SimulationEngine.advanceWeek(s)
        }
        XCTAssertTrue(headlines(s).contains { $0.contains("servers crash in Europe") })
    }

    func testPlayerFilterCoversYourMovesAndPricesChip() throws {
        var s = newState()
        try s.launchMarket(code: "NZ")
        try s.setPrices(code: "IE", prices: TierSet(ad: 5, standard: 12.99, premium: 17))
        s = SimulationEngine.advanceWeek(s)
        let yours = s.news.filter { $0.kind == .you || ($0.rivalID == nil && $0.kind != .industry) }
        XCTAssertTrue(yours.contains { $0.headline.contains("begins launching") })
        XCTAssertTrue(yours.contains { $0.headline.contains("prices in Ireland") })
        XCTAssertTrue(s.news.contains { $0.kind == .pricing })
    }

    func testStateWithPendingPricesSurvivesSaves() throws {
        var s = newState()
        try s.setPrices(code: "IE", prices: TierSet(ad: 5, standard: 12.99, premium: 17))
        let loaded = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(s))
        XCTAssertEqual(loaded, s)
        XCTAssertNotNil(loaded.pendingPriceChanges["IE"])
        XCTAssertEqual(SimulationEngine.advanceWeek(loaded).news.filter { $0.headline.contains("prices in Ireland") }.count, 1)
    }
}
