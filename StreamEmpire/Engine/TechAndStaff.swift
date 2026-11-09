import Foundation

/// Platforms, CDN capacity and staff decisions.
extension GameState {
    // MARK: Platforms

    mutating func startPlatform(_ platform: Platform) throws {
        guard outcome == .playing else { throw ActionError.gameOver }
        guard !platforms.contains(platform), !builds.contains(where: { $0.platform == platform }) else {
            throw ActionError.invalidProject("\(platform.displayName) is already built or in development.")
        }
        guard finances.cash >= platform.unlockCost else {
            throw ActionError.insufficientFunds(needed: platform.unlockCost)
        }
        finances.cash -= platform.unlockCost
        finances.ledger.other += platform.unlockCost
        builds.append(PlatformBuild(
            platform: platform,
            weeksLeft: Formulas.buildWeeks(base: platform.buildWeeks, engineeringLevel: staff.engineering)))
    }

    // MARK: Infrastructure

    var cdnStepPrice: Double {
        Formulas.cdnStepCost * Formulas.cdnCostMultiplier(engineeringLevel: staff.engineering)
    }

    mutating func expandCDN(region: Region) throws {
        guard outcome == .playing else { throw ActionError.gameOver }
        let steps = cdnSteps[region.rawValue] ?? 0
        guard steps < Formulas.maxCDNSteps else { throw ActionError.invalidProject("Maximum capacity reached.") }
        let price = cdnStepPrice
        guard finances.cash >= price else { throw ActionError.insufficientFunds(needed: price) }
        finances.cash -= price
        finances.ledger.other += price
        cdnSteps[region.rawValue] = steps + 1
    }

    /// Weekly CDN + platform upkeep.
    var weeklyTechCost: Double {
        let cdn = cdnSteps.keys.sorted().reduce(0.0) { $0 + Double(cdnSteps[$1] ?? 0) } * Formulas.cdnStepUpkeepPerWeek
            * Formulas.cdnCostMultiplier(engineeringLevel: staff.engineering)
        let apps = platforms.reduce(0.0) { $0 + $1.weeklyUpkeep }
        return cdn + apps
    }

    // MARK: Staff

    mutating func hire(_ department: Department) throws {
        guard outcome == .playing else { throw ActionError.gameOver }
        let level = staff[department]
        guard level < Formulas.maxDepartmentLevel else {
            throw ActionError.invalidProject("\(department.displayName) is already fully staffed.")
        }
        let cost = Formulas.hireCost(currentLevel: level)
        guard finances.cash >= cost else { throw ActionError.insufficientFunds(needed: cost) }
        finances.cash -= cost
        finances.ledger.other += cost
        staff[department] = level + 1
    }

    mutating func reduceStaff(_ department: Department) throws {
        guard staff[department] > 0 else { throw ActionError.invalidAmount }
        staff[department] -= 1
    }

    var weeklySalaries: Double { Double(staff.totalLevels) * Formulas.salaryPerLevelPerWeek }

    /// License price after the Content department's discount.
    func licensePrice(_ title: Title) -> Double {
        guard let license = title.license else { return 0 }
        return license.cost * (1 - Formulas.licenseDiscount(contentLevel: staff.content))
    }

    var loanRate: Double {
        max(0.04, Formulas.loanRate(profitable: finances.recentWeeklyProfit >= 0)
            - Formulas.loanRateDiscount(financeLevel: staff.finance))
    }
}
