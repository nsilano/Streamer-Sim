import Foundation

extension GameState {
    /// Cost of a local edit that lets a mature title play in strict countries.
    func editCost(_ title: Title) -> Double {
        (title.kind == .movie ? 120_000.0 : 320_000.0)
            * Formulas.licenseAudienceScale(totalSubscribers: totalSubscribers) * costScale
    }

    mutating func editForMarket(titleID: Int, code: String) throws {
        guard outcome == .playing else { throw ActionError.gameOver }
        guard let index = catalog.firstIndex(where: { $0.id == titleID }) else { throw ActionError.titleNotFound }
        guard catalog[index].mature, CountryRules.isStrict(code) else {
            throw ActionError.invalidProject("That title doesn't need an edit there.")
        }
        guard !CountryRules.bannedGenres(code).contains(catalog[index].genre) else {
            throw ActionError.invalidProject("That genre is banned there; no edit can fix it.")
        }
        guard !catalog[index].cleared.contains(code) else { throw ActionError.invalidProject("Already edited for that market.") }
        let price = editCost(catalog[index])
        guard finances.cash >= price else { throw ActionError.insufficientFunds(needed: price) }
        finances.cash -= price
        finances.ledger.localization += price
        catalog[index].cleared.append(code)
        catalog[index].invested += price
    }

    /// What it costs to extend a regional license to the whole world for the rest of its term.
    func territoryExtensionPrice(_ title: Title) -> Double {
        guard let license = title.license, !license.regions.isEmpty else { return 0 }
        let share = Double(license.regions.count) / Double(CountryData.all.count)
        let worldwide = license.cost / Formulas.territoryPriceFactor(share: share)
        let remaining = Double(title.weeksRemaining ?? license.weeks) / Double(max(1, license.weeks))
        return (worldwide - license.cost) * Formulas.licenseAudienceScale(totalSubscribers: totalSubscribers)
            * costScale * min(1, max(0.3, remaining))
    }

    mutating func extendTerritory(titleID: Int) throws {
        guard outcome == .playing else { throw ActionError.gameOver }
        guard let index = catalog.firstIndex(where: { $0.id == titleID }), let license = catalog[index].license else {
            throw ActionError.titleNotFound
        }
        guard !license.regions.isEmpty else { throw ActionError.invalidProject("You already hold worldwide rights.") }
        let price = territoryExtensionPrice(catalog[index])
        guard finances.cash >= price else { throw ActionError.insufficientFunds(needed: price) }
        let share = Double(license.regions.count) / Double(CountryData.all.count)
        finances.cash -= price
        finances.ledger.licensing += price
        catalog[index].license?.cost = license.cost / Formulas.territoryPriceFactor(share: share)
        catalog[index].license?.regions = []
        catalog[index].paidPrice += price
        catalog[index].invested += price
        addNews(.you, "\(companyName) extends \"\(catalog[index].name)\" worldwide", "Territory rights added for \(Format.money(price)).")
    }
}
