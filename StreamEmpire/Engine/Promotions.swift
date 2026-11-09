import Foundation

/// Pure promotion math.
enum PromoMath {
    static let maxActive = 3
    static let maxWeeks = 12
    static let fatigueWindowWeeks = 8
    static let discountRange = 0.1...0.6

    /// How well a campaign lands: your promotions policy and recent repeats matter.
    static func effectiveness(promosPolicy: String, fatigued: Bool) -> Double {
        var e = 1.0
        if promosPolicy == "never" { e *= 1.15 }       // promotions feel special
        if promosPolicy == "always" { e *= 0.6 }       // customers wait for deals anyway
        if fatigued { e *= 0.6 }
        return e
    }

    static func effects(kind: PromotionKind, intensity: Double, strength e: Double) -> PromoEffects {
        var fx = PromoEffects()
        switch kind {
        case .discount:
            fx.adds = 1 + 1.5 * intensity * e
            fx.arpu = 1 - 0.6 * intensity
        case .freeTrial:
            fx.adds = 1 + 0.6 * e
            fx.streaming = 1.05
        case .twoForOne:
            fx.adds = 1 + 0.35 * e
            fx.arpu = 0.94
        case .blitz:
            fx.adds = 1 + 0.45 * e
            fx.awareness = 0.03 * e
        case .winback:
            fx.adds = 1 + 0.25 * e
            fx.churn = 0.94
        }
        return fx
    }

    /// The churn spike that follows (nil if none).
    static func hangover(kind: PromotionKind, intensity: Double, weeks: Int) -> (weeks: Int, churn: Double)? {
        switch kind {
        case .discount: return (max(2, weeks / 2 + 1), 1 + 0.4 * intensity)
        case .freeTrial: return (3, 1.12)
        case .twoForOne: return (2, 1.04)
        case .blitz, .winback: return nil
        }
    }

    /// Up-front cost for the whole campaign.
    static func cost(kind: PromotionKind, weeks: Int, markets: Int, costScale: Double) -> Double {
        let setup: Double, perWeek: Double
        switch kind {
        case .discount: (setup, perWeek) = (40_000, 5_000)
        case .freeTrial: (setup, perWeek) = (70_000, 12_000)
        case .twoForOne: (setup, perWeek) = (90_000, 8_000)
        case .blitz: (setup, perWeek) = (120_000, 40_000)
        case .winback: (setup, perWeek) = (50_000, 10_000)
        }
        return (setup + perWeek * Double(weeks)) * pow(Double(max(1, markets)), 0.8) * costScale
    }
}

struct PromoQuote: Equatable {
    var cost: Double
    var effects: PromoEffects
    var strength: Double
    var fatigued: Bool
    var markets: Int
    var hangoverWeeks: Int
    var hangoverChurn: Double
}

extension GameState {
    // MARK: Effects

    /// Everything running promotions (and their hangovers) do to one country this week.
    func promoEffects(for code: String) -> PromoEffects {
        var total = PromoEffects.neutral
        for promo in promotions where promo.scope.isEmpty || promo.scope == code {
            let fx = PromoMath.effects(kind: promo.kind, intensity: promo.intensity, strength: promo.strength)
            total.adds *= fx.adds
            total.churn *= fx.churn
            total.arpu *= fx.arpu
            total.streaming *= fx.streaming
            total.awareness += fx.awareness
        }
        for hangover in promoHangovers where hangover.scope.isEmpty || hangover.scope == code {
            total.churn *= hangover.churn
        }
        return total
    }

    func isPromoFatigued(_ kind: PromotionKind) -> Bool {
        guard let last = promoLastEnded[kind.rawValue] else { return false }
        return week - last < PromoMath.fatigueWindowWeeks
    }

    private func subscribers(inScope scope: String) -> Double {
        if scope.isEmpty { return totalSubscribers }
        return markets[scope]?.subs.total ?? 0
    }

    // MARK: Launching

    func promotionQuote(kind: PromotionKind, scope: String, weeks: Int, intensity: Double) -> PromoQuote {
        let marketCount = scope.isEmpty ? max(1, liveMarketCodes.count) : 1
        let strength = PromoMath.effectiveness(promosPolicy: policyOptionID("promos"), fatigued: isPromoFatigued(kind))
        let hang = PromoMath.hangover(kind: kind, intensity: intensity, weeks: weeks)
        return PromoQuote(cost: PromoMath.cost(kind: kind, weeks: weeks, markets: marketCount, costScale: costScale),
                          effects: PromoMath.effects(kind: kind, intensity: intensity, strength: strength),
                          strength: strength, fatigued: isPromoFatigued(kind), markets: marketCount,
                          hangoverWeeks: hang?.weeks ?? 0, hangoverChurn: hang?.churn ?? 1)
    }

    mutating func launchPromotion(kind: PromotionKind, scope: String, weeks: Int, intensity: Double = 0) throws {
        guard outcome == .playing else { throw ActionError.gameOver }
        guard (1...PromoMath.maxWeeks).contains(weeks) else {
            throw ActionError.invalidProject("Promotions run 1 to \(PromoMath.maxWeeks) weeks.")
        }
        if !scope.isEmpty {
            guard markets[scope]?.isLive == true else { throw ActionError.invalidProject("You aren't live in that country yet.") }
        } else {
            guard !liveMarketCodes.isEmpty else { throw ActionError.invalidProject("Launch a market first.") }
        }
        if kind.usesIntensity, !PromoMath.discountRange.contains(intensity) {
            throw ActionError.invalidProject("Discounts run from 10% to 60%.")
        }
        guard promotions.count < PromoMath.maxActive else {
            throw ActionError.invalidProject("You can run at most \(PromoMath.maxActive) promotions at once.")
        }
        if promotions.contains(where: { $0.kind == kind && ($0.scope.isEmpty || scope.isEmpty || $0.scope == scope) }) {
            throw ActionError.invalidProject("You're already running a \(kind.title.lowercased()) there.")
        }

        let used = kind.usesIntensity ? intensity : 0
        let quote = promotionQuote(kind: kind, scope: scope, weeks: weeks, intensity: used)
        guard finances.cash >= quote.cost else { throw ActionError.insufficientFunds(needed: quote.cost) }
        finances.cash -= quote.cost
        finances.ledger.promotions += quote.cost

        promotions.append(Promotion(id: takeID(), kind: kind, scope: scope, weeksTotal: weeks, weeksLeft: weeks,
                                    intensity: used, strength: quote.strength, startWeek: week,
                                    startSubs: subscribers(inScope: scope), cost: quote.cost))
        let place = scope.isEmpty ? "all its markets" : (CountryData.country(scope)?.name ?? scope)
        let what = kind.usesIntensity ? "a \(Int(used * 100))%-off deal" : "a \(kind.title.lowercased())"
        addNews(.pricing, "\(companyName) launches \(what) in \(place)",
                "\(weeks) week\(weeks == 1 ? "" : "s") to win new subscribers. Campaign budget \(Format.money(quote.cost)).")
    }

    /// Stops a campaign early. The money is spent, but the hangover is lighter for the shorter run.
    mutating func cancelPromotion(id: Int) throws {
        guard let index = promotions.firstIndex(where: { $0.id == id }) else { throw ActionError.invalidAmount }
        finishPromotion(at: index)
    }

    // MARK: Weekly upkeep (called by the engine)

    mutating func advancePromotions() {
        for index in promoHangovers.indices { promoHangovers[index].weeksLeft -= 1 }
        promoHangovers.removeAll { $0.weeksLeft <= 0 }
        for index in promotions.indices { promotions[index].weeksLeft -= 1 }
        var finished = promotions.indices.filter { promotions[$0].weeksLeft <= 0 }
        while let index = finished.popLast() { finishPromotion(at: index) }
    }

    private mutating func finishPromotion(at index: Int) {
        let promo = promotions.remove(at: index)
        let ran = max(1, promo.weeksTotal - promo.weeksLeft)
        if let hang = PromoMath.hangover(kind: promo.kind, intensity: promo.intensity, weeks: ran) {
            promoHangovers.append(PromoHangover(scope: promo.scope, weeksLeft: hang.weeks, churn: hang.churn))
        }
        promoLastEnded[promo.kind.rawValue] = week
        if promo.kind == .discount, promo.intensity >= 0.4 { brandTrust = Formulas.clamp(brandTrust - 1.5, 0, 100) }
        if promo.kind == .blitz { brandTrust = Formulas.clamp(brandTrust + 0.5, 0, 100) }

        let gained = subscribers(inScope: promo.scope) - promo.startSubs
        let place = promo.scope.isEmpty ? "all markets" : (CountryData.country(promo.scope)?.name ?? promo.scope)
        let note = "\(gained >= 0 ? "+" : "-")\(Format.count(abs(gained))) net subscribers in \(place) for \(Format.money(promo.cost))."
        promoHistory.insert(PromoResult(id: promo.id, week: week, kind: promo.kind, scope: promo.scope, weeks: ran,
                                        cost: promo.cost, subscribersGained: gained, note: note), at: 0)
        if promoHistory.count > 12 { promoHistory.removeLast(promoHistory.count - 12) }
        addNews(.pricing, "\(companyName)'s \(promo.kind.title.lowercased()) ends", note)
    }
}
