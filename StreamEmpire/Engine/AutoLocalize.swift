import Foundation

extension GameState {
    /// Live markets, biggest first, one per language (a language only needs doing once).
    private var localizationMarkets: [String] {
        var seen = Set<Language>()
        var out: [String] = []
        let codes = liveMarketCodes.sorted {
            let a = markets[$0]?.subs.total ?? 0, b = markets[$1]?.subs.total ?? 0
            return a != b ? a > b : $0 < $1
        }
        for code in codes {
            guard let language = CountryData.country(code)?.language, seen.insert(language).inserted else { continue }
            out.append(code)
        }
        return out
    }

    /// Weekly: subtitles and dubs the catalog per your plan, until the weekly budget is used up.
    mutating func runAutoLocalization() {
        guard outcome == .playing, localization.subtitles != .off || localization.dubs != .off, !catalog.isEmpty else { return }
        var budget = localization.weeklyBudget
        let reserve = 4 * max(finances.lastWeek.costs, 100_000)
        var subbed = 0, dubbed = 0, spent = 0.0

        for code in localizationMarkets {
            guard let language = CountryData.country(code)?.language else { continue }
            if localization.dubs != .off {
                var targets = localizationTargets(code: code, dub: true)
                if localization.dubs == .top {
                    let alreadyDubbed = catalog.filter { $0.dubs.contains(language) }.count
                    targets = Array(targets.prefix(max(0, localization.topCount - alreadyDubbed)))
                }
                let index = Dictionary(catalog.indices.map { (catalog[$0].id, $0) }, uniquingKeysWith: { first, _ in first })
                for title in targets {
                    let price = localizationPrice(kind: title.kind, dub: true)
                    guard payLocalization(price, budget: &budget, reserve: reserve), let i = index[title.id] else { break }
                    catalog[i].dubs.append(language)
                    spent += price
                    dubbed += 1
                }
            }
            if localization.subtitles == .all {
                for i in catalog.indices {
                    let t = catalog[i]
                    guard t.language != language, !t.dubs.contains(language), !t.subtitles.contains(language) else { continue }
                    let price = localizationPrice(kind: t.kind, dub: false)
                    guard payLocalization(price, budget: &budget, reserve: reserve) else { break }
                    catalog[i].subtitles.append(language)
                    spent += price
                    subbed += 1
                }
            }
        }
        if subbed + dubbed > 0 {
            localizationStatus = "Week \(week): subtitled \(subbed) and dubbed \(dubbed) titles for \(Format.money(spent))."
        }
    }

    private mutating func payLocalization(_ price: Double, budget: inout Double, reserve: Double) -> Bool {
        guard price <= budget, finances.cash - price >= reserve else { return false }
        budget -= price
        finances.cash -= price
        finances.ledger.localization += price
        return true
    }

    // MARK: Do it now

    /// Cost of subtitling (or dubbing) everything missing in every language you operate in.
    func localizeAllPrice(dub: Bool, limit: Int? = nil) -> Double {
        localizationMarkets.reduce(0) { $0 + bulkLocalizePrice(code: $1, dub: dub, limit: limit) }
    }

    func localizeAllCount(dub: Bool, limit: Int? = nil) -> Int {
        localizationMarkets.reduce(0) { $0 + localizationTargets(code: $1, dub: dub, limit: limit).count }
    }

    /// One tap for the whole world: every language of every live market. Returns how many title-language jobs were done.
    @discardableResult
    mutating func localizeAll(dub: Bool, limit: Int? = nil) throws -> Int {
        guard outcome == .playing else { throw ActionError.gameOver }
        let price = localizeAllPrice(dub: dub, limit: limit)
        guard localizeAllCount(dub: dub, limit: limit) > 0 else {
            throw ActionError.invalidProject("Nothing left to \(dub ? "dub" : "subtitle") for the markets you operate in.")
        }
        guard finances.cash >= price else { throw ActionError.insufficientFunds(needed: price) }
        var total = 0
        for code in localizationMarkets {
            total += (try? bulkLocalize(code: code, dub: dub, limit: limit)) ?? 0
        }
        return total
    }

    /// Per language of your live markets: how many titles are subtitled or dubbed.
    func localizationCoverage() -> [(language: Language, flag: String, subtitled: Int, dubbed: Int, needed: Int)] {
        localizationMarkets.compactMap { code in
            guard let country = CountryData.country(code) else { return nil }
            let language = country.language
            let foreign = catalog.filter { $0.language != language }
            return (language, country.flag,
                    foreign.filter { $0.subtitles.contains(language) || $0.dubs.contains(language) }.count,
                    foreign.filter { $0.dubs.contains(language) }.count, foreign.count)
        }
    }
}
