import XCTest
#if canImport(StreamEmpireCore)
@testable import StreamEmpireCore
#else
@testable import StreamEmpire
#endif

// Playtest Bot 3: a randomized "fuzzer" that plays the CONTENT and WORLD side of the game (originals, seasons,
// localization, territories, content rules, output deals, sports, acquisitions, huge catalogs, every scenario and
// difficulty) and asserts invariants after every simulated week.
//
// All randomness comes from SeededRNG (the bot has its own generator, the game keeps its own), so every run is
// reproducible. Tests named `testBug_...` are EXPECTED TO FAIL on the current code: each one pins a suspected
// bug found by code review (see the comment above it).

// MARK: - Configuration

private struct BotConfig {
    var seed: UInt64
    var home: String
    var scenario: Scenario
    var difficulty: Difficulty
    var rich: Bool                    // cash is topped up every week (no bankruptcy), so long runs reach week 500
    var injections: [(week: Int, count: Int)]
}

// MARK: - The bot

private struct ContentFuzzBot {
    var rng: SeededRNG
    let rich: Bool
    var problems: [String] = []

    init(seed: UInt64, rich: Bool) {
        rng = SeededRNG(seed: seed &* 7_919 &+ 17)
        self.rich = rich
    }

    private mutating func note(_ message: String) { problems.append(message) }

    private mutating func choose<T>(_ items: [T]) -> T? {
        if items.isEmpty { return nil }
        return items[rng.nextInt(in: 0...(items.count - 1))]
    }

    private func notLaunched(_ s: GameState, _ code: String) -> Bool {
        guard let market = s.markets[code] else { return false }
        if case .notLaunched = market.status { return true }
        return false
    }

    private func spendProblem(_ label: String, cashBefore: Double, ledgerBefore: Double, ledgerAfter: Double,
                              expected: Double, after s: GameState) -> String? {
        let cashDelta = cashBefore - s.finances.cash
        if abs(cashDelta - expected) > 0.01 { return "\(label): cash fell by \(cashDelta) but the price was \(expected)" }
        if abs((ledgerAfter - ledgerBefore) - expected) > 0.01 {
            return "\(label): ledger grew by \(ledgerAfter - ledgerBefore) but the price was \(expected)"
        }
        return nil
    }

    // MARK: Weekly turn

    mutating func play(_ s: inout GameState) {
        guard s.outcome == .playing else { return }
        if rich && s.finances.cash < 1e10 { s.finances.cash = 2e10 }
        baseline(&s)
        let count = rng.nextInt(in: 0...4)
        for _ in 0..<count { randomAction(&s) }
    }

    /// Keeps the game alive so there are subscribers, revenue and titles to check.
    private mutating func baseline(_ s: inout GameState) {
        let want = s.catalog.count < 25 ? 3 : (rng.chance(0.3) ? 1 : 0)
        for _ in 0..<want {
            var ids: [Int] = []
            for t in s.licenseMarket where t.embargoWeeks == 0 { ids.append(t.id) }
            guard let id = choose(ids) else { break }
            _ = try? s.buyLicense(titleID: id)
        }
        for code in s.liveMarketCodes where (s.markets[code]?.marketingBudget ?? 0) == 0 {
            _ = try? s.setMarketing(code: code, weeklyBudget: 20_000)
        }
        if s.week % 20 == 5, s.liveMarketCodes.count < 6 { launch(&s) }
        if s.anySignupsPaused, rng.chance(0.25) {
            for scope in s.pausedSignups { _ = try? s.setSignupsPaused(scope: scope, paused: false) }
        }
        if !s.sportsOffers.isEmpty, rng.chance(0.5) { sports(&s) }
        if !s.acquisitionOffers.isEmpty, rng.chance(0.5) { acquisitions(&s) }
    }

    private mutating func randomAction(_ s: inout GameState) {
        let roll = rng.nextInt(in: 0...21)
        switch roll {
        case 0, 1, 2: commission(&s)
        case 3: season(&s)
        case 4: cancel(&s)
        case 5, 6: localizeOne(&s)
        case 7, 8: bulkOne(&s)
        case 9: edit(&s)
        case 10: extend(&s)
        case 11: if rng.chance(0.3) { remove(&s) }
        case 12: signups(&s)
        case 13: deals(&s)
        case 14: sports(&s)
        case 15: acquisitions(&s)
        case 16: studios(&s)
        case 17: titleDeals(&s)
        case 18: renew(&s)
        case 19: listings(&s)
        case 20: launch(&s)
        default: break
        }
    }

    // MARK: Actions

    private mutating func commission(_ s: inout GameState) {
        let kind: TitleKind = rng.chance(0.5) ? .movie : .series
        let genre = Genre.allCases[rng.nextInt(in: 0...(Genre.allCases.count - 1))]
        let language = Language.allCases[rng.nextInt(in: 0...(Language.allCases.count - 1))]
        let range = Formulas.budgetRange(kind)
        let budget = range.lowerBound + rng.nextDouble() * (range.upperBound - range.lowerBound)
        let weeks = rng.nextInt(in: 6...52)
        var studioID: Int? = nil
        if !s.studios.isEmpty, rng.chance(0.6) { studioID = choose(s.studios)?.id }
        let release: ReleaseStyle = rng.chance(0.5) ? .binge : .weekly
        let star = StarTier.allCases[rng.nextInt(in: 0...(StarTier.allCases.count - 1))]
        let cashBefore = s.finances.cash
        let projectsBefore = s.projects.count
        do {
            try s.commissionOriginal(kind: kind, genre: genre, language: language, budget: budget, weeks: weeks,
                                     studioID: studioID, release: release, star: star)
            if s.projects.count != projectsBefore + 1 { note("commissionOriginal succeeded but projects went \(projectsBefore) -> \(s.projects.count)") }
        } catch {
            if s.projects.count != projectsBefore { note("a refused commission still changed the project list") }
        }
        if s.finances.cash != cashBefore { note("commissionOriginal must not move cash up front") }
    }

    private mutating func season(_ s: inout GameState) {
        var originals: [Title] = []
        for t in s.catalog where t.isOriginal { originals.append(t) }
        guard let t = choose(originals) else { return }
        let range = Formulas.budgetRange(t.kind)
        let budget = range.lowerBound + rng.nextDouble() * (range.upperBound - range.lowerBound)
        let weeks = rng.nextInt(in: 6...52)
        let release: ReleaseStyle = rng.chance(0.5) ? .binge : .weekly
        let star = StarTier.allCases[rng.nextInt(in: 0...(StarTier.allCases.count - 1))]
        let refusal = s.canContinue(t)
        do {
            try s.orderSeason(titleID: t.id, budget: budget, weeks: weeks, studioID: nil, release: release, star: star)
            if refusal != nil { note("orderSeason succeeded although canContinue refused: \(refusal ?? "")") }
            if !s.projects.contains(where: { $0.sequelOf == t.id }) { note("orderSeason did not create a sequel project") }
        } catch {
            // refusals (production cap, studio slots, cash) are legitimate
        }
    }

    private mutating func cancel(_ s: inout GameState) {
        guard let p = choose(s.projects) else { return }
        do {
            try s.cancelProduction(id: p.id)
            if s.projects.contains(where: { $0.id == p.id }) { note("cancelProduction left the project in place") }
        } catch {
            note("cancelProduction threw for a project that exists: \(error)")
        }
    }

    private mutating func localizeOne(_ s: inout GameState) {
        guard let t = choose(s.catalog) else { return }
        let language = Language.allCases[rng.nextInt(in: 0...(Language.allCases.count - 1))]
        let dub = rng.chance(0.5)
        let price = s.localizationPrice(kind: t.kind, dub: dub)
        let cashBefore = s.finances.cash
        let ledgerBefore = s.finances.ledger.localization
        do {
            try s.localizeTitle(titleID: t.id, language: language, dub: dub)
            if let m = spendProblem("localizeTitle", cashBefore: cashBefore, ledgerBefore: ledgerBefore,
                                    ledgerAfter: s.finances.ledger.localization, expected: price, after: s) { note(m) }
            if let now = s.catalog.first(where: { $0.id == t.id }) {
                let list = dub ? now.dubs : now.subtitles
                if !list.contains(language) { note("localizeTitle paid but did not add the language") }
            }
        } catch {
            if s.finances.cash != cashBefore || s.finances.ledger.localization != ledgerBefore {
                note("a refused localizeTitle still changed cash or the ledger")
            }
        }
    }

    private mutating func bulkOne(_ s: inout GameState) {
        let all = CountryData.all
        let code = all[rng.nextInt(in: 0...(all.count - 1))].code
        let dub = rng.chance(0.5)
        var limit: Int? = nil
        if rng.chance(0.5) { limit = rng.nextInt(in: 1...30) }
        let targets = s.localizationTargets(code: code, dub: dub, limit: limit)
        var only: Set<Int>? = nil
        if rng.chance(0.4) {
            var picked = Set<Int>()
            for t in targets { if rng.chance(0.5) { picked.insert(t.id) } }
            if rng.chance(0.3) { picked.insert(-12345) }       // an id that is not a target must be ignored
            only = picked
        }
        var expected = targets
        if let only { expected = expected.filter { only.contains($0.id) } }
        var price = 0.0
        for t in expected { price += s.localizationPrice(kind: t.kind, dub: dub) }
        if let limit, targets.count > limit { note("localizationTargets ignored its limit \(limit): \(targets.count)") }
        let cashBefore = s.finances.cash
        let ledgerBefore = s.finances.ledger.localization
        do {
            let n = try s.bulkLocalize(code: code, dub: dub, limit: limit, only: only)
            if n != expected.count { note("bulkLocalize returned \(n) but \(expected.count) titles were expected") }
            if let m = spendProblem("bulkLocalize \(code)", cashBefore: cashBefore, ledgerBefore: ledgerBefore,
                                    ledgerAfter: s.finances.ledger.localization, expected: price, after: s) { note(m) }
        } catch {
            if !expected.isEmpty, cashBefore >= price { note("bulkLocalize threw \(error) although \(expected.count) titles were affordable") }
            if s.finances.cash != cashBefore || s.finances.ledger.localization != ledgerBefore {
                note("a refused bulkLocalize still changed cash or the ledger")
            }
        }
    }

    private mutating func edit(_ s: inout GameState) {
        guard let t = choose(s.catalog) else { return }
        var strict: [String] = []
        for c in CountryData.all where CountryRules.isStrict(c.code) { strict.append(c.code) }
        guard let code = choose(strict) else { return }
        let price = s.editCost(t)
        let cashBefore = s.finances.cash
        let ledgerBefore = s.finances.ledger.localization
        do {
            try s.editForMarket(titleID: t.id, code: code)
            if let m = spendProblem("editForMarket", cashBefore: cashBefore, ledgerBefore: ledgerBefore,
                                    ledgerAfter: s.finances.ledger.localization, expected: price, after: s) { note(m) }
            if let now = s.catalog.first(where: { $0.id == t.id }), !now.cleared.contains(code) {
                note("editForMarket paid but did not clear \(code)")
            }
        } catch {
            if s.finances.cash != cashBefore { note("a refused editForMarket still changed cash") }
        }
    }

    private mutating func extend(_ s: inout GameState) {
        var regional: [Title] = []
        for t in s.catalog { if let l = t.license, !l.regions.isEmpty { regional.append(t) } }
        var pick = choose(regional)
        if pick == nil { pick = choose(s.catalog) }
        guard let t = pick else { return }
        let price = s.territoryExtensionPrice(t)
        let cashBefore = s.finances.cash
        let ledgerBefore = s.finances.ledger.licensing
        do {
            try s.extendTerritory(titleID: t.id)
            if let m = spendProblem("extendTerritory", cashBefore: cashBefore, ledgerBefore: ledgerBefore,
                                    ledgerAfter: s.finances.ledger.licensing, expected: price, after: s) { note(m) }
            if let now = s.catalog.first(where: { $0.id == t.id }), !(now.license?.regions.isEmpty ?? false) {
                note("extendTerritory did not make the rights worldwide")
            }
        } catch {
            if s.finances.cash != cashBefore { note("a refused extendTerritory still changed cash") }
        }
    }

    private mutating func remove(_ s: inout GameState) {
        guard let t = choose(s.catalog) else { return }
        do {
            try s.removeTitle(titleID: t.id)
            if s.catalog.contains(where: { $0.id == t.id }) { note("removeTitle left the title in the catalog") }
            if s.titleStats[t.id] != nil { note("removeTitle left titleStats behind") }
        } catch {
            note("removeTitle threw for a title that exists: \(error)")
        }
    }

    private mutating func signups(_ s: inout GameState) {
        var scopes: [String] = [GameState.allScope]
        for r in Region.allCases { scopes.append(r.rawValue) }
        guard let scope = choose(scopes) else { return }
        let paused = rng.chance(0.6)
        _ = try? s.setSignupsPaused(scope: scope, paused: paused)
        if s.pausedSignups.contains(scope) != paused { note("setSignupsPaused(\(scope), \(paused)) did not stick") }
        if Set(s.pausedSignups).count != s.pausedSignups.count { note("pausedSignups has duplicates") }
    }

    private mutating func deals(_ s: inout GameState) {
        if rng.chance(0.6) {
            let genre = Genre.allCases[rng.nextInt(in: 0...(Genre.allCases.count - 1))]
            _ = try? s.signOutputDeal(genre: genre)
        } else if let deal = choose(s.outputDeals) {
            _ = try? s.cancelOutputDeal(id: deal.id)
            if s.outputDeals.contains(where: { $0.id == deal.id }) { note("cancelOutputDeal left the deal in place") }
        }
        if s.outputDeals.count > GameState.maxOutputDeals { note("more than \(GameState.maxOutputDeals) output deals") }
    }

    private mutating func sports(_ s: inout GameState) {
        guard let offer = choose(s.sportsOffers) else { return }
        let premium = 1.0 + rng.nextDouble() * 0.6
        _ = try? s.bidForSports(offerID: offer.id, premium: premium)
    }

    private mutating func acquisitions(_ s: inout GameState) {
        guard let offer = choose(s.acquisitionOffers) else { return }
        let before = s.catalog.count
        let studiosBefore = s.studios.count
        do {
            try s.acceptAcquisition(id: offer.id)
            if offer.titleCount > 0, s.catalog.count != before + offer.titleCount {
                note("acquisition promised \(offer.titleCount) titles, catalog grew by \(s.catalog.count - before)")
            }
            if offer.titleCount == 0, s.studios.count != studiosBefore + 1 { note("studio acquisition added no studio") }
        } catch {
            // refusals (cash, studio cap) are fine
        }
    }

    private mutating func studios(_ s: inout GameState) {
        if rng.chance(0.5) {
            let genre = Genre.allCases[rng.nextInt(in: 0...(Genre.allCases.count - 1))]
            _ = try? s.foundStudio(specialty: genre)
        } else if let studio = choose(s.studios) {
            _ = try? s.upgradeStudio(id: studio.id)
        }
        if s.studios.count > Formulas.maxStudios { note("more studios than the cap") }
    }

    private mutating func titleDeals(_ s: inout GameState) {
        guard let t = choose(s.catalog) else { return }
        if rng.chance(0.5) {
            let terms = [13, 26, 52, 104]
            if let weeks = choose(terms) {
                let loanedBefore = s.loanedOut.count
                if (try? s.licenseOut(titleID: t.id, weeks: weeks)) != nil {
                    if s.loanedOut.count != loanedBefore + 1 { note("licenseOut did not record the loan") }
                    if s.catalog.contains(where: { $0.id == t.id }) { note("licensed-out title is still in the catalog") }
                }
            }
        } else {
            _ = try? s.buyOutRights(titleID: t.id)
        }
    }

    private mutating func renew(_ s: inout GameState) {
        guard let t = s.expiringTitles.first else { return }
        let years = rng.nextInt(in: 1...5)
        _ = try? s.renewLicense(titleID: t.id, years: years)
    }

    private mutating func listings(_ s: inout GameState) {
        if rng.chance(0.5) { _ = try? s.expandListings() } else if rng.chance(0.5) { _ = try? s.refreshListings() }
        if s.licenseMarket.count > s.listingTarget + 20 { note("licenseMarket has \(s.licenseMarket.count) listings, target \(s.listingTarget)") }
    }

    private mutating func launch(_ s: inout GameState) {
        var codes: [String] = []
        for c in CountryData.all where notLaunched(s, c.code) { codes.append(c.code) }
        guard let code = choose(codes) else { return }
        _ = try? s.launchMarket(code: code)
    }
}

// MARK: - Tests

final class BotContentTests: XCTestCase {
    private var failCount = 0

    private func report(_ tag: String, _ messages: [String]) {
        for m in messages {
            failCount += 1
            if failCount <= 40 { XCTFail("\(tag): \(m)") }
        }
    }

    private func newState(seed: UInt64 = 42) -> GameState {
        var s = GameState.newGame(startCountry: "IE", companyName: "Test Co", seed: seed)
        s.eventsEnabled = false
        s.finances.cash = 1e12
        return s
    }

    private func filler(_ id: Int) -> Title {
        Title(id: id, name: "Filler \(id)", kind: .movie, genre: .drama, language: .english, quality: 60,
              popularity: 50, ageWeeks: 10, isOriginal: true, license: nil, weeksRemaining: nil, listingWeeksLeft: 0)
    }

    /// Appends `count` generated, owned titles (with staggered expiry) to simulate a giant library.
    private func inject(_ s: inout GameState, count: Int) {
        var taken = Set<String>()
        for t in s.catalog { taken.insert(t.name) }
        for t in s.licenseMarket { taken.insert(t.name) }
        for p in s.projects { taken.insert(p.name) }
        for l in s.loanedOut { taken.insert(l.title.name) }
        for _ in 0..<count {
            let id = s.takeID()
            var t = TitleGenerator.generate(id: id, rng: &s.rng, avoiding: taken)
            taken.insert(t.name)
            if let lic = t.license {
                let forever = s.rng.chance(0.3)
                let left = s.rng.nextInt(in: 20...(lic.years * 52 + 100))
                t.weeksRemaining = forever ? nil : left
                t.paidPrice = lic.cost
                t.invested = lic.cost
            }
            t.listingWeeksLeft = 0
            t.embargoWeeks = 0
            t.popularityAtPurchase = t.popularity
            s.catalog.append(t)
        }
    }

    /// A rich game with five live markets and `titles` generated titles.
    private func bigState(titles: Int, seed: UInt64) -> GameState {
        var s = newState(seed: seed)
        for code in ["IE", "GB", "DE", "FR", "US"] {
            s.markets[code]?.status = .live
            s.markets[code]?.subs = TierSet(ad: 100_000, standard: 300_000, premium: 100_000)
            s.markets[code]?.awareness = 0.5
        }
        for r in Region.allCases { s.cloudUnits[r.rawValue] = 40 }
        inject(&s, count: titles)
        return s
    }

    // MARK: Invariants

    private func violations(_ s: GameState, prev: GameState) -> [String] {
        var v: [String] = []
        func finite(_ x: Double, _ what: String) { if !x.isFinite { v.append("non-finite \(what): \(x)") } }

        finite(s.finances.cash, "cash")
        finite(s.totalSubscribers, "totalSubscribers")
        if s.totalSubscribers < 0 { v.append("negative total subscribers") }
        for code in s.markets.keys.sorted() {
            guard let m = s.markets[code] else { continue }
            for tier in Tier.allCases {
                let x = m.subs[tier]
                if !x.isFinite || x < 0 { v.append("bad subscriber count \(x) in \(code) \(tier)") }
            }
            if !m.awareness.isFinite || m.awareness < 0 || m.awareness > 1 { v.append("awareness \(m.awareness) in \(code)") }
        }
        if let r = s.lastReport {
            finite(r.financials.profit, "weekly profit")
            finite(r.financials.revenue, "weekly revenue")
            finite(r.financials.costs, "weekly costs")
        }

        // Titles
        let loanedIDs = Set(s.loanedOut.map { $0.title.id })
        let validCodes = Set(CountryData.all.map { $0.code })
        var strict = Set<String>()
        for c in CountryData.all where CountryRules.isStrict(c.code) { strict.insert(c.code) }
        var prevByID: [Int: Title] = [:]
        for t in prev.catalog { prevByID[t.id] = t }
        var seen = Set<Int>()
        for t in s.catalog {
            let tag = "title \(t.id) \"\(t.name)\""
            if seen.contains(t.id) { v.append("duplicate catalog id \(t.id)") }
            seen.insert(t.id)
            if loanedIDs.contains(t.id) { v.append("\(tag) is both in the catalog and licensed out") }
            if Set(t.dubs).count != t.dubs.count { v.append("\(tag) has duplicate dubs") }
            if Set(t.subtitles).count != t.subtitles.count { v.append("\(tag) has duplicate subtitles") }
            if t.dubs.contains(t.language) { v.append("\(tag) is dubbed into its own language") }
            if t.subtitles.contains(t.language) { v.append("\(tag) is subtitled in its own language") }
            if Set(t.cleared).count != t.cleared.count { v.append("\(tag) has duplicate cleared countries") }
            for code in t.cleared where !strict.contains(code) { v.append("\(tag) cleared in non-strict \(code)") }
            if !t.cleared.isEmpty && !t.mature { v.append("\(tag) is cleared but not mature") }
            if t.quality < 0 || t.quality > 100 { v.append("\(tag) quality \(t.quality)") }
            if t.popularity < 0 || t.popularity > 100 { v.append("\(tag) popularity \(t.popularity)") }
            if t.ageWeeks < 0 { v.append("\(tag) negative age") }
            if t.seasons < 1 || t.seasons > 9 { v.append("\(tag) seasons \(t.seasons)") }
            if t.awards > 0 && !t.isOriginal { v.append("\(tag) has awards but is not an original") }
            if let left = t.weeksRemaining, left <= 0 { v.append("\(tag) expired (\(left) weeks) but is still in the catalog") }
            if t.isOriginal && t.license != nil { v.append("\(tag) is an original with a license") }
            if let l = t.license {
                if l.years < 1 || l.years > 5 { v.append("\(tag) license years \(l.years)") }
                if !l.cost.isFinite || l.cost < 0 { v.append("\(tag) license cost \(l.cost)") }
                if Set(l.regions).count != l.regions.count { v.append("\(tag) duplicate regions") }
                for code in l.regions where !validCodes.contains(code) { v.append("\(tag) unknown region code \(code)") }
            }
            if !t.paidPrice.isFinite || !t.invested.isFinite { v.append("\(tag) non-finite paidPrice/invested") }
            // Worldwide titles can only be blocked in the few banned/strict countries.
            if t.license?.regions.isEmpty ?? true {
                var anywhere = false
                for c in CountryData.all where t.isAvailable(in: c.code) { anywhere = true; break }
                if !anywhere { v.append("\(tag) is worldwide but available nowhere") }
            }
            if let p = prevByID[t.id] {
                if t.seasons < p.seasons { v.append("\(tag) seasons went down \(p.seasons) -> \(t.seasons)") }
                if t.awards < p.awards { v.append("\(tag) awards went down") }
            }
        }
        var marketNames = Set<String>()
        var marketIDs = Set<Int>()
        for t in s.licenseMarket {
            if marketNames.contains(t.name) { v.append("duplicate listing name \"\(t.name)\"") }
            marketNames.insert(t.name)
            if marketIDs.contains(t.id) { v.append("duplicate listing id \(t.id)") }
            marketIDs.insert(t.id)
            if seen.contains(t.id) { v.append("listing \(t.id) is also in the catalog") }
        }

        // Stats
        var credit = 0.0
        for id in s.titleStats.keys.sorted() {
            guard let st = s.titleStats[id] else { continue }
            if !seen.contains(id) && !loanedIDs.contains(id) { v.append("titleStats keeps an entry for title \(id) that left the catalog") }
            let values = [st.weeklyViewers, st.weeklyRevenue, st.peakViewers, st.totalViews, st.lifetimeRevenue,
                          st.licenseIncome, st.topMarketViewers]
            for x in values where !x.isFinite || x < 0 { v.append("titleStats[\(id)] has a bad number \(x)") }
            if st.peakViewers + 1e-6 < st.weeklyViewers { v.append("titleStats[\(id)] peak below this week's viewers") }
            if let p = prev.titleStats[id], seen.contains(id) {
                if st.lifetimeRevenue + 1e-6 < p.lifetimeRevenue { v.append("titleStats[\(id)] lifetime revenue went down") }
                if st.totalViews + 1e-6 < p.totalViews { v.append("titleStats[\(id)] total views went down") }
            }
            if seen.contains(id) { credit += st.weeklyRevenue }
        }
        if s.week == prev.week + 1, let r = s.lastReport {
            let revenue = r.financials.subscriptionRevenue + r.financials.adRevenue
            if credit > revenue * (1 + 1e-9) + 1e-6 {
                v.append("title revenue credits \(credit) exceed subscription+ad revenue \(revenue)")
            }
        }

        // Appeal must stay finite in every live market.
        for code in s.liveMarketCodes {
            guard let country = CountryData.country(code) else { continue }
            var bad = 0
            for t in s.catalog {
                let a = Formulas.titleAppeal(t, in: country)
                if !a.isFinite || a < 0 { bad += 1 }
            }
            if bad > 0 { v.append("\(bad) titles have non-finite or negative appeal in \(code)") }
            let ca = Formulas.catalogAppeal(s.catalog, in: country)
            if !ca.isFinite || ca < 0 || ca > 1 { v.append("catalog appeal \(ca) in \(code)") }
        }

        // Projects
        var projectIDs = Set<Int>()
        for p in s.projects {
            if projectIDs.contains(p.id) { v.append("duplicate project id \(p.id)") }
            projectIDs.insert(p.id)
            if seen.contains(p.id) || loanedIDs.contains(p.id) { v.append("project id \(p.id) collides with a title id") }
            if p.weeksLeft <= 0 { v.append("finished project \"\(p.name)\" (weeksLeft \(p.weeksLeft)) was not removed") }
            if p.weeksLeft > p.weeksTotal { v.append("project \"\(p.name)\" has more weeks left than total") }
            if !p.weeklyCost.isFinite || p.weeklyCost < 0 { v.append("project \"\(p.name)\" weekly cost \(p.weeklyCost)") }
        }
        for studio in s.studios where s.activeProjects(at: studio.id) > studio.slots {
            v.append("studio \(studio.name) runs more projects than slots")
        }

        // Outcome and scenario
        if s.score != 0 && s.outcome != .won { v.append("score \(s.score) without a win") }
        if s.outcome == .lost && s.lossReason == nil { v.append("lost without a reason") }
        if s.outcome == .won && s.lossReason != nil { v.append("won but has a loss reason") }
        if prev.outcome != .playing && s.outcome != prev.outcome { v.append("a finished game changed outcome") }
        if let d = s.scenario.deadline, s.scenario != .sandbox {
            if s.outcome == .playing && s.week - 1 >= d { v.append("\(s.scenario.title): still playing after the deadline (week \(s.week - 1) >= \(d))") }
            if s.outcome == .lost, let reason = s.lossReason,
               reason.hasPrefix("Time ran out") || reason.hasPrefix("Eight years"), s.week - 1 < d {
                v.append("\(s.scenario.title): lost on time before the deadline (week \(s.week - 1) < \(d))")
            }
        } else if let reason = s.lossReason, reason.hasPrefix("Time ran out") {
            v.append("sandbox lost on time")
        }
        if s.outcome == .won && s.scenario == .profitable {
            let streak = s.finances.profitHistory.suffix(8).allSatisfy { $0 > 0 }
            if !(s.totalSubscribers >= 500_000 && streak) {
                v.append("profitable scenario won without 500K subs and 8 profitable weeks")
            }
        }
        if s.outcome == .won && s.scenario == .tenMillion && s.totalSubscribers < 10_000_000 - 1 {
            v.append("tenMillion won with \(s.totalSubscribers) subscribers")
        }
        return v
    }

    /// Read-only helpers must not crash and must give each card a unique id (SwiftUI ForEach identity).
    private func readOnlyChecks(_ s: GameState, prev: GameState) -> [String] {
        var v: [String] = []
        func unique(_ items: [Advice], _ what: String) {
            let ids = items.map { $0.id }
            if Set(ids).count != ids.count { v.append("\(what) has duplicate ids: \(ids)") }
        }
        unique(s.advice(), "advice()")
        unique(s.recommendations(), "recommendations()")
        unique(s.diagnosis(), "diagnosis()")
        _ = s.costBreakdown()
        _ = s.losingMarkets()
        let reasons = PauseCheck.reasons(before: prev, after: s)
        let ids = reasons.map { $0.id }
        if Set(ids).count != ids.count { v.append("PauseCheck has duplicate reason ids") }
        for t in s.catalog.prefix(15) {
            let fit = s.marketFit(of: t)
            if !fit.isFinite || fit < 0 || fit > 1 { v.append("marketFit \(fit) for \(t.name)") }
        }
        for t in s.catalog.prefix(40) {
            let spec = PosterSpec.make(for: t)
            if spec != PosterSpec.make(for: t) { v.append("PosterSpec is not deterministic for \(t.name)") }
            if spec.seeds.count != 8 || spec.palette.count != 3 { v.append("PosterSpec shape for \(t.name)") }
            for x in spec.seeds where x < 0 || x >= 1 { v.append("PosterSpec seed \(x) out of range") }
            if spec.titleLines.count > 3 { v.append("PosterSpec has \(spec.titleLines.count) lines for \(t.name)") }
        }
        return v
    }

    // MARK: Driver

    @discardableResult
    private func run(_ cfg: BotConfig, weeks: Int, invariants: Bool) -> GameState {
        var s = GameState.newGame(startCountry: cfg.home, companyName: "Bot \(cfg.seed)", seed: cfg.seed,
                                  difficulty: cfg.difficulty, scenario: cfg.scenario)
        s.eventsEnabled = false
        s.renewalMode = cfg.seed % 2 == 0 ? .standard : .off
        var bot = ContentFuzzBot(seed: cfg.seed, rich: cfg.rich)
        for _ in 0..<weeks {
            guard s.outcome == .playing else { break }
            for inj in cfg.injections where inj.week == s.week { inject(&s, count: inj.count) }
            bot.play(&s)
            let tag = "seed \(cfg.seed) week \(s.week) \(cfg.scenario.rawValue)/\(cfg.difficulty.rawValue)"
            for p in bot.problems { report(tag, ["bot action: \(p)"]) }
            bot.problems.removeAll()
            let prev = s
            s = SimulationEngine.advanceWeek(s)
            guard invariants else { continue }
            report(tag, violations(s, prev: prev))
            if s.week % 10 == 0 { report(tag, readOnlyChecks(s, prev: prev)) }
            if s.week % 50 == 0 {
                do {
                    let data = try JSONEncoder().encode(s)
                    let back = try JSONDecoder().decode(GameState.self, from: data)
                    if back != s { report(tag, ["JSON round trip changed the state"]) }
                } catch {
                    report(tag, ["JSON round trip threw \(error)"])
                }
            }
        }
        if s.outcome != .playing {
            let again = SimulationEngine.advanceWeek(s)
            if again != s { report("seed \(cfg.seed)", ["advanceWeek changed a finished game"]) }
        }
        return s
    }

    private var configs: [BotConfig] {
        [
            BotConfig(seed: 11, home: "IE", scenario: .sandbox, difficulty: .medium, rich: true, injections: []),
            BotConfig(seed: 12, home: "US", scenario: .tenMillion, difficulty: .easy, rich: true, injections: []),
            BotConfig(seed: 13, home: "GB", scenario: .profitable, difficulty: .hard, rich: true, injections: []),
            BotConfig(seed: 14, home: "JP", scenario: .dethrone, difficulty: .medium, rich: true, injections: []),
            BotConfig(seed: 15, home: "DE", scenario: .sandbox, difficulty: .hard, rich: false, injections: []),
            BotConfig(seed: 16, home: "BR", scenario: .sandbox, difficulty: .easy, rich: true,
                      injections: [(week: 100, count: 500), (week: 250, count: 800)]),
            BotConfig(seed: 17, home: "IN", scenario: .profitable, difficulty: .easy, rich: false, injections: []),
            BotConfig(seed: 18, home: "FR", scenario: .tenMillion, difficulty: .medium, rich: false, injections: []),
        ]
    }

    // MARK: Fuzz runs

    func testBotPlaysEveryScenarioAndDifficultyForFiveHundredWeeks() {
        for cfg in configs { run(cfg, weeks: 500, invariants: true) }
        XCTAssertEqual(failCount, 0, "\(failCount) invariant violations (first 40 are listed above)")
    }

    func testBotRunsAreDeterministic() {
        let cfg = configs[0]
        let a = run(cfg, weeks: 150, invariants: false)
        let b = run(cfg, weeks: 150, invariants: false)
        XCTAssertTrue(a == b, "two identical bot runs (seed \(cfg.seed)) ended in different states")
        let cfg2 = configs[5]
        let c = run(cfg2, weeks: 120, invariants: false)
        let d = run(cfg2, weeks: 120, invariants: false)
        XCTAssertTrue(c == d, "two identical bot runs with injected catalogs (seed \(cfg2.seed)) ended in different states")
    }

    // MARK: Giant catalogs

    func testFiveThousandTitleCatalogWeeksFinishInTime() {
        var s = bigState(titles: 5_000, seed: 77)
        XCTAssertGreaterThanOrEqual(s.catalog.count, 5_000)
        let start = Date()
        for _ in 0..<20 { s = SimulationEngine.advanceWeek(s) }
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertLessThan(elapsed, 20.0, "20 weeks at 5,000 titles took \(elapsed)s (generous bound 20s)")
        XCTAssertTrue(s.totalSubscribers.isFinite)
        XCTAssertTrue(s.finances.cash.isFinite)
    }

    func testEightThousandTitleCatalogStaysCorrectAndFinite() {
        var s = bigState(titles: 8_000, seed: 78)
        var bot = ContentFuzzBot(seed: 78, rich: true)
        for _ in 0..<6 {
            bot.play(&s)
            for p in bot.problems { report("8000 titles week \(s.week)", ["bot action: \(p)"]) }
            bot.problems.removeAll()
            let prev = s
            s = SimulationEngine.advanceWeek(s)
            report("8000 titles week \(s.week)", violations(s, prev: prev))
        }
        report("8000 titles", readOnlyChecks(s, prev: s))
        // Price brake: a giant library makes new licenses much dearer.
        XCTAssertGreaterThan(s.catalogSizePriceFactor, 5.0)
        // On-demand actions at this size must also finish.
        let start = Date()
        _ = try? s.refreshListings()
        for _ in 0..<GameState.maxListingReach { _ = try? s.expandListings() }
        _ = try? s.bulkLocalize(code: "DE", dub: false)
        _ = try? s.bulkLocalize(code: "JP", dub: true, limit: 20)
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertLessThan(elapsed, 30.0, "listing and localization actions at 8,000 titles took \(elapsed)s")
        XCTAssertEqual(failCount, 0)
    }

    // MARK: Generators

    func testTitleGeneratorContract() {
        var rng = SeededRNG(seed: 4242)
        var taken = Set<String>()
        var bad: [String] = []
        let valid = Set(CountryData.all.map { $0.code })
        for i in 0..<4_000 {
            let t = TitleGenerator.generate(id: i, rng: &rng, avoiding: taken)
            if t.name.isEmpty { bad.append("#\(i) empty name") }
            if taken.contains(t.name) { bad.append("#\(i) duplicate of an avoided name: \(t.name)") }
            taken.insert(t.name)
            guard let l = t.license else { bad.append("#\(i) \(t.name) has no license"); continue }
            if l.years < 1 || l.years > 5 { bad.append("#\(i) years \(l.years)") }
            if !l.cost.isFinite || l.cost <= 0 { bad.append("#\(i) cost \(l.cost)") }
            if Set(l.regions).count != l.regions.count { bad.append("#\(i) duplicate regions") }
            for code in l.regions where !valid.contains(code) { bad.append("#\(i) bad region \(code)") }
            if t.quality < 0 || t.quality > 100 || t.popularity < 0 || t.popularity > 100 { bad.append("#\(i) quality/popularity out of range") }
            if t.listingWeeksLeft < 4 { bad.append("#\(i) listing lasts \(t.listingWeeksLeft) weeks") }
            if t.embargoWeeks < 0 || t.embargoWeeks > 6 { bad.append("#\(i) embargo \(t.embargoWeeks)") }
            if t.isOriginal || t.weeksRemaining != nil { bad.append("#\(i) a fresh listing must not be owned") }
            if !t.subtitles.isEmpty || !t.dubs.isEmpty || !t.cleared.isEmpty { bad.append("#\(i) a fresh listing is already localized") }
        }
        XCTAssertTrue(bad.isEmpty, bad.prefix(10).joined(separator: "; "))
    }

    func testParodyLibraryNamesAreUniqueAndConsistent() {
        let all = ParodyLibrary.all
        let lowered = all.map { $0.name.lowercased() }
        XCTAssertEqual(Set(lowered).count, lowered.count, "ParodyLibrary.all names must be unique (case-insensitive)")
        for g in Genre.allCases {
            for p in ParodyLibrary.byGenre[g] ?? [] where p.genre != g { XCTFail("\(p.name) is filed under \(g) but says \(p.genre)") }
        }
        let names = Set(all.map { $0.name })
        for n in ParodyLibrary.iconicNames { XCTAssertTrue(names.contains(n), "iconic title \(n) is not in the library") }
    }

    func testPosterSpecIsDeterministicAndWrapsSafely() {
        var rng = SeededRNG(seed: 5)
        for i in 0..<300 {
            let t = TitleGenerator.generate(id: i, rng: &rng)
            let a = PosterSpec.make(for: t), b = PosterSpec.make(for: t)
            XCTAssertEqual(a, b)
            XCTAssertLessThanOrEqual(a.titleLines.count, 3)
            XCTAssertEqual(a.titleLines.joined().replacingOccurrences(of: " ", with: ""),
                           t.name.replacingOccurrences(of: " ", with: ""))
        }
        XCTAssertEqual(PosterSpec.wrap(""), [])
        XCTAssertLessThanOrEqual(PosterSpec.wrap("A B C D E F G H I J K L M N O P Q R S T").count, 3)
    }

    // MARK: Suspected bugs (these tests are EXPECTED TO FAIL on the current code)

    /// BUG (LOW/MEDIUM) OriginalsAndFunding.swift:80 + SimulationEngine.swift:516: finishing a movie sequel writes
    /// `s.catalog[pi].seasons = title.seasons`, so the PARENT movie now also says "2 seasons" and can be continued
    /// again, and so can the sequel. Both orders compute the same next number and produce two "X III" titles.
    func testBug_movieSequelsCollideOnName() throws {
        var s = newState(seed: 5)
        let m = Title(id: s.takeID(), name: "Moon Heist", kind: .movie, genre: .action, language: .english, quality: 70,
                      popularity: 70, ageWeeks: 0, isOriginal: true, license: nil, weeksRemaining: nil, listingWeeksLeft: 0)
        s.catalog = [m]
        try s.orderSeason(titleID: m.id, budget: 5_000_000, weeks: 6)
        for _ in 0..<7 { s = SimulationEngine.advanceWeek(s) }
        XCTAssertTrue(s.projects.isEmpty, "the sequel should be finished")
        let sequel = try XCTUnwrap(s.catalog.first { $0.name == "Moon Heist II" })
        try s.orderSeason(titleID: m.id, budget: 5_000_000, weeks: 6)
        try s.orderSeason(titleID: sequel.id, budget: 5_000_000, weeks: 6)
        let names = s.projects.map { $0.name }
        XCTAssertEqual(Set(names).count, names.count, "two sequel projects share a name: \(names)")
    }

    /// BUG (LOW) OriginalsAndFunding.swift:105-114: localizeTitle lets you pay for subtitles in a language the title
    /// is already dubbed in, although bulkLocalize (BulkLocalize.swift:14) treats a dub as covering the subtitles and
    /// Formulas.languageMatch ignores the subtitles when a dub exists (so the money buys nothing).
    func testBug_subtitlesAfterDubAreAccepted() throws {
        var s = newState()
        let t = filler(7_001)
        s.catalog = [t]
        try s.localizeTitle(titleID: t.id, language: .german, dub: true)
        var threw = false
        do { try s.localizeTitle(titleID: t.id, language: .german, dub: false) } catch { threw = true }
        XCTAssertTrue(threw, "paying for German subtitles on a title already dubbed in German should be refused")
    }

    /// BUG (LOW) TitleGenerator.swift:57-64 (pickParody): when the base name and all nine roman-numeral variants are
    /// already avoided, it returns `base` anyway, an avoided (duplicate) name, instead of widening or failing.
    func testBug_pickParodyReturnsAnAvoidedNameWhenSuffixesRunOut() {
        let pool = ParodyLibrary.byGenre[.local] ?? []
        XCTAssertFalse(pool.isEmpty)
        var avoid = Set<String>()
        for p in pool {
            avoid.insert(p.name)
            for suffix in ["II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"] { avoid.insert("\(p.name) \(suffix)") }
        }
        var rng = SeededRNG(seed: 99)
        let pick = TitleGenerator.pickParody(genre: .local, rng: &rng, avoiding: avoid)
        XCTAssertFalse(avoid.contains(pick.name), "pickParody returned \"\(pick.name)\" although it is in the avoid set")
    }

    /// BUG (MEDIUM) CEOActions.swift:~105 (runOutputDeals): the delivered title is generated from a random genre's
    /// parody (name, kind, language) and then only `title.genre` is overwritten, so a "Docs" output deal delivers
    /// titles named after dramas, comedies and so on (and with their `mature` roll for the wrong genre).
    func testBug_outputDealTitlesAreNamedForTheWrongGenre() throws {
        var s = newState()
        try s.signOutputDeal(genre: .docs)
        for _ in 0..<60 { s = SimulationEngine.advanceWeek(s) }
        XCTAssertFalse(s.catalog.isEmpty, "the deal should have delivered titles")
        let docsNames = (ParodyLibrary.byGenre[.docs] ?? []).map { $0.name }
        var mismatched: [String] = []
        for t in s.catalog where !docsNames.contains(where: { t.name.hasPrefix($0) }) { mismatched.append(t.name) }
        XCTAssertTrue(mismatched.isEmpty, "docs deal delivered non-docs parodies: \(mismatched)")
    }

    /// BUG (LOW, UI) SimulationEngine.swift:421-425: every expired license makes its own "License expired" event and
    /// PauseCheck.swift:56 turns each into its own pause reason. A curator/auto-renew batch bought together expires
    /// together, so hundreds of cards can appear at once (the pause panel is unbounded).
    func testBug_expiredLicensesFloodThePausePanel() {
        var s = newState()
        var list: [Title] = []
        for i in 0..<40 {
            var t = filler(9_000 + i)
            t.isOriginal = false
            t.license = LicenseTerms(cost: 100_000, years: 1, regions: [], exclusive: false)
            t.weeksRemaining = 1
            list.append(t)
        }
        s.catalog = list
        let next = SimulationEngine.advanceWeek(s)
        XCTAssertTrue(next.catalog.isEmpty, "all 40 licenses should have expired")
        let expired = PauseCheck.reasons(before: s, after: next).filter { $0.id.hasPrefix("expired-") }
        XCTAssertLessThanOrEqual(expired.count, 3, "\(expired.count) separate 'license expired' pause reasons for one week")
    }

    /// BUG (LOW, debatable) Restrictions.swift:34-37: territoryExtensionPrice ignores `catalogSizePriceFactor` and the
    /// content-staff discount that `licensePrice` applies, so at a 4,000-title library (x9 licensing prices) widening
    /// rights costs the same as in a tiny library: a loophole for buying cheap regional rights then extending them.
    func testBug_territoryExtensionIgnoresTheCatalogSizePrice() {
        var s = newState()
        var regional = filler(8_000)
        regional.isOriginal = false
        regional.license = LicenseTerms(cost: 1_000_000, years: 3, regions: ["IE", "GB"], exclusive: false)
        regional.weeksRemaining = 100
        s.catalog = [regional]
        let small = s.territoryExtensionPrice(regional)
        var big = [regional]
        for i in 0..<4_000 { big.append(filler(8_001 + i)) }
        s.catalog = big
        let large = s.territoryExtensionPrice(regional)
        XCTAssertGreaterThan(large, small * 2, "extension price \(large) at 4,000 titles vs \(small) at 1 title (licensePrice is x\(s.catalogSizePriceFactor))")
    }
}
