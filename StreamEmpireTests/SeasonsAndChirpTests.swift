import XCTest
#if canImport(StreamEmpireCore)
@testable import StreamEmpireCore
#else
@testable import StreamEmpire
#endif

final class SeasonsAndChirpTests: XCTestCase {
    private func newState() -> GameState {
        var s = GameState.newGame(startCountry: "IE", companyName: "Test Co", seed: 77)
        s.eventsEnabled = false
        return s
    }

    // MARK: Seasons

    func testWinterBoostsSignupsAndSummerSlowsThem() {
        let winter = Seasons.effects(week: 2, region: .europe)
        let summer = Seasons.effects(week: 28, region: .europe)
        XCTAssertGreaterThan(winter.adds, 1.05)
        XCTAssertLessThan(summer.adds, 0.95)
        XCTAssertLessThan(winter.churn, 1)
        XCTAssertGreaterThan(summer.churn, 1)
    }

    func testHolidaysAddABump() {
        XCTAssertGreaterThan(Seasons.effects(week: 51, region: .northAmerica).adds, Seasons.effects(week: 47, region: .northAmerica).adds)
    }

    func testSouthernRegionsRunHalfAYearBehindAndAreMilder() {
        let north = Seasons.effects(week: 2, region: .europe)
        let south = Seasons.effects(week: 2, region: .latinAmerica)
        XCTAssertLessThan(south.adds, 1)
        XCTAssertLessThan(abs(south.adds - 1), abs(north.adds - 1))
    }

    func testSeasonsRepeatEveryYear() {
        XCTAssertEqual(Seasons.effects(week: 10, region: .europe).adds, Seasons.effects(week: 62, region: .europe).adds, accuracy: 1e-12)
    }

    // MARK: Policies move reputation

    func testHarshPolicyCostsReputationAndFriendlyOneEarnsIt() throws {
        var s = newState()
        s.finances.cash = 500_000_000
        s.markets["IE"]?.subs.standard = 5_000_000
        let before = s.brandTrust
        try s.setPolicy("sharing", option: "strict", forcedBad: false)
        XCTAssertLessThan(s.brandTrust, before, "a harsh policy costs reputation straight away")
        let low = s.brandTrust
        s.week += 30
        try s.setPolicy("sharing", option: "allow", forcedBad: false)
        XCTAssertGreaterThan(s.brandTrust, low, "going back to the friendly option earns it back")
    }

    // MARK: Pause sensitivity and automation

    func testPauseSensitivityLevels() {
        XCTAssertTrue(PauseSensitivity.critical.stops("cash"))
        XCTAssertTrue(PauseSensitivity.critical.stops("load100-europe"))
        XCTAssertFalse(PauseSensitivity.critical.stops("war-3"))
        XCTAssertFalse(PauseSensitivity.critical.stops("expiring"))
        XCTAssertTrue(PauseSensitivity.important.stops("runway"))
        XCTAssertFalse(PauseSensitivity.important.stops("war-3"))
        XCTAssertTrue(PauseSensitivity.everything.stops("war-3"))
        XCTAssertTrue(PauseSensitivity.everything.stops("expired-9"))
    }

    func testAutoScaleRentsCloudWhenLoadIsHighAndIsOffByDefault() {
        var s = newState()
        s.finances.cash = 100_000_000
        s.markets["IE"]?.subs.standard = 3_000_000
        s.cloudUnits = [:]
        var off = s
        off.autoScaleCloud()
        XCTAssertEqual(off.cloudUnits[Region.europe.rawValue] ?? 0, 0, "off unless you switch it on")
        s.autoScale = true
        let load = s.effectiveLoad(.europe)
        s.autoScaleCloud()
        if load >= 0.85 { XCTAssertEqual(s.cloudUnits[Region.europe.rawValue], 1) }
        else { XCTAssertLessThanOrEqual(s.cloudUnits[Region.europe.rawValue] ?? 0, 0) }
    }

    // MARK: Chirp feed

    func testChirpPostsAreStableAndFollowReputation() {
        var s = newState()
        s.addNews(.you, "Test Co launches in France", "A new market.")
        let item = s.news[0]
        let a = Chirp.make(item, state: s), b = Chirp.make(item, state: s)
        XCTAssertEqual(a, b)
        XCTAssertTrue(a.mine)
        XCTAssertEqual(a.name, "Test Co")
        XCTAssertTrue(a.handle.hasPrefix("@"))
        s.brandTrust = 100
        var happy = 0
        for i in 0..<200 {
            var copy = item
            copy.id = i + 1000
            if let reply = Chirp.make(copy, state: s).reply, reply.positive { happy += 1 }
        }
        s.brandTrust = 0
        var happyLow = 0
        for i in 0..<200 {
            var copy = item
            copy.id = i + 1000
            if let reply = Chirp.make(copy, state: s).reply, reply.positive { happyLow += 1 }
        }
        XCTAssertGreaterThan(happy, happyLow, "a trusted company draws friendlier replies")
    }

    // MARK: Renewal rules

    private func expiringTitle(quality: Int = 80) -> Title {
        Title(id: 5_555, name: "Renew Me", kind: .series, genre: .drama, language: .english,
              quality: quality, popularity: 70, ageWeeks: 30, isOriginal: false,
              license: LicenseTerms(cost: 100_000, years: 2, regions: [], exclusive: false),
              weeksRemaining: 6, listingWeeksLeft: 0)
    }

    func testRenewalRulesBlockExcludedAndLowQualityTitles() throws {
        var s = newState()
        s.finances.cash = 50_000_000
        s.renewalMode = .generous
        var t = expiringTitle()
        s.catalog = [t]
        XCTAssertNil(s.renewalBlock(t), "an ordinary cheap title renews")
        try s.setAutoRenew(titleID: t.id, enabled: false)
        t = s.catalog[0]
        XCTAssertNotNil(s.renewalBlock(t))
        try s.setAutoRenew(titleID: t.id, enabled: true)
        var rules = s.renewalRules
        rules.minQuality = 90
        try s.updateRenewalRules(rules)
        XCTAssertNotNil(s.renewalBlock(s.catalog[0]), "below the quality bar")
        s.catalog[0].sought = true
        XCTAssertNil(s.renewalBlock(s.catalog[0]), "sought-after titles skip the bar")
    }

    func testRenewalTermFollowsTheRules() throws {
        var s = newState()
        s.finances.cash = 50_000_000
        s.renewalMode = .generous
        s.catalog = [expiringTitle()]
        var rules = s.renewalRules
        rules.years = 3
        try s.updateRenewalRules(rules)
        var events: [GameEvent] = []
        s.autoRenewEverything(events: &events)
        XCTAssertEqual(s.catalog[0].license?.years, 3)
        XCTAssertThrowsError(try s.updateRenewalRules(RenewalRules(years: 9)))
    }

    func testRenewalPostureFollowsFinances() {
        var s = newState()
        s.finances.cash = 80_000_000
        s.finances.profitHistory = [2_000_000, 2_000_000, 2_000_000, 2_000_000]
        s.finances.lastWeek.staff = 1_000_000
        XCTAssertEqual(s.renewalPosture, .flush)
        s.finances.cash = 3_000_000
        s.finances.profitHistory = [-1_000_000, -1_000_000, -1_000_000, -1_000_000]
        XCTAssertEqual(s.renewalPosture, .tight)
        s.finances.cash = 40_000_000
        s.finances.profitHistory = [100_000, 100_000, 100_000, 100_000]
        s.finances.lastWeek.staff = 5_000_000
        XCTAssertEqual(s.renewalPosture, .normal)
        s.renewalRules.adaptToFinances = false
        s.finances.cash = 1_000
        XCTAssertEqual(s.renewalPosture, .normal, "switched off")
    }

    func testRichCompanyRenewsMediocreTitlesAndPoorOneDropsThem() {
        var s = newState()
        s.renewalMode = .careful
        var t = expiringTitle(quality: 50)
        t.paidPrice = 100_000
        t.popularityAtPurchase = 70
        s.catalog = [t]
        s.finances.lastWeek.staff = 1_000_000
        s.finances.cash = 80_000_000
        s.finances.profitHistory = [2_000_000, 2_000_000, 2_000_000, 2_000_000]
        XCTAssertNil(s.renewalBlock(s.catalog[0]), "flush: no hesitation, even for a mediocre title")
        s.finances.cash = 5_000_000
        s.finances.profitHistory = [-1_000_000, -1_000_000, -1_000_000, -1_000_000]
        XCTAssertNotNil(s.renewalBlock(s.catalog[0]), "tight: quality 50 is below the 60 bar")
    }
}
