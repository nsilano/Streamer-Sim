import XCTest
#if canImport(StreamEmpireCore)
@testable import StreamEmpireCore
#else
@testable import StreamEmpire
#endif

final class Phase25Tests: XCTestCase {
    private func newState() -> GameState {
        var s = GameState.newGame(startCountry: "IE", companyName: "Test Co", seed: 31)
        s.eventsEnabled = false
        s.finances.cash = 1e9
        return s
    }

    func testRefreshReplacesEveryListingForAFee() throws {
        var s = newState()
        let before = Set(s.licenseMarket.map(\.id))
        let cash = s.finances.cash
        let price = s.refreshListingsPrice()
        try s.refreshListings()
        XCTAssertEqual(s.licenseMarket.count, s.listingTarget)
        XCTAssertTrue(Set(s.licenseMarket.map(\.id)).isDisjoint(with: before))
        XCTAssertEqual(s.finances.cash, cash - price, accuracy: 0.01)
        XCTAssertEqual(Set(s.licenseMarket.map(\.name)).count, s.licenseMarket.count, "no duplicate names")
    }

    func testExpandingShowsMoreListingsPermanently() throws {
        var s = newState()
        XCTAssertEqual(s.listingTarget, GameState.targetListings)
        let first = s.expandListingsPrice()
        try s.expandListings()
        XCTAssertEqual(s.listingTarget, GameState.targetListings + GameState.listingsPerReachLevel)
        XCTAssertEqual(s.licenseMarket.count, s.listingTarget, "filled right away")
        XCTAssertGreaterThan(s.expandListingsPrice(), first, "each level costs more")
        for _ in 1..<GameState.maxListingReach { try s.expandListings() }
        XCTAssertEqual(s.listingReach, GameState.maxListingReach)
        XCTAssertThrowsError(try s.expandListings())
        for _ in 0..<20 { s = SimulationEngine.advanceWeek(s) }
        XCTAssertGreaterThan(s.licenseMarket.count, GameState.targetListings, "the bigger market keeps refilling")
    }

    func testRefreshNeedsCash() {
        var s = newState()
        s.finances.cash = 0
        XCTAssertThrowsError(try s.refreshListings())
        XCTAssertThrowsError(try s.expandListings())
    }

    func testReachSurvivesSaves() throws {
        var s = newState()
        try s.expandListings()
        let loaded = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(s))
        XCTAssertEqual(loaded, s)
    }
}
