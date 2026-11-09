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
        if title.dubs.contains(country.language) { return 0.95 }
        if title.subtitles.contains(country.language) { return 0.8 }
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

    /// One rival's footprint in a single country.
    struct RivalPresence: Equatable {
        var share: Double          // share of the country's subscriber ceiling
        var strength: Double       // catalog strength 0...100
        var priceLevel: Double     // 1.0 normal, <1 price cuts
    }

    /// Strength-weighted rival share (feeds `rivalFactor`) and price-cut heat 0...1 (feeds churn).
    static func rivalPressure(_ rivals: [RivalPresence]) -> (effectiveShare: Double, heat: Double) {
        let totalShare = rivals.reduce(0) { $0 + $1.share }
        guard totalShare > 0 else { return (0, 0) }
        let effective = rivals.reduce(0) { $0 + $1.share * (0.7 + 0.6 * $1.strength / 100) }
        let heat = rivals.reduce(0) { $0 + $1.share * min(1, max(0, 1 - $1.priceLevel) * 3) } / totalShare
        return (effective, heat)
    }

    /// Weekly chance a given rival outbids you for a listing.
    static func bidChance(personality: RivalPersonality, quality: Int) -> Double {
        let base: Double
        switch personality {
        case .aggressiveBidder: base = 0.025
        case .globalExpander: base = 0.012
        case .balanced: base = 0.012
        case .originalsHeavy: base = 0.008
        case .priceCutter: base = 0.008
        }
        return base * (0.5 + Double(quality) / 100)
    }

    /// Weekly chance a rival opens a new country.
    static func expansionChance(personality: RivalPersonality) -> Double {
        switch personality {
        case .globalExpander: return 0.03
        case .aggressiveBidder: return 0.015
        case .originalsHeavy, .balanced: return 0.012
        case .priceCutter: return 0.01
        }
    }

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

    // MARK: Originals

    static func idealProductionWeeks(_ kind: TitleKind) -> Int { kind == .movie ? 26 : 40 }
    static func budgetReference(_ kind: TitleKind) -> Double { kind == .movie ? 8_000_000 : 30_000_000 }
    static func budgetRange(_ kind: TitleKind) -> ClosedRange<Double> {
        kind == .movie ? 500_000...40_000_000 : 2_000_000...120_000_000
    }
    static let productionWeeksRange = 6...52
    static let maxConcurrentProjects = 6

    /// Average quality an original of this budget and schedule will reach (before luck).
    static func expectedOriginalQuality(kind: TitleKind, budget: Double, weeks: Int) -> Double {
        let money = 30 + 45 * (1 - exp(-budget / budgetReference(kind)))
        let ratio = min(1, Double(weeks) / Double(idealProductionWeeks(kind)))
        return money * (0.85 + 0.15 * ratio)
    }

    /// Release-day quality: expected value plus luck (+/-22) and a rare breakout bonus.
    static func rolledOriginalQuality(expected: Double, u1: Double, u2: Double, u3: Double, breakout: Bool) -> Int {
        let luck = (u1 + u2 + u3 - 1.5) / 1.5 * 22
        return Int(clamp(expected + luck + (breakout ? 20 : 0), 5, 100))
    }

    static func originalPopularity(quality: Int, u: Double) -> Int {
        Int(clamp(0.55 * Double(quality) + u * 45, 5, 100))
    }

    // MARK: Localization & quotas

    static func subtitleCost(_ kind: TitleKind) -> Double { kind == .movie ? 25_000 : 90_000 }
    static func dubCost(_ kind: TitleKind) -> Double { kind == .movie ? 120_000 : 450_000 }

    /// 1.0 = compliant. Needs at least 5 titles before quotas apply.
    static func quotaCompliance(localCount: Int, total: Int, quota: Double) -> Double {
        guard total >= 5, quota > 0 else { return 1.0 }
        return min(1.0, (Double(localCount) / Double(total)) / quota)
    }

    static func quotaFine(revenue: Double, risk: Double, compliance: Double) -> Double {
        revenue * risk * (1 - compliance) * 0.25
    }

    // MARK: Funding

    static let ipoMinSubscribers = 5_000_000.0
    static let ipoMinAnnualRevenue = 300_000_000.0
    static let roundMinAnnualRevenue = 1_000_000.0
    static let roundCooldownWeeks = 26
    static let maxRounds = 4
    static let minOwnership = 0.3

    /// Lenders lend against revenue, plus half of any positive cash.
    static func creditLimit(annualRevenue: Double, cash: Double) -> Double {
        3 * annualRevenue + max(0, cash) * 0.5
    }

    static func loanRate(profitable: Bool) -> Double { profitable ? 0.08 : 0.14 }

    static func valuation(annualRevenue: Double, subscribers: Double) -> Double {
        20_000_000 + 5 * annualRevenue + 60 * subscribers
    }
}

// MARK: - Tech, infrastructure & staff

extension Formulas {
    static let maxDepartmentLevel = 5
    static let salaryPerLevelPerWeek = 10_000.0
    static func hireCost(currentLevel: Int) -> Double { 200_000 * Double(currentLevel + 1) }

    static let baseWebReach = 0.70
    static func platformReach(_ platforms: [Platform]) -> Double {
        let bonus = Platform.allCases.filter { platforms.contains($0) }.reduce(0) { $0 + $1.reachBonus }
        return baseWebReach + bonus
    }

    // CDN: every region starts with 200k subscribers of capacity; each expansion adds 250k.
    static let baseCDNCapacity = 200_000.0
    static let cdnStepCapacity = 250_000.0
    static let cdnStepCost = 150_000.0
    static let cdnStepUpkeepPerWeek = 600.0
    static let maxCDNSteps = 40

    static func cdnCapacity(steps: Int) -> Double { baseCDNCapacity + Double(steps) * cdnStepCapacity }

    /// 1.0 while within capacity; buffering and outages degrade it once load passes 100%.
    static func serviceQuality(load: Double) -> Double {
        load <= 1 ? 1.0 : clamp(1 - (load - 1) * 1.2, 0.3, 1.0)
    }

    // Department effects (level 0...5)
    static func licenseDiscount(contentLevel: Int) -> Double { 0.02 * Double(contentLevel) }
    static func originalQualityBonus(contentLevel: Int) -> Double { 2.0 * Double(contentLevel) }
    static func marketingBoost(marketingLevel: Int) -> Double { 1.0 + 0.06 * Double(marketingLevel) }
    static func buildWeeks(base: Int, engineeringLevel: Int) -> Int { max(2, base - engineeringLevel) }
    static func cdnCostMultiplier(engineeringLevel: Int) -> Double { 1.0 - 0.05 * Double(engineeringLevel) }
    static func fineMultiplier(legalLevel: Int) -> Double { 1.0 - 0.15 * Double(legalLevel) }
    static func regulationCostMultiplier(legalLevel: Int) -> Double { 1.0 - 0.10 * Double(legalLevel) }
    static func lobbySuccessChance(legalLevel: Int) -> Double { 0.6 + 0.05 * Double(legalLevel) }
    static func loanRateDiscount(financeLevel: Int) -> Double { 0.005 * Double(financeLevel) }
    static func valuationBoost(financeLevel: Int) -> Double { 1.0 + 0.03 * Double(financeLevel) }
}
