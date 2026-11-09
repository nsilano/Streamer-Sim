import Foundation

extension GameState {
    // MARK: Reading policies

    func policyOptionID(_ policyID: String) -> String {
        policies[policyID] ?? PolicyData.definition(policyID)?.defaultOption ?? ""
    }

    func activeOption(_ definition: PolicyDefinition) -> PolicyOption {
        definition.option(policyOptionID(definition.id)) ?? definition.options[0]
    }

    /// Everything your policies, brand trust, regulatory heat and recent reactions do to the business this week.
    func policyEffects() -> PolicyEffects {
        var total = PolicyEffects.neutral
        for definition in PolicyData.all { total.combine(activeOption(definition).effects) }
        let trustLift = (brandTrust - 60) / 100 * 0.3        // 0 at the starting trust of 60
        total.adds *= 1 + trustLift
        total.churn *= 1 - trustLift
        total.fines *= 1 + regulatoryHeat / 100
        for shock in policyShocks {
            total.churn *= shock.churn
            total.adds *= shock.adds
        }
        return total
    }

    func weeksUntilPolicyCanChange(_ policyID: String) -> Int {
        guard let last = policyChangedWeek[policyID] else { return 0 }
        return max(0, Formulas.policyCooldownWeeks - (week - last))
    }

    /// Why this option can't be chosen right now, or nil if it can.
    func policyBlocker(_ definition: PolicyDefinition, _ option: PolicyOption) -> String? {
        if policyOptionID(definition.id) == option.id { return "Already your policy." }
        let wait = weeksUntilPolicyCanChange(definition.id)
        if wait > 0 { return "You changed this recently. Wait \(wait) more week\(wait == 1 ? "" : "s")." }
        if totalSubscribers < option.minSubscribers { return "Needs \(Format.count(option.minSubscribers)) subscribers first." }
        if finances.cash < policyPrice(option) { return "Needs \(Format.money(policyPrice(option))) to set up." }
        return nil
    }

    // MARK: Enacting

    /// Changes a policy and lets the world react. `forcedBad` lets tests pick the outcome.
    @discardableResult
    mutating func setPolicy(_ policyID: String, option optionID: String, forcedBad: Bool? = nil) throws -> PolicyReaction {
        guard outcome == .playing else { throw ActionError.gameOver }
        guard let definition = PolicyData.definition(policyID), let option = definition.option(optionID) else {
            throw ActionError.invalidProject("Unknown policy.")
        }
        if let reason = policyBlocker(definition, option) { throw ActionError.locked(reason) }

        if option.cost > 0 {
            let price = policyPrice(option)
            finances.cash -= price
            finances.ledger.other += price
        }
        policies[policyID] = optionID
        policyChangedWeek[policyID] = week

        let before = totalSubscribers
        var tone = PolicyTone.mixed
        var headline = "\(companyName) changes its \(definition.title.lowercased()) policy"
        var detail = "Now: \(option.title). \(option.detail)"

        if option.good != nil || option.bad != nil {
            let chance = Formulas.clamp(option.badChance * (1.3 - brandTrust * 0.006), 0, 0.95)
            let isBad = forcedBad ?? (option.bad != nil && rng.chance(chance))
            if let result = isBad ? option.bad : (option.good ?? option.bad) {
                apply(result, policyID: policyID)
                tone = isBad ? .bad : .good
                headline = result.headline
                detail = result.detail
            }
        }

        let change = totalSubscribers - before
        let reaction = PolicyReaction(id: takeID(), week: week, policyTitle: definition.title, optionTitle: option.title,
                                      tone: tone, headline: headline, detail: detail, subscribersChange: change)
        policyLog.insert(reaction, at: 0)
        if policyLog.count > 30 { policyLog.removeLast(policyLog.count - 30) }
        addNews(.you, headline, detail)
        return reaction
    }

    private mutating func apply(_ result: PolicyOutcome, policyID: String) {
        if result.subsPct != 0 {
            for code in markets.keys.sorted() {
                guard var market = markets[code], market.isLive else { continue }
                for tier in Tier.allCases { market.subs[tier] *= (1 + result.subsPct) }
                markets[code] = market
            }
        }
        brandTrust = Formulas.clamp(brandTrust + result.trust, 0, 100)
        regulatoryHeat = Formulas.clamp(regulatoryHeat + result.heat, 0, 100)
        if result.shockWeeks > 0 {
            policyShocks.removeAll { $0.policyID == policyID }
            policyShocks.append(PolicyShock(policyID: policyID, weeksLeft: result.shockWeeks,
                                            churn: result.shockChurn, adds: result.shockAdds))
        }
        if result.rivalPounces {
            // The rival with the biggest footprint where you operate seizes the moment.
            let candidates = rivals.indices.filter { index in
                markets.contains { $0.value.isLive && (rivals[index].subs[$0.key] ?? 0) > 0 }
            }
            if let index = candidates.max(by: { rivals[$0].totalSubs < rivals[$1].totalSubs }) {
                rivals[index].priceLevel = Formulas.clamp(rivals[index].priceLevel - 0.06, 0.6, 1.15)
                addNews(.pricing, "\(rivals[index].name) pounces on \(companyName)'s backlash",
                        "\(rivals[index].name) launches a promotion aimed at unhappy \(companyName) customers.", rival: rivals[index].id)
            }
        }
    }

    // MARK: Weekly upkeep (called by the engine)

    /// Drifts trust and heat, and counts temporary shocks down.
    mutating func advancePolicyState(effects: PolicyEffects) {
        brandTrust = Formulas.clamp(brandTrust + effects.trust + (60 - brandTrust) * 0.01, 0, 100)
        regulatoryHeat = Formulas.clamp(regulatoryHeat + effects.heat - regulatoryHeat * 0.03, 0, 100)
        for index in policyShocks.indices { policyShocks[index].weeksLeft -= 1 }
        policyShocks.removeAll { $0.weeksLeft <= 0 }
    }

    /// Plain-English summary of what your current policies do overall.
    func policySummary() -> [(label: String, percent: Double)] {
        var total = PolicyEffects.neutral
        for definition in PolicyData.all { total.combine(activeOption(definition).effects) }
        return [("New subscribers", total.adds - 1), ("Churn", total.churn - 1), ("Revenue per subscriber", total.arpu - 1),
                ("Ad revenue", total.adRevenue - 1), ("Hosting costs", total.streamingCost - 1), ("Regulatory fines", total.fines - 1)]
            .filter { abs($0.1) > 0.0005 }
            .map { (label: $0.0, percent: $0.1) }
    }
}

extension Formulas {
    static let policyCooldownWeeks = 8
}
