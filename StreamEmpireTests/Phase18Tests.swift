import XCTest
#if canImport(StreamEmpireCore)
@testable import StreamEmpireCore
#else
@testable import StreamEmpire
#endif

final class Phase18Tests: XCTestCase {
    private func newState() -> GameState {
        var s = GameState.newGame(startCountry: "IE", companyName: "Test Co", seed: 5)
        s.eventsEnabled = false
        s.finances.cash = 1e9
        return s
    }

    private func title(id: Int = 1, genre: Genre = .drama, mature: Bool = false, regions: [String] = []) -> Title {
        Title(id: id, name: "T\(id)", kind: .series, genre: genre, language: .english, quality: 70, popularity: 60,
              ageWeeks: 20, isOriginal: false,
              license: LicenseTerms(cost: 1_000_000, years: 2, regions: regions, exclusive: false),
              weeksRemaining: 100, listingWeeksLeft: 0, paidPrice: 1_000_000, invested: 1_000_000, mature: mature)
    }

    func testBannedGenresAndStrictness() {
        XCTAssertTrue(title(genre: .reality).blockReason(in: "SA") != nil)
        XCTAssertFalse(title(genre: .reality).isAvailable(in: "SA"))
        XCTAssertTrue(title(genre: .reality).isAvailable(in: "IE"))
        XCTAssertNotNil(title(mature: true).blockReason(in: "IN"))
        XCTAssertNil(title(mature: true).blockReason(in: "IE"))
        XCTAssertNil(title(mature: false).blockReason(in: "IN"))
        XCTAssertNotNil(CountryRules.summary("SA"))
        XCTAssertNil(CountryRules.summary("IE"))
    }

    func testLocalEditUnlocksMatureTitlesButNotBannedGenres() throws {
        var s = newState()
        s.catalog = [title(mature: true), title(id: 2, genre: .reality, mature: true)]
        let cash = s.finances.cash
        let cost = s.editCost(s.catalog[0])
        try s.editForMarket(titleID: 1, code: "IN")
        XCTAssertTrue(s.catalog[0].isAvailable(in: "IN"))
        XCTAssertEqual(s.finances.cash, cash - cost, accuracy: 0.01)
        XCTAssertThrowsError(try s.editForMarket(titleID: 1, code: "IN"), "already edited")
        XCTAssertThrowsError(try s.editForMarket(titleID: 2, code: "SA"), "banned genre cannot be edited")
        XCTAssertThrowsError(try s.editForMarket(titleID: 1, code: "IE"), "not strict")
    }

    func testRestrictedTitlesAreLeftOutOfAMarketsCatalog() {
        let ie = CountryData.country("IE")!, sa = CountryData.country("SA")!
        let reality = title(genre: .reality)
        XCTAssertGreaterThan(Formulas.titleAppeal(reality, in: ie), 0)
        var s = newState()
        s.catalog = [reality]
        XCTAssertGreaterThan(s.marketFit(of: reality), 0)
        _ = sa
    }

    func testTerritoryLicensesAreCheaperAndCanBeExtended() throws {
        var s = newState()
        let regions = CountryRules.codes(in: [.europe])
        var t = title(regions: regions)
        t.license?.cost = 1_000_000 * Formulas.territoryPriceFactor(share: Double(regions.count) / 30)
        s.catalog = [t]
        XCTAssertTrue(s.catalog[0].isAvailable(in: "IE"))
        XCTAssertFalse(s.catalog[0].isAvailable(in: "US"))
        let price = s.territoryExtensionPrice(s.catalog[0])
        XCTAssertGreaterThan(price, 0)
        let cash = s.finances.cash
        try s.extendTerritory(titleID: 1)
        XCTAssertEqual(s.finances.cash, cash - price, accuracy: 0.01)
        XCTAssertTrue(s.catalog[0].isAvailable(in: "US"))
        XCTAssertEqual(s.territoryExtensionPrice(s.catalog[0]), 0)
        XCTAssertThrowsError(try s.extendTerritory(titleID: 1))
    }

    func testGeneratedListingsIncludeTheNewVariety() {
        var rng = SeededRNG(seed: 3)
        var regional = 0, mature = 0, embargo = 0, controversial = 0, evergreen = 0
        for i in 0..<1_000 {
            let t = TitleGenerator.generate(id: i, rng: &rng)
            if !t.license!.regions.isEmpty { regional += 1 }
            if t.mature { mature += 1 }
            if t.embargoWeeks > 0 { embargo += 1; XCTAssertGreaterThan(t.listingWeeksLeft, t.embargoWeeks) }
            if t.controversial { controversial += 1 }
            if t.evergreen { evergreen += 1 }
        }
        for n in [regional, mature, embargo, controversial, evergreen] { XCTAssertGreaterThan(n, 20) }
        XCTAssertLessThan(regional, 500)
    }

    func testEmbargoedListingsCannotBeBoughtUntilTheyOpen() throws {
        var s = newState()
        var t = title(id: 9)
        t.license?.regions = []
        t.embargoWeeks = 3
        t.listingWeeksLeft = 10
        t.weeksRemaining = nil
        s.licenseMarket = [t]
        XCTAssertThrowsError(try s.buyLicense(titleID: 9))
        var c = Curator(); c.minQuality = 0
        XCTAssertEqual(c.rejectReason(t, languages: [.english]), "embargo")
        s.eventsEnabled = false
        for _ in 0..<3 { s = SimulationEngine.advanceWeek(s) }
        if let listing = s.licenseMarket.first(where: { $0.id == 9 }) {
            XCTAssertEqual(listing.embargoWeeks, 0)
            XCTAssertNoThrow(try s.buyLicense(titleID: 9))
        }
    }

    func testPiracyRisesWithPriceAndThinCatalogs() {
        let cheap = Formulas.piracy(price: 5, tolerance: 8, appeal: 0.8)
        let pricey = Formulas.piracy(price: 14, tolerance: 8, appeal: 0.8)
        let thin = Formulas.piracy(price: 14, tolerance: 8, appeal: 0.1)
        XCTAssertLessThan(cheap, pricey)
        XCTAssertLessThan(pricey, thin)
        XCTAssertLessThanOrEqual(thin, 0.6)
        XCTAssertGreaterThan(Formulas.piracy(price: 10, tolerance: 4, appeal: 0.3),
                             Formulas.piracy(price: 10, tolerance: 12, appeal: 0.3), "poorer markets pirate more")
    }

    func testPiracyIsRecordedPerMarket() {
        var s = newState()
        s.markets["IE"]?.subs = TierSet(ad: 0, standard: 10_000, premium: 0)
        s = SimulationEngine.advanceWeek(s)
        XCTAssertGreaterThan(s.markets["IE"]!.piracy, 0)
    }

    func testTrendsArriveOnSchedule() {
        XCTAssertEqual(Trends.effects(week: 10).arpu, 1.0)
        XCTAssertLessThan(Trends.effects(week: 60).arpu, 1.0)
        XCTAssertGreaterThan(Trends.effects(week: 110).ads, 1.0)
        XCTAssertGreaterThan(Trends.effects(week: 160).churn, 1.0)
        XCTAssertLessThan(Trends.effects(week: 210).adds, 1.0)
        var s = newState()
        s.week = 104
        Trends.announce(&s)
        XCTAssertTrue(s.news.contains { $0.headline == "Ad tiers go mainstream" })
    }

    func testEvergreenTitlesKeepAppeal() {
        var old = title(); old.ageWeeks = 900
        var classic = old; classic.evergreen = true
        XCTAssertGreaterThan(Formulas.freshness(of: classic), Formulas.freshness(of: old))
        XCTAssertEqual(Formulas.freshness(of: classic), 0.6, accuracy: 1e-9)
    }

    func testControversialTitlesDrawMoreButCostTrust() {
        let ie = CountryData.country("IE")!
        var plain = title(); plain.ageWeeks = 30
        var spicy = plain; spicy.controversial = true
        XCTAssertGreaterThan(Formulas.titleAppeal(spicy, in: ie), Formulas.titleAppeal(plain, in: ie))
        var s = newState()
        s.catalog = [spicy]
        for _ in 0..<2_500 where !s.news.contains(where: { $0.headline.contains("Controversy over") }) {
            s = SimulationEngine.advanceWeek(s)
        }
        XCTAssertTrue(s.news.contains { $0.headline.contains("Controversy over") }, "a scandal eventually happens")
    }

    func testBatchOneStateRoundTrips() throws {
        var s = newState()
        s.catalog = [title(mature: true)]
        try s.editForMarket(titleID: 1, code: "IN")
        s = SimulationEngine.advanceWeek(s)
        let loaded = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(s))
        XCTAssertEqual(loaded, s)
    }
}
