import XCTest
#if canImport(StreamEmpireCore)
@testable import StreamEmpireCore
#else
@testable import StreamEmpire
#endif

final class Phase15Tests: XCTestCase {
    private func newState(_ difficulty: Difficulty = .medium, seed: UInt64 = 42) -> GameState {
        var s = GameState.newGame(startCountry: "IE", companyName: "Test Co", seed: seed, difficulty: difficulty)
        s.eventsEnabled = false
        s.finances.cash = 1e12
        s.cloudUnits[Region.europe.rawValue] = 10
        return s
    }

    private func titles(_ n: Int) -> [Title] {
        (0..<n).map {
            Title(id: 40_000 + $0, name: "R\($0)", kind: .movie, genre: .drama, language: .english, quality: 70,
                  popularity: 70, ageWeeks: 0, isOriginal: true, license: nil, weeksRemaining: nil, listingWeeksLeft: 0)
        }
    }

    /// A week of results with a promotion running.
    private func week(_ kind: PromotionKind?, intensity: Double = 0.3, scope: String = "", live: [String] = [],
                      configure: (inout GameState) -> Void = { _ in }) throws -> (GameState, WeeklyReport) {
        var s = newState()
        s.catalog = titles(15)
        for code in live { s.markets[code]?.status = .live }
        for code in ["IE"] + live {
            s.markets[code]?.awareness = 0.4
            s.markets[code]?.subs = TierSet(ad: 5_000, standard: 20_000, premium: 5_000)
        }
        configure(&s)
        if let kind { try s.launchPromotion(kind: kind, scope: scope, weeks: 4, intensity: intensity) }
        let next = SimulationEngine.advanceWeek(s)
        return (next, next.lastReport!)
    }

    // MARK: Math

    func testKindsAreDescribed() {
        XCTAssertEqual(PromotionKind.allCases.count, 5)
        for kind in PromotionKind.allCases {
            XCTAssertFalse(kind.title.isEmpty); XCTAssertFalse(kind.blurb.isEmpty)
            XCTAssertFalse(kind.pros.isEmpty); XCTAssertFalse(kind.cons.isEmpty)
        }
        XCTAssertTrue(PromotionKind.discount.usesIntensity)
        XCTAssertFalse(PromotionKind.blitz.usesIntensity)
    }

    func testEffectsOfEachCampaign() {
        let d30 = PromoMath.effects(kind: .discount, intensity: 0.3, strength: 1)
        XCTAssertEqual(d30.adds, 1.45, accuracy: 1e-9)
        XCTAssertEqual(d30.arpu, 0.82, accuracy: 1e-9)
        XCTAssertGreaterThan(PromoMath.effects(kind: .discount, intensity: 0.5, strength: 1).adds, d30.adds)
        XCTAssertLessThan(PromoMath.effects(kind: .discount, intensity: 0.5, strength: 1).arpu, d30.arpu)
        XCTAssertEqual(PromoMath.effects(kind: .freeTrial, intensity: 0, strength: 1).streaming, 1.05)
        XCTAssertEqual(PromoMath.effects(kind: .twoForOne, intensity: 0, strength: 1).arpu, 0.94)
        XCTAssertGreaterThan(PromoMath.effects(kind: .blitz, intensity: 0, strength: 1).awareness, 0)
        XCTAssertEqual(PromoMath.effects(kind: .blitz, intensity: 0, strength: 1).arpu, 1.0, "no revenue hit")
        XCTAssertLessThan(PromoMath.effects(kind: .winback, intensity: 0, strength: 1).churn, 1)
        XCTAssertLessThan(PromoMath.effects(kind: .discount, intensity: 0.3, strength: 0.6).adds, d30.adds, "weaker when fatigued")
    }

    func testHangoversFollowTheRushes() {
        XCTAssertNotNil(PromoMath.hangover(kind: .discount, intensity: 0.5, weeks: 6))
        XCTAssertEqual(PromoMath.hangover(kind: .discount, intensity: 0.5, weeks: 6)?.weeks, 4)
        XCTAssertGreaterThan(PromoMath.hangover(kind: .discount, intensity: 0.5, weeks: 6)!.churn, PromoMath.hangover(kind: .discount, intensity: 0.2, weeks: 6)!.churn)
        XCTAssertNotNil(PromoMath.hangover(kind: .freeTrial, intensity: 0, weeks: 4))
        XCTAssertNil(PromoMath.hangover(kind: .blitz, intensity: 0, weeks: 4))
        XCTAssertNil(PromoMath.hangover(kind: .winback, intensity: 0, weeks: 4))
    }

    func testPolicyAndFatigueChangeEffectiveness() {
        XCTAssertEqual(PromoMath.effectiveness(promosPolicy: "seasonal", fatigued: false), 1.0)
        XCTAssertGreaterThan(PromoMath.effectiveness(promosPolicy: "never", fatigued: false), 1.0)
        XCTAssertLessThan(PromoMath.effectiveness(promosPolicy: "always", fatigued: false), 1.0)
        XCTAssertLessThan(PromoMath.effectiveness(promosPolicy: "never", fatigued: true), PromoMath.effectiveness(promosPolicy: "never", fatigued: false))
    }

    func testCostsScaleWithLengthMarketsAndDifficulty() {
        let base = PromoMath.cost(kind: .blitz, weeks: 4, markets: 1, costScale: 1)
        XCTAssertEqual(base, 120_000 + 4 * 40_000, accuracy: 0.01)
        XCTAssertGreaterThan(PromoMath.cost(kind: .blitz, weeks: 8, markets: 1, costScale: 1), base)
        XCTAssertGreaterThan(PromoMath.cost(kind: .blitz, weeks: 4, markets: 5, costScale: 1), base)
        XCTAssertLessThan(PromoMath.cost(kind: .blitz, weeks: 4, markets: 5, costScale: 1), base * 5, "bulk discount")
        XCTAssertEqual(PromoMath.cost(kind: .blitz, weeks: 4, markets: 1, costScale: 1.4), base * 1.4, accuracy: 0.01)
        let hard = newState(.hard), medium = newState(.medium)
        XCTAssertEqual(hard.promotionQuote(kind: .winback, scope: "", weeks: 4, intensity: 0).cost
                       / medium.promotionQuote(kind: .winback, scope: "", weeks: 4, intensity: 0).cost, 1.4, accuracy: 1e-9)
    }

    // MARK: Launching

    func testLaunchingChargesAndAnnounces() throws {
        var s = newState()
        let quote = s.promotionQuote(kind: .discount, scope: "", weeks: 4, intensity: 0.3)
        let cash = s.finances.cash
        try s.launchPromotion(kind: .discount, scope: "", weeks: 4, intensity: 0.3)
        XCTAssertEqual(cash - s.finances.cash, quote.cost, accuracy: 0.01)
        XCTAssertEqual(s.finances.ledger.promotions, quote.cost, accuracy: 0.01)
        XCTAssertEqual(s.promotions.count, 1)
        XCTAssertEqual(s.promotions[0].weeksLeft, 4)
        XCTAssertTrue(s.news.first!.headline.contains("30%-off deal"))
        XCTAssertEqual(s.news.first!.kind, .pricing)
        let report = SimulationEngine.advanceWeek(s).lastReport!.financials
        XCTAssertEqual(report.promotions, quote.cost, accuracy: 0.01, "shown as its own cost line")
    }

    func testLaunchRules() throws {
        var s = newState()
        XCTAssertThrowsError(try s.launchPromotion(kind: .blitz, scope: "", weeks: 0))
        XCTAssertThrowsError(try s.launchPromotion(kind: .blitz, scope: "", weeks: 13))
        XCTAssertThrowsError(try s.launchPromotion(kind: .blitz, scope: "NZ", weeks: 4), "not live there")
        XCTAssertThrowsError(try s.launchPromotion(kind: .discount, scope: "", weeks: 4, intensity: 0.05))
        XCTAssertThrowsError(try s.launchPromotion(kind: .discount, scope: "", weeks: 4, intensity: 0.9))
        try s.launchPromotion(kind: .blitz, scope: "", weeks: 4)
        XCTAssertThrowsError(try s.launchPromotion(kind: .blitz, scope: "IE", weeks: 4), "already running one")
        try s.launchPromotion(kind: .winback, scope: "IE", weeks: 4)
        try s.launchPromotion(kind: .freeTrial, scope: "", weeks: 4)
        XCTAssertThrowsError(try s.launchPromotion(kind: .twoForOne, scope: "", weeks: 4), "at most 3 at once")
        var poor = newState()
        poor.finances.cash = 100
        XCTAssertThrowsError(try poor.launchPromotion(kind: .blitz, scope: "", weeks: 4))
        XCTAssertTrue(poor.promotions.isEmpty)
    }

    // MARK: Effects

    func testDiscountsBoostSignupsAndCutRevenue() throws {
        let base = try week(nil), promo = try week(.discount, intensity: 0.3)
        // The default "never discount" policy makes promotions land 15% harder: 1 + 1.5 x 0.3 x 1.15.
        XCTAssertEqual(promo.1.newSubs / base.1.newSubs, 1 + 1.5 * 0.3 * 1.15, accuracy: 0.001)
        XCTAssertEqual(promo.1.financials.subscriptionRevenue / base.1.financials.subscriptionRevenue, 0.82, accuracy: 1e-6)
        XCTAssertEqual(promo.1.financials.adRevenue, base.1.financials.adRevenue, accuracy: 1e-6, "ads unaffected")
    }

    func testEachCampaignMovesItsOwnLevers() throws {
        let base = try week(nil)
        XCTAssertGreaterThan(try week(.freeTrial).1.financials.streaming, base.1.financials.streaming)
        XCTAssertEqual(try week(.freeTrial).1.financials.streaming / base.1.financials.streaming, 1.05, accuracy: 1e-6)
        XCTAssertEqual(try week(.twoForOne).1.financials.subscriptionRevenue / base.1.financials.subscriptionRevenue, 0.94, accuracy: 1e-6)
        XCTAssertEqual(try week(.blitz).1.financials.subscriptionRevenue, base.1.financials.subscriptionRevenue, accuracy: 1e-6)
        XCTAssertGreaterThan(try week(.blitz).0.markets["IE"]!.awareness, base.0.markets["IE"]!.awareness)
        XCTAssertLessThan(try week(.winback).1.churned, base.1.churned)
        for kind in PromotionKind.allCases { XCTAssertGreaterThan(try week(kind).1.newSubs, base.1.newSubs, "\(kind)") }
    }

    func testCountryScopedPromotionsOnlyAffectThatCountry() throws {
        let base = try week(nil, live: ["NZ"])
        let ie = try week(.discount, scope: "IE", live: ["NZ"])
        func subs(_ r: (GameState, WeeklyReport), _ code: String) -> Double { r.1.markets.first { $0.id == code }!.newSubs }
        XCTAssertGreaterThan(subs(ie, "IE"), subs(base, "IE") * 1.4)
        XCTAssertEqual(subs(ie, "NZ"), subs(base, "NZ"), accuracy: 1e-9)
        let all = try week(.discount, scope: "", live: ["NZ"])
        XCTAssertGreaterThan(subs(all, "NZ"), subs(base, "NZ") * 1.4)
    }

    func testPromotionsPolicyAndFatigueMatter() throws {
        let normal = try week(.discount, intensity: 0.5).1.newSubs
        let never = try week(.discount, intensity: 0.5) { try? $0.setPolicy("promos", option: "never") }.1.newSubs
        XCTAssertEqual(try week(nil).1.newSubs > 0, true)
        // The policy is applied when the campaign launches; "never" makes it hit harder, "always" blunts it.
        var s = newState()
        try s.setPolicy("promos", option: "always")
        XCTAssertLessThan(s.promotionQuote(kind: .discount, scope: "", weeks: 4, intensity: 0.5).strength, 1)
        let calm = newState()    // the default policy is already "never discount"
        XCTAssertEqual(calm.policyOptionID("promos"), "never")
        XCTAssertEqual(calm.promotionQuote(kind: .discount, scope: "", weeks: 4, intensity: 0.5).strength, 1.15, accuracy: 1e-9)
        XCTAssertGreaterThan(never, 0); XCTAssertGreaterThan(normal, 0)

        var repeated = newState()
        try repeated.launchPromotion(kind: .blitz, scope: "", weeks: 1)
        _ = repeated.promotionQuote(kind: .blitz, scope: "", weeks: 1, intensity: 0)
        repeated = SimulationEngine.advanceWeek(repeated)
        XCTAssertTrue(repeated.promotions.isEmpty)
        XCTAssertTrue(repeated.isPromoFatigued(.blitz))
        XCTAssertLessThan(repeated.promotionQuote(kind: .blitz, scope: "", weeks: 1, intensity: 0).strength, 1)
        XCTAssertFalse(repeated.isPromoFatigued(.discount))
    }

    // MARK: Ending

    func testPromotionsEndLeaveAHangoverAndAResult() throws {
        var s = newState()
        s.catalog = titles(15)
        s.markets["IE"]?.awareness = 0.4
        s.markets["IE"]?.subs = TierSet(ad: 5_000, standard: 20_000, premium: 5_000)
        try s.launchPromotion(kind: .discount, scope: "", weeks: 3, intensity: 0.5)
        let trust = s.brandTrust
        for _ in 0..<3 { s = SimulationEngine.advanceWeek(s) }
        XCTAssertTrue(s.promotions.isEmpty, "over after its three weeks")
        XCTAssertEqual(s.promoHistory.count, 1)
        let result = s.promoHistory[0]
        XCTAssertEqual(result.kind, .discount)
        XCTAssertGreaterThan(result.subscribersGained, 0)
        XCTAssertTrue(result.note.contains("net subscribers"))
        XCTAssertTrue(s.news.contains { $0.headline.contains("percent-off deal ends") })
        XCTAssertLessThan(s.brandTrust, trust, "deep discounts cheapen the brand")
        XCTAssertFalse(s.promoHangovers.isEmpty)
        XCTAssertGreaterThan(s.promoEffects(for: "IE").churn, 1)

        // The afterglow: extra churn for a couple of weeks, then it fades.
        let hangoverWeeks = s.promoHangovers[0].weeksLeft
        for _ in 0..<hangoverWeeks { s = SimulationEngine.advanceWeek(s) }
        XCTAssertTrue(s.promoHangovers.isEmpty)
        XCTAssertEqual(s.promoEffects(for: "IE"), .neutral)
    }

    func testHangoverRaisesChurn() throws {
        var s = newState()
        s.catalog = titles(15)
        s.markets["IE"]?.subs = TierSet(ad: 5_000, standard: 20_000, premium: 5_000)
        var plain = s
        s.promoHangovers = [PromoHangover(scope: "", weeksLeft: 3, churn: 1.3)]
        let hung = SimulationEngine.advanceWeek(s).lastReport!.churned
        plain = SimulationEngine.advanceWeek(plain)
        XCTAssertEqual(hung / plain.lastReport!.churned, 1.3, accuracy: 0.001)
    }

    func testCancellingEarly() throws {
        var s = newState()
        try s.launchPromotion(kind: .freeTrial, scope: "", weeks: 8)
        let id = s.promotions[0].id
        let paid = s.promotions[0].cost
        let cash = s.finances.cash
        s = SimulationEngine.advanceWeek(s)
        try s.cancelPromotion(id: id)
        XCTAssertTrue(s.promotions.isEmpty)
        XCTAssertEqual(s.finances.cash, cash + s.finances.lastWeek.profit + paid, accuracy: 1, "no refund")
        XCTAssertEqual(s.promoHistory.first?.weeks, 1)
        XCTAssertThrowsError(try s.cancelPromotion(id: id))
        XCTAssertTrue(s.isPromoFatigued(.freeTrial))
    }

    func testBlitzesHelpTrustAndCostCategory() throws {
        var s = newState()
        try s.launchPromotion(kind: .blitz, scope: "", weeks: 1)
        let trust = s.brandTrust
        s = SimulationEngine.advanceWeek(s)
        XCTAssertGreaterThan(s.brandTrust, trust - 0.0001)
        XCTAssertTrue(CostCategory.allCases.contains(.promotions))
        XCTAssertTrue(s.costBreakdown().contains { $0.category == .promotions })
        XCTAssertEqual(s.costBreakdown().reduce(0) { $0 + $1.amount }, s.finances.lastWeek.costs, accuracy: 0.01)
    }

    func testHistoryIsCappedAndSavesRoundTrip() throws {
        var s = newState()
        for i in 0..<15 {
            try s.launchPromotion(kind: .winback, scope: "", weeks: 1)
            s = SimulationEngine.advanceWeek(s)
            s.promoLastEnded = [:]
            _ = i
        }
        XCTAssertEqual(s.promoHistory.count, 12)
        try s.launchPromotion(kind: .discount, scope: "IE", weeks: 5, intensity: 0.25)
        let loaded = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(s))
        XCTAssertEqual(loaded, s)
        XCTAssertEqual(loaded.promotions.first?.intensity, 0.25)
    }
}
