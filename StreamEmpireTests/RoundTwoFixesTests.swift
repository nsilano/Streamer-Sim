import XCTest
#if canImport(StreamEmpireCore)
@testable import StreamEmpireCore
#else
@testable import StreamEmpire
#endif

final class RoundTwoFixesTests: XCTestCase {
    private func newState() -> GameState {
        var s = GameState.newGame(startCountry: "IE", companyName: "Fix Co", seed: 5)
        s.eventsEnabled = false
        return s
    }

    private func title(_ id: Int, quality: Int = 70) -> Title {
        Title(id: id, name: "T\(id)", kind: .series, genre: .drama, language: .english, quality: quality, popularity: 60,
              ageWeeks: 20, isOriginal: true, license: nil, weeksRemaining: nil, listingWeeksLeft: 0)
    }

    func testAppealNeedsAHugeLibraryForFull() {
        let ie = CountryData.country("IE")!
        func appeal(_ n: Int) -> Double { Formulas.catalogAppeal((0..<n).map { title($0) }, in: ie) }
        XCTAssertLessThan(appeal(25), 0.80, "25 titles is no longer almost full appeal")
        XCTAssertGreaterThan(appeal(25), appeal(10))
        XCTAssertLessThan(appeal(100), 0.92)
        XCTAssertLessThan(appeal(300), 0.97)
        XCTAssertGreaterThan(appeal(1000), 0.95, "a Netflix-sized library gets close to full appeal")
        XCTAssertLessThanOrEqual(appeal(5000), 1.0)
    }

    func testFreePlansAreCappedAndTheFreeTierDoesNotSwallowEveryone() {
        XCTAssertLessThanOrEqual(Formulas.priceFactor(price: 0, tolerance: 10), 1.6)
        let split = Formulas.tierSplit(prices: TierSet(ad: 0, standard: 10, premium: 15))
        XCTAssertLessThan(split.ad, 0.9)
    }

    func testPoachingNeedsARivalToBeCheaperThanYou() {
        var s = newState()
        let rival = s.rivals[0]
        s.rivals[0].subs["IE"] = 500_000
        let theirs = s.rivalPrices(s.rivals[0], in: "IE")!.standard
        XCTAssertNotNil(rival.id)
        s.markets["IE"]?.prices.standard = max(0.5, theirs * 0.5)   // you are far cheaper than the rival
        s.markets["IE"]?.subs = TierSet(ad: 0, standard: 800_000, premium: 0)
        let before = s.rivals[0].subs["IE"] ?? 0
        s.rivals[0].priceLevel = 0.7
        s = SimulationEngine.advanceWeek(s)
        XCTAssertGreaterThanOrEqual(s.rivals[0].subs["IE"] ?? 0, before * 0.99, "a pricier rival does not poach")
    }

    func testOverdraftCostsInterestAndTheCreditWarningStops() {
        var s = newState()
        s.finances.cash = -1_000_000
        s = SimulationEngine.advanceWeek(s)
        XCTAssertGreaterThan(s.lastReport!.financials.interest, 1_000_000 * 0.12 / 52 * 0.9)
        var before = newState(), after = newState()
        before.finances.cash = -0.5 * before.overdraftLimit
        after.finances.cash = -0.85 * after.overdraftLimit
        let reasons = PauseCheck.reasons(before: before, after: after)
        XCTAssertTrue(reasons.contains { $0.id == "credit" })
        XCTAssertTrue(PauseSensitivity.critical.stops("credit"))
    }

    func testDepartmentLevelNeverExceedsTheCap() {
        var s = newState()
        s.staff.engineering = 5
        s.staff.pay[Department.engineering.rawValue] = 1.6
        XCTAssertLessThanOrEqual(s.staff.effectiveLevel(.engineering), Double(Formulas.maxDepartmentLevel))
    }

    func testFailedTakeoverStartsACooldown() {
        var s = newState()
        s.takeoverCooldownUntil = s.week + 10
        XCTAssertThrowsError(try s.launchTakeover(rivalID: s.rivals[0].id, premium: 0.3))
    }

    func testClosedMarketsNeedAnUnlockAndOpenToRivalsLate() {
        for code in ["IR", "CU", "CN"] {
            XCTAssertNotNil(CountryData.country(code)?.unlock, code)
        }
        XCTAssertTrue(CountryData.closedToRivals.contains("CN"))
        XCTAssertGreaterThan(CountryData.closedMarketsOpenWeek, 100)
    }

    func testLoanedOutTitlesStillCountForTheCatalogSizePrice() throws {
        var s = newState()
        s.catalog = (0..<400).map { title($0) }
        let before = s.catalogSizePriceFactor
        s.licenseMarket = []
        let t = s.catalog.removeLast()
        s.loanedOut = [LoanedTitle(title: t, weeksLeft: 13, fee: 1, to: "x")]
        XCTAssertEqual(s.catalogSizePriceFactor, before, accuracy: 1e-9)
    }
}
