import XCTest
#if canImport(StreamEmpireCore)
@testable import StreamEmpireCore
#else
@testable import StreamEmpire
#endif

final class Phase13Tests: XCTestCase {
    private func newState(_ difficulty: Difficulty, seed: UInt64 = 42) -> GameState {
        var s = GameState.newGame(startCountry: "IE", companyName: "Test Co", seed: seed, difficulty: difficulty)
        s.eventsEnabled = false
        s.finances.cash = 1e12
        return s
    }

    func testDifficultyLevels() {
        XCTAssertEqual(Difficulty.allCases, [.easy, .medium, .hard])
        XCTAssertLessThan(Difficulty.easy.costMultiplier, Difficulty.medium.costMultiplier)
        XCTAssertLessThan(Difficulty.medium.costMultiplier, Difficulty.hard.costMultiplier)
        XCTAssertEqual(Difficulty.medium.costMultiplier, 1.0)
        XCTAssertEqual(Difficulty.medium.rivalGrowthMultiplier, 1.0)
        XCTAssertLessThan(Difficulty.easy.rivalGrowthMultiplier, Difficulty.hard.rivalGrowthMultiplier)
        XCTAssertTrue(Difficulty.allCases.allSatisfy { !$0.blurb.isEmpty && !$0.title.isEmpty })
    }

    func testDefaultIsMediumAndChangesNothing() {
        let plain = GameState.newGame(startCountry: "IE", companyName: "X", seed: 7)
        XCTAssertEqual(plain.difficulty, .medium)
        XCTAssertEqual(plain.costScale, 1.0)
        XCTAssertEqual(plain.finances.cash, GameState.startingCash)
        let medium = GameState.newGame(startCountry: "IE", companyName: "X", seed: 7, difficulty: .medium)
        XCTAssertEqual(plain, medium)
    }

    func testEverythingCostsMoreOnHarder() throws {
        let easy = newState(.easy), medium = newState(.medium), hard = newState(.hard)
        let ie = CountryData.country("NZ")!
        let title = medium.licenseMarket[0]
        func ratio(_ a: Double, _ b: Double) -> Double { a / b }

        XCTAssertEqual(ratio(hard.licensePrice(title), medium.licensePrice(title)), 1.4, accuracy: 1e-9)
        XCTAssertEqual(ratio(easy.licensePrice(title), medium.licensePrice(title)), 0.75, accuracy: 1e-9)
        XCTAssertEqual(ratio(hard.launchPrice(ie), medium.launchPrice(ie)), 1.4, accuracy: 1e-9)
        XCTAssertEqual(ratio(hard.platformPrice(.ios), medium.platformPrice(.ios)), 1.4, accuracy: 1e-9)
        XCTAssertEqual(ratio(hard.hirePrice(.legal), medium.hirePrice(.legal)), 1.4, accuracy: 1e-9)
        XCTAssertEqual(ratio(hard.studioFoundingPrice, medium.studioFoundingPrice), 1.4, accuracy: 1e-9)
        XCTAssertEqual(ratio(hard.curatorHirePrice, medium.curatorHirePrice), 1.4, accuracy: 1e-9)
        XCTAssertEqual(ratio(hard.datacenterBuildPrice, medium.datacenterBuildPrice), 1.4, accuracy: 1e-9)
        XCTAssertEqual(ratio(hard.localizationPrice(kind: .movie, dub: true), medium.localizationPrice(kind: .movie, dub: true)), 1.4, accuracy: 1e-9)
        XCTAssertEqual(ratio(hard.tierLaunchPrice(.ad, code: "IE") ?? 0, medium.tierLaunchPrice(.ad, code: "IE") ?? 1), 1.4, accuracy: 1e-9)
    }

    func testChargesMatchTheDisplayedPrices() throws {
        for difficulty in Difficulty.allCases {
            var s = newState(difficulty)
            let nz = CountryData.country("NZ")!
            var cash = s.finances.cash
            try s.launchMarket(code: "NZ")
            XCTAssertEqual(cash - s.finances.cash, s.launchPrice(nz), accuracy: 0.01, "\(difficulty)")

            cash = s.finances.cash
            let price = s.platformPrice(.android)
            try s.startPlatform(.android)
            XCTAssertEqual(cash - s.finances.cash, price, accuracy: 0.01)

            cash = s.finances.cash
            let hire = s.hirePrice(.content)
            try s.hire(.content)
            XCTAssertEqual(cash - s.finances.cash, hire, accuracy: 0.01)

            cash = s.finances.cash
            let title = s.licenseMarket[0]
            let list = s.licensePrice(title)
            try s.buyLicense(titleID: title.id)
            XCTAssertEqual(cash - s.finances.cash, list, accuracy: 0.01)

            cash = s.finances.cash
            let studio = s.studioFoundingPrice
            try s.foundStudio(specialty: .drama)
            XCTAssertEqual(cash - s.finances.cash, studio, accuracy: 0.01)

            cash = s.finances.cash
            let tier = s.tierLaunchPrice(.premium, code: "IE")!
            try s.launchTier(.premium, code: "IE")
            XCTAssertEqual(cash - s.finances.cash, tier, accuracy: 0.01)
        }
    }

    func testRunningCostsScaleWithDifficulty() {
        func fin(_ difficulty: Difficulty) -> WeeklyFinancials {
            var s = newState(difficulty)
            s.markets["IE"]?.subs = TierSet(ad: 0, standard: 10_000, premium: 0)
            s.staff.legal = 2
            s.platforms = [.web, .ios]
            s.cloudUnits[Region.europe.rawValue] = 1
            return SimulationEngine.advanceWeek(s).lastReport!.financials
        }
        let medium = fin(.medium), hard = fin(.hard), easy = fin(.easy)
        XCTAssertEqual(hard.operations / medium.operations, 1.4, accuracy: 1e-9)
        XCTAssertEqual(hard.streaming / medium.streaming, 1.4, accuracy: 1e-9)
        XCTAssertEqual(easy.streaming / medium.streaming, 0.75, accuracy: 1e-9)
        XCTAssertEqual(hard.tech / medium.tech, 1.4, accuracy: 1e-6)
        let staffMedium = medium.staff - Formulas.overheadRate * medium.revenue
        let staffHard = hard.staff - Formulas.overheadRate * hard.revenue
        XCTAssertEqual(staffHard / staffMedium, 1.4, accuracy: 1e-6)
        XCTAssertEqual(hard.revenue, medium.revenue, accuracy: 1e-6, "income doesn't change")
        XCTAssertEqual(hard.marketing, medium.marketing, "marketing budgets are yours to set")
        XCTAssertGreaterThan(hard.costs, medium.costs)
        XCTAssertLessThan(easy.costs, medium.costs)
    }

    func testProductionAndPoliciesCostMore() throws {
        func weeklyCost(_ difficulty: Difficulty) throws -> Double {
            var s = newState(difficulty)
            try s.commissionOriginal(kind: .movie, genre: .drama, language: .english, budget: 4_000_000, weeks: 8)
            return s.projects[0].weeklyCost
        }
        XCTAssertEqual(try weeklyCost(.hard) / weeklyCost(.medium), 1.4, accuracy: 1e-9)

        var hard = newState(.hard), medium = newState(.medium)
        for s in [0, 1] {
            if s == 0 { hard.markets["IE"]?.subs = TierSet(ad: 0, standard: 100_000, premium: 0) }
            else { medium.markets["IE"]?.subs = TierSet(ad: 0, standard: 100_000, premium: 0) }
        }
        let hardCash = hard.finances.cash, mediumCash = medium.finances.cash
        try hard.setPolicy("support", option: "premium")
        try medium.setPolicy("support", option: "premium")
        XCTAssertEqual((hardCash - hard.finances.cash) / (mediumCash - medium.finances.cash), 1.4, accuracy: 1e-9)
    }

    func testRivalsGrowFasterOnHard() {
        func netflux(_ difficulty: Difficulty) -> Double {
            var s = newState(difficulty)
            for _ in 0..<80 { s = SimulationEngine.advanceWeek(s) }
            return s.rivals.first { $0.id == "netflux" }!.totalSubs
        }
        XCTAssertGreaterThan(netflux(.hard), netflux(.medium))
        XCTAssertLessThan(netflux(.easy), netflux(.medium))
    }

    func testDifficultySurvivesSavesAndRestarts() throws {
        var s = newState(.hard, seed: 11)
        for _ in 0..<3 { s = SimulationEngine.advanceWeek(s) }
        let loaded = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(s))
        XCTAssertEqual(loaded.difficulty, .hard)
        XCTAssertEqual(s.restarted(sameWorld: true, newSeed: 1).difficulty, .hard)
        XCTAssertEqual(s.restarted(sameWorld: false, newSeed: 99).difficulty, .hard)
        XCTAssertEqual(s.restarted(sameWorld: true, newSeed: 1).finances.cash, GameState.startingCash)
    }
}
