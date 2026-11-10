import XCTest
#if canImport(StreamEmpireCore)
@testable import StreamEmpireCore
#else
@testable import StreamEmpire
#endif

/// A reasonable-but-unsophisticated autopilot, used to sanity-check game pacing.
enum Bot {
    static func step(_ s: inout GameState, home: String) {
        if let event = s.pendingEvent, let first = event.choices.first {
            try? s.resolveEvent(choiceID: first.id)
        }
        guard let homeCountry = CountryData.country(home) else { return }
        let live = s.liveMarketCodes

        // Keep a healthy catalog: best appeal per dollar that we can comfortably afford.
        let target = min(40, 10 + s.week / 6 + 3 * live.count)
        var purchases = 0
        while s.catalog.count < target, purchases < 3 {
            purchases += 1
            let cash = s.finances.cash
            let affordable = s.licenseMarket.filter {
                let price = s.licensePrice($0)
                return price < cash * 0.2 && price < cash - 2_000_000
            }
            func value(_ t: Title) -> Double {
                guard let license = t.license else { return 0 }
                return Formulas.titleAppeal(t, in: homeCountry) * sqrt(Double(license.years)) / max(1, s.licensePrice(t))
            }
            guard let best = affordable.max(by: { value($0) < value($1) }) else { break }
            try? s.buyLicense(titleID: best.id)
        }

        // Marketing in every live market, scaled to cash on hand.
        for code in live {
            try? s.setMarketing(code: code, weeklyBudget: min(50_000, max(0, s.finances.cash * 0.004)))
        }

        // Ship on more platforms once there's money.
        if s.finances.cash > 6_000_000 {
            for platform in [Platform.ios, .android, .smartTV, .consoles]
            where !s.platforms.contains(platform) && !s.builds.contains(where: { $0.platform == platform }) {
                try? s.startPlatform(platform)
                break
            }
        }

        // Add servers before a region fills up.
        for region in Region.allCases where s.serverLoad(region) > 0.7 {
            let building = s.datacenters.contains { $0.region == region && !$0.isOnline }
            if !building, s.datacenters(in: region).count < 3, s.finances.cash > 3_000_000 {
                try? s.buildDatacenter(region: region)
            } else if s.serverLoad(region) > 0.85, s.finances.cash > 500_000 {
                try? s.rentCloud(region: region)
            }
            if s.serverLoad(region) > 0.8, s.finances.cash > 6_000_000,
               let dc = s.datacenters(in: region).first(where: { s.datacenterUpgradePrice($0) != nil }) {
                try? s.upgradeDatacenter(id: dc.id)
            }
        }

        // Expand every 13 weeks if affordable and profitable.
        if s.week % 13 == 0, s.finances.recentWeeklyProfit > 0 {
            let cash = s.finances.cash
            let options = CountryData.all.filter {
                s.markets[$0.code]?.status == .notLaunched && s.launchBlocker(code: $0.code) == nil
                    && $0.launchCost * 2.5 < cash
            }
            if let pick = options.max(by: { $0.households / $0.launchCost < $1.households / $1.launchCost }) {
                try? s.launchMarket(code: pick.code)
            }
        }
    }

    struct Snapshot {
        var week: Int
        var subs: Double
        var cash: Double
        var profit: Double
        var rank: Int
        var catalog: Int
        var live: Int
        var outcome: GameOutcome
        var topRival: Double
    }

    static func play(home: String, weeks: Int, seed: UInt64 = 7) -> [Snapshot] {
        var s = GameState.newGame(startCountry: home, companyName: "Bot Co", seed: seed)
        var snapshots: [Snapshot] = []
        for _ in 0..<weeks {
            step(&s, home: home)
            s = SimulationEngine.advanceWeek(s)
            if [26, 52, 104, 156, 260].contains(s.week - 1) || s.outcome != .playing {
                snapshots.append(Snapshot(week: s.week - 1, subs: s.totalSubscribers, cash: s.finances.cash,
                                          profit: s.finances.lastWeek.profit, rank: s.rank,
                                          catalog: s.catalog.count, live: s.liveMarketCodes.count,
                                          outcome: s.outcome,
                                          topRival: s.rivals.map(\.totalSubs).max() ?? 0))
            }
            if s.outcome != .playing { break }
        }
        return snapshots
    }
}

final class BalanceTests: XCTestCase {
    func testAutopilotPacingAcrossStarterCountries() {
        for home in ["IE", "NZ", "NL", "CA"] {
            let snapshots = Bot.play(home: home, weeks: 156)
            for snap in snapshots {
                print(String(format: "BALANCE %@ w%d subs=%.0f cash=%.0f profit=%.0f rank=%d cat=%d live=%d top=%.0f %@",
                             home, snap.week, snap.subs, snap.cash, snap.profit, snap.rank,
                             snap.catalog, snap.live, snap.topRival, snap.outcome.rawValue))
            }
            let last = snapshots.last!
            XCTAssertNotEqual(last.outcome, .lost, "\(home): a sensible player shouldn't go bankrupt in 3 years")
            // Pacing bands for a simple autopilot (observed: ~130-250K at year 1, 0.4-1.5M at year 2, 0.5-5M at year 3 (small markets sit at the low end)).
            let bands: [Int: ClosedRange<Double>] = [52: 60_000...1_500_000,
                                                      104: 250_000...6_000_000,
                                                      156: 450_000...15_000_000]   // lowered from 800K: country rules, territories, piracy and trends are deliberate extra difficulty
            for snap in snapshots {
                if let band = bands[snap.week] {
                    XCTAssertTrue(band.contains(snap.subs), "\(home) week \(snap.week): \(Int(snap.subs)) subs outside \(band)")
                }
                XCTAssertLessThan(snap.rank, 14)
                XCTAssertLessThan(snap.subs, snap.topRival, "\(home) week \(snap.week): #1 should take longer than 3 years for a basic player")
            }
        }
    }

    /// Long-run probe: prints pacing out to 5 years from the biggest starter market (no assertions on scale yet).
    func testLongRunProbe() {
        for snap in Bot.play(home: "CA", weeks: 260) {
            print(String(format: "BALANCE-LONG CA w%d subs=%.0f cash=%.0f profit=%.0f rank=%d live=%d top=%.0f %@",
                         snap.week, snap.subs, snap.cash, snap.profit, snap.rank, snap.live, snap.topRival,
                         snap.outcome.rawValue))
        }
    }

    func testAutopilotIsDeterministic() {
        let a = Bot.play(home: "NL", weeks: 60).map(\.subs)
        let b = Bot.play(home: "NL", weeks: 60).map(\.subs)
        XCTAssertEqual(a, b)
    }
}
