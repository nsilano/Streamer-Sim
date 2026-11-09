import XCTest
#if canImport(StreamEmpireCore)
@testable import StreamEmpireCore
#else
@testable import StreamEmpire
#endif

final class Phase6Tests: XCTestCase {
    private func newState(country: String = "IE", seed: UInt64 = 42) -> GameState {
        var s = GameState.newGame(startCountry: country, companyName: "Test Co", seed: seed)
        s.eventsEnabled = false
        s.finances.cash = 1e12
        return s
    }

    private func title(id: Int = 1, genre: Genre = .drama, original: Bool = false, exclusive: Bool = false, age: Int = 20) -> Title {
        Title(id: id, name: "The Crimson Harbor Chronicles", kind: .series, genre: genre, language: .english,
              quality: 70, popularity: 60, ageWeeks: age, isOriginal: original,
              license: original ? nil : LicenseTerms(cost: 1_000_000, years: 2, regions: [], exclusive: exclusive),
              weeksRemaining: nil, listingWeeksLeft: 5)
    }

    /// IE where the player holds most of the market and rivals are tiny.
    private func dominantState() -> GameState {
        var s = newState()
        s.markets["IE"]?.subs = TierSet(ad: 0, standard: 600_000, premium: 0)
        for i in s.rivals.indices { s.rivals[i].subs = ["IE": 20_000] }
        s.catalog = (0..<15).map { title(id: 100 + $0) }
        return s
    }

    // MARK: Rival reaction to dominance

    func testDominanceThreatCurve() {
        XCTAssertEqual(Formulas.dominanceThreat(playerShare: 0.10), 0)
        XCTAssertEqual(Formulas.dominanceThreat(playerShare: 0.25), 0)
        XCTAssertEqual(Formulas.dominanceThreat(playerShare: 0.60), 1, accuracy: 1e-9)
        XCTAssertEqual(Formulas.dominanceThreat(playerShare: 0.95), 1)
        XCTAssertGreaterThan(Formulas.dominanceThreat(playerShare: 0.45), Formulas.dominanceThreat(playerShare: 0.35))
    }

    func testRetaliationAndPoachingMath() {
        XCTAssertEqual(Formulas.retaliationChance(personality: .balanced, threat: 0), 0.04, accuracy: 1e-9)
        XCTAssertGreaterThan(Formulas.retaliationChance(personality: .balanced, threat: 1), 0.04)
        XCTAssertGreaterThan(Formulas.retaliationChance(personality: .priceCutter, threat: 1),
                             Formulas.retaliationChance(personality: .balanced, threat: 1))
        XCTAssertLessThan(Formulas.priceFloor(threat: 1), Formulas.priceFloor(threat: 0))
        XCTAssertEqual(Formulas.poachRate(priceLevel: 1.0, threat: 1), 0, "no discount, no poaching")
        XCTAssertEqual(Formulas.poachRate(priceLevel: 0.8, threat: 0), 0, "no threat, no poaching")
        XCTAssertEqual(Formulas.poachRate(priceLevel: 0.8, threat: 1), 0.006, accuracy: 1e-9)
    }

    func testThreatUsesMarketShareWhereRivalsCompete() {
        var s = newState()
        XCTAssertEqual(s.countryThreat("IE"), 0)
        s = dominantState()
        XCTAssertEqual(s.countryThreat("IE"), 1, accuracy: 1e-9)
        XCTAssertEqual(s.threat(from: s.rivals[0]), 1, accuracy: 1e-9)
        s.markets["IE"]?.subs = .zero
        XCTAssertEqual(s.threat(from: s.rivals[0]), 0)
    }

    func testDiscountingRivalsPoachSubscribersFromADominantPlayer() {
        func run(level: Double) -> GameState {
            var s = dominantState()
            s.rivals[0].priceLevel = level
            return SimulationEngine.advanceWeek(s)
        }
        let war = run(level: 0.8), calm = run(level: 1.0)
        XCTAssertLessThan(war.markets["IE"]!.subs.total, calm.markets["IE"]!.subs.total, "defections")
        XCTAssertGreaterThan(war.rivals[0].subs["IE"]!, calm.rivals[0].subs["IE"]!, "the rival gained them")
    }

    func testDominancePricesStartWarsOverTime() {
        func discountedWeeks(dominant: Bool) -> Int {
            var s = dominant ? dominantState() : newState()
            var weeks = 0
            for _ in 0..<200 {
                s = SimulationEngine.advanceWeek(s)
                if s.rivals.contains(where: { $0.priceLevel < 0.9 }) { weeks += 1 }
                // Keep the scenario stable: the player stays dominant.
                if dominant { s.markets["IE"]?.subs = TierSet(ad: 0, standard: 600_000, premium: 0) }
            }
            return weeks
        }
        XCTAssertGreaterThan(discountedWeeks(dominant: true), discountedWeeks(dominant: false))
    }

    func testPriceWarIsAnnouncedAndPricesStayInRange() {
        var s = dominantState()
        var sawWar = false
        for _ in 0..<300 {
            s = SimulationEngine.advanceWeek(s)
            if s.lastReport!.events.contains(where: { $0.headline.contains("price war") }) { sawWar = true }
            s.markets["IE"]?.subs = TierSet(ad: 0, standard: 600_000, premium: 0)
            for r in s.rivals { XCTAssertTrue((0.6...1.15).contains(r.priceLevel), "\(r.id) \(r.priceLevel)") }
        }
        XCTAssertTrue(sawWar, "a dominant player should provoke a price war within 300 weeks")
    }

    // MARK: Map status

    func testMapStatusColorsCountries() throws {
        var s = newState()
        XCTAssertEqual(s.mapStatus("IE"), .live)
        XCTAssertEqual(s.mapStatus("NZ"), .available)
        XCTAssertEqual(s.mapStatus("US"), .locked)
        try s.launchMarket(code: "NZ")
        XCTAssertEqual(s.mapStatus("NZ"), .launching)
        s.catalog = (0..<40).map { title(id: 200 + $0) }
        XCTAssertEqual(s.mapStatus("US"), .available)
    }

    func testAnyCountryCanBeTheStartingMarket() {
        for country in CountryData.all {
            let s = GameState.newGame(startCountry: country.code, companyName: "X", seed: 1)
            XCTAssertEqual(s.liveMarketCodes, [country.code], country.code)
        }
        XCTAssertEqual(CountryData.country("US")!.sizeHint, "Huge market")
        XCTAssertEqual(CountryData.country("IE")!.sizeHint, "Small & cozy")
    }

    func testWorldMapDecodes() throws {
        let json = #"{"w":2000,"h":988,"countries":[{"code":"IE","name":"Ireland","rings":[[10,10,20,10,20,20]],"cx":15,"cy":15},{"code":"","name":"Elsewhere","rings":[[0,0,5,0,5,5]],"cx":2,"cy":2}]}"#
        let map = try WorldMap.decode(Data(json.utf8))
        XCTAssertEqual(map.countries.count, 2)
        XCTAssertEqual(map.playable.map(\.code), ["IE"])
        XCTAssertEqual(map.w, 2000)
    }

    // MARK: Poster covers

    func testPostersAreDeterministicAndVaried() {
        let a = PosterSpec.make(for: title(id: 7))
        XCTAssertEqual(a, PosterSpec.make(for: title(id: 7)))
        XCTAssertNotEqual(a.seeds, PosterSpec.make(for: title(id: 8)).seeds)
        XCTAssertEqual(a.seeds.count, 8)
        XCTAssertEqual(a.palette.count, 3)
        XCTAssertTrue(a.seeds.allSatisfy { (0..<1).contains($0) })
    }

    func testPosterMotifsFollowGenreAndBadges() {
        XCTAssertEqual(PosterSpec.make(for: title(genre: .anime)).motif, .burst)
        XCTAssertEqual(PosterSpec.make(for: title(genre: .docs)).motif, .landscape)
        XCTAssertEqual(Set(Genre.allCases.map(PosterSpec.motif(for:))).count, Genre.allCases.count, "one motif per genre")
        XCTAssertEqual(PosterSpec.make(for: title(original: true)).badge, "ORIGINAL")
        XCTAssertEqual(PosterSpec.make(for: title(exclusive: true)).badge, "EXCLUSIVE")
        XCTAssertEqual(PosterSpec.make(for: title(age: 1)).badge, "NEW")
        XCTAssertNil(PosterSpec.make(for: title(age: 50)).badge)
    }

    func testPosterTitleWrapping() {
        XCTAssertEqual(PosterSpec.wrap("Crimson Harbor"), ["Crimson", "Harbor"])
        XCTAssertEqual(PosterSpec.wrap("Dad's Frozen Lighthouse Club").count, 3)
        XCTAssertEqual(PosterSpec.wrap("Echo"), ["Echo"])
        XCTAssertLessThanOrEqual(PosterSpec.wrap("A B C D E F G H I J K L M N O P", maxChars: 3, maxLines: 3).count, 3)
        XCTAssertEqual(PosterSpec.make(for: title()).titleLines.joined(separator: " "), "The Crimson Harbor Chronicles")
    }

    // MARK: Bars, advice & pay presets

    func testTitleBarsStayInRange() {
        let s = newState()
        let t = title()
        XCTAssertTrue((0...1).contains(s.marketFit(of: t)))
        XCTAssertTrue((0.25...1).contains(s.freshness(of: t)))
        XCTAssertGreaterThan(s.freshness(of: title(age: 0)), s.freshness(of: title(age: 200)))
        var better = t; better.quality = 95
        XCTAssertGreaterThan(s.marketFit(of: better), s.marketFit(of: t))
    }

    func testAdviceFlagsOverloadedServersAndEmptyCatalog() {
        var s = newState(country: "CA")
        XCTAssertTrue(s.advice().contains { $0.id == "catalog" && $0.urgent })
        s.markets["CA"]?.subs = TierSet(ad: 0, standard: 500_000, premium: 0)
        let first = s.advice().first!
        XCTAssertTrue(first.urgent)
        XCTAssertTrue(s.advice().contains { $0.id == "cdn-northAmerica" && $0.urgent })
        s.cdnSteps[Region.northAmerica.rawValue] = 4
        XCTAssertFalse(s.advice().contains { $0.id.hasPrefix("cdn-") })
    }

    func testAdviceNoticesLowPayAndRunway() throws {
        var s = newState()
        s.catalog = (0..<12).map { title(id: 300 + $0) }
        s.staff.legal = 2
        try s.setPay(.legal, scale: 0.8)
        XCTAssertTrue(s.advice().contains { $0.id == "pay-legal" })
        s.finances.cash = 1_000_000
        s.finances.profitHistory = [-500_000, -500_000]
        XCTAssertTrue(s.advice().contains { $0.id == "runway" })
    }

    func testPayLevelPresets() {
        XCTAssertEqual(PayLevel.closest(to: 1.0), .fair)
        XCTAssertEqual(PayLevel.closest(to: 0.7), .low)
        XCTAssertEqual(PayLevel.closest(to: 1.5), .generous)
        XCTAssertEqual(PayLevel.fair.scale, 1.0)
        XCTAssertFalse(Department.allCases.map(\.summary).contains(""))
        XCTAssertTrue(Department.content.benefit(at: 3).contains("6%"))
    }
}
