import XCTest
#if canImport(StreamEmpireCore)
@testable import StreamEmpireCore
#else
@testable import StreamEmpire
#endif

final class Phase20Tests: XCTestCase {
    private func newState(_ code: String = "IE") -> GameState {
        var s = GameState.newGame(startCountry: code, companyName: "Test Co", seed: 33)
        s.eventsEnabled = false
        s.finances.cash = 1e9
        s.markets[code]?.subs = TierSet(ad: 0, standard: 50_000, premium: 0)
        return s
    }

    private func licensed(id: Int, exclusive: Bool = false, quality: Int = 70) -> Title {
        Title(id: id, name: "L\(id)", kind: .series, genre: .drama, language: .english, quality: quality, popularity: 60,
              ageWeeks: 10, isOriginal: false,
              license: LicenseTerms(cost: 1_000_000, years: 2, regions: [], exclusive: exclusive),
              weeksRemaining: 90, listingWeeksLeft: 0, paidPrice: 1_000_000, invested: 1_000_000)
    }

    // MARK: Earnings and accounting

    func testQuarterlyReportsAppearEvery13Weeks() {
        var s = newState()
        for _ in 0..<40 { s = SimulationEngine.advanceWeek(s) }
        XCTAssertEqual(s.quarterReports.map(\.id), [1, 2, 3])
        XCTAssertEqual(s.quarterReports[0].verdict, "met", "no expectations to compare with yet")
        XCTAssertTrue(s.news.contains { $0.headline.contains("expectations") })
    }

    func testBeatingExpectationsLiftsValuationAndMissingHurtsIt() {
        var s = newState()
        s.finances.history = Array(repeating: WeeklyFinancials(), count: 13)
        s.week = 26
        s.quarterReports = [QuarterReport(id: 1, week: 13, revenue: 0, profit: 0, accountingProfit: -10_000_000,
                                          expectedProfit: -10_000_000, subscribers: 0, verdict: "met")]
        var beat = s
        Earnings.report(&beat)
        XCTAssertEqual(beat.quarterReports.last?.verdict, "beat")
        XCTAssertGreaterThan(beat.earningsSentiment, 1)
        var miss = s
        miss.quarterReports[0].accountingProfit = 10_000_000
        Earnings.report(&miss)
        XCTAssertEqual(miss.quarterReports.last?.verdict, "missed")
        XCTAssertLessThan(miss.earningsSentiment, 1)
        XCTAssertLessThan(miss.valuation, beat.valuation)
    }

    // MARK: Taxes, currencies, ads

    func testDigitalTaxesApplyWhereTheyExist() {
        var fr = newState("FR"), ie = newState("IE")
        fr = SimulationEngine.advanceWeek(fr)
        ie = SimulationEngine.advanceWeek(ie)
        XCTAssertGreaterThan(fr.lastReport!.financials.taxes, 0)
        XCTAssertEqual(ie.lastReport!.financials.taxes, 0)
        XCTAssertEqual(CostCategory.taxes.amount(in: fr.lastReport!.financials), fr.lastReport!.financials.taxes)
    }

    func testCurrenciesDriftWithinBounds() {
        var s = newState()
        for _ in 0..<300 {
            s.driftCurrencies()
            for region in Region.allCases { XCTAssertTrue((0.8...1.2).contains(s.fxIndex(region))) }
        }
        XCTAssertEqual(s.fxIndex(.northAmerica), 1.0)
        XCTAssertTrue(Region.allCases.filter { $0 != .northAmerica }.contains { s.fxIndex($0) != 1.0 })
    }

    func testAdLoadTradesRevenueForChurn() throws {
        func run(_ load: Double) -> GameState {
            var s = newState()
            s.markets["IE"]?.subs = TierSet(ad: 40_000, standard: 0, premium: 0)
            s.markets["IE"]?.liveTiers = [.ad]
            try? s.setAdLoad(load)
            return SimulationEngine.advanceWeek(s)
        }
        XCTAssertGreaterThan(run(1.5).lastReport!.financials.adRevenue, run(0.5).lastReport!.financials.adRevenue)
        var s = newState()
        XCTAssertThrowsError(try s.setAdLoad(2))
    }

    // MARK: Features

    func testFeaturesCostCashAndUpkeepAndTakeEffect() throws {
        var s = newState()
        XCTAssertEqual(s.featureUpkeep, 0)
        let cash = s.finances.cash
        let price = s.featurePrice(.fourK)
        try s.buyFeature(.fourK)
        XCTAssertEqual(s.finances.cash, cash - price, accuracy: 0.01)
        XCTAssertGreaterThan(s.featureUpkeep, 0)
        XCTAssertThrowsError(try s.buyFeature(.fourK), "single-level feature")
        let ie = CountryData.country("IE")!
        XCTAssertGreaterThan(s.featureEffects(for: ie).streaming, 1)
        XCTAssertLessThan(s.featureEffects(for: ie).churn, 1)
        try s.buyFeature(.recommendations); try s.buyFeature(.recommendations); try s.buyFeature(.recommendations)
        XCTAssertEqual(s.featureEffects(for: ie).appeal, 1.09, accuracy: 1e-9)
        XCTAssertThrowsError(try s.buyFeature(.recommendations))
        XCTAssertLessThan(s.featurePrice(.kidsProfiles), s.featurePrice(.recommendations) + 10_000_000)
    }

    func testFourKCancelsTheTrendPenalty() throws {
        var s = newState()
        s.week = 200
        let ie = CountryData.country("IE")!
        let without = Trends.effects(week: 200).churn * s.featureEffects(for: ie).churn
        try s.buyFeature(.fourK)
        let with = Trends.effects(week: 200).churn * s.featureEffects(for: ie).churn
        XCTAssertLessThan(with, without)
        XCTAssertEqual(with, 0.98, accuracy: 1e-9)
    }

    func testDownloadsHelpPoorMarketsMore() throws {
        var s = newState()
        try s.buyFeature(.downloads)
        let poor = CountryData.all.first { $0.priceTolerance < 6 }!
        let rich = CountryData.all.first { $0.priceTolerance >= 10 }!
        XCTAssertLessThan(s.featureEffects(for: poor).churn, s.featureEffects(for: rich).churn)
        XCTAssertGreaterThan(s.featureEffects(for: poor).adds, 1)
    }

    // MARK: Sports

    func testSportsAuctionsOpenYearlyAndBidsWork() throws {
        var s = newState()
        s.week = 20
        s.refreshSportsOffers()
        XCTAssertFalse(s.sportsOffers.isEmpty)
        let offer = s.sportsOffers[0]
        var wins = 0
        for seed in 1...40 {
            var t = s
            t.rng = SeededRNG(seed: UInt64(seed))
            let cash = t.finances.cash
            try t.bidForSports(offerID: offer.id, premium: 1.6)
            XCTAssertFalse(t.sportsOffers.contains { $0.id == offer.id })
            if !t.sportsHeld.isEmpty {
                wins += 1
                XCTAssertEqual(t.finances.cash, cash - offer.askPrice * 1.6, accuracy: 0.01)
            } else {
                XCTAssertEqual(t.finances.cash, cash, accuracy: 0.01, "losing costs nothing")
            }
        }
        XCTAssertTrue((15...40).contains(wins), "a 60% premium wins most auctions: \(wins)")
        var low = 0
        for seed in 1...40 {
            var t = s; t.rng = SeededRNG(seed: UInt64(seed))
            try t.bidForSports(offerID: offer.id, premium: 1.0)
            if !t.sportsHeld.isEmpty { low += 1 }
        }
        XCTAssertLessThan(low, wins)
    }

    func testHeldSportsRightsBoostTheRegionAndExpire() {
        var s = newState()
        s.sportsHeld = [SportsRight(id: 1, name: "Premier Footy League", region: .europe, weeksLeft: 2)]
        XCTAssertGreaterThan(s.sportsEffects(region: .europe).appealBonus, 0)
        XCTAssertEqual(s.sportsEffects(region: .asiaPacific).appealBonus, 0)
        s.refreshSportsOffers(); s.refreshSportsOffers()
        XCTAssertTrue(s.sportsHeld.isEmpty)
    }

    // MARK: Partnerships and acquisitions

    func testPartnershipsBoostSignUpsAtALowerPrice() throws {
        var s = newState()
        s.markets["IE"]?.status = .live
        XCTAssertThrowsError(try s.signPartnership(code: "US", kind: .carrier), "not launched")
        let cash = s.finances.cash
        let price = s.partnershipPrice(CountryData.country("IE")!)
        try s.signPartnership(code: "IE", kind: .carrier)
        XCTAssertEqual(s.finances.cash, cash - price, accuracy: 0.01)
        XCTAssertGreaterThan(s.partnerEffects(for: "IE").adds, 1)
        XCTAssertLessThan(s.partnerEffects(for: "IE").arpu, 1)
        XCTAssertThrowsError(try s.signPartnership(code: "IE", kind: .carrier), "one per country")
        for _ in 0..<52 { s.progressPartnerships() }
        XCTAssertTrue(s.partnerships.isEmpty)
    }

    func testAcquiringALibraryAddsPermanentTitles() throws {
        var s = newState()
        s.acquisitionOffers = [AcquisitionOffer(id: 5, kind: .library, name: "Library", price: 5_000_000, titleCount: 6, weeksLeft: 8)]
        let cash = s.finances.cash
        try s.acceptAcquisition(id: 5)
        XCTAssertEqual(s.catalog.count, 6)
        XCTAssertTrue(s.catalog.allSatisfy { $0.weeksRemaining == nil && $0.license == nil && $0.quality >= 50 })
        XCTAssertEqual(Set(s.catalog.map(\.name)).count, 6)
        XCTAssertEqual(s.finances.cash, cash - 5_000_000, accuracy: 0.01)
        XCTAssertTrue(s.acquisitionOffers.isEmpty)
    }

    func testAcquiringAStudioAndTheLimit() throws {
        var s = newState()
        s.acquisitionOffers = [AcquisitionOffer(id: 5, kind: .studio, name: "Little Studio", price: 3_000_000, titleCount: 0, weeksLeft: 8)]
        try s.acceptAcquisition(id: 5)
        XCTAssertEqual(s.studios.last?.level, 2)
        s.studios = (0..<Formulas.maxStudios).map { Studio(id: 100 + $0, name: "S\($0)", specialty: .drama, level: 1, experience: 0, foundedWeek: 1) }
        s.acquisitionOffers = [AcquisitionOffer(id: 6, kind: .studio, name: "Another", price: 3_000_000, titleCount: 0, weeksLeft: 8)]
        XCTAssertThrowsError(try s.acceptAcquisition(id: 6))
    }

    func testOffersAppearOnSchedule() {
        var s = newState()
        s.week = 10
        var found = false
        for seed in 1...5 {
            var t = s; t.rng = SeededRNG(seed: UInt64(seed)); t.refreshAcquisitionOffers()
            if !t.acquisitionOffers.isEmpty { found = true }
        }
        XCTAssertTrue(found)
    }

    // MARK: Rival recalls

    func testRivalsCanPullBackNonExclusiveTitlesWithARefund() {
        var s = newState()
        s.catalog = [licensed(id: 1), licensed(id: 2, exclusive: true), licensed(id: 3, quality: 30)]
        var events: [GameEvent] = []
        var pulled = false
        for seed in 1...20_000 where !pulled {
            var t = s
            t.rng = SeededRNG(seed: UInt64(seed))
            let cash = t.finances.cash
            RivalRecalls.run(&t, events: &events)
            if t.catalog.count == 2 {
                pulled = true
                XCTAssertFalse(t.catalog.contains { $0.id == 1 })
                XCTAssertTrue(t.catalog.contains { $0.id == 2 }, "exclusives are safe")
                XCTAssertTrue(t.catalog.contains { $0.id == 3 }, "rivals only want good shows")
                XCTAssertGreaterThan(t.finances.cash, cash)
            }
        }
        XCTAssertTrue(pulled)
    }

    func testRecallRefundIsNotDoubleCounted() {
        var s = newState()
        s.catalog = [licensed(id: 1)]
        for seed in 1...20_000 where s.catalog.count == 1 {
            s.rng = SeededRNG(seed: UInt64(seed))
            var events: [GameEvent] = []
            RivalRecalls.run(&s, events: &events)
        }
        XCTAssertTrue(s.catalog.isEmpty)
        let cash = s.finances.cash
        let refund = s.finances.ledger.licensing
        XCTAssertLessThan(refund, 0)
        let next = SimulationEngine.advanceWeek(s)
        // Cash moves with the week's profit only; the refund is not credited a second time.
        // (the refund is already in `cash`; the report shows it as lower costs, so profit includes it once more)
        XCTAssertEqual(next.finances.cash - cash, next.lastReport!.financials.profit + refund, accuracy: 1.0)
    }

    func testBatchThreeRoundTrips() throws {
        var s = newState()
        try s.buyFeature(.kidsProfiles)
        s.sportsOffers = [SportsOffer(id: 1, name: "Premier Footy League", region: .europe, askPrice: 1_000_000, weeksLeft: 3)]
        s.partnerships = [Partnership(id: 2, country: "IE", kind: .carrier, weeksLeft: 10)]
        for _ in 0..<15 { s = SimulationEngine.advanceWeek(s) }
        let loaded = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(s))
        XCTAssertEqual(loaded, s)
    }
}
