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
        for region in Region.allCases where s.cdnLoad(region) > 0.8 && s.finances.cash > 1_000_000 {
            try? s.expandCDN(region: region)
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
                                          outcome: s.outcome))
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
                print(String(format: "BALANCE %@ w%d subs=%.0f cash=%.0f profit=%.0f rank=%d cat=%d live=%d %@",
                             home, snap.week, snap.subs, snap.cash, snap.profit, snap.rank,
                             snap.catalog, snap.live, snap.outcome.rawValue))
            }
            let last = snapshots.last!
            XCTAssertNotEqual(last.outcome, .lost, "\(home): a sensible player shouldn't go bankrupt in 3 years")
            XCTAssertGreaterThan(last.subs, 10_000, "\(home): should have real subscribers by year 3")
        }
    }

    func testAutopilotIsDeterministic() {
        let a = Bot.play(home: "NL", weeks: 60).map(\.subs)
        let b = Bot.play(home: "NL", weeks: 60).map(\.subs)
        XCTAssertEqual(a, b)
    }
}
