import Foundation

/// Localize many titles for one market in a single tap.
extension GameState {
    /// Titles that would benefit from subtitles (or dubbing) in a country's language, best fit first.
    /// Skips titles already in that language or already localized at that level (a dub counts as subtitled).
    func localizationTargets(code: String, dub: Bool, limit: Int? = nil) -> [Title] {
        guard let country = CountryData.country(code) else { return [] }
        let language = country.language
        let needing = catalog.filter { title in
            guard title.language != language, title.inTerritory(code), title.blockReason(in: code) == nil else { return false }
            if dub { return !title.dubs.contains(language) }
            return !title.dubs.contains(language) && !title.subtitles.contains(language)
        }
        let ranked = needing.sorted {
            let a = Formulas.titleAppeal($0, in: country), b = Formulas.titleAppeal($1, in: country)
            return a != b ? a > b : $0.id < $1.id
        }
        return limit.map { Array(ranked.prefix(max(0, $0))) } ?? ranked
    }

    func bulkLocalizePrice(code: String, dub: Bool, limit: Int? = nil) -> Double {
        localizationTargets(code: code, dub: dub, limit: limit).reduce(0) { $0 + localizationPrice(kind: $1.kind, dub: dub) }
    }

    /// Subtitles or dubs every target in one go (or only `only`, if given). Returns how many titles were localized.
    @discardableResult
    mutating func bulkLocalize(code: String, dub: Bool, limit: Int? = nil, only: Set<Int>? = nil) throws -> Int {
        guard outcome == .playing else { throw ActionError.gameOver }
        guard let country = CountryData.country(code) else { throw ActionError.countryNotFound }
        var targets = localizationTargets(code: code, dub: dub, limit: limit)
        if let only { targets = targets.filter { only.contains($0.id) } }
        guard !targets.isEmpty else { throw ActionError.invalidProject("Nothing left to \(dub ? "dub" : "subtitle") in \(country.language.displayName).") }
        let price = targets.reduce(0) { $0 + localizationPrice(kind: $1.kind, dub: dub) }
        guard finances.cash >= price else { throw ActionError.insufficientFunds(needed: price) }
        finances.cash -= price
        finances.ledger.localization += price
        let ids = Set(targets.map(\.id))
        for i in catalog.indices where ids.contains(catalog[i].id) {
            if dub { catalog[i].dubs.append(country.language) } else { catalog[i].subtitles.append(country.language) }
        }
        addNews(.you, "\(companyName) \(dub ? "dubs" : "subtitles") \(targets.count) titles in \(country.language.displayName)",
                "\(country.flag) A \(Format.money(price)) push to win viewers in \(country.name).")
        return targets.count
    }
}
