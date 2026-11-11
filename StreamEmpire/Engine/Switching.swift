import Foundation

/// Customers switching between you and each rival in a country, based on catalog, price and service.
/// A better offer pulls a rival's customers to you; a worse one sends yours to them.
extension Formulas {
    /// Weekly cap on the share of one rival's customers you can win in a country.
    static let maxSwitchInRate = 0.003
    /// Weekly cap on the share of your customers that can leave for rivals in a country (all rivals together).
    static let maxSwitchOutRate = 0.0015

    /// Positive: you look better than this rival. Catalog counts most, then price, then service quality.
    static func switchScore(yourAppeal: Double, rivalStrength: Double, yourPrice: Double, rivalPrice: Double,
                            service: Double) -> Double {
        let catalog = yourAppeal - rivalStrength / 100
        let price = clamp((rivalPrice - yourPrice) / max(1, rivalPrice), -0.5, 0.5)
        return catalog + 0.6 * price + 0.5 * (service - 1)
    }

    /// Weekly share of the losing side that switches. Winning customers also needs people to know you exist.
    static func switchRate(score: Double, awareness: Double) -> Double {
        if score > 0 { return min(maxSwitchInRate, score * 0.01) * min(1, 0.3 + awareness) }
        return max(-maxSwitchInRate, score * 0.01)
    }
}

enum Switching {
    struct Flow: Equatable {
        var gained = 0.0
        var lost = 0.0
        var byRival: [String: Double] = [:]      // rival id -> net customers to you (negative = to them)
    }

    /// The per-rival score used both by the simulation and by the country sheet.
    static func score(_ s: GameState, rival: Rival, country: Country, appeal: Double, service: Double) -> Double {
        let market = s.markets[country.code]
        let rivalPrice = Formulas.rivalPrice(country: country, priceFactor: rival.priceFactor,
                                             priceLevel: rival.priceLevel, tier: .standard)
        return Formulas.switchScore(yourAppeal: appeal, rivalStrength: rival.catalogStrength,
                                    yourPrice: market?.prices.standard ?? country.priceTolerance,
                                    rivalPrice: rivalPrice, service: service)
    }

    /// Moves customers between you and the rivals in one live country this week.
    static func apply(_ s: inout GameState, country: Country, appeal: Double, service: Double) -> Flow {
        let code = country.code
        guard var market = s.markets[code], market.isLive else { return Flow() }
        var flow = Flow()
        var outRates: [(index: Int, rate: Double)] = []
        for i in s.rivals.indices {
            let theirs = s.rivals[i].subs[code] ?? 0
            guard theirs > 0 else { continue }
            let rate = Formulas.switchRate(score: score(s, rival: s.rivals[i], country: country, appeal: appeal, service: service),
                                           awareness: market.awareness)
            if rate > 0, s.signupsPaused(in: country.region) { continue }   // nobody new joins while sign-ups are shut
            if rate > 0 {
                let moved = theirs * rate
                s.rivals[i].subs[code] = theirs - moved
                flow.gained += moved
                flow.byRival[s.rivals[i].id, default: 0] += moved
            } else if rate < 0 {
                outRates.append((i, -rate))
            }
        }
        let base = market.subs.total
        if base > 0, !outRates.isEmpty {
            let total = outRates.reduce(0) { $0 + $1.rate }
            let scale = total > Formulas.maxSwitchOutRate ? Formulas.maxSwitchOutRate / total : 1
            for (i, rate) in outRates {
                let moved = base * rate * scale
                s.rivals[i].subs[code, default: 0] += moved
                flow.lost += moved
                flow.byRival[s.rivals[i].id, default: 0] -= moved
            }
            let keep = max(0, 1 - flow.lost / base)
            for tier in Tier.allCases { market.subs[tier] *= keep }
        }
        if flow.gained > 0 {
            let split = Formulas.tierSplit(prices: market.prices, tiers: market.liveTiers)
            for tier in Tier.allCases { market.subs[tier] += flow.gained * split[tier] }
        }
        s.markets[code] = market
        return flow
    }

    /// Weekly headline for the biggest swing, plus a report line when it matters.
    static func report(_ s: inout GameState, flows: [String: Double], gained: Double, lost: Double, events: inout [GameEvent]) {
        guard let top = flows.keys.sorted().max(by: { abs(flows[$0] ?? 0) < abs(flows[$1] ?? 0) }),
              let rival = s.rivals.first(where: { $0.id == top }), let net = flows[top], abs(net) >= 1_000 else { return }
        if net > 0 {
            s.addNews(.subscribers, "\(Format.count(net)) switch from \(rival.name) to \(s.companyName)",
                      "Viewers are moving to the better catalog and price.", rival: rival.id)
        } else {
            s.addNews(.subscribers, "\(Format.count(-net)) leave \(s.companyName) for \(rival.name)",
                      "\(rival.name) looks like the better deal right now.", rival: rival.id)
        }
        if gained >= 5_000 || lost >= 5_000 {
            events.append(s.makeEvent(gained >= lost ? .news : .warning, "Switchers: +\(Format.count(gained)) / -\(Format.count(lost))",
                                      "Won from rivals this week vs lost to them. Biggest swing: \(rival.name)."))
        }
    }
}

extension GameState {
    /// For the country sheet: which way customers are flowing against each rival (positive = toward you).
    func switchOutlook(code: String) -> [(rival: Rival, score: Double)] {
        guard let country = CountryData.country(code), markets[code]?.isLive == true else { return [] }
        let titles = catalog.filter { $0.isAvailable(in: code) }
        let appeal = min(0.98, Formulas.catalogAppeal(titles, in: country) * featureEffects(for: country).appeal
                         + sportsEffects(region: country.region).appealBonus)
        let service = Formulas.serviceQuality(load: effectiveLoad(country.region))
        return rivals.filter { ($0.subs[code] ?? 0) > 0 }
            .map { ($0, Switching.score(self, rival: $0, country: country, appeal: appeal, service: service)) }
    }
}
