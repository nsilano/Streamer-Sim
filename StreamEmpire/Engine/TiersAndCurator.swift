import Foundation

/// Tier launches, the licensing manager, and playthrough restarts.
extension GameState {
    // MARK: Tiers

    func tierLaunchPrice(_ tier: Tier, code: String) -> Double? {
        guard let country = CountryData.country(code) else { return nil }
        return Formulas.tierLaunchCost(tier, in: country)
    }

    mutating func launchTier(_ tier: Tier, code: String) throws {
        guard outcome == .playing else { throw ActionError.gameOver }
        guard let market = markets[code], market.isLive, let country = CountryData.country(code) else {
            throw ActionError.invalidProject("Launch the market before adding tiers.")
        }
        guard !market.liveTiers.contains(tier), !market.tierBuilds.contains(where: { $0.tier == tier }) else {
            throw ActionError.invalidProject("\(tier.displayName) is already live or being set up in \(country.name).")
        }
        let cost = Formulas.tierLaunchCost(tier, in: country)
        guard finances.cash >= cost else { throw ActionError.insufficientFunds(needed: cost) }
        finances.cash -= cost
        finances.ledger.launch += cost
        markets[code]?.tierBuilds.append(TierBuild(tier: tier, weeksLeft: Formulas.tierLaunchWeeks(tier)))
    }

    // MARK: Licensing manager

    mutating func hireCurator() throws {
        guard outcome == .playing else { throw ActionError.gameOver }
        guard curator == nil else { throw ActionError.invalidProject("You already have a licensing manager.") }
        guard finances.cash >= Curator.hireCost else { throw ActionError.insufficientFunds(needed: Curator.hireCost) }
        finances.cash -= Curator.hireCost
        finances.ledger.other += Curator.hireCost
        curator = Curator()
    }

    mutating func fireCurator() { curator = nil }

    mutating func updateCurator(_ new: Curator) throws {
        guard curator != nil else { throw ActionError.invalidProject("Hire a licensing manager first.") }
        guard new.weeklyBudget >= 0, new.maxPricePerTitle >= 0, new.cashReserve >= 0,
              (0...100).contains(new.minQuality), new.targetCatalogSize >= 0, (1...5).contains(new.maxYears) else {
            throw ActionError.invalidAmount
        }
        curator = new
    }

    // MARK: Restarting a playthrough

    var startSeed: UInt64 { UInt64(startSeedText) ?? 1 }

    /// A fresh game in the same country and company. `sameWorld` replays the exact same seed.
    func restarted(sameWorld: Bool, newSeed: UInt64) -> GameState {
        GameState.newGame(startCountry: startCountry.isEmpty ? (liveMarketCodes.first ?? "IE") : startCountry,
                          companyName: companyName, seed: sameWorld ? startSeed : newSeed)
    }
}
