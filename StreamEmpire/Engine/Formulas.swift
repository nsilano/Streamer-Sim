import Foundation

/// Pure simulation math. No state, no randomness (noise is passed in).
enum Formulas {
    // Tunable constants (Phase 4 balancing pass).
    static let baseAddRate = 0.02            // share of headroom that can join per week at appeal 1.0
    static let baseChurn = 0.009              // weekly churn at neutral conditions
    static let appealSaturation = 6.0         // summed title appeal at which catalog appeal ~63%
    static let streamingCostPerSubWeek = 0.25
    static let baseStaffCostPerWeek = 20_000.0
    static let adARPUPerMonthAtFullStrength = 4.0
    static let weeksPerMonth = 52.0 / 12.0
    static let overheadRate = 0.04            // G&A as a share of revenue
    static let appStoreFeeRate = 0.06         // per mobile app (iOS, Android) as a share of subscription revenue

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
        let base = kind == .movie ? 160_000.0 : 480_000.0
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
        4_000 + country.households * 6_000
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

    /// Rights holders charge more the bigger your audience: x1.0 at launch, x3 at 1M subs, x21 at 10M (cap x100).
    static func licenseAudienceScale(totalSubscribers: Double) -> Double {
        min(100, 1 + max(0, totalSubscribers) / 500_000)
    }

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

    // Servers: every region starts with 150k viewers of starter hosting. Datacenters and rented cloud add more.
    static let baseServerCapacity = 150_000.0
    static let datacenterCapacities: [Double] = [250_000, 500_000, 900_000, 1_500_000, 2_500_000]
    static let datacenterUpkeeps: [Double] = [4_000, 8_000, 15_000, 26_000, 45_000]
    static let datacenterUpgradeCosts: [Double] = [600_000, 1_200_000, 2_400_000, 4_500_000]   // from level 1...4
    static let datacenterBuildCost = 500_000.0
    static let datacenterBuildWeeks = 8
    static let maxDatacentersPerRegion = 4
    static let maxDatacenterLevel = 5
    /// Cloud is instant but about 7x pricier per viewer than a datacenter.
    static let cloudUnitCapacity = 100_000.0
    static let cloudUnitCostPerWeek = 12_000.0
    static let maxCloudUnits = 10
    static let surgeLoadMultiplier = 1.3
    static let outageQualityMultiplier = 0.6

    static func datacenterCapacity(level: Int) -> Double {
        datacenterCapacities[min(max(level, 1), maxDatacenterLevel) - 1]
    }
    static func datacenterUpkeep(level: Int) -> Double {
        datacenterUpkeeps[min(max(level, 1), maxDatacenterLevel) - 1]
    }
    static func datacenterUpgradeCost(currentLevel: Int) -> Double {
        datacenterUpgradeCosts[min(max(currentLevel, 1), maxDatacenterLevel - 1) - 1]
    }

    /// 1.0 up to 90% load; a little lag from 90-100%; buffering above 100% that gets worse fast.
    static func serviceQuality(load: Double) -> Double {
        if load <= 0.9 { return 1.0 }
        if load <= 1.0 { return 1.0 - (load - 0.9) * 0.5 }
        return clamp(0.95 - (load - 1.0) * 1.2, 0.3, 1.0)
    }

    /// Weekly chance servers crash in a region. Nothing until 105% load; two or more datacenters add redundancy.
    static func crashChance(load: Double, datacenters: Int, engineeringLevel: Double) -> Double {
        guard load > 1.05 else { return 0 }
        let base = min(0.6, (load - 1.05) * 0.8)
        let redundancy = datacenters >= 2 ? 0.7 : 1.0
        return base * redundancy * max(0.5, 1.0 - 0.05 * engineeringLevel)
    }

    /// Share of a region's subscribers who leave when servers crash.
    static func crashLoss(load: Double) -> Double { clamp(0.03 + (load - 1.0) * 0.1, 0.03, 0.12) }

    // Department effects (level 0...5)
    static func licenseDiscount(contentLevel: Double) -> Double { 0.02 * contentLevel }
    static func originalQualityBonus(contentLevel: Double) -> Double { 2.0 * contentLevel }
    static func marketingBoost(marketingLevel: Double) -> Double { 1.0 + 0.06 * marketingLevel }
    static func buildWeeks(base: Int, engineeringLevel: Double) -> Int { max(2, base - Int(engineeringLevel.rounded())) }
    static func cdnCostMultiplier(engineeringLevel: Double) -> Double { max(0.3, 1.0 - 0.05 * engineeringLevel) }
    static func fineMultiplier(legalLevel: Double) -> Double { max(0.1, 1.0 - 0.15 * legalLevel) }
    static func regulationCostMultiplier(legalLevel: Double) -> Double { max(0.2, 1.0 - 0.10 * legalLevel) }
    static func lobbySuccessChance(legalLevel: Double) -> Double { min(0.95, 0.6 + 0.05 * legalLevel) }
    static func loanRateDiscount(financeLevel: Double) -> Double { 0.005 * financeLevel }
    static func valuationBoost(financeLevel: Double) -> Double { 1.0 + 0.03 * financeLevel }
}

// MARK: - Pay & studios

extension Formulas {
    static let payRange = 0.6...1.6

    /// Output of a team relative to its level: 1.0 at market pay, +/-60% of the pay difference.
    static func payEffectiveness(_ pay: Double) -> Double {
        1 + (clamp(pay, payRange.lowerBound, payRange.upperBound) - 1) * 0.6
    }

    /// Weekly chance of a department level (or studio talent) walking out when pay is under 90% of market.
    static func attritionChance(pay: Double) -> Double { max(0, 0.9 - pay) * 0.04 }

    static let studioFoundingCost = 3_000_000.0
    static let maxStudios = 3
    static let maxStudioLevel = 5
    static func studioUpgradeCost(currentLevel: Int) -> Double { 2_000_000 * Double(currentLevel) }
    static func studioUpkeep(level: Int) -> Double { 25_000 * Double(level) }

    /// In-house productions cost less than outsourced ones; bigger studios are more efficient.
    static func inHouseCostFactor(level: Int) -> Double { 0.85 - 0.04 * Double(level) }

    /// Extra quality from a studio: level, accumulated experience, a genre specialty and well-paid crews.
    static func studioQualityBonus(level: Int, experience: Double, specialtyMatch: Bool, payEffect: Double) -> Double {
        (3.0 * Double(level) + experience * 0.1 + (specialtyMatch ? 5 : 0)) * payEffect
    }

    static func studioPopularityBonus(experience: Double) -> Int { Int(experience * 0.08) }

    static func studioExperienceGain(quality: Int) -> Double { 8 + Double(quality) / 10 }

    /// Experience lost per week when crews are underpaid.
    static func studioExperienceDecay(pay: Double) -> Double { max(0, 0.9 - pay) * 10 }

    // MARK: Global pricing

    /// Price for each tier at `level` x the country's fair prices, rounded to 50 cents.
    static func prices(for country: Country, level: Double) -> TierSet {
        let base = CountryData.defaultPrices(for: country)
        func scaled(_ v: Double) -> Double { min(100, max(0, (v * level * 2).rounded() / 2)) }
        return TierSet(ad: scaled(base.ad), standard: scaled(base.standard), premium: scaled(base.premium))
    }
}


// MARK: - Rival reaction to dominance

extension Formulas {
    /// 0...1: how threatened rivals feel when you hold this share of a country's subscribers.
    /// Nothing below 25%; maxes out around 60%.
    static func dominanceThreat(playerShare: Double) -> Double {
        clamp((playerShare - 0.25) / 0.35, 0, 1)
    }

    /// Weekly chance a rival changes its prices. Threat makes cuts far more likely.
    static func retaliationChance(personality: RivalPersonality, threat: Double) -> Double {
        let reaction: Double
        switch personality {
        case .priceCutter: reaction = 0.30
        case .aggressiveBidder: reaction = 0.22
        default: reaction = 0.15
        }
        return 0.04 + threat * reaction
    }

    /// Lowest price level a rival will go to; wars go deeper than ordinary promotions.
    static func priceFloor(threat: Double) -> Double { 0.7 - 0.1 * threat }

    /// Fraction of your subscribers a discounting rival pulls away each week in a market you dominate.
    static func poachRate(priceLevel: Double, threat: Double) -> Double {
        threat * max(0, 0.95 - priceLevel) * 0.04
    }
}
