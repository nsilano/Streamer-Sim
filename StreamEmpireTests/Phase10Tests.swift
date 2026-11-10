import XCTest
#if canImport(StreamEmpireCore)
@testable import StreamEmpireCore
#else
@testable import StreamEmpire
#endif

final class Phase10Tests: XCTestCase {
    private func newState(country: String = "IE", seed: UInt64 = 42) -> GameState {
        var s = GameState.newGame(startCountry: country, companyName: "Test Co", seed: seed)
        s.eventsEnabled = false
        s.finances.cash = 1e12
        return s
    }

    private func rivalIndex(_ s: GameState, _ id: String) -> Int { s.rivals.firstIndex { $0.id == id }! }

    // MARK: News

    func testNewGameHasAWelcomeStoryAndNoMilestoneSpam() {
        let s = newState()
        XCTAssertEqual(s.news.count, 1)
        XCTAssertEqual(s.unreadNewsCount, 0)
        XCTAssertTrue(s.milestonesReached.contains("netflux-subs-300"))
        let after = SimulationEngine.advanceWeek(s)
        // (A rival may legitimately cross a fresh threshold in week one; what must stay quiet are already-passed ones.)
        let reached = s.milestonesReached
        XCTAssertFalse(after.news.contains { $0.kind == .subscribers && $0.rivalID == nil }, "your own milestones stay quiet")
        XCTAssertTrue(Set(reached).isSubset(of: Set(after.milestonesReached)))
    }

    func testSubscriberMilestoneIsReported() {
        var s = newState()
        s.rivals[rivalIndex(s, "plume")].subs = ["US": 49_999_000]
        s = SimulationEngine.advanceWeek(s)
        let story = s.news.first { $0.kind == .subscribers && $0.rivalID == "plume" }
        XCTAssertNotNil(story)
        XCTAssertTrue(story!.headline.contains("passes"))
        let again = SimulationEngine.advanceWeek(s)
        XCTAssertEqual(again.news.filter { $0.kind == .subscribers && $0.rivalID == "plume" }.count, 1, "reported once")
    }

    func testProfitMilestoneIsReported() {
        var s = newState()
        s.rivals[rivalIndex(s, "hulo")].subs = ["US": 80_200_000]
        s = SimulationEngine.advanceWeek(s)
        XCTAssertTrue(s.news.contains { $0.kind == .profit && $0.rivalID == "hulo" })
        XCTAssertEqual(Rival(id: "x", name: "X", personality: .balanced, cash: 0, catalogStrength: 50,
                             subs: ["US": 1_000_000], priceLevel: 1, weeklyGrowth: 0).annualProfit, 1_000_000 * 0.12 * 52, accuracy: 1)
    }

    func testRivalLaunchesAndLicenseWinsMakeTheNews() {
        var s = newState()
        for _ in 0..<250 { s = SimulationEngine.advanceWeek(s) }
        XCTAssertTrue(s.news.contains { $0.kind == .expansion }, "rivals expand and the feed says so")
        XCTAssertTrue(s.news.contains { $0.kind == .licensing }, "big license wins are reported")
        XCTAssertTrue(s.news.allSatisfy { item in item.rivalID == nil || s.rivals.contains { $0.id == item.rivalID } })
    }

    func testPriceWarsMakeTheNews() {
        var s = newState()
        s.markets["IE"]?.subs = TierSet(ad: 0, standard: 1_500_000, premium: 0)
        for i in s.rivals.indices { s.rivals[i].subs = ["IE": 20_000] }
        s.cloudUnits[Region.europe.rawValue] = 10
        var sawPricing = false, sawWar = false
        for _ in 0..<300 {
            s = SimulationEngine.advanceWeek(s)
            s.markets["IE"]?.subs = TierSet(ad: 0, standard: 1_500_000, premium: 0)
            // The feed keeps only the latest 150 stories, so look as they happen.
            if s.news.contains(where: { $0.kind == .pricing }) { sawPricing = true }
            if s.news.contains(where: { $0.headline.contains("price war") }) { sawWar = true }
        }
        XCTAssertTrue(sawPricing)
        XCTAssertTrue(sawWar)
    }

    func testOvertakingRivalsIsNews() {
        var s = newState()
        s.markets["IE"]?.subs = TierSet(ad: 0, standard: 250_000_000, premium: 0)
        s = SimulationEngine.advanceWeek(s)
        let story = s.news.first { $0.kind == .you && $0.headline.contains("overtakes") }
        XCTAssertNotNil(story)
        XCTAssertTrue(story!.headline.hasPrefix("Test Co"))
        XCTAssertEqual(s.previousRanking, s.leaderboard.map { $0.id })
    }

    func testUnreadCountAndCap() {
        var s = newState()
        s.addNews(.industry, "A", "a")
        s.addNews(.industry, "B", "b")
        XCTAssertEqual(s.unreadNewsCount, 2)
        XCTAssertEqual(s.news.first?.headline, "B", "newest first")
        s.markNewsRead()
        XCTAssertEqual(s.unreadNewsCount, 0)
        for i in 0..<200 { s.addNews(.industry, "N\(i)", "") }
        XCTAssertEqual(s.news.count, 150)
        XCTAssertEqual(s.news.first?.headline, "N199")
    }

    // MARK: Dollar prices

    func testPsychologicalPrices() {
        XCTAssertEqual(Formulas.psychologicalPrice(11.0), 11.49, accuracy: 1e-9)
        XCTAssertEqual(Formulas.psychologicalPrice(11.6), 11.99, accuracy: 1e-9)
        XCTAssertEqual(Formulas.psychologicalPrice(9.5), 9.99, accuracy: 1e-9)
        XCTAssertEqual(Formulas.psychologicalPrice(0.2), 0.99, accuracy: 1e-9)
        XCTAssertEqual(Formulas.psychologicalPrice(0), 0.99, accuracy: 1e-9)
    }

    func testRivalDollarPrices() {
        let us = CountryData.country("US")!      // fair price $15
        func price(_ factor: Double, _ level: Double, _ tier: Tier) -> Double {
            Formulas.rivalPrice(country: us, priceFactor: factor, priceLevel: level, tier: tier)
        }
        XCTAssertEqual(price(1.1, 1.0, .standard), 16.99, accuracy: 1e-9)
        XCTAssertLessThan(price(1.1, 1.0, .ad), price(1.1, 1.0, .standard))
        XCTAssertGreaterThan(price(1.1, 1.0, .premium), price(1.1, 1.0, .standard))
        XCTAssertLessThan(price(1.1, 0.8, .standard), price(1.1, 1.0, .standard), "promotions lower the price")
        XCTAssertLessThan(price(0.7, 1.0, .standard), price(1.2, 1.0, .standard), "cheap brands vs premium brands")
        let rivals = RivalData.initialRivals()
        XCTAssertTrue(rivals.allSatisfy { $0.priceFactor > 0 })
        XCTAssertGreaterThan(rivals.first { $0.id == "orchard" }!.priceFactor, rivals.first { $0.id == "hulo" }!.priceFactor)
    }

    func testViewingRivalPricesPerCountry() {
        let s = newState()
        let netflux = s.rivals.first { $0.id == "netflux" }!
        let prices = s.rivalPrices(netflux, in: "IE")
        XCTAssertNotNil(prices)
        XCTAssertGreaterThan(prices!.standard, 0)
        let hulo = s.rivals.first { $0.id == "hulo" }!
        XCTAssertNil(s.rivalPrices(hulo, in: "IE"), "Hulo isn't in Ireland")
    }

    func testSettingExactDollarPricesEverywhere() throws {
        var s = newState()
        try s.launchMarket(code: "NZ")
        try s.applyPrices(TierSet(ad: 4.99, standard: 9.99, premium: 14.99))
        XCTAssertEqual(s.markets["IE"]!.prices, TierSet(ad: 4.99, standard: 9.99, premium: 14.99))
        XCTAssertEqual(s.markets["NZ"]!.prices, TierSet(ad: 4.99, standard: 9.99, premium: 14.99))
        XCTAssertNotEqual(s.markets["CA"]!.prices.standard, 9.99, "unlaunched markets are untouched")
        XCTAssertThrowsError(try s.applyPrices(TierSet(ad: -1, standard: 9, premium: 14)))
        XCTAssertThrowsError(try s.applyPrices(TierSet(ad: 1, standard: 900, premium: 14)))
        try s.setPrices(code: "IE", prices: TierSet(ad: 3.25, standard: 8.75, premium: 13.10))
        XCTAssertEqual(s.markets["IE"]!.prices.standard, 8.75, "any dollar amount, not just steps")
    }

    func testMatchingAndUndercuttingARival() throws {
        var s = newState()
        let netflux = s.rivals.first { $0.id == "netflux" }!
        let theirs = s.rivalPrices(netflux, in: "IE")!
        try s.matchRival(id: "netflux", in: "IE")
        XCTAssertEqual(s.markets["IE"]!.prices, theirs)
        try s.matchRival(id: "netflux", in: "IE", undercutBy: 1)
        XCTAssertEqual(s.markets["IE"]!.prices.standard, theirs.standard - 1, accuracy: 1e-9)
        XCTAssertThrowsError(try s.matchRival(id: "hulo", in: "IE"))
        XCTAssertThrowsError(try s.matchRival(id: "nobody", in: "IE"))
    }

    // MARK: Finances

    func testCostBreakdownIsRankedAndAddsUp() throws {
        var s = newState()
        s.markets["IE"]?.subs = TierSet(ad: 0, standard: 100_000, premium: 0)
        s.markets["IE"]?.marketingBudget = 50_000
        try s.hire(.legal)
        s = SimulationEngine.advanceWeek(s)
        let lines = s.costBreakdown()
        XCTAssertFalse(lines.isEmpty)
        XCTAssertEqual(lines.map(\.amount), lines.map(\.amount).sorted(by: >), "biggest first")
        XCTAssertEqual(lines.reduce(0) { $0 + $1.amount }, s.finances.lastWeek.costs, accuracy: 0.01)
        XCTAssertEqual(lines.reduce(0) { $0 + $1.shareOfCosts }, 1, accuracy: 1e-6)
        XCTAssertTrue(lines.contains { $0.category == .marketing && abs($0.amount - 50_000) < 0.01 })
        XCTAssertTrue(lines.contains { $0.category == .other }, "the hiring fee shows up")
    }

    func testHistoryAndLifetimeTotals() {
        var s = newState()
        for _ in 0..<5 { s = SimulationEngine.advanceWeek(s) }
        XCTAssertEqual(s.finances.history.count, 5)
        XCTAssertEqual(s.finances.lifetime.staff, s.finances.history.reduce(0) { $0 + $1.staff }, accuracy: 0.01)
        XCTAssertEqual(s.finances.lifetime.costs, s.finances.history.reduce(0) { $0 + $1.costs }, accuracy: 0.01)
        for _ in 0..<30 { s = SimulationEngine.advanceWeek(s) }
        XCTAssertEqual(s.finances.history.count, 26)
        XCTAssertGreaterThan(s.finances.lifetime.costs, s.finances.history.reduce(0) { $0 + $1.costs })
    }

    func testPerCountryProfitAndLoss() {
        var s = newState()
        s.markets["IE"]?.subs = TierSet(ad: 0, standard: 10_000, premium: 0)
        s.markets["IE"]?.marketingBudget = 5_000
        s = SimulationEngine.advanceWeek(s)
        let ie = s.lastReport!.markets.first { $0.id == "IE" }!
        let expected = 10_000 * Formulas.streamingCostPerSubWeek + Formulas.operatingCost(for: CountryData.country("IE")!) + 5_000
        XCTAssertEqual(ie.costs, expected, accuracy: 0.01)
        XCTAssertEqual(ie.profit, ie.revenue - ie.costs, accuracy: 0.001)
    }

    func testDiagnosisExplainsALoss() {
        var s = newState()
        XCTAssertEqual(s.diagnosis().first?.id, "wait", "nothing to explain before week 1")
        s = SimulationEngine.advanceWeek(s)       // no subscribers: all cost, no revenue
        let items = s.diagnosis()
        XCTAssertEqual(items.first?.id, "loss")
        XCTAssertTrue(items.first!.urgent)
        XCTAssertTrue(items.first!.detail.contains("Biggest costs"))
        XCTAssertTrue(items.contains { $0.id == "market-IE" }, "the home market costs more than it earns")
        XCTAssertEqual(s.losingMarkets().first?.id, "IE")
    }

    func testDiagnosisCelebratesProfit() {
        var s = newState()
        s.markets["IE"]?.subs = TierSet(ad: 0, standard: 400_000, premium: 0)
        s.cloudUnits[Region.europe.rawValue] = 10
        s = SimulationEngine.advanceWeek(s)
        XCTAssertGreaterThan(s.finances.lastWeek.profit, 0)
        XCTAssertEqual(s.diagnosis().first?.id, "profit")
    }

    func testMarketingHeavySpendingIsFlagged() {
        var s = newState()
        s.markets["IE"]?.subs = TierSet(ad: 0, standard: 2_000, premium: 0)
        s.markets["IE"]?.marketingBudget = 200_000
        s = SimulationEngine.advanceWeek(s)
        XCTAssertTrue(s.diagnosis().contains { $0.id == "marketing" })
    }

    // MARK: Licensing manager (real-game behaviour)

    func testManagerActuallyLicensesInARealGame() throws {
        for seed in UInt64(1)...6 {
            var s = newState(seed: seed)
            s.finances.cash = 25_000_000                 // the real starting cash
            try s.hireCurator()
            for _ in 0..<10 { s = SimulationEngine.advanceWeek(s) }
            XCTAssertGreaterThanOrEqual(s.catalog.count, 3, "seed \(seed): \(s.curatorStatus ?? "no status")")
            XCTAssertNotNil(s.curatorStatus)
        }
    }

    func testManagerExplainsWhyNothingWasBought() throws {
        var s = newState()
        try s.hireCurator()
        var c = s.curator!
        c.minQuality = 100
        try s.updateCurator(c)
        s = SimulationEngine.advanceWeek(s)
        XCTAssertEqual(s.catalog.count, 0)
        XCTAssertTrue(s.curatorStatus!.contains("Nothing bought"))
        XCTAssertTrue(s.curatorStatus!.contains("below quality 100"))
    }

    func testUnspentAllowanceCarriesOverSoPricierTitlesBecomeAffordable() throws {
        var s = newState()
        s.rivals = []
        try s.hireCurator()
        var c = s.curator!
        c.weeklyBudget = 500_000
        c.maxPricePerTitle = 5_000_000
        try s.updateCurator(c)
        let pricey = Title(id: 9_999, name: "Big Series", kind: .series, genre: .drama, language: .english,
                           quality: 90, popularity: 90, ageWeeks: 5, isOriginal: false,
                           license: LicenseTerms(cost: 1_200_000, years: 2, regions: [], exclusive: false),
                           weeksRemaining: nil, listingWeeksLeft: 99)
        s.licenseMarket = [pricey]
        XCTAssertEqual(s.curatorShop()?.bought.count, 0, "week 1: only $500K available")
        XCTAssertEqual(s.curator!.carryBudget, 500_000, accuracy: 0.01)
        XCTAssertEqual(s.curatorShop()?.bought.count, 0, "week 2: $1.0M available")
        XCTAssertEqual(s.curatorShop()?.bought, ["Big Series"], "week 3: $1.5M available")
        XCTAssertEqual(s.catalog.count, 1)
        XCTAssertEqual(s.curator!.carryBudget, 300_000, accuracy: 0.01)
        XCTAssertLessThanOrEqual(s.curator!.carryBudget, 3 * s.curator!.weeklyBudget)
    }

    func testShopNow() throws {
        var s = newState()
        XCTAssertThrowsError(try s.shopNow())
        try s.hireCurator()
        s.licenseMarket = [Title(id: 77, name: "Quick Buy", kind: .movie, genre: .drama, language: .english,
                                 quality: 80, popularity: 70, ageWeeks: 3, isOriginal: false,
                                 license: LicenseTerms(cost: 300_000, years: 2, regions: [], exclusive: false),
                                 weeksRemaining: nil, listingWeeksLeft: 8)]
        try s.shopNow()
        XCTAssertEqual(s.catalog.map(\.name), ["Quick Buy"])
        XCTAssertTrue(s.curatorStatus!.contains("Signed 1 title"))
    }

    func testPhase10StateRoundTrips() throws {
        var s = newState()
        try s.hireCurator()
        try s.shopNow()
        s.addNews(.industry, "Hello", "World")
        let loaded = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(s))
        XCTAssertEqual(loaded, s)
        XCTAssertEqual(loaded.news.first?.headline, "Hello")
        XCTAssertNotNil(loaded.curatorStatus)
    }
}
