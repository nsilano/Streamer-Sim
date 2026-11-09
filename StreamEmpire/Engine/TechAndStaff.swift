import Foundation

/// Platforms, CDN capacity and staff decisions.
extension GameState {
    // MARK: Platforms

    mutating func startPlatform(_ platform: Platform) throws {
        guard outcome == .playing else { throw ActionError.gameOver }
        guard !platforms.contains(platform), !builds.contains(where: { $0.platform == platform }) else {
            throw ActionError.invalidProject("\(platform.displayName) is already built or in development.")
        }
        let price = platformPrice(platform)
        guard finances.cash >= price else {
            throw ActionError.insufficientFunds(needed: price)
        }
        finances.cash -= price
        finances.ledger.other += price
        addNews(.you, "\(companyName) starts building its \(platform.displayName)", "Ready in about \(Formulas.buildWeeks(base: platform.buildWeeks, engineeringLevel: staff.effectiveLevel(.engineering))) weeks.")
        builds.append(PlatformBuild(
            platform: platform,
            weeksLeft: Formulas.buildWeeks(base: platform.buildWeeks, engineeringLevel: staff.effectiveLevel(.engineering))))
    }

    // MARK: Servers & datacenters

    private var serverCostMultiplier: Double {
        Formulas.cdnCostMultiplier(engineeringLevel: staff.effectiveLevel(.engineering))
    }

    var datacenterBuildPrice: Double { scaled(Formulas.datacenterBuildCost * serverCostMultiplier) }

    func datacenterUpgradePrice(_ datacenter: Datacenter) -> Double? {
        guard datacenter.isOnline, datacenter.level < Formulas.maxDatacenterLevel else { return nil }
        return scaled(Formulas.datacenterUpgradeCost(currentLevel: datacenter.level) * serverCostMultiplier)
    }

    func datacenters(in region: Region) -> [Datacenter] { datacenters.filter { $0.region == region } }

    mutating func buildDatacenter(region: Region) throws {
        guard outcome == .playing else { throw ActionError.gameOver }
        let existing = datacenters(in: region)
        guard existing.count < Formulas.maxDatacentersPerRegion else {
            throw ActionError.invalidProject("\(region.displayName) already has \(Formulas.maxDatacentersPerRegion) datacenters. Upgrade one instead.")
        }
        let price = datacenterBuildPrice
        guard finances.cash >= price else { throw ActionError.insufficientFunds(needed: price) }
        finances.cash -= price
        finances.ledger.other += price
        let weeks = Formulas.buildWeeks(base: Formulas.datacenterBuildWeeks,
                                        engineeringLevel: staff.effectiveLevel(.engineering))
        datacenters.append(Datacenter(id: takeID(), name: DatacenterNames.name(region: region, index: existing.count),
                                      region: region, level: 1, weeksToBuild: weeks))
    }

    mutating func upgradeDatacenter(id: Int) throws {
        guard outcome == .playing else { throw ActionError.gameOver }
        guard let index = datacenters.firstIndex(where: { $0.id == id }) else { throw ActionError.invalidAmount }
        guard let price = datacenterUpgradePrice(datacenters[index]) else {
            throw ActionError.invalidProject("\(datacenters[index].name) can't be upgraded right now.")
        }
        guard finances.cash >= price else { throw ActionError.insufficientFunds(needed: price) }
        finances.cash -= price
        finances.ledger.other += price
        datacenters[index].level += 1
    }

    /// Rent one block of cloud capacity (instant, expensive). Release it when the rush is over.
    mutating func rentCloud(region: Region) throws {
        guard outcome == .playing else { throw ActionError.gameOver }
        let units = cloudUnits[region.rawValue] ?? 0
        guard units < Formulas.maxCloudUnits else {
            throw ActionError.invalidProject("You can rent at most \(Formulas.maxCloudUnits) cloud blocks per region. Build a datacenter.")
        }
        cloudUnits[region.rawValue] = units + 1
    }

    mutating func releaseCloud(region: Region) throws {
        let units = cloudUnits[region.rawValue] ?? 0
        guard units > 0 else { throw ActionError.invalidAmount }
        cloudUnits[region.rawValue] = units - 1
    }

    /// Weekly cost of platforms, datacenters (once online) and rented cloud.
    var weeklyTechCost: Double {
        let owned = datacenters.filter { $0.isOnline }.reduce(0.0) { $0 + Formulas.datacenterUpkeep(level: $1.level) }
        let cloud = cloudUnits.keys.sorted().reduce(0.0) { $0 + Double(cloudUnits[$1] ?? 0) } * Formulas.cloudUnitCostPerWeek
        let apps = platforms.reduce(0.0) { $0 + $1.weeklyUpkeep }
        return scaled((owned + cloud) * serverCostMultiplier + apps)
    }

    // MARK: Staff

    mutating func hire(_ department: Department) throws {
        guard outcome == .playing else { throw ActionError.gameOver }
        let level = staff[department]
        guard level < Formulas.maxDepartmentLevel else {
            throw ActionError.invalidProject("\(department.displayName) is already fully staffed.")
        }
        let cost = hirePrice(department)
        guard finances.cash >= cost else { throw ActionError.insufficientFunds(needed: cost) }
        finances.cash -= cost
        finances.ledger.other += cost
        staff[department] = level + 1
    }

    mutating func reduceStaff(_ department: Department) throws {
        guard staff[department] > 0 else { throw ActionError.invalidAmount }
        staff[department] -= 1
    }

    var weeklySalaries: Double { scaled(staff.weeklySalaries + (curator != nil ? Curator.weeklySalary : 0)) }

    /// License price after the Content department's discount.
    func licensePrice(_ title: Title) -> Double {
        guard let license = title.license else { return 0 }
        return license.cost * (1 - Formulas.licenseDiscount(contentLevel: staff.effectiveLevel(.content)))
            * Formulas.licenseAudienceScale(totalSubscribers: totalSubscribers) * costScale
    }

    var loanRate: Double {
        max(0.04, Formulas.loanRate(profitable: finances.recentWeeklyProfit >= 0)
            - Formulas.loanRateDiscount(financeLevel: staff.effectiveLevel(.finance)))
    }
}
