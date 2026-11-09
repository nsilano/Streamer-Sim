import Foundation

enum ActionError: Error, LocalizedError, Equatable {
    case gameOver
    case insufficientFunds(needed: Double)
    case titleNotFound
    case countryNotFound
    case alreadyLaunched
    case locked(String)
    case invalidPrice
    case invalidAmount
    case invalidProject(String)
    case noPendingEvent
    case unknownChoice
    case decisionPending

    var errorDescription: String? {
        switch self {
        case .gameOver: return "The game is over."
        case .insufficientFunds(let needed): return "Not enough cash. You need \(Format.money(needed))."
        case .titleNotFound: return "That title is no longer available."
        case .countryNotFound: return "Unknown country."
        case .alreadyLaunched: return "You have already launched in that country."
        case .locked(let reason): return reason
        case .invalidPrice: return "Prices must be between $0 and $100."
        case .invalidAmount: return "That amount isn't allowed."
        case .invalidProject(let reason): return reason
        case .noPendingEvent: return "There is no decision to make."
        case .unknownChoice: return "That isn't one of the options."
        case .decisionPending: return "Make your decision first."
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
        let price = licensePrice(licenseMarket[index])
        guard finances.cash >= price else {
            throw ActionError.insufficientFunds(needed: price)
        }
        var title = licenseMarket.remove(at: index)
        title.weeksRemaining = license.weeks
        title.listingWeeksLeft = 0
        title.paidPrice = price
        title.invested = price
        title.popularityAtPurchase = title.popularity
        finances.cash -= price
        finances.ledger.licensing += price
        catalog.append(title)
        if price >= 1_000_000 || title.quality >= 85 {
            addNews(.you, "\(companyName) licenses \"\(title.name)\"",
                    "A \(title.quality)-quality \(title.genre.displayName.lowercased()) \(title.kind.displayName.lowercased()) for \(Format.money(price)), a \(license.years)-year deal.")
        }
    }

    mutating func launchMarket(code: String) throws {
        guard outcome == .playing else { throw ActionError.gameOver }
        guard let country = CountryData.country(code), let market = markets[code] else {
            throw ActionError.countryNotFound
        }
        guard market.status == .notLaunched else { throw ActionError.alreadyLaunched }
        if let reason = launchBlocker(code: code) { throw ActionError.locked(reason) }
        let price = launchPrice(country)
        guard finances.cash >= price else {
            throw ActionError.insufficientFunds(needed: price)
        }
        finances.cash -= price
        finances.ledger.launch += price
        markets[code]?.status = .launching(weeksLeft: 4)
        addNews(.you, "\(companyName) begins launching in \(country.name)",
                "\(country.flag) Setup takes 4 weeks and costs \(Format.money(price)). Subscribers can join once it's live.")
    }

    mutating func setPrices(code: String, prices: TierSet) throws {
        guard markets[code] != nil else { throw ActionError.countryNotFound }
        for tier in Tier.allCases where prices[tier] < 0 || prices[tier] > 100 {
            throw ActionError.invalidPrice
        }
        changePrices(code: code, to: prices)
    }

    /// Changes a country's prices and remembers where they started this week, so the news can report the net change.
    mutating func changePrices(code: String, to new: TierSet) {
        guard let market = markets[code] else { return }
        if market.prices != new, pendingPriceChanges[code] == nil { pendingPriceChanges[code] = market.prices }
        markets[code]?.prices = new
    }

    mutating func setMarketing(code: String, weeklyBudget: Double) throws {
        guard markets[code] != nil else { throw ActionError.countryNotFound }
        markets[code]?.marketingBudget = max(0, weeklyBudget)
    }
}

extension GameState {
    mutating func resolveEvent(choiceID: String) throws {
        try RandomEvents.resolve(&self, choiceID: choiceID)
    }
}
