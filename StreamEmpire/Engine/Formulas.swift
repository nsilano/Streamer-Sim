import Foundation

/// Pure simulation math. No state, no randomness (noise is passed in).
enum Formulas {
    // Tunable constants (Phase 4 balancing pass).
    static let baseAddRate = 0.012            // share of headroom that can join per week at appeal 1.0
    static let baseChurn = 0.010              // weekly churn at neutral conditions
    static let appealSaturation = 8.0         // summed title appeal at which catalog appeal ~63%
    static let streamingCostPerSubWeek = 0.07
    static let baseStaffCostPerWeek = 20_000.0
    static let adARPUPerMonthAtFullStrength = 4.0
    static let weeksPerMonth = 52.0 / 12.0

    static func clamp(_ v: Double, _ lo: Double, _ hi: Double) -> Double { min(hi, max(lo, v)) }

    // MARK: Content

    static func languageMatch(title: Title, country: Country) -> Double {
        if title.language == country.language { return 1.0 }
        if title.language == .english { return 0.7 }
        return 0.35
    }

    /// Titles lose appeal as they age (never below 25%).
    static func freshness(ageWeeks: Int) -> Double {
        max(0.25, exp(-Double(ageWeeks) / 130.0))
    }

    /// New releases get a short boost during their first 4 weeks.
    static func releaseBoost(ageWeeks: Int) -> Double {
        ageWeeks < 4 ? 1.0 + 0.5 * Double(4 - ageWeeks) / 4.0 : 1.0
    }

    static func titleAppeal(_ title: Title, in country: Country) -> Double {
        let quality = Double(title.quality) / 100
        let popularity = 0.4 + 0.6 * Double(title.popularity) / 100
        var appeal = quality * popularity
            * country.taste(title.genre)
            * languageMatch(title: title, country: country)
            * freshness(ageWeeks: title.ageWeeks)
            * releaseBoost(ageWeeks: title.ageWeeks)
        if title.license?.exclusive == true { appeal *= 1.15 }
        if title.genre == .local && title.language != country.language { appeal *= 0.3 }
        return appeal
    }

    /// 0...1 with diminishing returns as the catalog grows.
    static func catalogAppeal(_ titles: [Title], in country: Country) -> Double {
        let sum = titles.reduce(0) { $0 + titleAppeal($1, in: country) }
        return 1 - exp(-sum / appealSaturation)
    }

    static func licenseCost(kind: TitleKind, quality: Int, popularity: Int, years: Int,
                            ageWeeks: Int, exclusive: Bool) -> Double {
        let base = kind == .movie ? 400_000.0 : 1_200_000.0
        let q = Double(quality) / 100
        let qualityTerm = 0.3 + q * q * 2.2
        let popularityTerm = 0.5 + Double(popularity) / 100
        let durationTerm = pow(Double(years), 0.8)
        let ageDiscount = 1.0 - min(Double(ageWeeks) / 520.0, 0.6)
        var cost = base * qualityTerm * popularityTerm * durationTerm * ageDiscount
        if exclusive { cost *= 1.4 }
        return (cost / 1000).rounded() * 1000
    }

    // MARK: Pricing

    /// Tier-weighted price used for demand and churn.
    static func blendedPrice(_ prices: TierSet) -> Double {
        0.3 * prices.ad + 0.5 * prices.standard + 0.2 * prices.premium
    }

    /// 1.0 when price equals tolerance; falls steeply above it, rises below it.
    static func priceFactor(price: Double, tolerance: Double) -> Double {
        let ratio = max(price, 0.01) / tolerance
        return 2.0 / (1.0 + pow(ratio, 2.5))
    }

    /// Share of NEW subscribers choosing each tier (sums to 1).
    static func tierSplit(prices: TierSet) -> TierSet {
        func weight(_ price: Double, _ appeal: Double) -> Double { appeal / pow(max(price, 0) + 1, 1.2) }
        let ad = weight(prices.ad, 1.0)
        let standard = weight(prices.standard, 1.0)
        let premium = weight(prices.premium, 0.6)
        let total = ad + standard + premium
        return TierSet(ad: ad / total, standard: standard / total, premium: premium / total)
    }

    // MARK: Marketing & awareness

    static func marketingScale(households: Double) -> Double { households * 60_000 }

    static func marketingFactor(spend: Double, households: Double) -> Double {
        1.0 + 0.6 * (1 - exp(-spend / marketingScale(households: households)))
    }

    static func nextAwareness(awareness: Double, spend: Double, households: Double, penetration: Double) -> Double {
        let push = (1 - awareness) * (1 - exp(-spend / marketingScale(households: households))) * 0.2
        let organic = (1 - awareness) * penetration * 0.05
        let decay = awareness * 0.015
        return clamp(awareness + push + organic - decay, 0, 1)
    }

    static func wordOfMouth(penetration: Double) -> Double { 1.0 + min(penetration * 4, 0.8) }

    static func rivalFactor(rivalShare: Double) -> Double { max(0.2, 1.0 - 0.6 * rivalShare) }

    // MARK: Subscribers

    /// Gross new subscribers this week, before the headroom cap.
    static func grossAdds(headroom: Double, appeal: Double, priceFactor: Double, awareness: Double,
                          marketingFactor: Double, wordOfMouth: Double, rivalFactor: Double,
                          reach: Double, noise: Double) -> Double {
        headroom * baseAddRate * appeal * priceFactor * (0.2 + awareness)
            * marketingFactor * wordOfMouth * rivalFactor * reach * noise
    }

    /// Weekly churn rate (fraction of subscribers lost).
    static func churnRate(appeal: Double, price: Double, tolerance: Double,
                          serviceQuality: Double, rivalHeat: Double = 0) -> Double {
        let content = 1.6 - appeal                                   // 0.6 ... 1.6
        let priceEffect = clamp(0.8 + 0.4 * price / tolerance, 0.6, 2.0)
        let service = 1.0 + (1.0 - clamp(serviceQuality, 0, 1)) * 3.0
        return baseChurn * content * priceEffect * service * (1.0 + 0.3 * rivalHeat)
    }

    // MARK: Money

    /// Subscriptions are billed monthly: weekly revenue = price x 12 / 52.
    static func subscriptionRevenue(subs: TierSet, prices: TierSet) -> Double {
        Tier.allCases.reduce(0) { $0 + subs[$1] * prices[$1] } / weeksPerMonth
    }

    static func adRevenue(adSubs: Double, adStrength: Double) -> Double {
        adSubs * adARPUPerMonthAtFullStrength * adStrength / weeksPerMonth
    }

    static func operatingCost(for country: Country) -> Double {
        4_000 + country.households * 2_500
    }
}
