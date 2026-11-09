import Foundation

enum ActionError: Error, LocalizedError, Equatable {
    case gameOver
    case insufficientFunds(needed: Double)
    case titleNotFound
    case countryNotFound
    case alreadyLaunched
    case locked(String)
    case invalidPrice

    var errorDescription: String? {
        switch self {
        case .gameOver: return "The game is over."
        case .insufficientFunds(let needed): return "Not enough cash. You need \(Format.money(needed))."
        case .titleNotFound: return "That title is no longer available."
        case .countryNotFound: return "Unknown country."
        case .alreadyLaunched: return "You have already launched in that country."
        case .locked(let reason): return reason
        case .invalidPrice: return "Prices must be between $0 and $100."
        }
    }
}

/// Player decisions. All pure state changes, usable from tests and UI alike.
extension GameState {
    /// Why a market can't be launched yet (nil if the unlock requirement is met or there is none).
    func launchBlocker(code: String) -> String? {
        guard let country = CountryData.country(code), let unlock = country.unlock else { return nil }
        if totalSubscribers >= unlock.minGlobalSubs || catalog.count >= unlock.minCatalogSize { return nil }
        return "\(country.name) unlocks at \(Format.count(unlock.minGlobalSubs)) global subscribers or \(unlock.minCatalogSize) titles in your catalog."
    }

    mutating func buyLicense(titleID: Int) throws {
        guard outcome == .playing else { throw ActionError.gameOver }
        guard let index = licenseMarket.firstIndex(where: { $0.id == titleID }),
              let license = licenseMarket[index].license else { throw ActionError.titleNotFound }
        guard finances.cash >= license.cost else {
            throw ActionError.insufficientFunds(needed: license.cost)
        }
        var title = licenseMarket.remove(at: index)
        title.weeksRemaining = license.weeks
        title.listingWeeksLeft = 0
        finances.cash -= license.cost
        finances.ledger.licensing += license.cost
        catalog.append(title)
    }

    mutating func launchMarket(code: String) throws {
        guard outcome == .playing else { throw ActionError.gameOver }
        guard let country = CountryData.country(code), let market = markets[code] else {
            throw ActionError.countryNotFound
        }
        guard market.status == .notLaunched else { throw ActionError.alreadyLaunched }
        if let reason = launchBlocker(code: code) { throw ActionError.locked(reason) }
        guard finances.cash >= country.launchCost else {
            throw ActionError.insufficientFunds(needed: country.launchCost)
        }
        finances.cash -= country.launchCost
        finances.ledger.launch += country.launchCost
        markets[code]?.status = .launching(weeksLeft: 4)
    }

    mutating func setPrices(code: String, prices: TierSet) throws {
        guard markets[code] != nil else { throw ActionError.countryNotFound }
        for tier in Tier.allCases where prices[tier] < 0 || prices[tier] > 100 {
            throw ActionError.invalidPrice
        }
        markets[code]?.prices = prices
    }

    mutating func setMarketing(code: String, weeklyBudget: Double) throws {
        guard markets[code] != nil else { throw ActionError.countryNotFound }
        markets[code]?.marketingBudget = max(0, weeklyBudget)
    }
}
