import XCTest
#if canImport(StreamEmpireCore)
@testable import StreamEmpireCore
#else
@testable import StreamEmpire
#endif

final class Phase5Tests: XCTestCase {
    private func newState(seed: UInt64 = 42) -> GameState {
        var s = GameState.newGame(startCountry: "IE", companyName: "Test Co", seed: seed)
        s.eventsEnabled = false
        return s
    }

    private func titles(_ n: Int) -> [Title] {
        (0..<n).map {
            Title(id: 9500 + $0, name: "Q\($0)", kind: .movie, genre: .drama, language: .english,
                  quality: 70, popularity: 70, ageWeeks: 0, isOriginal: true,
                  license: nil, weeksRemaining: nil, listingWeeksLeft: 0)
        }
    }

    // MARK: Pay

    func testPayEffectivenessMath() {
        XCTAssertEqual(Formulas.payEffectiveness(1.0), 1.0)
        XCTAssertEqual(Formulas.payEffectiveness(1.5), 1.3, accuracy: 1e-9)
        XCTAssertEqual(Formulas.payEffectiveness(0.7), 0.82, accuracy: 1e-9)
        XCTAssertEqual(Formulas.payEffectiveness(9), Formulas.payEffectiveness(1.6), "clamped")
        XCTAssertEqual(Formulas.payEffectiveness(0), Formulas.payEffectiveness(0.6), "clamped")
        XCTAssertEqual(Formulas.attritionChance(pay: 1.0), 0)
        XCTAssertEqual(Formulas.attritionChance(pay: 0.9), 0, accuracy: 1e-12)
        XCTAssertEqual(Formulas.attritionChance(pay: 0.6), 0.012, accuracy: 1e-9)
    }

    func testSalariesScaleWithPay() throws {
        var s = newState()
        s.staff.legal = 2
        XCTAssertEqual(s.weeklySalaries, 20_000, accuracy: 0.01)
        try s.setPay(.legal, scale: 1.5)
        XCTAssertEqual(s.weeklySalaries, 30_000, accuracy: 0.01)
        XCTAssertThrowsError(try s.setPay(.legal, scale: 0.5))
        XCTAssertThrowsError(try s.setPay(.legal, scale: 1.7))
        XCTAssertThrowsError(try s.setStudioPay(scale: 2.0))
        XCTAssertEqual(s.staff.payScale(.content), 1.0, "untouched departments stay at market")

        let withPay = SimulationEngine.advanceWeek(s).lastReport!.financials.staff
        try s.setPay(.legal, scale: 1.0)
        let marketPay = SimulationEngine.advanceWeek(s).lastReport!.financials.staff
        XCTAssertEqual(withPay - marketPay, 10_000, accuracy: 0.01)
    }

    func testBetterPayMakesDepartmentsMoreEffective() throws {
        var s = newState()
        s.staff.content = 2
        let title = s.licenseMarket[0]
        let market = s.licensePrice(title)
        try s.setPay(.content, scale: 1.6)
        let generous = s.licensePrice(title)
        try s.setPay(.content, scale: 0.6)
        let stingy = s.licensePrice(title)
        XCTAssertLessThan(generous, market)
        XCTAssertGreaterThan(stingy, generous)
        XCTAssertEqual(s.staff.effectiveLevel(.content), 2 * 0.76, accuracy: 1e-9)
    }

    func testUnderpaidStaffEventuallyQuit() throws {
        var s = newState()
        s.finances.cash = 1e12
        s.staff.legal = 3
        try s.setPay(.legal, scale: 0.6)
        var weeks = 0
        while s.staff.legal == 3, weeks < 1500 {
            s = SimulationEngine.advanceWeek(s)
            weeks += 1
        }
        XCTAssertEqual(s.staff.legal, 2, "an underpaid team should lose people")
        XCTAssertTrue(s.lastReport!.events.contains { $0.headline.contains("quit") })
    }

    func testFairlyPaidStaffStay() {
        var s = newState()
        s.finances.cash = 1e12
        s.staff.legal = 3
        for _ in 0..<300 { s = SimulationEngine.advanceWeek(s) }
        XCTAssertEqual(s.staff.members(.legal).count, 3, "nobody quits at fair pay")
        XCTAssertGreaterThanOrEqual(s.staff.legal, 3, "and long service only adds skill")
    }

    // MARK: Studios

    func testFoundingStudios() throws {
        var s = newState()
        let cash = s.finances.cash
        try s.foundStudio(specialty: .drama)
        XCTAssertEqual(s.finances.cash, cash - Formulas.studioFoundingCost, accuracy: 0.01)
        XCTAssertEqual(s.studios.count, 1)
        XCTAssertEqual(s.studios[0].level, 1)
        XCTAssertEqual(s.studios[0].slots, 2)
        XCTAssertFalse(s.studios[0].name.isEmpty)
        try s.foundStudio(specialty: .comedy)
        try s.foundStudio(specialty: .action)
        XCTAssertThrowsError(try s.foundStudio(specialty: .kids), "max 3 studios")

        var poor = newState()
        poor.finances.cash = 1_000_000
        XCTAssertThrowsError(try poor.foundStudio(specialty: .drama))
    }

    func testUpgradingStudios() throws {
        var s = newState()
        try s.foundStudio(specialty: .drama)
        let id = s.studios[0].id
        let cash = s.finances.cash
        try s.upgradeStudio(id: id)
        XCTAssertEqual(s.studios[0].level, 2)
        XCTAssertEqual(s.studios[0].slots, 3)
        XCTAssertEqual(s.finances.cash, cash - 2_000_000, accuracy: 0.01)
        s.finances.cash = 100_000_000
        for _ in 0..<3 { try s.upgradeStudio(id: id) }
        XCTAssertEqual(s.studios[0].level, Formulas.maxStudioLevel)
        XCTAssertThrowsError(try s.upgradeStudio(id: id))
        XCTAssertThrowsError(try s.upgradeStudio(id: 424242))
    }

    func testInHouseIsCheaperThanOutsourcing() throws {
        var s = newState()
        try s.foundStudio(specialty: .drama)
        try s.commissionOriginal(kind: .movie, genre: .drama, language: .english, budget: 4_000_000, weeks: 8)
        try s.commissionOriginal(kind: .movie, genre: .drama, language: .english, budget: 4_000_000, weeks: 8,
                                 studioID: s.studios[0].id)
        let outsourced = s.projects.first { $0.studioID == nil }!
        let inHouse = s.projects.first { $0.studioID != nil }!
        XCTAssertEqual(outsourced.weeklyCost, 500_000, accuracy: 0.01)
        XCTAssertEqual(inHouse.weeklyCost, 500_000 * Formulas.inHouseCostFactor(level: 1), accuracy: 0.01)
        XCTAssertLessThan(inHouse.weeklyCost, outsourced.weeklyCost)
        XCTAssertGreaterThan(Formulas.inHouseCostFactor(level: 1), Formulas.inHouseCostFactor(level: 5))
    }

    func testStudioSlotsLimitInHouseWorkOnly() throws {
        var s = newState()
        try s.foundStudio(specialty: .drama)
        let id = s.studios[0].id
        func make() throws {
            try s.commissionOriginal(kind: .movie, genre: .drama, language: .english, budget: 1_000_000, weeks: 10, studioID: id)
        }
        try make(); try make()
        XCTAssertEqual(s.freeSlots(at: s.studios[0]), 0)
        XCTAssertThrowsError(try make(), "level 1 = 2 slots")
        XCTAssertNoThrow(try s.commissionOriginal(kind: .movie, genre: .drama, language: .english,
                                                   budget: 1_000_000, weeks: 10), "outsourcing is separate")
        try s.upgradeStudio(id: id)
        XCTAssertNoThrow(try make())
        XCTAssertThrowsError(try s.commissionOriginal(kind: .movie, genre: .drama, language: .english,
                                                       budget: 1_000_000, weeks: 10, studioID: 999))
    }

    func testStudioQualityBonusMath() {
        XCTAssertEqual(Formulas.studioQualityBonus(level: 1, experience: 0, specialtyMatch: false, payEffect: 1), 3)
        XCTAssertEqual(Formulas.studioQualityBonus(level: 1, experience: 0, specialtyMatch: true, payEffect: 1), 8)
        XCTAssertEqual(Formulas.studioQualityBonus(level: 3, experience: 100, specialtyMatch: true, payEffect: 1), 24)
        XCTAssertEqual(Formulas.studioQualityBonus(level: 1, experience: 0, specialtyMatch: true, payEffect: 1.3), 10.4, accuracy: 1e-9)
        XCTAssertEqual(Formulas.studioPopularityBonus(experience: 100), 8)
        XCTAssertGreaterThan(Formulas.studioExperienceGain(quality: 90), Formulas.studioExperienceGain(quality: 30))
    }

    func testStudioBonusUsesSpecialtyAndPay() throws {
        var s = newState()
        try s.foundStudio(specialty: .action)
        let studio = s.studios[0]
        XCTAssertEqual(s.studioBonus(for: studio, genre: .action), 8, accuracy: 1e-9)
        XCTAssertEqual(s.studioBonus(for: studio, genre: .drama), 3, accuracy: 1e-9)
        try s.setStudioPay(scale: 1.5)
        XCTAssertEqual(s.studioBonus(for: studio, genre: .action), 8 * 1.3, accuracy: 1e-9)
    }

    func testStudioProductionBuildsExperience() throws {
        var s = newState()
        try s.foundStudio(specialty: .action)
        try s.commissionOriginal(kind: .movie, genre: .action, language: .english, budget: 1_000_000, weeks: 6,
                                 studioID: s.studios[0].id)
        for _ in 0..<6 { s = SimulationEngine.advanceWeek(s) }
        XCTAssertTrue(s.projects.isEmpty)
        let original = try XCTUnwrap(s.catalog.first)
        XCTAssertTrue(original.isOriginal)
        XCTAssertGreaterThan(s.studios[0].experience, 0)
        let premiere = try XCTUnwrap(s.lastReport!.events.first { $0.headline.contains("premieres") })
        XCTAssertTrue(premiere.detail.contains(s.studios[0].name))
    }

    func testStudioUpkeepAndCrewPay() throws {
        var s = newState()
        try s.foundStudio(specialty: .drama)
        XCTAssertEqual(SimulationEngine.advanceWeek(s).lastReport!.financials.studios, 25_000, accuracy: 0.01)
        try s.setStudioPay(scale: 1.5)
        XCTAssertEqual(SimulationEngine.advanceWeek(s).lastReport!.financials.studios, 37_500, accuracy: 0.01)
        XCTAssertEqual(newState().weeklyStudioCost, 0)
    }

    func testUnderpaidCrewsLoseExperience() throws {
        var s = newState()
        try s.foundStudio(specialty: .drama)
        s.studios[0].experience = 50
        try s.setStudioPay(scale: 0.6)
        s = SimulationEngine.advanceWeek(s)
        XCTAssertEqual(s.studios[0].experience, 47, accuracy: 1e-9)
        try s.setStudioPay(scale: 1.0)
        s = SimulationEngine.advanceWeek(s)
        XCTAssertEqual(s.studios[0].experience, 47, accuracy: 1e-9, "market pay: no decay")
    }

    // MARK: Subscription prices

    func testApplyPriceLevelScalesLaunchedMarketsOnly() throws {
        var s = newState()
        let nzBefore = s.markets["NZ"]!.prices
        try s.applyPriceLevel(1.5)
        let ie = CountryData.country("IE")!
        XCTAssertEqual(s.markets["IE"]!.prices, Formulas.prices(for: ie, level: 1.5))
        XCTAssertEqual(s.markets["IE"]!.prices.standard, 16.5, accuracy: 1e-9)
        XCTAssertEqual(s.markets["NZ"]!.prices, nzBefore, "not launched: untouched")
        try s.applyPriceLevel(1.0)
        XCTAssertEqual(s.markets["IE"]!.prices, CountryData.defaultPrices(for: ie))
        XCTAssertThrowsError(try s.applyPriceLevel(3.0))
        XCTAssertThrowsError(try s.applyPriceLevel(0.1))
    }

    func testLowerPricesBringMoreSignups() throws {
        func adds(level: Double) throws -> Double {
            var s = newState()
            s.catalog = titles(15)
            s.markets["IE"]?.awareness = 0.4
            try s.applyPriceLevel(level)
            return SimulationEngine.advanceWeek(s).lastReport!.newSubs
        }
        XCTAssertGreaterThan(try adds(level: 0.7), try adds(level: 1.5))
    }

    // MARK: Persistence

    func testPhase5StateRoundTrips() throws {
        var s = newState()
        try s.foundStudio(specialty: .anime)
        try s.setStudioPay(scale: 1.2)
        try s.setPay(.marketing, scale: 0.8)
        try s.commissionOriginal(kind: .series, genre: .anime, language: .japanese, budget: 10_000_000, weeks: 30,
                                 studioID: s.studios[0].id)
        let loaded = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(s))
        XCTAssertEqual(loaded, s)
        XCTAssertEqual(loaded.staff.payScale(.marketing), 0.8)
        XCTAssertEqual(loaded.projects[0].studioID, s.studios[0].id)
    }
}
