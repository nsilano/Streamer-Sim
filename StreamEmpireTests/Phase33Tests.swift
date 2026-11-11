import XCTest
#if canImport(StreamEmpireCore)
@testable import StreamEmpireCore
#else
@testable import StreamEmpire
#endif

final class Phase33Tests: XCTestCase {
    private func newState() -> GameState {
        var s = GameState.newGame(startCountry: "IE", companyName: "Test Co", seed: 19)
        s.eventsEnabled = false
        s.finances.cash = 1e10
        return s
    }

    private func titles(_ n: Int) -> [Title] {
        (0..<n).map {
            Title(id: 5_000 + $0, name: "B\($0)", kind: .series, genre: .drama, language: .english, quality: 60, popularity: 60,
                  ageWeeks: 10, isOriginal: true, license: nil, weeksRemaining: nil, listingWeeksLeft: 0)
        }
    }

    func testBigCatalogsPayMoreButEightThousandIsReachable() {
        XCTAssertEqual(Formulas.catalogSizePriceFactor(count: 0), 1)
        XCTAssertEqual(Formulas.catalogSizePriceFactor(count: 300), 1)
        XCTAssertLessThan(Formulas.catalogSizePriceFactor(count: 600), 1.3)
        XCTAssertEqual(Formulas.catalogSizePriceFactor(count: 2_000), 3.3, accuracy: 0.2)
        XCTAssertEqual(Formulas.catalogSizePriceFactor(count: 4_000), 9.2, accuracy: 0.5)
        XCTAssertEqual(Formulas.catalogSizePriceFactor(count: 8_000), 27, accuracy: 2, "Netflix-sized: only a giant can afford it")
        XCTAssertGreaterThan(Formulas.catalogSizePriceFactor(count: 12_000), 45, "nobody can own everything")
        var last = 1.0
        for n in stride(from: 300, through: 12_000, by: 100) {
            let f = Formulas.catalogSizePriceFactor(count: n)
            XCTAssertGreaterThanOrEqual(f, last)
            last = f
        }
    }

    func testLicensePricesFollowTheCatalogSize() {
        var small = newState(), big = newState()
        let listing = small.licenseMarket.first { $0.embargoWeeks == 0 }!
        big.licenseMarket = small.licenseMarket
        small.catalog = titles(100)
        big.catalog = titles(4_000)
        XCTAssertGreaterThan(big.licensePrice(listing), small.licensePrice(listing) * 8)
        XCTAssertEqual(big.catalogSizePriceFactor, Formulas.catalogSizePriceFactor(count: 4_000), accuracy: 1e-9)
    }

    func testPresetsBuyMoreTitlesPerWeekTheBolderTheyAre() {
        XCTAssertLessThan(CuratorMode.passive.purchasesPerWeek, CuratorMode.moderate.purchasesPerWeek)
        XCTAssertLessThan(CuratorMode.moderate.purchasesPerWeek, CuratorMode.aggressive.purchasesPerWeek)
        var s = newState()
        try? s.hireCurator(mode: .aggressive)
        XCTAssertEqual(s.effectiveCurator()?.purchasesPerWeek, CuratorMode.aggressive.purchasesPerWeek)
        var custom = newState()
        try? custom.hireCurator()
        XCTAssertEqual(custom.effectiveCurator()?.purchasesPerWeek, Curator.maxPurchasesPerWeek)
    }

    func testManagerCatalogLimitModes() throws {
        var s = newState()
        try s.hireCurator(mode: .moderate)
        let auto = s.effectiveCurator()!.targetCatalogSize
        var c = s.curator!
        c.capMode = .fixed; c.catalogCap = 77
        try s.updateCurator(c)
        XCTAssertEqual(s.effectiveCurator()!.targetCatalogSize, 77)
        c.capMode = .none
        try s.updateCurator(c)
        XCTAssertGreaterThan(s.effectiveCurator()!.targetCatalogSize, 100_000)
        c.capMode = .auto
        try s.updateCurator(c)
        XCTAssertEqual(s.effectiveCurator()!.targetCatalogSize, auto)
    }

    func testFixedLimitStopsTheManagerButNoLimitKeepsBuying() throws {
        func catalogAfter(_ mode: CatalogCapMode) throws -> Int {
            var s = newState()
            s.rivals = []
            try s.hireCurator(mode: .aggressive)
            var c = s.curator!
            c.capMode = mode; c.catalogCap = 5
            try s.updateCurator(c)
            s.finances.lastWeek.subscriptionRevenue = 20_000_000
            for _ in 0..<12 { s = SimulationEngine.advanceWeek(s) }
            return s.catalog.count
        }
        let capped = try catalogAfter(.fixed)
        let free = try catalogAfter(.none)
        XCTAssertLessThanOrEqual(capped, 5)
        XCTAssertGreaterThan(free, capped)
    }

    func testCustomModeStillUsesItsOwnTarget() throws {
        var s = newState()
        try s.hireCurator()
        var c = s.curator!
        c.targetCatalogSize = 12
        try s.updateCurator(c)
        XCTAssertEqual(s.effectiveCurator()!.targetCatalogSize, 12)
    }

    func testCapSettingsSurviveSaves() throws {
        var s = newState()
        try s.hireCurator(mode: .passive)
        s.curator?.capMode = .fixed
        s.curator?.catalogCap = 300
        let loaded = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(s))
        XCTAssertEqual(loaded.curator?.catalogCap, 300)
        XCTAssertEqual(loaded.curator?.capMode, .fixed)
    }
}
