import Foundation

/// In-house studios, pay settings and the global price tool.
extension GameState {
    // MARK: Studios

    mutating func foundStudio(specialty: Genre) throws {
        guard outcome == .playing else { throw ActionError.gameOver }
        guard studios.count < Formulas.maxStudios else {
            throw ActionError.invalidProject("You can run at most \(Formulas.maxStudios) studios.")
        }
        guard finances.cash >= Formulas.studioFoundingCost else {
            throw ActionError.insufficientFunds(needed: Formulas.studioFoundingCost)
        }
        finances.cash -= Formulas.studioFoundingCost
        finances.ledger.other += Formulas.studioFoundingCost
        let id = takeID()
        let name = StudioNames.make(rng: &rng)
        studios.append(Studio(id: id, name: name, specialty: specialty, level: 1, experience: 0, foundedWeek: week))
    }

    mutating func upgradeStudio(id: Int) throws {
        guard outcome == .playing else { throw ActionError.gameOver }
        guard let index = studios.firstIndex(where: { $0.id == id }) else { throw ActionError.invalidAmount }
        let level = studios[index].level
        guard level < Formulas.maxStudioLevel else {
            throw ActionError.invalidProject("\(studios[index].name) is already at the top level.")
        }
        let cost = Formulas.studioUpgradeCost(currentLevel: level)
        guard finances.cash >= cost else { throw ActionError.insufficientFunds(needed: cost) }
        finances.cash -= cost
        finances.ledger.other += cost
        studios[index].level = level + 1
    }

    func activeProjects(at studioID: Int) -> Int { projects.filter { $0.studioID == studioID }.count }

    func freeSlots(at studio: Studio) -> Int { max(0, studio.slots - activeProjects(at: studio.id)) }

    var weeklyStudioCost: Double {
        studios.reduce(0.0) { $0 + Formulas.studioUpkeep(level: $1.level) } * staff.studioPay
    }

    /// Expected quality bonus (before luck) a project would get at this studio.
    func studioBonus(for studio: Studio, genre: Genre) -> Double {
        Formulas.studioQualityBonus(level: studio.level, experience: studio.experience,
                                    specialtyMatch: studio.specialty == genre,
                                    payEffect: Formulas.payEffectiveness(staff.studioPay))
    }

    // MARK: Pay

    mutating func setPay(_ department: Department, scale: Double) throws {
        guard Formulas.payRange.contains(scale) else { throw ActionError.invalidAmount }
        staff.setPay(department, (scale * 100).rounded() / 100)
    }

    mutating func setStudioPay(scale: Double) throws {
        guard Formulas.payRange.contains(scale) else { throw ActionError.invalidAmount }
        staff.studioPay = (scale * 100).rounded() / 100
    }

    // MARK: Subscription prices

    /// Sets every launched market's prices to `level` x that country's fair prices (0.4x ... 2.0x).
    mutating func applyPriceLevel(_ level: Double) throws {
        guard (0.4...2.0).contains(level) else { throw ActionError.invalidAmount }
        for code in markets.keys.sorted() {
            guard let market = markets[code], market.status != .notLaunched,
                  let country = CountryData.country(code) else { continue }
            markets[code]?.prices = Formulas.prices(for: country, level: level)
        }
    }

    /// Sets exact dollar prices for every launched market (0...100 per tier).
    mutating func applyPrices(_ prices: TierSet) throws {
        for tier in Tier.allCases where prices[tier] < 0 || prices[tier] > 100 { throw ActionError.invalidPrice }
        for code in markets.keys.sorted() where markets[code]?.status != .notLaunched {
            markets[code]?.prices = prices
        }
    }

    func rivalPrices(_ rival: Rival, in code: String) -> TierSet? {
        guard let country = CountryData.country(code), (rival.subs[code] ?? 0) > 0 else { return nil }
        func price(_ tier: Tier) -> Double {
            Formulas.rivalPrice(country: country, priceFactor: rival.priceFactor, priceLevel: rival.priceLevel, tier: tier)
        }
        return TierSet(ad: price(.ad), standard: price(.standard), premium: price(.premium))
    }

    /// Copies a rival's dollar prices in one country, optionally undercutting them.
    mutating func matchRival(id: String, in code: String, undercutBy: Double = 0) throws {
        guard let rival = rivals.first(where: { $0.id == id }), let theirs = rivalPrices(rival, in: code) else {
            throw ActionError.invalidProject("That rival isn't in this country.")
        }
        var prices = TierSet(ad: max(0.49, theirs.ad - undercutBy), standard: max(0.49, theirs.standard - undercutBy),
                             premium: max(0.49, theirs.premium - undercutBy))
        prices.ad = min(100, prices.ad); prices.standard = min(100, prices.standard); prices.premium = min(100, prices.premium)
        try setPrices(code: code, prices: prices)
    }
}
