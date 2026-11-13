import XCTest
#if canImport(StreamEmpireCore)
@testable import StreamEmpireCore
#else
@testable import StreamEmpire
#endif

final class Phase11Tests: XCTestCase {
    private func newState(country: String = "IE", seed: UInt64 = 42) -> GameState {
        var s = GameState.newGame(startCountry: country, companyName: "Test Co", seed: seed)
        s.eventsEnabled = false
        s.finances.cash = 1e12
        return s
    }

    private func englishTitles(_ n: Int) -> [Title] {
        (0..<n).map {
            Title(id: 20_000 + $0, name: "E\($0)", kind: .movie, genre: .drama, language: .english, quality: 70,
                  popularity: 70, ageWeeks: 0, isOriginal: true, license: nil, weeksRemaining: nil, listingWeeksLeft: 0)
        }
    }

    private func rival(_ s: GameState, _ id: String) -> Rival { s.rivals.first { $0.id == id }! }

    // MARK: Parody titles

    func testLibraryIsBigAndUnique() {
        let all = ParodyLibrary.all
        XCTAssertGreaterThanOrEqual(all.count, 280)
        XCTAssertEqual(Set(all.map(\.name)).count, all.count, "no duplicate names")
        for genre in Genre.allCases {
            XCTAssertGreaterThanOrEqual(ParodyLibrary.byGenre[genre]?.count ?? 0, 15, "\(genre)")
        }
        XCTAssertTrue(all.filter { $0.genre == .anime }.allSatisfy { $0.language == .japanese })
        XCTAssertTrue(all.filter { $0.genre == .local }.allSatisfy { $0.language != .english })
        XCTAssertTrue(all.filter { ![.local, .anime].contains($0.genre) }.allSatisfy { $0.language == .english })
        XCTAssertTrue(all.contains { $0.name == "The First of Us" })
        XCTAssertTrue(all.contains { $0.kind == .movie } && all.contains { $0.kind == .series })
        XCTAssertTrue(all.allSatisfy { !$0.name.isEmpty })
    }

    func testEveryListingIsAParody() {
        var rng = SeededRNG(seed: 5)
        let byName = Dictionary(uniqueKeysWithValues: ParodyLibrary.all.map { ($0.name, $0) })
        for id in 0..<300 {
            let title = TitleGenerator.generate(id: id, rng: &rng)
            guard let parody = byName[title.name] else { return XCTFail("\(title.name) is not in the library") }
            XCTAssertEqual(title.kind, parody.kind)
            XCTAssertEqual(title.genre, parody.genre)
            XCTAssertEqual(title.language, parody.language)
        }
    }

    func testNamesAreNotRepeatedWhileInUse() {
        let s = newState()
        let names = s.licenseMarket.map(\.name)
        XCTAssertEqual(Set(names).count, names.count)
        XCTAssertTrue(Set(names).isSubset(of: Set(ParodyLibrary.all.map(\.name))))
        var running = s
        for _ in 0..<60 {
            running = SimulationEngine.advanceWeek(running)
            let market = running.licenseMarket.map(\.name)
            XCTAssertEqual(Set(market).count, market.count, "no duplicate listings")
            XCTAssertTrue(Set(market).isDisjoint(with: Set(running.catalog.map(\.name))))
        }
    }

    func testSequelNumbersWhenAGenreRunsDry() {
        var rng = SeededRNG(seed: 9)
        let everyDrama = Set((ParodyLibrary.byGenre[.drama] ?? []).map(\.name))
        let first = TitleGenerator.pickParody(genre: .drama, rng: &rng, avoiding: everyDrama)
        XCTAssertTrue(first.name.hasSuffix(" II"))
        XCTAssertTrue(everyDrama.contains(String(first.name.dropLast(3))))
        let second = TitleGenerator.pickParody(genre: .drama, rng: &rng, avoiding: everyDrama.union([first.name]))
        XCTAssertTrue(second.name.hasSuffix(" II") || second.name.hasSuffix(" III"))
    }

    func testDifferentSeedsGiveDifferentCatalogs() {
        XCTAssertNotEqual(newState(seed: 1).licenseMarket.map(\.name), newState(seed: 2).licenseMarket.map(\.name))
        XCTAssertEqual(newState(seed: 3).licenseMarket.map(\.name), newState(seed: 3).licenseMarket.map(\.name))
    }

    // MARK: Gentler regulation

    func testQuotaFinesWaitForEstablishedServices() {
        XCTAssertFalse(Formulas.quotaFinesApply(week: 10, subscribers: 500_000))
        XCTAssertFalse(Formulas.quotaFinesApply(week: 100, subscribers: 5_000))
        XCTAssertTrue(Formulas.quotaFinesApply(week: 60, subscribers: 30_000))

        func fines(week: Int, subs: Double) -> Double {
            var s = newState()
            s.week = week
            s.markets["NL"]?.status = .live
            s.markets["NL"]?.subs = TierSet(ad: 0, standard: subs, premium: 0)
            s.catalog = englishTitles(10)
            return SimulationEngine.advanceWeek(s).lastReport!.financials.fines
        }
        XCTAssertEqual(fines(week: 10, subs: 100_000), 0, accuracy: 1e-9, "early game is safe")
        XCTAssertEqual(fines(week: 60, subs: 5_000), 0, accuracy: 1e-9, "small markets are left alone")
        XCTAssertGreaterThan(fines(week: 60, subs: 100_000), 0)
    }

    func testFinesAreCappedAndWarnedOnce() {
        var s = newState()
        s.week = 60
        s.markets["NL"]?.status = .live
        s.markets["NL"]?.subs = TierSet(ad: 0, standard: 100_000, premium: 0)
        s.catalog = englishTitles(10)
        s = SimulationEngine.advanceWeek(s)
        let nl = s.lastReport!.markets.first { $0.id == "NL" }!
        XCTAssertLessThanOrEqual(s.lastReport!.financials.fines, Formulas.maxFineShareOfRevenue * nl.revenue + 0.01)

        // A new country with too little local content is warned about exactly once, before fines apply.
        var early = newState()
        early.week = 30
        early.markets["NL"]?.status = .live
        early.markets["NL"]?.subs = TierSet(ad: 0, standard: 5_000, premium: 0)
        early.catalog = englishTitles(10)
        early = SimulationEngine.advanceWeek(early)
        XCTAssertTrue(early.lastReport!.events.contains { $0.headline.contains("Regulators are watching") })
        early = SimulationEngine.advanceWeek(early)
        XCTAssertFalse(early.lastReport!.events.contains { $0.headline.contains("Regulators are watching") })
        XCTAssertEqual(early.finances.lastWeek.fines, 0, accuracy: 1e-9)
    }

    func testRegulationIsNeverARandomPopUp() {
        var s = newState()
        s.eventsEnabled = true
        s.week = 80
        s.finances.revenueHistory = Array(repeating: 1_000_000, count: 52)
        for _ in 0..<1_000 {
            s.pendingEvent = nil
            s.lastEventWeek = -100
            if let event = RandomEvents.roll(&s) { XCTAssertNotEqual(event.key, "regulation") }
        }
        XCTAssertLessThan(RandomEvents.regulationUnit(newState()), 200_000, "regulation costs are modest early on")
    }

    // MARK: Shares

    func testMarketCapMath() {
        XCTAssertEqual(Formulas.rivalMarketCap(annualProfit: 0, subscribers: 0, sentiment: 1), 50_000_000)
        let base = Formulas.rivalMarketCap(annualProfit: 100_000_000, subscribers: 20_000_000, sentiment: 1)
        XCTAssertEqual(base, 25 * 100_000_000 + 60 * 20_000_000, accuracy: 1)
        XCTAssertGreaterThan(Formulas.rivalMarketCap(annualProfit: 100_000_000, subscribers: 20_000_000, sentiment: 1.3), base)
        let s = newState()
        XCTAssertGreaterThan(s.marketCap(rival(s, "netflux")), s.marketCap(rival(s, "kaiju")))
    }

    func testBuyingSharesCostsMoreAsYouOwnMore() throws {
        var s = newState()
        let kaiju = rival(s, "kaiju")
        let cap = s.marketCap(kaiju)
        let first = s.sharePrice(kaiju, percent: 0.05)
        XCTAssertEqual(first, cap * 0.05 * (1 + 0.025), accuracy: 1)
        let cash = s.finances.cash
        try s.buyShares(rivalID: "kaiju", percent: 0.05)
        XCTAssertEqual(s.finances.cash, cash - first, accuracy: 1)
        XCTAssertEqual(s.stake(in: "kaiju"), 0.05, accuracy: 1e-9)
        XCTAssertGreaterThan(s.sharePrice(rival(s, "kaiju"), percent: 0.05), first / 1.1, "price moves with sentiment and stake")
        XCTAssertGreaterThan(Formulas.sharePurchaseCost(marketCap: 1e9, currentStake: 0.3, percent: 0.05, poisonPill: false),
                             Formulas.sharePurchaseCost(marketCap: 1e9, currentStake: 0.0, percent: 0.05, poisonPill: false))
        XCTAssertEqual(Formulas.sharePurchaseCost(marketCap: 1e9, currentStake: 0.2, percent: 0.05, poisonPill: true),
                       1.6 * Formulas.sharePurchaseCost(marketCap: 1e9, currentStake: 0.2, percent: 0.05, poisonPill: false), accuracy: 1)
    }

    func testDisclosureAndPoisonPill() throws {
        var s = newState()
        try s.buyShares(rivalID: "kaiju", percent: 0.04)
        XCTAssertFalse(s.news.contains { $0.headline.contains("discloses") })
        try s.buyShares(rivalID: "kaiju", percent: 0.02)
        XCTAssertTrue(s.news.contains { $0.headline.contains("discloses") && $0.headline.contains("Kaiju Plus") })
        XCTAssertFalse(rival(s, "kaiju").poisonPill)
        try s.buyShares(rivalID: "kaiju", percent: 0.15)
        XCTAssertTrue(rival(s, "kaiju").poisonPill)
        XCTAssertTrue(s.news.contains { $0.headline.contains("poison pill") })
    }

    func testShareLimitsAndValidation() throws {
        var s = newState()
        for _ in 0..<2 { try s.buyShares(rivalID: "kaiju", percent: 0.245) }
        XCTAssertThrowsError(try s.buyShares(rivalID: "kaiju", percent: 0.1), "49% open-market limit") { error in
            guard case ActionError.locked = error else { return XCTFail("\(error)") }
        }
        XCTAssertThrowsError(try s.buyShares(rivalID: "kaiju", percent: 0.9))
        XCTAssertThrowsError(try s.buyShares(rivalID: "kaiju", percent: 0.0))
        XCTAssertThrowsError(try s.buyShares(rivalID: "nobody", percent: 0.05))
        var poor = newState()
        poor.finances.cash = 1000
        XCTAssertThrowsError(try poor.buyShares(rivalID: "netflux", percent: 0.05))
    }

    func testSellingSharesAndValue() throws {
        var s = newState()
        try s.buyShares(rivalID: "kaiju", percent: 0.10)
        XCTAssertEqual(s.totalStakeValue, s.stakeValue(in: "kaiju"), accuracy: 1)
        let cap = s.marketCap(rival(s, "kaiju"))
        let cash = s.finances.cash
        try s.sellShares(rivalID: "kaiju", percent: 0.04)
        let proceeds = s.finances.cash - cash
        XCTAssertGreaterThan(proceeds, 0)
        XCTAssertLessThanOrEqual(proceeds, Formulas.shareSaleProceeds(marketCap: cap, percent: 0.04) + 1, "selling pushes the price down first")
        XCTAssertEqual(s.stake(in: "kaiju"), 0.06, accuracy: 1e-9)
        XCTAssertThrowsError(try s.sellShares(rivalID: "kaiju", percent: 0.5))
        try s.sellShares(rivalID: "kaiju", percent: 0.06)
        XCTAssertEqual(s.stake(in: "kaiju"), 0)
        XCTAssertNil(s.stakes["kaiju"])
        XCTAssertNil(s.stakeBasis["kaiju"])
        XCTAssertLessThan(Formulas.shareSaleProceeds(marketCap: 1e9, percent: 0.1), 1e9 * 0.1, "selling has a spread")
    }

    func testSharePricesMoveWithInvestorMood() {
        var s = newState()
        let before = s.marketCap(rival(s, "kaiju"))
        for _ in 0..<150 { s = SimulationEngine.advanceWeek(s) }
        for r in s.rivals { XCTAssertTrue((0.6...1.6).contains(r.sentiment), "\(r.id) \(r.sentiment)") }
        XCTAssertNotEqual(s.marketCap(rival(s, "kaiju")), before)
    }

    // MARK: Takeovers

    func testTakeoverNeedsAStakeAndMoney() throws {
        var s = newState()
        XCTAssertThrowsError(try s.launchTakeover(rivalID: "kaiju", premium: 0.5)) { error in
            guard case ActionError.locked = error else { return XCTFail("\(error)") }
        }
        try s.buyShares(rivalID: "kaiju", percent: 0.10)
        XCTAssertThrowsError(try s.launchTakeover(rivalID: "kaiju", premium: 0.05), "premium range")
        var poor = s
        poor.finances.cash = 1_000
        XCTAssertThrowsError(try poor.launchTakeover(rivalID: "kaiju", premium: 0.5))

        let k = rival(s, "kaiju")
        let cost = s.takeoverCost(k, premium: 0.5)
        XCTAssertEqual(cost, s.marketCap(k) * 0.9 * 1.5, accuracy: 1)
        let cash = s.finances.cash
        try s.launchTakeover(rivalID: "kaiju", premium: 0.5)
        XCTAssertEqual(s.finances.cash, cash - cost, accuracy: 1)
        XCTAssertEqual(s.takeover?.weeksLeft, Formulas.takeoverWeeks)
        XCTAssertThrowsError(try s.launchTakeover(rivalID: "kaiju", premium: 0.5), "one bid at a time")
        XCTAssertTrue(s.news.contains { $0.headline.contains("hostile bid") })
    }

    func testSuccessChanceDependsOnPremiumStakeAndDefences() {
        func chance(_ premium: Double = 0.5, stake: Double = 0.1, pill: Bool = false, strength: Double = 60, antitrust: Bool = false) -> Double {
            Formulas.takeoverSuccessChance(premium: premium, stake: stake, poisonPill: pill, catalogStrength: strength, antitrust: antitrust)
        }
        XCTAssertGreaterThan(chance(0.9), chance(0.3))
        XCTAssertGreaterThan(chance(stake: 0.4), chance(stake: 0.1))
        XCTAssertLessThan(chance(pill: true), chance())
        XCTAssertLessThan(chance(antitrust: true), chance())
        XCTAssertLessThan(chance(strength: 95), chance(strength: 30))
        XCTAssertTrue((0.05...0.95).contains(chance(5, stake: 1)))
        XCTAssertTrue((0.05...0.95).contains(chance(0, stake: 0, pill: true, strength: 100, antitrust: true)))
    }

    func testAntitrustFlagsDominantCombinations() throws {
        var s = newState()
        let mid = rival(s, "plume")
        XCTAssertFalse(s.antitrustRisk(mid))
        s.markets["IE"]?.subs = TierSet(ad: 0, standard: 600_000_000, premium: 0)
        XCTAssertTrue(s.antitrustRisk(mid))
    }

    func testSuccessfulTakeoverAbsorbsTheRival() throws {
        var s = newState()
        try s.buyShares(rivalID: "hulo", percent: 0.10)
        try s.launchTakeover(rivalID: "hulo", premium: 0.6)
        let hulo = rival(s, "hulo")
        let usSubs = hulo.subs["US"] ?? 0
        let cashBefore = s.finances.cash
        let catalogBefore = s.catalog.count
        XCTAssertNotEqual(s.mapStatus("US"), .live)
        s.finishTakeover(success: true)

        XCTAssertNil(s.takeover)
        XCTAssertEqual(s.rivals.count, 11)
        XCTAssertFalse(s.rivals.contains { $0.id == "hulo" })
        XCTAssertEqual(s.acquiredRivals, ["hulo"])
        XCTAssertNil(s.stakes["hulo"])
        XCTAssertEqual(s.mapStatus("US"), .live, "you inherit their presence")
        XCTAssertEqual(s.markets["US"]!.subs.standard, usSubs * Formulas.takeoverRetention, accuracy: 1)
        XCTAssertEqual(s.finances.cash, cashBefore + hulo.cash * 0.5, accuracy: 1)
        XCTAssertGreaterThan(s.catalog.count, catalogBefore)
        XCTAssertTrue(s.catalog.allSatisfy { $0.license == nil || $0.weeksRemaining != nil })
        XCTAssertTrue(s.news.contains { $0.headline.contains("acquires Hulo") })
        XCTAssertEqual(s.leaderboard.count, 12)
        s = SimulationEngine.advanceWeek(s)
        XCTAssertTrue(s.goals.contains("takeover"))
    }

    func testFailedTakeoverRefundsMostOfTheMoney() throws {
        var s = newState()
        try s.buyShares(rivalID: "kaiju", percent: 0.10)
        try s.launchTakeover(rivalID: "kaiju", premium: 0.5)
        let escrow = s.takeover!.escrow
        let cash = s.finances.cash
        let priceBefore = rival(s, "kaiju").priceLevel
        s.finishTakeover(success: false)
        XCTAssertEqual(s.finances.cash, cash + escrow * (1 - Formulas.takeoverFeeRate), accuracy: 1)
        XCTAssertEqual(s.finances.ledger.other, escrow * Formulas.takeoverFeeRate, accuracy: 1)
        XCTAssertTrue(rival(s, "kaiju").poisonPill)
        XCTAssertLessThan(rival(s, "kaiju").priceLevel, priceBefore)
        XCTAssertEqual(s.stake(in: "kaiju"), 0.10, accuracy: 1e-9, "you keep your shares")
        XCTAssertEqual(s.rivals.count, 12)
        XCTAssertTrue(s.news.contains { $0.headline.contains("reject") })
    }

    func testTheEngineHoldsTheVoteAfterFourWeeks() throws {
        var s = newState()
        try s.buyShares(rivalID: "kaiju", percent: 0.10)
        try s.launchTakeover(rivalID: "kaiju", premium: 0.9)
        for week in 1...Formulas.takeoverWeeks {
            s = SimulationEngine.advanceWeek(s)
            if week < Formulas.takeoverWeeks { XCTAssertNotNil(s.takeover) }
        }
        XCTAssertNil(s.takeover, "the vote is held and the bid ends")
        XCTAssertEqual(s.rivals.count + s.acquiredRivals.count, 12)
        XCTAssertTrue(s.lastReport!.events.contains { $0.headline.contains("Takeover of") || $0.headline.contains("You acquired") })
    }

    func testInvestmentsSurviveSaves() throws {
        var s = newState()
        try s.buyShares(rivalID: "kaiju", percent: 0.10)
        try s.launchTakeover(rivalID: "kaiju", premium: 0.5)
        let loaded = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(s))
        XCTAssertEqual(loaded, s)
        XCTAssertEqual(loaded.takeover?.rivalID, "kaiju")
        XCTAssertEqual(loaded.stakes["kaiju"] ?? 0, 0.10, accuracy: 1e-9)
    }
}
