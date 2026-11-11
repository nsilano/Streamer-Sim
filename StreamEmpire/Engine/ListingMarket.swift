import Foundation

/// Refreshing the licensing market on demand and permanently widening how many offers you see.
extension GameState {
    static let maxListingReach = 8
    static let listingsPerReachLevel = 10

    /// How many listings the market holds for you.
    var listingTarget: Int { GameState.targetListings + GameState.listingsPerReachLevel * listingReach }

    /// Cost to replace today's listings with a fresh batch.
    func refreshListingsPrice() -> Double {
        scaled(150_000) * min(5, max(1, Formulas.licenseAudienceScale(totalSubscribers: totalSubscribers).squareRoot()))
    }

    /// Cost of the next expansion level (more listings, permanently).
    func expandListingsPrice() -> Double { scaled(1_000_000 * Double(listingReach + 1) * Double(listingReach + 1)) }

    /// Swap every listing for new ones. Listings you were negotiating disappear too.
    mutating func refreshListings() throws {
        guard outcome == .playing else { throw ActionError.gameOver }
        let price = refreshListingsPrice()
        guard finances.cash >= price else { throw ActionError.insufficientFunds(needed: price) }
        finances.cash -= price
        finances.ledger.licensing += price
        licenseMarket.removeAll()
        fillListings(limit: Int.max)
    }

    mutating func expandListings() throws {
        guard outcome == .playing else { throw ActionError.gameOver }
        guard listingReach < GameState.maxListingReach else { throw ActionError.invalidProject("Your scouts already cover the whole market.") }
        let price = expandListingsPrice()
        guard finances.cash >= price else { throw ActionError.insufficientFunds(needed: price) }
        finances.cash -= price
        finances.ledger.other += price
        listingReach += 1
        fillListings(limit: Int.max)
        addNews(.you, "\(companyName) widens its content scouting", "\(listingTarget) titles on offer at any time.")
    }

    /// Tops the market up to the target, adding at most `limit` titles.
    mutating func fillListings(limit: Int) {
        var added = 0
        while licenseMarket.count < listingTarget && added < limit {
            let taken = Set(licenseMarket.map(\.name) + catalog.map(\.name) + projects.map(\.name) + loanedOut.map(\.title.name))
            licenseMarket.append(TitleGenerator.generate(id: takeID(), rng: &rng, avoiding: taken))
            added += 1
        }
    }
}
