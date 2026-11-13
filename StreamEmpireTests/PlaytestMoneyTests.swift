import XCTest
#if canImport(StreamEmpireCore)
@testable import StreamEmpireCore
#else
@testable import StreamEmpire
#endif

/// "Playtest bot 1: money and capital." A long-running winner bot that tries to reach #1 with capital strategies
/// (loans, investor rounds, IPO, buybacks, hostile takeovers, licensing titles out, stacked promotions, extreme prices)
/// and asserts invariants every week, plus focused probes.
///
/// Methods named `testBug_*` are deterministic repros of suspected engine bugs found by reading the code. THEY ARE
/// EXPECTED TO FAIL on the current code and assert the desired behaviour.
/// Grep the CI log for "PLAYTEST money".
final class PlaytestMoneyTests: XCTestCase {

    // MARK: Failure collector (one message per tag so a systematic bug does not spam)

    private final class Report {
        var messages: [String] = []
        var seen: Set<String> = []
        func check(_ ok: Bool, _ tag: String, _ message: @autoclosure () -> String) {
            if ok { return }
            if seen.contains(tag) { return }
            seen.insert(tag)
            messages.append("[\(tag)] \(message())")
        }
    }

    private func whole(_ x: Double) -> String {
        guard x.isFinite else { return "NaN" }
        return String(Int(max(-9.0e15, min(9.0e15, x))))
    }

    private func startCode(_ preferred: String) -> String {
        CountryData.country(preferred) != nil ? preferred : (CountryData.starters.first?.code ?? "US")
    }

    // MARK: The bot

    private enum Style { case blitz, burn, raider }

    private struct Bot {
        var rng: SeededRNG
        var style: Style
        var shareArbGain = 0.0
        var flipIncome = 0.0
        var flips = 0
        var loansTaken = 0
        var arbCycles = 0

        init(seed: UInt64, style: Style) {
            rng = SeededRNG(seed: seed &* 104_729 &+ 7)
            self.style = style
        }

        mutating func act(_ s: inout GameState, order: [Country]) {
            guard s.outcome == .playing else { return }
            let costs = max(s.finances.lastWeek.costs, 150_000.0)
            let live = s.liveMarketCodes

            // One-time setup.
            if s.week == 1 {
                _ = try? s.hireCurator(mode: .aggressive)
                if var c = s.curator {
                    c.capMode = .fixed
                    c.catalogCap = 350
                    _ = try? s.updateCurator(c)
                }
                s.renewalMode = .standard
                s.expiryAlerts = .show
                s.autoScale = true
            }
            // Keep the catalog small enough to simulate quickly.
            if var c = s.curator {
                let wantOn = s.catalog.count < 420
                if c.enabled != wantOn { c.enabled = wantOn; _ = try? s.updateCurator(c) }
            }

            // Pricing.
            if s.week == 1 || s.week % 13 == 0 {
                switch style {
                case .blitz: _ = try? s.applyPriceLevel(0.7)
                case .burn: _ = try? s.applyPriceLevel(0.4)
                case .raider: _ = try? s.applyPriceLevel(1.0)
                }
            }

            // Marketing.
            if s.week % 4 == 1 {
                var factor = 0.0
                if style == .burn {
                    factor = s.finances.cash > costs * 8 ? 0.6 : (s.finances.cash > costs * 3 ? 0.15 : 0.0)
                } else {
                    factor = s.finances.cash > costs * 40 ? 0.5 : (s.finances.cash > costs * 15 ? 0.2 : 0.0)
                }
                for code in live {
                    if let country = CountryData.country(code) {
                        _ = try? s.setMarketing(code: code, weeklyBudget: factor * Formulas.marketingScale(households: country.households))
                    }
                }
            }

            // Launch markets as soon as affordable, biggest first.
            var launches = 0
            let maxLaunches = style == .burn ? 3 : 2
            for country in order where launches < maxLaunches {
                guard s.markets[country.code]?.status == .notLaunched, s.launchBlocker(code: country.code) == nil else { continue }
                let price = s.launchPrice(country)
                if s.finances.cash >= price + costs * 8 {
                    if (try? s.launchMarket(code: country.code)) != nil { launches += 1 }
                } else {
                    break
                }
            }

            // Tiers.
            if s.week % 8 == 3, s.finances.cash > costs * 20 {
                for code in live {
                    if (s.markets[code]?.subs.total ?? 0) > 150_000 {
                        _ = try? s.launchTier(.ad, code: code)
                        _ = try? s.launchTier(.premium, code: code)
                    }
                }
            }

            // Platforms.
            if s.week % 4 == 2 {
                for platform in [Platform.ios, .android, .smartTV, .consoles] {
                    if s.finances.cash > s.platformPrice(platform) * 3 + costs * 10 {
                        _ = try? s.startPlatform(platform)
                    }
                }
            }

            // Staff.
            if s.week % 6 == 4, s.finances.cash > costs * 25 {
                let departments: [Department] = [.marketing, .engineering, .content, .finance, .legal]
                var pick = departments[0]
                for d in departments where s.staff[d] < s.staff[pick] { pick = d }
                if s.staff[pick] < Formulas.maxDepartmentLevel, s.finances.cash > s.hirePrice(pick) * 6 {
                    _ = try? s.hire(pick)
                }
            }

            // Originals.
            if style != .burn, s.week > 20, s.week % 8 == 5, s.projects.count < 2,
               s.finances.cash > costs * 30 + 20_000_000 {
                let genre = rng.pick([Genre.drama, .comedy, .action])
                _ = try? s.commissionOriginal(kind: .series, genre: genre, language: .english, budget: 12_000_000, weeks: 40)
            }

            // Promotions.
            if style != .raider, s.week % 13 == 6, s.finances.cash > costs * 25 {
                for kind in [PromotionKind.blitz, .freeTrial, .winback] {
                    let quote = s.promotionQuote(kind: kind, scope: "", weeks: 6, intensity: 0)
                    if quote.cost < s.finances.cash * 0.15 {
                        _ = try? s.launchPromotion(kind: kind, scope: "", weeks: 6)
                    }
                }
            }

            // Sports rights.
            if s.week % 52 == 21 {
                let offers = s.sportsOffers
                for offer in offers where s.finances.cash > offer.askPrice * 1.3 * 6 {
                    _ = try? s.bidForSports(offerID: offer.id, premium: 1.3)
                    break
                }
            }

            // Funding: loans when cash is short, rounds and IPO the moment they are allowed.
            if s.creditRoom >= 1_000_000, s.finances.cash < costs * 12 + 5_000_000, s.loans.count < 8 {
                let amount = min(s.creditRoom * 0.9, max(2_000_000, costs * 30))
                if amount >= 250_000, (try? s.takeLoan(amount: amount, termWeeks: 208)) != nil { loansTaken += 1 }
            }
            if s.roundBlocker == nil { _ = try? s.raiseRound(percent: 0.25) }
            if s.ipoBlocker == nil { _ = try? s.launchIPO() }
            if s.equity.ipoDone, s.equity.ownership < 0.999,
               s.finances.cash > costs * 60 + s.buybackPrice(percent: 0.10) {
                _ = try? s.buyBackShares(percent: 0.10)
            }
            if s.equity.ipoDone, s.finances.cash > costs * 120 { _ = try? s.payDividend() }
            if let loan = s.loans.first, s.finances.cash > loan.balance + costs * 80 {
                _ = try? s.repayLoan(id: loan.id, amount: loan.balance)
            }

            // Hostile takeovers: the biggest rival we can afford (borrowing the gap when it is worth it).
            if style != .burn || s.week > 100, s.takeover == nil, s.week > 30 {
                let targets = s.rivals.sorted { $0.totalSubs > $1.totalSubs }
                let budget = s.finances.cash - costs * 4
                for rival in targets {
                    let held = s.stake(in: rival.id)
                    let need = (s.takeoverCost(rival, premium: 0.6) + (held < 0.05 ? s.sharePrice(rival, percent: 0.05) : 0)) * 1.12
                    if need <= budget {
                        if held < 0.05 { _ = try? s.buyShares(rivalID: rival.id, percent: 0.05) }
                        _ = try? s.launchTakeover(rivalID: rival.id, premium: 0.6)
                        break
                    } else if need <= budget + s.creditRoom * 0.9, s.loans.count < 10,
                              rival.totalSubs > s.totalSubscribers * 0.3 {
                        let amount = min(s.creditRoom * 0.95, need - budget + 1_000_000)
                        if amount >= 250_000, (try? s.takeLoan(amount: amount, termWeeks: 208)) != nil { loansTaken += 1 }
                        break
                    }
                }
            }

            if style == .raider {
                // Output deals, immediately sublicensed (probing licenseOut vs deal fee).
                if s.outputDeals.count < GameState.maxOutputDeals, s.week % 10 == 0,
                   s.finances.cash > s.outputDealFee() * 40 {
                    _ = try? s.signOutputDeal(genre: .drama)
                }
                let flippable = s.catalog.filter {
                    !$0.isOriginal && $0.invested == 0 && ($0.license?.exclusive ?? false) && ($0.weeksRemaining ?? 0) > 110
                }
                for title in flippable {
                    let fee = s.sublicenseFee(title, weeks: 104)
                    if (try? s.licenseOut(titleID: title.id, weeks: 104)) != nil {
                        flipIncome += fee
                        flips += 1
                    }
                }
                // Share round-trip arbitrage when a rival's investor mood is low.
                for rival in s.rivals where rival.sentiment < 0.8 && s.stake(in: rival.id) == 0 && s.takeover == nil {
                    var cycles = 0
                    while cycles < 8 {
                        guard let now = s.rivals.first(where: { $0.id == rival.id }), now.sentiment < 0.8 else { break }
                        let cost = s.sharePrice(now, percent: 0.19)
                        guard cost * 1.5 < s.finances.cash else { break }
                        let before = s.finances.cash
                        guard (try? s.buyShares(rivalID: rival.id, percent: 0.19)) != nil else { break }
                        _ = try? s.sellShares(rivalID: rival.id, percent: 0.19)
                        shareArbGain += s.finances.cash - before
                        arbCycles += 1
                        cycles += 1
                    }
                }
                // Liquidity: sell the rights to the most valuable title when about to run dry.
                if s.finances.cash < costs * 3, s.creditRoom < 250_000 {
                    var best: (id: Int, fee: Double)?
                    for title in s.catalog where (title.weeksRemaining ?? 999) > 60 {
                        let fee = s.sublicenseFee(title, weeks: 52)
                        if fee > (best?.fee ?? 0) { best = (title.id, fee) }
                    }
                    if let best, (try? s.licenseOut(titleID: best.id, weeks: 52)) != nil { flipIncome += best.fee }
                }
            }
        }
    }

    // MARK: Invariants

    private func fields(_ f: WeeklyFinancials) -> [(String, Double)] {
        [("subscriptionRevenue", f.subscriptionRevenue), ("adRevenue", f.adRevenue), ("licensing", f.licensing),
         ("streaming", f.streaming), ("staff", f.staff), ("marketing", f.marketing), ("operations", f.operations),
         ("launch", f.launch), ("originals", f.originals), ("localization", f.localization),
         ("interest", f.interest), ("fines", f.fines), ("other", f.other), ("tech", f.tech),
         ("studios", f.studios), ("policies", f.policies), ("promotions", f.promotions),
         ("licenseOutRevenue", f.licenseOutRevenue), ("taxes", f.taxes)]
    }

    private func checkState(old: GameState, new: GameState, seed: UInt64, report: Report) {
        let ctx = "seed \(seed) week \(old.week)"
        report.check(new.finances.cash.isFinite, "cashFinite", "\(ctx): cash \(new.finances.cash)")
        report.check(new.totalSubscribers.isFinite && new.totalSubscribers >= 0, "subsFinite",
                     "\(ctx): total subscribers \(new.totalSubscribers)")
        report.check(new.valuation.isFinite && new.creditLimit.isFinite && new.creditRoom.isFinite, "fundingFinite",
                     "\(ctx): valuation \(new.valuation) creditLimit \(new.creditLimit)")
        report.check(new.equity.ownership >= 0 && new.equity.ownership <= 1.0000001, "ownershipRange",
                     "\(ctx): ownership \(new.equity.ownership)")
        for (name, value) in fields(new.finances.lastWeek) {
            report.check(value.isFinite, "fin.\(name)", "\(ctx): WeeklyFinancials.\(name) = \(value)")
        }
        report.check(new.finances.annualizedRevenue.isFinite, "annualizedFinite", "\(ctx): annualized revenue")

        var overCeiling = ""
        for code in new.markets.keys.sorted() {
            let subs = new.markets[code]?.subs ?? TierSet.zero
            let ok = subs.ad.isFinite && subs.standard.isFinite && subs.premium.isFinite
                && subs.ad >= 0 && subs.standard >= 0 && subs.premium >= 0
            report.check(ok, "marketSubs", "\(ctx): market \(code) subs \(subs)")
            if let country = CountryData.country(code), subs.total > country.subscriberCeiling * 1.06 {
                overCeiling = "\(code) has \(subs.total) vs ceiling \(country.subscriberCeiling)"
            }
            if let market = new.markets[code] {
                let prices = market.prices
                report.check(prices.ad.isFinite && prices.standard.isFinite && prices.premium.isFinite
                             && market.marketingBudget.isFinite, "marketPricesFinite", "\(ctx): \(code) prices/marketing")
            }
        }
        report.check(overCeiling.isEmpty, "ceiling", "\(ctx): own subscribers over ceiling x1.06: \(overCeiling)")

        for rival in new.rivals {
            var ok = rival.cash.isFinite && rival.catalogStrength.isFinite && rival.priceLevel.isFinite && rival.sentiment.isFinite
            for code in rival.subs.keys.sorted() {
                let v = rival.subs[code] ?? 0
                if !v.isFinite || v < 0 { ok = false }
            }
            report.check(ok, "rivalFinite", "\(ctx): rival \(rival.id) non-finite or negative")
            report.check(rival.cash >= 0, "rivalCashNegative", "\(ctx): rival \(rival.id) cash \(rival.cash)")
        }

        // Unique ids.
        let titleIDs = new.catalog.map(\.id) + new.licenseMarket.map(\.id) + new.loanedOut.map(\.title.id)
        report.check(Set(titleIDs).count == titleIDs.count, "dupTitleIDs", "\(ctx): duplicate title ids")
        report.check(Set(new.loans.map(\.id)).count == new.loans.count, "dupLoanIDs", "\(ctx): duplicate loan ids")
        report.check(Set(new.rivals.map(\.id)).count == new.rivals.count, "dupRivalIDs", "\(ctx): duplicate rival ids")
        report.check(Set(new.projects.map(\.id)).count == new.projects.count, "dupProjectIDs", "\(ctx): duplicate project ids")
        report.check(Set(new.news.map(\.id)).count == new.news.count, "dupNewsIDs", "\(ctx): duplicate news ids")
        for loan in new.loans {
            report.check(loan.balance.isFinite && loan.balance > 0 && loan.balance <= loan.principal + 0.01, "loanBalance",
                         "\(ctx): loan \(loan.id) balance \(loan.balance) principal \(loan.principal)")
        }

        // Shares and takeovers.
        let rivalIDs = Set(new.rivals.map(\.id))
        for id in new.stakes.keys.sorted() {
            let stake = new.stakes[id] ?? 0
            report.check(rivalIDs.contains(id), "stakeOfGoneRival", "\(ctx): stake in \(id) which no longer exists")
            report.check(stake >= 0 && stake <= Formulas.openMarketLimit + 1e-6, "stakeRange", "\(ctx): stake \(stake) in \(id)")
        }
        for id in new.acquiredRivals {
            report.check(!rivalIDs.contains(id), "acquiredStillThere", "\(ctx): acquired rival \(id) is still a rival")
        }
        if let bid = new.takeover {
            report.check(rivalIDs.contains(bid.rivalID) && bid.escrow.isFinite && bid.escrow > 0, "bidState", "\(ctx): bad takeover bid")
        }

        // Overdraft and outcome rules.
        if new.outcome == .playing {
            report.check(new.finances.cash >= -new.overdraftLimit - 1, "overdraft",
                         "\(ctx): cash \(new.finances.cash) below the overdraft limit \(new.overdraftLimit) but still playing")
        }
        if new.outcome == .lost {
            report.check(new.lossReason != nil, "lossReason", "\(ctx): lost without a reason")
        }
        if old.outcome == .playing, new.outcome == .won, new.scenario == .sandbox {
            report.check(new.rank == 1, "wonButNotFirst", "\(ctx): won at rank \(new.rank)")
        }
    }

    // MARK: Playing a full game

    private func playGame(seed: UInt64, start: String, difficulty: Difficulty, style: Style, report: Report) {
        let startedAt = Date()
        var s = GameState.newGame(startCountry: startCode(start), companyName: "Playtest Money", seed: seed, difficulty: difficulty)
        s.eventsEnabled = false
        var bot = Bot(seed: seed, style: style)
        let order = CountryData.all.sorted { $0.households > $1.households }
        var bestRank = Int.max
        var units = 0.0
        var stop = "weeks"
        let maxUnits = 16_000_000.0

        for _ in 1...1_560 {
            bot.act(&s, order: order)
            let old = s
            s = SimulationEngine.advanceWeek(old)
            checkState(old: old, new: s, seed: seed, report: report)
            let rank = s.rank
            if rank < bestRank {
                bestRank = rank
                print("PLAYTEST money milestone week=\(s.week) rank=\(rank)")
            }
            if s.outcome != .playing { stop = "outcome"; break }
            units += Double(max(1, s.liveMarketCodes.count)) * Double(max(40, s.catalog.count))
            if units > maxUnits { stop = "workBudget"; break }
            if s.week % 10 == 0, Date().timeIntervalSince(startedAt) > 18 { stop = "wallClock"; break }
        }

        let result: String
        switch s.outcome {
        case .won: result = "won"
        case .lost: result = "lost"
        case .playing: result = "playing"
        }
        print("PLAYTEST money seed=\(seed) diff=\(difficulty.rawValue) result=\(result) week=\(s.week) rank=\(s.rank) subs=\(whole(s.totalSubscribers)) cash=\(whole(s.finances.cash)) markets=\(s.liveMarketCodes.count) catalog=\(s.catalog.count)")
        print("PLAYTEST money note seed=\(seed) style=\(style) stop=\(stop) lossReason=\(s.lossReason ?? "-") rounds=\(s.equity.roundsRaised) ipo=\(s.equity.ipoDone) ownership=\(String(format: "%.2f", s.equity.ownership)) loansNow=\(s.loans.count) loansTaken=\(bot.loansTaken) takeovers=\(s.acquiredRivals.count) flips=\(bot.flips) flipIncome=\(whole(bot.flipIncome)) shareArbCycles=\(bot.arbCycles) shareArbGain=\(whole(bot.shareArbGain)) lifetimeLicenseOut=\(whole(s.finances.lifetime.licenseOutRevenue)) lifetimeInterest=\(whole(s.finances.lifetime.interest)) valuation=\(whole(s.valuation)) annualRevenue=\(whole(s.finances.annualizedRevenue))")
    }

    func testWinnerBot_blitzUSMedium() {
        let report = Report()
        playGame(seed: 101, start: "US", difficulty: .medium, style: .blitz, report: report)
        XCTAssertTrue(report.messages.isEmpty, report.messages.joined(separator: "\n"))
    }

    func testWinnerBot_burnGermanyHard() {
        let report = Report()
        playGame(seed: 202, start: "DE", difficulty: .hard, style: .burn, report: report)
        XCTAssertTrue(report.messages.isEmpty, report.messages.joined(separator: "\n"))
    }

    func testWinnerBot_raiderEasy() {
        let report = Report()
        playGame(seed: 303, start: "US", difficulty: .easy, style: .raider, report: report)
        XCTAssertTrue(report.messages.isEmpty, report.messages.joined(separator: "\n"))
    }

    // MARK: Helpers for probes

    private func freshGame(seed: UInt64 = 5, scenario: Scenario = .sandbox) -> GameState {
        var s = GameState.newGame(startCountry: "US", companyName: "Probe Co", seed: seed, scenario: scenario)
        s.eventsEnabled = false
        return s
    }

    /// Buys the cheapest on-sale listing and returns its id.
    private func buyCheapest(_ s: inout GameState) -> Int? {
        let options = s.licenseMarket.filter { $0.license != nil && $0.embargoWeeks == 0 }
            .sorted { s.licensePrice($0) < s.licensePrice($1) }
        guard let pick = options.first else { return nil }
        do { try s.buyLicense(titleID: pick.id) } catch { return nil }
        return pick.id
    }

    // MARK: Invariant probes (should pass)

    /// With no player actions in the way, cash must follow the books exactly:
    /// new cash = old cash + weekly profit + prepaid spend - loan principal - prepaid license income
    ///            - (spend recorded in the new ledger, which was deducted during the week) + (income recorded there).
    func testProbe_cashIdentityHoldsEveryWeek() {
        var s = freshGame(seed: 9)
        s.finances.cash = 200_000_000
        for _ in 0..<3 { _ = buyCheapest(&s) }
        if let first = s.catalog.first {
            if let i = s.catalog.firstIndex(where: { $0.id == first.id }) { s.catalog[i].weeksRemaining = 400 }
            _ = try? s.licenseOut(titleID: first.id, weeks: 13)
        }
        XCTAssertNoThrow(try s.takeLoan(amount: 1_000_000, termWeeks: 52))
        for _ in 0..<30 {
            let old = s
            let principal = old.loans.reduce(0.0) { $0 + min($1.balance, $1.weeklyPrincipal) }
            s = SimulationEngine.advanceWeek(old)
            let f = s.finances.lastWeek
            let expected = old.finances.cash + f.profit + old.finances.ledger.total - principal
                - old.finances.ledger.licenseIncome - s.finances.ledger.total + s.finances.ledger.licenseIncome
            XCTAssertEqual(s.finances.cash, expected, accuracy: max(1.0, abs(expected) * 1e-9), "week \(old.week)")
            if s.outcome != .playing { break }
        }
    }

    /// Repeated max loans can never push debt past the credit limit, and borrowing then repaying is cash neutral.
    func testProbe_loanLoopIsBoundedAndNeutral() {
        var s = freshGame(seed: 12)
        s.finances.revenueHistory = Array(repeating: 2_000_000, count: 52)
        let start = s.finances.cash
        var taken = 0.0
        for _ in 0..<40 {
            let room = s.creditRoom
            guard room >= 250_000 else { break }
            guard (try? s.takeLoan(amount: room, termWeeks: 52)) != nil else { break }
            taken += room
        }
        XCTAssertLessThanOrEqual(s.outstandingDebt, s.creditLimit * 1.0001 + 1, "debt exceeded the credit limit")
        XCTAssertEqual(s.finances.cash, start + taken, accuracy: 1.0)
        let toRepay = s.loans
        for loan in toRepay { _ = try? s.repayLoan(id: loan.id, amount: loan.balance) }
        XCTAssertEqual(s.finances.cash, start, accuracy: 1.0, "borrow-then-repay changed cash")
        XCTAssertTrue(s.loans.isEmpty)
    }

    /// Equity rounds respect the ownership floor and the round cap, even when cooldowns are skipped.
    func testProbe_roundsRespectFloor() {
        var s = freshGame(seed: 14)
        s.finances.revenueHistory = Array(repeating: 1_000_000, count: 52)
        var raised = 0
        for _ in 0..<10 {
            s.equity.lastRoundWeek = -100
            if (try? s.raiseRound(percent: 0.25)) != nil { raised += 1 }
        }
        XCTAssertLessThanOrEqual(raised, Formulas.maxRounds)
        XCTAssertGreaterThanOrEqual(s.equity.ownership, Formulas.minOwnership - 1e-9)
        print("PLAYTEST money probe rounds raised=\(raised) ownership=\(s.equity.ownership) cash=\(whole(s.finances.cash))")
    }

    /// Extreme prices, price level tool, stacked promotions and huge marketing never produce NaN or negative revenue.
    func testProbe_extremeActionsStayFinite() {
        let priceSets: [TierSet] = [TierSet(ad: 0, standard: 0, premium: 0), TierSet(ad: 100, standard: 100, premium: 100),
                                    TierSet(ad: 0, standard: 100, premium: 0), TierSet(ad: 100, standard: 0, premium: 100)]
        for (index, prices) in priceSets.enumerated() {
            var s = freshGame(seed: UInt64(30 + index))
            s.finances.cash = 5_000_000_000
            _ = buyCheapest(&s)
            s.markets["US"]?.subs = TierSet(ad: 100_000, standard: 1_000_000, premium: 200_000)
            s.markets["US"]?.liveTiers = [.ad, .standard, .premium]
            XCTAssertNoThrow(try s.setPrices(code: "US", prices: prices))
            _ = try? s.launchPromotion(kind: .discount, scope: "", weeks: 12, intensity: 0.6)
            _ = try? s.launchPromotion(kind: .freeTrial, scope: "", weeks: 12)
            _ = try? s.launchPromotion(kind: .twoForOne, scope: "", weeks: 12)
            _ = try? s.setMarketing(code: "US", weeklyBudget: 50_000_000)
            for _ in 0..<26 {
                s = SimulationEngine.advanceWeek(s)
                XCTAssertTrue(s.finances.cash.isFinite, "prices \(prices)")
                XCTAssertTrue(s.totalSubscribers.isFinite && s.totalSubscribers >= 0, "prices \(prices)")
                XCTAssertGreaterThanOrEqual(s.finances.lastWeek.subscriptionRevenue, 0)
                if let market = s.markets["US"], let country = CountryData.country("US") {
                    XCTAssertLessThanOrEqual(market.subs.total, country.subscriberCeiling * 1.06)
                }
                if s.outcome != .playing { break }
            }
        }
        for level in [0.4, 2.0] {
            var s = freshGame(seed: 40)
            XCTAssertNoThrow(try s.applyPriceLevel(level))
            for _ in 0..<10 { s = SimulationEngine.advanceWeek(s) }
            XCTAssertTrue(s.finances.cash.isFinite)
        }
        var s = freshGame(seed: 41)
        XCTAssertThrowsError(try s.applyPriceLevel(0.39))
        XCTAssertThrowsError(try s.applyPriceLevel(2.01))
        XCTAssertThrowsError(try s.setPrices(code: "US", prices: TierSet(ad: -1, standard: 5, premium: 5)))
        XCTAssertThrowsError(try s.setPrices(code: "US", prices: TierSet(ad: 5, standard: 100.01, premium: 5)))
    }

    /// Harvest probe: what does a $100 price earn compared with the fair price over a year? (Logged, not asserted.)
    func testProbe_priceHarvest() {
        var results: [(String, Double, Double)] = []
        for (label, price) in [("fair", 15.0), ("gouge", 100.0)] {
            var s = freshGame(seed: 50)
            s.finances.cash = 2_000_000_000
            for _ in 0..<14 { _ = buyCheapest(&s) }
            s.markets["US"]?.subs = TierSet(ad: 0, standard: 2_000_000, premium: 0)
            s.markets["US"]?.awareness = 0.6
            XCTAssertNoThrow(try s.setPrices(code: "US", prices: TierSet(ad: price, standard: price, premium: price)))
            var revenue = 0.0
            for _ in 0..<52 {
                s = SimulationEngine.advanceWeek(s)
                revenue += s.finances.lastWeek.subscriptionRevenue
                if s.outcome != .playing { break }
            }
            XCTAssertTrue(revenue.isFinite)
            results.append((label, revenue, s.totalSubscribers))
        }
        for (label, revenue, subs) in results {
            print("PLAYTEST money probe harvest \(label) revenue52w=\(whole(revenue)) subsEnd=\(whole(subs))")
        }
    }

    /// Scenario deadlines end an idle game with a reason.
    func testProbe_scenarioDeadlineEndsIdleGame() {
        var s = freshGame(seed: 60, scenario: .profitable)
        for _ in 0..<120 {
            s = SimulationEngine.advanceWeek(s)
            if s.outcome != .playing { break }
        }
        XCTAssertNotEqual(s.outcome, .playing, "an idle game must end by the deadline")
        if s.outcome == .lost { XCTAssertNotNil(s.lossReason) }
        print("PLAYTEST money probe scenario outcome=\(s.outcome.rawValue) week=\(s.week) reason=\(s.lossReason ?? "-")")
    }

    // MARK: Definite bugs (expected to FAIL on current code)

    /// SimulationEngine books licenseOut fees as weekly revenue, so a one-off fee is annualised x52 and inflates
    /// credit limit (3x), valuation (5x), IPO/round eligibility and the bankruptcy floor.
    func testBug_licenseOutFeeInflatesAnnualRevenue() {
        var s = freshGame()
        s.finances.cash = 1_000_000_000
        guard let id = buyCheapest(&s), let index = s.catalog.firstIndex(where: { $0.id == id }) else {
            XCTFail("could not buy a listing"); return
        }
        s.catalog[index].weeksRemaining = 400
        XCTAssertGreaterThan(s.sublicenseFee(s.catalog[index], weeks: 52), 0)
        XCTAssertNoThrow(try s.licenseOut(titleID: id, weeks: 52))
        let after = SimulationEngine.advanceWeek(s)
        let operating = (after.finances.lastWeek.subscriptionRevenue + after.finances.lastWeek.adRevenue) * 52
        XCTAssertLessThanOrEqual(after.finances.annualizedRevenue, operating + 1,
                                 "a one-off sublicense fee must not count toward annualised recurring revenue")
    }

    /// Renewals ratchet the price down each time (paidPrice = renewal price, then 80% again), ignoring audience growth.
    func testBug_renewalPriceRatchetsDown() {
        var s = freshGame()
        s.finances.cash = 1_000_000_000
        guard let id = buyCheapest(&s), let index = s.catalog.firstIndex(where: { $0.id == id }) else {
            XCTFail("could not buy a listing"); return
        }
        s.catalog[index].weeksRemaining = 10
        XCTAssertNoThrow(try s.renewLicense(titleID: id, years: 5))
        let firstPerYear = s.catalog[index].paidPrice / 5
        s.catalog[index].weeksRemaining = 10
        XCTAssertNoThrow(try s.renewLicense(titleID: id, years: 5))
        let secondPerYear = s.catalog[index].paidPrice / 5
        XCTAssertGreaterThanOrEqual(secondPerYear, firstPerYear * 0.999,
                                    "second renewal per-year price \(secondPerYear) fell below first \(firstPerYear)")
    }

    /// Output-deal titles are sublicensed for far more than the deal's per-title cost once the audience is big.
    func testBug_outputDealTitleFlipsForProfit() {
        var s = freshGame()
        s.markets["US"]?.subs = TierSet(ad: 0, standard: 50_000_000, premium: 0)
        s.finances.cash = 5_000_000_000
        XCTAssertNoThrow(try s.signOutputDeal(genre: .drama))
        guard let deal = s.outputDeals.first else { XCTFail("no deal"); return }
        let paidPerTitle = deal.weeklyFee * Double(GameState.outputDeliveryEvery)
        var steps = 0
        while !s.catalog.contains(where: { !$0.isOriginal && $0.invested == 0 }) && steps < 12 {
            s = SimulationEngine.advanceWeek(s)
            steps += 1
        }
        guard let title = s.catalog.first(where: { !$0.isOriginal && $0.invested == 0 }) else {
            XCTFail("no delivery after \(steps) weeks"); return
        }
        let fee = s.sublicenseFee(title, weeks: 104)
        XCTAssertLessThanOrEqual(fee, paidPerTitle, "sublicense fee \(fee) vs deal cost \(paidPerTitle) per title")
    }

    /// NaN slips through the `< 0 || > 100` price range check.
    func testBug_nanPriceRejected() {
        var s = freshGame()
        XCTAssertThrowsError(try s.setPrices(code: "US", prices: TierSet(ad: .nan, standard: 10, premium: 10)))
        XCTAssertThrowsError(try s.applyPrices(TierSet(ad: 5, standard: .nan, premium: 5)))
    }

    /// setMarketing accepts an infinite budget.
    func testBug_infiniteMarketingRejected() {
        var s = freshGame()
        _ = try? s.setMarketing(code: "US", weeklyBudget: .infinity)
        XCTAssertTrue(s.markets["US"]?.marketingBudget.isFinite ?? false, "marketing budget is \(s.markets["US"]?.marketingBudget ?? 0)")
    }

    /// Challenge score counts raw cash, so borrowing right before the finish line raises it.
    func testBug_scoreIgnoresDebt() {
        var s = freshGame(scenario: .tenMillion)
        s.finances.revenueHistory = Array(repeating: 2_000_000, count: 52)
        let before = Scenarios.score(s)
        XCTAssertNoThrow(try s.takeLoan(amount: 100_000_000, termWeeks: 208))
        XCTAssertLessThanOrEqual(Scenarios.score(s), before, "taking a loan must not raise the score")
    }

    /// Dividends and buybacks have no game-over guard (every other money action does).
    func testBug_gameOverBlocksCorporateActions() {
        var s = freshGame()
        s.equity.ipoDone = true
        s.equity.ownership = 0.8
        s.finances.cash = 1_000_000_000
        s.outcome = .lost
        XCTAssertThrowsError(try s.payDividend())
        XCTAssertThrowsError(try s.buyBackShares(percent: 0.05))
    }

    /// With every rival gone (all acquired) the win check `rivals.max()` is nil, so you can never win.
    func testBug_noRivalsLeftStillWins() {
        var s = freshGame()
        s.rivals = []
        s.previousRanking = ["player"]
        s.week = 60
        s.markets["US"]?.subs = TierSet(ad: 0, standard: 1_000_000, premium: 0)
        s.finances.cash = 500_000_000
        s = SimulationEngine.advanceWeek(s)
        XCTAssertEqual(s.outcome, .won, "the only service left on Earth should be #1")
    }

    /// buyShares raises the rival's sentiment and sellShares pays out at the raised price, so a same-week round trip
    /// profits whenever investor mood is low (<~0.75), and can be looped without limit.
    func testBug_shareRoundTripProfitsWhenSentimentLow() {
        var s = freshGame()
        s.finances.cash = 1_000_000_000_000
        let id = s.rivals[0].id
        s.rivals[0].sentiment = 0.62
        let before = s.finances.cash
        XCTAssertNoThrow(try s.buyShares(rivalID: id, percent: 0.19))
        XCTAssertNoThrow(try s.sellShares(rivalID: id, percent: 0.19))
        XCTAssertLessThanOrEqual(s.finances.cash, before, "round trip made \(s.finances.cash - before)")
    }

    /// IPO sells 15% at 1.4x valuation, buybacks reacquire at 1.1x: buying the same 15% back is free money.
    func testBug_ipoThenBuybackIsFreeMoney() {
        var s = freshGame()
        s.markets["US"]?.subs = TierSet(ad: 0, standard: 6_000_000, premium: 0)
        s.finances.revenueHistory = Array(repeating: 6_000_000, count: 52)
        s.finances.cash = 100_000_000
        let start = s.finances.cash
        XCTAssertNil(s.ipoBlocker)
        XCTAssertNoThrow(try s.launchIPO())
        XCTAssertNoThrow(try s.buyBackShares(percent: 0.10))
        XCTAssertNoThrow(try s.buyBackShares(percent: 0.05))
        XCTAssertEqual(s.equity.ownership, 1.0, accuracy: 1e-9)
        XCTAssertLessThanOrEqual(s.finances.cash, start + 1, "selling then repurchasing 15% netted \(s.finances.cash - start)")
    }

    /// Churn's price effect is clamped at x2 while revenue per subscriber scales linearly with price, so
    /// a $100 price on an installed base is a runaway profit. Desired: gouging must cost far more churn.
    func testBug_churnPriceEffectCapsAtTwoX() {
        let fair = Formulas.churnRate(appeal: 0.5, price: 10, tolerance: 10, serviceQuality: 1.0)
        let gouge = Formulas.churnRate(appeal: 0.5, price: 100, tolerance: 10, serviceQuality: 1.0)
        XCTAssertGreaterThanOrEqual(gouge, fair * 4 - 1e-9, "10x the fair price only multiplies churn by \(gouge / fair)")
    }
}
