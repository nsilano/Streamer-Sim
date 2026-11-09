import XCTest
#if canImport(StreamEmpireCore)
@testable import StreamEmpireCore
#else
@testable import StreamEmpire
#endif

final class Phase12Tests: XCTestCase {
    private func newState(seed: UInt64 = 42) -> GameState {
        var s = GameState.newGame(startCountry: "IE", companyName: "Test Co", seed: seed)
        s.eventsEnabled = false
        s.finances.cash = 1e12
        return s
    }

    private func titles(_ n: Int) -> [Title] {
        (0..<n).map {
            Title(id: 30_000 + $0, name: "P\($0)", kind: .movie, genre: .drama, language: .english, quality: 70,
                  popularity: 70, ageWeeks: 0, isOriginal: true, license: nil, weeksRemaining: nil, listingWeeksLeft: 0)
        }
    }

    /// One week of results with a policy set (or the defaults).
    private func week(_ policy: (String, String)? = nil, subs: TierSet = TierSet(ad: 20_000, standard: 50_000, premium: 10_000),
                      configure: (inout GameState) -> Void = { _ in }) throws -> (GameState, WeeklyReport) {
        var s = newState()
        s.catalog = titles(15)
        s.markets["IE"]?.awareness = 0.4
        s.markets["IE"]?.subs = subs
        s.cloudUnits[Region.europe.rawValue] = 10
        configure(&s)
        if let (id, option) = policy { try s.setPolicy(id, option: option, forcedBad: false) }
        let next = SimulationEngine.advanceWeek(s)
        return (next, next.lastReport!)
    }

    // MARK: The data

    func testPolicyDefinitionsAreConsistent() {
        let all = PolicyData.all
        XCTAssertGreaterThanOrEqual(all.count, 20)
        XCTAssertEqual(Set(all.map(\.id)).count, all.count, "unique policy ids")
        for category in PolicyCategory.allCases { XCTAssertTrue(all.contains { $0.category == category }, "\(category)") }
        for definition in all {
            XCTAssertGreaterThanOrEqual(definition.options.count, 2, definition.id)
            XCTAssertEqual(Set(definition.options.map(\.id)).count, definition.options.count, definition.id)
            let fallback = definition.option(definition.defaultOption)
            XCTAssertNotNil(fallback, "\(definition.id) has a default")
            XCTAssertEqual(fallback?.effects, .neutral, "\(definition.id): the default option must be neutral")
            XCTAssertEqual(fallback?.cost, 0)
            XCTAssertFalse(definition.summary.isEmpty)
            for option in definition.options {
                XCTAssertFalse(option.title.isEmpty); XCTAssertFalse(option.detail.isEmpty)
                if option.id != definition.defaultOption {
                    XCTAssertTrue(!option.pros.isEmpty || !option.cons.isEmpty, "\(definition.id).\(option.id) explains itself")
                }
                for m in [option.effects.adds, option.effects.churn, option.effects.arpu, option.effects.adRevenue,
                          option.effects.streamingCost, option.effects.fines] {
                    XCTAssertTrue((0.5...1.5).contains(m), "\(definition.id).\(option.id) multiplier \(m)")
                }
                if option.badChance > 0 { XCTAssertNotNil(option.bad, "\(definition.id).\(option.id) can go badly") }
            }
        }
        XCTAssertNotNil(PolicyData.definition("sharing")?.option("household")?.bad)
        XCTAssertNotNil(PolicyData.definition("sharing")?.option("household")?.good)
    }

    func testNewGamesAreNeutralAndStayThatWay() {
        var s = newState()
        XCTAssertEqual(s.policyEffects(), .neutral)
        XCTAssertEqual(s.brandTrust, 60)
        XCTAssertEqual(s.regulatoryHeat, 0)
        XCTAssertTrue(s.policySummary().isEmpty)
        for _ in 0..<20 { s = SimulationEngine.advanceWeek(s) }
        XCTAssertEqual(s.brandTrust, 60, accuracy: 1e-9)
        XCTAssertEqual(s.regulatoryHeat, 0, accuracy: 1e-9)
    }

    // MARK: Enacting

    func testChangingAPolicy() throws {
        var s = newState()
        let reaction = try s.setPolicy("trial", option: "seven")
        XCTAssertEqual(s.policyOptionID("trial"), "seven")
        XCTAssertEqual(s.policyLog.first, reaction)
        XCTAssertEqual(reaction.tone, .mixed)
        XCTAssertTrue(s.news.first!.headline.contains("free trial"))
        XCTAssertEqual(s.policySummary().first { $0.label == "New subscribers" }?.percent ?? 0, 0.12, accuracy: 1e-9)
        XCTAssertThrowsError(try s.setPolicy("trial", option: "seven"), "already active")
        XCTAssertThrowsError(try s.setPolicy("trial", option: "thirty"), "cooldown") { error in
            guard case ActionError.locked = error else { return XCTFail("\(error)") }
        }
        XCTAssertEqual(s.weeksUntilPolicyCanChange("trial"), Formulas.policyCooldownWeeks)
        s.week += Formulas.policyCooldownWeeks
        XCTAssertNoThrow(try s.setPolicy("trial", option: "thirty"))
        XCTAssertThrowsError(try s.setPolicy("nope", option: "x"))
        XCTAssertThrowsError(try s.setPolicy("trial", option: "nope"))
    }

    func testSetupCostsAndAudienceRequirements() throws {
        var s = newState()
        XCTAssertThrowsError(try s.setPolicy("bundles", option: "telecom"), "needs 50k subscribers")
        s.markets["IE"]?.subs = TierSet(ad: 0, standard: 60_000, premium: 0)
        let cash = s.finances.cash
        try s.setPolicy("bundles", option: "telecom")
        XCTAssertEqual(s.finances.cash, cash - 300_000, accuracy: 0.01)
        XCTAssertEqual(s.finances.ledger.other, 300_000, accuracy: 0.01)
        var poor = newState()
        poor.finances.cash = 1_000
        XCTAssertThrowsError(try poor.setPolicy("support", option: "premium"))
        let definition = PolicyData.definition("support")!
        XCTAssertNotNil(poor.policyBlocker(definition, definition.option("premium")!))
        XCTAssertNil(poor.policyBlocker(definition, definition.option("selfserve")!))
    }

    // MARK: Reactions: good and bad

    func testAGoodReaction() throws {
        var s = newState()
        s.markets["IE"]?.subs = TierSet(ad: 0, standard: 100_000, premium: 0)
        let reaction = try s.setPolicy("sharing", option: "household", forcedBad: false)
        XCTAssertEqual(reaction.tone, .good)
        XCTAssertEqual(reaction.subscribersChange, 5_000, accuracy: 1, "+5% conversions")
        XCTAssertEqual(s.markets["IE"]!.subs.standard, 105_000, accuracy: 1)
        XCTAssertEqual(s.brandTrust, 57, accuracy: 1e-9)
        XCTAssertEqual(s.policyShocks.first?.adds, 1.15)
        XCTAssertTrue(s.news.contains { $0.headline == "Crackdown converts sharers" })
    }

    func testABadReactionHurtsAndRivalsPounce() throws {
        var s = newState()
        s.markets["IE"]?.subs = TierSet(ad: 0, standard: 100_000, premium: 0)
        let levelsBefore = s.rivals.map(\.priceLevel)
        let reaction = try s.setPolicy("sharing", option: "household", forcedBad: true)
        XCTAssertEqual(reaction.tone, .bad)
        XCTAssertEqual(reaction.subscribersChange, -4_000, accuracy: 1)
        XCTAssertEqual(s.brandTrust, 50, accuracy: 1e-9)
        XCTAssertEqual(s.policyShocks.first?.churn, 1.6)
        XCTAssertTrue(zip(levelsBefore, s.rivals.map(\.priceLevel)).contains { $0 > $1 }, "a rival cuts prices to exploit it")
        XCTAssertTrue(s.news.contains { $0.headline.contains("pounces") })
        // The backlash fades: shocks expire, trust recovers slowly.
        var later = s
        for _ in 0..<7 { later = SimulationEngine.advanceWeek(later) }
        XCTAssertTrue(later.policyShocks.isEmpty)
    }

    func testReactionsAreRandomButDeterministicAndTrustHelps() throws {
        func outcomes(trust: Double) throws -> Int {
            var bad = 0
            for seed in UInt64(1)...60 {
                var s = newState(seed: seed)
                s.brandTrust = trust
                if try s.setPolicy("sharing", option: "household").tone == .bad { bad += 1 }
            }
            return bad
        }
        XCTAssertEqual(try outcomes(trust: 60), try outcomes(trust: 60), "deterministic")
        XCTAssertGreaterThan(try outcomes(trust: 5), try outcomes(trust: 95), "trusted brands get the benefit of the doubt")
        XCTAssertGreaterThan(try outcomes(trust: 60), 0)
        XCTAssertLessThan(try outcomes(trust: 60), 60)
    }

    func testSafeChangesGiveAMixedReactionWithNoRoll() throws {
        var a = newState(seed: 1), b = newState(seed: 1)
        _ = try a.setPolicy("promos", option: "seasonal")
        XCTAssertEqual(a.rng, b.rng, "no dice rolled")
        XCTAssertEqual(a.policyLog.first?.tone, .mixed)
        _ = try b.setPolicy("sharing", option: "household")
        XCTAssertNotEqual(b.rng, newState(seed: 1).rng)
    }

    // MARK: Effects on the business

    func testFreeTrialsBringMoreSignups() throws {
        let base = try week().1.newSubs, thirty = try week(("trial", "thirty")).1.newSubs
        XCTAssertEqual(thirty / base, 1.25, accuracy: 0.001)
    }

    func testPasswordCrackdownRaisesRevenuePerSubscriber() throws {
        let base = try week().1.financials.subscriptionRevenue
        let household = try week(("sharing", "household")).1.financials.subscriptionRevenue
        // +10% per subscriber, and a good reaction converts 5% more sharers into subscribers right away.
        XCTAssertEqual(household / base, 1.10 * 1.05, accuracy: 1e-6)
    }

    func testAdLoadAndPrivacyMoveAdRevenue() throws {
        let base = try week().1.financials.adRevenue
        XCTAssertEqual(try week(("adload", "heavy")).1.financials.adRevenue / base, 1.35, accuracy: 1e-6)
        XCTAssertEqual(try week(("adload", "light")).1.financials.adRevenue / base, 0.7, accuracy: 1e-6)
        XCTAssertEqual(try week(("privacy", "monetize")).1.financials.adRevenue / base, 1.2, accuracy: 1e-6)
    }

    func testVideoQualityMovesHostingCosts() throws {
        let base = try week().1.financials.streaming
        XCTAssertEqual(try week(("quality", "all4k")).1.financials.streaming / base, 1.2, accuracy: 1e-6)
        XCTAssertEqual(try week(("quality", "saver")).1.financials.streaming / base, 0.85, accuracy: 1e-6)
    }

    func testRunningCostsOfPoliciesAreReported() throws {
        let support = try week(("support", "premium"))
        XCTAssertEqual(support.1.financials.policies, 0.025 * support.1.financials.revenue, accuracy: 0.01)
        XCTAssertEqual(try week(("moderation", "strict")).1.financials.policies, 8_000, accuracy: 0.01)
        XCTAssertEqual(try week().1.financials.policies, 0)
        XCTAssertTrue(CostCategory.allCases.contains(.policies))
        let lines = support.0.costBreakdown()
        XCTAssertTrue(lines.contains { $0.category == .policies })
        XCTAssertEqual(lines.reduce(0) { $0 + $1.amount }, support.0.finances.lastWeek.costs, accuracy: 0.01)
    }

    func testChurnPolicies() throws {
        let base = try week().1.churned
        XCTAssertLessThan(try week(("cancel", "maze")).1.churned, base * 0.9)
        XCTAssertLessThan(try week(("annual", "both")).1.churned, base)
        XCTAssertGreaterThan(try week(("schedule", "binge")).1.churned, base)
    }

    func testLocalCommitmentCutsFines() throws {
        func fines(_ option: String?) throws -> Double {
            var s = newState()
            s.week = 60
            s.markets["NL"]?.status = .live
            s.markets["NL"]?.subs = TierSet(ad: 0, standard: 100_000, premium: 0)
            s.catalog = titles(10)
            if let option { try s.setPolicy("local", option: option) }
            return SimulationEngine.advanceWeek(s).lastReport!.financials.fines
        }
        let base = try fines(nil)
        XCTAssertGreaterThan(base, 0)
        XCTAssertEqual(try fines("champion") / base, 0.5, accuracy: 0.01)
        XCTAssertEqual(try fines("minimal") / base, 1.4, accuracy: 0.01)
    }

    func testBrandTrustAndRegulatoryHeatDriftWithPolicies() throws {
        var s = newState()
        try s.setPolicy("cancel", option: "maze", forcedBad: false)
        for _ in 0..<12 { s = SimulationEngine.advanceWeek(s) }
        XCTAssertLessThan(s.brandTrust, 58, "dark patterns erode trust")
        XCTAssertGreaterThan(s.regulatoryHeat, 3, "and attract regulators")
        var kind = newState()
        try kind.setPolicy("cancel", option: "easy")
        try kind.setPolicy("privacy", option: "strict")
        for _ in 0..<30 { kind = SimulationEngine.advanceWeek(kind) }
        XCTAssertGreaterThan(kind.brandTrust, 60)
        XCTAssertEqual(kind.regulatoryHeat, 0, accuracy: 1e-9, "heat never goes below zero")
        for _ in 0..<400 { s = SimulationEngine.advanceWeek(s) }
        XCTAssertTrue((0.0...100.0).contains(s.brandTrust) && (0.0...100.0).contains(s.regulatoryHeat))
    }

    func testTrustMovesSignupsAndChurn() {
        var low = newState(), high = newState()
        low.brandTrust = 20
        high.brandTrust = 100
        XCTAssertLessThan(low.policyEffects().adds, 1)
        XCTAssertGreaterThan(high.policyEffects().adds, 1)
        XCTAssertEqual(high.policyEffects().adds, 1.12, accuracy: 1e-9)
        XCTAssertEqual(high.policyEffects().churn, 0.88, accuracy: 1e-9)
        XCTAssertGreaterThan(low.policyEffects().churn, 1)
        high.regulatoryHeat = 50
        XCTAssertEqual(high.policyEffects().fines, 1.5, accuracy: 1e-9)
    }

    func testHeatMakesRegulationEventsMoreLikely() {
        var calm = newState(), hot = newState()
        for s in [0, 1] {
            var state = s == 0 ? calm : hot
            state.eventsEnabled = true
            state.week = 80
            state.finances.revenueHistory = Array(repeating: 1_000_000, count: 52)
            if s == 1 { state.regulatoryHeat = 90 }
            if s == 0 { calm = state } else { hot = state }
        }
        func regulations(_ start: GameState) -> Int {
            var s = start
            var count = 0
            for _ in 0..<3_000 {
                s.pendingEvent = nil
                s.lastRegulationWeek = -100
                if let event = RandomEvents.roll(&s), event.key == "regulation" { count += 1 }
            }
            return count
        }
        XCTAssertGreaterThan(regulations(hot), regulations(calm))
    }

    func testPoliciesSurviveSaves() throws {
        var s = newState()
        try s.setPolicy("sharing", option: "household", forcedBad: true)
        try s.setPolicy("adload", option: "heavy")
        let loaded = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(s))
        XCTAssertEqual(loaded, s)
        XCTAssertEqual(loaded.policyOptionID("adload"), "heavy")
        XCTAssertEqual(loaded.policyLog.count, 2)
        XCTAssertEqual(loaded.policyShocks.count, 1)
    }
}
