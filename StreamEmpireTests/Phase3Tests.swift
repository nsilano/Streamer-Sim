import XCTest
#if canImport(StreamEmpireCore)
@testable import StreamEmpireCore
#else
@testable import StreamEmpire
#endif

final class Phase3Tests: XCTestCase {
    private func newState(seed: UInt64 = 42, events: Bool = false) -> GameState {
        var s = GameState.newGame(startCountry: "IE", companyName: "Test Co", seed: seed)
        s.eventsEnabled = events
        return s
    }

    private func titles(_ n: Int, language: Language = .english, dubs: [Language] = []) -> [Title] {
        (0..<n).map {
            Title(id: 7000 + $0, name: "X\($0)", kind: .movie, genre: .drama, language: language,
                  quality: 60, popularity: 60, ageWeeks: 0, isOriginal: true,
                  license: nil, weeksRemaining: nil, listingWeeksLeft: 0, subtitles: [], dubs: dubs)
        }
    }

    /// A state with revenue history so lenders and investors will talk to us.
    private func fundedState() -> GameState {
        var s = newState()
        s.finances.revenueHistory = Array(repeating: 1_000_000, count: 52)   // $52M a year
        return s
    }

    // MARK: Originals

    func testExpectedQualityRisesWithBudgetAndTime() {
        XCTAssertGreaterThan(Formulas.expectedOriginalQuality(kind: .series, budget: 60_000_000, weeks: 40),
                             Formulas.expectedOriginalQuality(kind: .series, budget: 5_000_000, weeks: 40))
        XCTAssertGreaterThan(Formulas.expectedOriginalQuality(kind: .movie, budget: 8_000_000, weeks: 30),
                             Formulas.expectedOriginalQuality(kind: .movie, budget: 8_000_000, weeks: 6))
    }

    func testRolledQualityIsBoundedAndHitsAreNotGuaranteed() {
        let expected = Formulas.expectedOriginalQuality(kind: .series, budget: 120_000_000, weeks: 52)
        let best = Formulas.rolledOriginalQuality(expected: expected, u1: 1, u2: 1, u3: 1, breakout: true)
        let worst = Formulas.rolledOriginalQuality(expected: expected, u1: 0, u2: 0, u3: 0, breakout: false)
        XCTAssertLessThanOrEqual(best, 100)
        XCTAssertGreaterThanOrEqual(worst, 5)
        XCTAssertLessThan(worst, 75, "even a huge budget can flop")
        XCTAssertGreaterThan(best, worst)
        XCTAssertGreaterThan(Formulas.rolledOriginalQuality(expected: 50, u1: 0.5, u2: 0.5, u3: 0.5, breakout: true),
                             Formulas.rolledOriginalQuality(expected: 50, u1: 0.5, u2: 0.5, u3: 0.5, breakout: false))
        XCTAssertTrue((5...100).contains(Formulas.originalPopularity(quality: 90, u: 1)))
    }

    func testCommissionValidation() {
        var s = newState()
        XCTAssertThrowsError(try s.commissionOriginal(kind: .movie, genre: .drama, language: .english, budget: 100, weeks: 20))
        XCTAssertThrowsError(try s.commissionOriginal(kind: .movie, genre: .drama, language: .english, budget: 5_000_000, weeks: 3))
        XCTAssertThrowsError(try s.commissionOriginal(kind: .movie, genre: .drama, language: .english, budget: 5_000_000, weeks: 60))
        for _ in 0..<Formulas.maxConcurrentProjects {
            XCTAssertNoThrow(try s.commissionOriginal(kind: .movie, genre: .drama, language: .english, budget: 1_000_000, weeks: 10))
        }
        XCTAssertThrowsError(try s.commissionOriginal(kind: .movie, genre: .drama, language: .english, budget: 1_000_000, weeks: 10))
    }

    func testOriginalIsProducedOnScheduleAtWeeklyCost() throws {
        var s = newState()
        try s.commissionOriginal(kind: .movie, genre: .action, language: .english, budget: 4_000_000, weeks: 8)
        XCTAssertEqual(s.projects.count, 1)
        XCTAssertEqual(s.projects[0].weeklyCost, 500_000, accuracy: 1e-6)

        s = SimulationEngine.advanceWeek(s)
        XCTAssertEqual(s.lastReport!.financials.originals, 500_000, accuracy: 1e-6)
        for _ in 0..<6 { s = SimulationEngine.advanceWeek(s) }
        XCTAssertTrue(s.catalog.filter { $0.isOriginal }.isEmpty, "not ready after 7 weeks")
        s = SimulationEngine.advanceWeek(s)

        XCTAssertTrue(s.projects.isEmpty)
        let original = try XCTUnwrap(s.catalog.first)
        XCTAssertTrue(original.isOriginal)
        XCTAssertNil(original.license)
        XCTAssertNil(original.weeksRemaining, "originals are owned forever")
        XCTAssertTrue(original.isAvailable(in: "NZ") && original.isAvailable(in: "IE"), "worldwide")
        XCTAssertTrue((5...100).contains(original.quality))
        XCTAssertTrue(s.lastReport!.events.contains { $0.headline.contains("premieres") })
        // Eight weeks of production spend total $4M.
        let spent = 25_000_000 - s.finances.cash
        XCTAssertGreaterThan(spent, 4_000_000)
    }

    func testOriginalsSurviveLicenseExpiryChecks() throws {
        var s = newState()
        s.catalog = titles(1)
        for _ in 0..<5 { s = SimulationEngine.advanceWeek(s) }
        XCTAssertEqual(s.catalog.count, 1)
    }

    // MARK: Localization & quotas

    func testLocalizationImprovesLanguageMatch() {
        let nl = CountryData.country("NL")!
        var title = titles(1)[0]
        let base = Formulas.languageMatch(title: title, country: nl)
        title.subtitles = [.dutch]
        let subbed = Formulas.languageMatch(title: title, country: nl)
        title.dubs = [.dutch]
        let dubbed = Formulas.languageMatch(title: title, country: nl)
        XCTAssertEqual(base, 0.7, accuracy: 1e-9)
        XCTAssertGreaterThan(subbed, base)
        XCTAssertGreaterThan(dubbed, subbed)
        XCTAssertLessThan(dubbed, 1.0)
    }

    func testLocalizeTitleChargesAndRecords() throws {
        var s = newState()
        s.catalog = titles(1)
        let cash = s.finances.cash
        try s.localizeTitle(titleID: 7000, language: .dutch, dub: true)
        XCTAssertEqual(s.finances.cash, cash - Formulas.dubCost(.movie), accuracy: 0.01)
        XCTAssertEqual(s.catalog[0].dubs, [.dutch])
        try s.localizeTitle(titleID: 7000, language: .dutch, dub: false)
        XCTAssertEqual(s.catalog[0].subtitles, [.dutch])
        XCTAssertThrowsError(try s.localizeTitle(titleID: 7000, language: .dutch, dub: true), "already dubbed")
        XCTAssertThrowsError(try s.localizeTitle(titleID: 7000, language: .english, dub: false), "same language")
        XCTAssertThrowsError(try s.localizeTitle(titleID: 1, language: .french, dub: false), "unknown title")

        s = SimulationEngine.advanceWeek(s)
        XCTAssertEqual(s.lastReport!.financials.localization,
                       Formulas.dubCost(.movie) + Formulas.subtitleCost(.movie), accuracy: 0.01)
    }

    func testQuotaMath() {
        XCTAssertEqual(Formulas.quotaCompliance(localCount: 0, total: 4, quota: 0.3), 1.0, "too few titles to apply")
        XCTAssertEqual(Formulas.quotaCompliance(localCount: 3, total: 10, quota: 0.3), 1.0, accuracy: 1e-9)
        XCTAssertEqual(Formulas.quotaCompliance(localCount: 1, total: 10, quota: 0.4), 0.25, accuracy: 1e-9)
        XCTAssertEqual(Formulas.quotaFine(revenue: 100_000, risk: 0.2, compliance: 1), 0, accuracy: 1e-9)
        XCTAssertEqual(Formulas.quotaFine(revenue: 100_000, risk: 0.2, compliance: 0), 2_500, accuracy: 1e-6)
    }

    func testMissingLocalContentDrawsFinesUntilDubbed() {
        func fines(catalog: [Title]) -> Double {
            var s = newState()
            s.markets["NL"]?.status = .live
            s.week = 60                       // fines only apply to established services
            s.markets["NL"]?.subs = TierSet(ad: 0, standard: 30_000, premium: 0)
            s.catalog = catalog
            return SimulationEngine.advanceWeek(s).lastReport!.financials.fines
        }
        XCTAssertGreaterThan(fines(catalog: titles(10, language: .english)), 0)
        XCTAssertEqual(fines(catalog: titles(10, language: .dutch)), 0, accuracy: 1e-9)
        XCTAssertEqual(fines(catalog: titles(10, language: .english, dubs: [.dutch])), 0, accuracy: 1e-9)
    }

    // MARK: Loans

    func testNoLoanWithoutRevenue() {
        var s = newState()
        XCTAssertEqual(s.finances.annualizedRevenue, 0)
        // Lenders count half of positive cash, so a cash-rich start can borrow a little...
        XCTAssertEqual(s.creditRoom, 12_500_000, accuracy: 1)
        // ...but a broke company with no revenue can't borrow at all.
        s.finances.cash = -1_000_000
        XCTAssertEqual(s.creditRoom, 0)
        XCTAssertThrowsError(try s.takeLoan(amount: 1_000_000, termWeeks: 104)) { error in
            guard case ActionError.locked = error else { return XCTFail("\(error)") }
        }
    }

    func testLoanLifecycleAndCashIdentity() throws {
        var s = fundedState()
        let cash = s.finances.cash
        try s.takeLoan(amount: 5_200_000, termWeeks: 52)
        XCTAssertEqual(s.finances.cash, cash + 5_200_000, accuracy: 0.01)
        XCTAssertEqual(s.outstandingDebt, 5_200_000, accuracy: 0.01)
        XCTAssertEqual(s.loans[0].weeklyPrincipal, 100_000, accuracy: 0.01)

        let before = s.finances.cash
        s = SimulationEngine.advanceWeek(s)
        let fin = s.lastReport!.financials
        XCTAssertEqual(fin.interest, 5_200_000 * 0.08 / 52, accuracy: 0.01)
        XCTAssertEqual(s.loans[0].balance, 5_100_000, accuracy: 0.01)
        // Cash moves by profit minus principal repaid (principal isn't a P&L cost).
        XCTAssertEqual(s.finances.cash, before + fin.profit - 100_000, accuracy: 0.01)

        try s.repayLoan(id: s.loans[0].id, amount: 5_100_000)
        XCTAssertTrue(s.loans.isEmpty)
    }

    func testLoanLimitedByCreditRoom() {
        var s = fundedState()
        let room = s.creditRoom
        XCTAssertGreaterThan(room, 0)
        XCTAssertThrowsError(try s.takeLoan(amount: room + 1_000_000, termWeeks: 104))
        XCTAssertThrowsError(try s.takeLoan(amount: 1_000_000, termWeeks: 77), "invalid term")
    }

    // MARK: Investors & IPO

    func testInvestorRoundDilutesAndPaysOut() throws {
        var s = fundedState()
        XCTAssertNil(s.roundBlocker)
        XCTAssertEqual(s.valuation, 20_000_000 + 5 * 52_000_000, accuracy: 1)
        let cash = s.finances.cash, value = s.valuation
        try s.raiseRound(percent: 0.10)
        XCTAssertEqual(s.finances.cash, cash + value * 0.10, accuracy: 0.01)
        XCTAssertEqual(s.equity.ownership, 0.9, accuracy: 1e-9)
        XCTAssertNotNil(s.roundBlocker, "cooldown")
        XCTAssertThrowsError(try s.raiseRound(percent: 0.10))
        s.week += Formulas.roundCooldownWeeks
        XCTAssertNil(s.roundBlocker)
        XCTAssertThrowsError(try s.raiseRound(percent: 0.5), "too large")
    }

    func testRoundsNeedRevenue() {
        var s = newState()
        XCTAssertNotNil(s.roundBlocker)
        XCTAssertThrowsError(try s.raiseRound(percent: 0.1))
    }

    func testIPOThresholdsAndEffects() throws {
        var s = newState()
        XCTAssertNotNil(s.ipoBlocker)
        s.markets["IE"]?.subs = TierSet(ad: 0, standard: 6_000_000, premium: 0)
        XCTAssertNotNil(s.ipoBlocker, "needs revenue too")
        s.finances.revenueHistory = Array(repeating: 10_000_000, count: 52)   // $520M a year
        XCTAssertNil(s.ipoBlocker)

        let cash = s.finances.cash, value = s.valuation
        try s.launchIPO()
        XCTAssertEqual(s.finances.cash, cash + value * 1.4 * 0.15, accuracy: 0.01)
        XCTAssertEqual(s.equity.ownership, 0.85, accuracy: 1e-9)
        XCTAssertTrue(s.equity.ipoDone)
        XCTAssertThrowsError(try s.launchIPO())
        XCTAssertNotNil(s.roundBlocker, "no private rounds after IPO")

        s = SimulationEngine.advanceWeek(s)
        XCTAssertTrue(s.goals.contains("ipo"))
        XCTAssertTrue(s.lastReport!.events.contains { $0.headline.contains("IPO") })
    }

    // MARK: Lose rule with funding

    func testFundingAvailableDelaysBankruptcyUntilHardLimit() {
        var s = fundedState()
        s.finances.cash = -1_000_000
        s.finances.weeksInDebt = 7
        XCTAssertTrue(s.fundingAvailable)
        s = SimulationEngine.advanceWeek(s)
        XCTAssertEqual(s.outcome, .playing, "lenders still willing")
        XCTAssertEqual(s.finances.weeksInDebt, 8)

        s.finances.weeksInDebt = SimulationEngine.hardDebtLimit - 1
        s = SimulationEngine.advanceWeek(s)
        XCTAssertEqual(s.outcome, .lost)
    }

    func testNoFundingMeansEightWeekRuleStillApplies() {
        var s = newState()
        s.finances.cash = -1_000_000
        s.finances.weeksInDebt = 7
        XCTAssertFalse(s.fundingAvailable)
        s = SimulationEngine.advanceWeek(s)
        XCTAssertEqual(s.outcome, .lost)
    }

    // MARK: Events

    func testViralEventBoostsATitle() {
        var s = newState()
        s.catalog = titles(1)
        s.catalog[0].popularity = 50
        s.catalog[0].ageWeeks = 80
        let event = RandomEvents.create("viral", &s)
        XCTAssertNil(s.pendingEvent)
        XCTAssertTrue(event.headline.contains("viral"))
        XCTAssertEqual(s.catalog[0].popularity, 75)
        XCTAssertEqual(s.catalog[0].ageWeeks, 0)
    }

    func testChoiceEventDoesNotBlockAndSettlesItself() throws {
        var s = newState()
        let event = RandomEvents.create("outage", &s)
        XCTAssertEqual(event.choices.count, 2)
        XCTAssertNotNil(s.pendingEvent)
        XCTAssertGreaterThan(s.pendingEvent!.expiresWeek, s.week)

        let week = s.week
        let next = SimulationEngine.advanceWeek(s)
        XCTAssertEqual(next.week, week + 1, "alerts never stop the calendar")
        XCTAssertNotNil(next.pendingEvent, "still waiting for the player")

        // Ignored alerts apply their default and disappear.
        var later = s
        for _ in 0..<(RandomEvents.alertLastsWeeks + 1) { later = SimulationEngine.advanceWeek(later) }
        XCTAssertNil(later.pendingEvent)
    }

    func testChoiceEventCanBeResolved() throws {
        var s = newState()
        _ = RandomEvents.create("outage", &s)
        XCTAssertThrowsError(try s.resolveEvent(choiceID: "nonsense"))
        let cash = s.finances.cash
        try s.resolveEvent(choiceID: "fix")
        XCTAssertNil(s.pendingEvent)
        XCTAssertLessThan(s.finances.cash, cash)
        XCTAssertThrowsError(try s.resolveEvent(choiceID: "fix"), "already resolved")
    }

    func testRandomEventsAreGatedEarly() {
        var s = newState()
        s.eventsEnabled = true
        s.week = 8
        for _ in 0..<2_000 { XCTAssertNil(RandomEvents.roll(&s)) }
        s.week = 30
        s.lastEventWeek = 25
        for _ in 0..<2_000 { XCTAssertNil(RandomEvents.roll(&s), "cool-down between events") }
    }

    func testStrikeDelaysOrCostsMoney() throws {
        var s = newState()
        try s.commissionOriginal(kind: .movie, genre: .drama, language: .english, budget: 4_000_000, weeks: 10)
        var delayed = s
        _ = RandomEvents.create("strike", &delayed)
        try delayed.resolveEvent(choiceID: "wait")
        XCTAssertEqual(delayed.projects[0].weeksLeft, 16)

        var paid = s
        _ = RandomEvents.create("strike", &paid)
        let cash = paid.finances.cash
        try paid.resolveEvent(choiceID: "pay")
        XCTAssertEqual(paid.projects[0].weeksLeft, 10)
        XCTAssertEqual(paid.finances.cash, cash - 600_000, accuracy: 0.01)
    }

    func testPiracyAndOutageIgnoredLoseSubscribers() throws {
        var s = newState()
        s.markets["IE"]?.subs = TierSet(ad: 0, standard: 10_000, premium: 0)
        _ = RandomEvents.create("piracy", &s)
        try s.resolveEvent(choiceID: "ignore")
        XCTAssertEqual(s.markets["IE"]!.subs.total, 9_900, accuracy: 1e-6)
    }

    func testRecessionDurationAndEffect() throws {
        var s = newState()
        _ = RandomEvents.create("recession", &s)
        var promo = s
        try s.resolveEvent(choiceID: "hold")
        XCTAssertEqual(s.recessionWeeksLeft, 26)
        _ = promo
        promo = newState()
        _ = RandomEvents.create("recession", &promo)
        try promo.resolveEvent(choiceID: "promo")
        XCTAssertEqual(promo.recessionWeeksLeft, 12)

        // Recession slows sign-ups and raises churn.
        func week(recession: Bool) -> WeeklyReport {
            var t = newState()
            t.catalog = titles(20)
            t.markets["IE"]?.awareness = 0.5
            t.markets["IE"]?.subs = TierSet(ad: 0, standard: 50_000, premium: 0)
            t.recessionWeeksLeft = recession ? 5 : 0
            return SimulationEngine.advanceWeek(t).lastReport!
        }
        let normal = week(recession: false), down = week(recession: true)
        XCTAssertLessThan(down.newSubs, normal.newSubs)
        XCTAssertGreaterThan(down.churned, normal.churned)
    }

    func testRecessionCountsDownAndEnds() {
        var s = newState()
        s.recessionWeeksLeft = 2
        s = SimulationEngine.advanceWeek(s)
        XCTAssertEqual(s.recessionWeeksLeft, 1)
        s = SimulationEngine.advanceWeek(s)
        XCTAssertEqual(s.recessionWeeksLeft, 0)
        XCTAssertTrue(s.lastReport!.events.contains { $0.headline == "Recession over" })
    }

    func testRandomEventsEventuallyFireAndAreDeterministic() {
        func run() -> GameState {
            var s = newState(events: true)
            s.markets["IE"]?.subs = TierSet(ad: 0, standard: 8_000, premium: 0)
            for _ in 0..<600 {
                if s.pendingEvent != nil { break }
                s = SimulationEngine.advanceWeek(s)
            }
            return s
        }
        let a = run(), b = run()
        XCTAssertNotNil(a.pendingEvent, "a decision event should appear within 600 weeks")
        XCTAssertEqual(a, b)
    }

    // MARK: Goals

    func testBonusGoalsAreRecorded() {
        var s = newState()
        for code in s.markets.keys { s.markets[code]?.status = .live }
        s.finances.revenueHistory = Array(repeating: 200_000_000, count: 52)
        s = SimulationEngine.advanceWeek(s)
        XCTAssertTrue(s.goals.contains("allMarkets"))
        XCTAssertTrue(s.goals.contains("revenue10B"))
        let before = s.goals
        s = SimulationEngine.advanceWeek(s)
        XCTAssertEqual(s.goals, before, "goals are only recorded once")
    }

    // MARK: Persistence

    func testPhase3StateRoundTrips() throws {
        var s = fundedState()
        try s.commissionOriginal(kind: .series, genre: .drama, language: .dutch, budget: 10_000_000, weeks: 30)
        try s.takeLoan(amount: 1_000_000, termWeeks: 104)
        try s.raiseRound(percent: 0.1)
        _ = RandomEvents.create("password", &s)
        let data = try JSONEncoder().encode(s)
        let loaded = try JSONDecoder().decode(GameState.self, from: data)
        XCTAssertEqual(loaded, s)
        XCTAssertNotNil(loaded.pendingEvent)
    }
}
