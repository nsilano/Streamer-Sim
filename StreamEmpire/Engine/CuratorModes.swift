import Foundation

extension GameState {
    /// The rules the manager follows this week: your own for Custom, or a preset sized to your finances.
    func effectiveCurator() -> Curator? { curator.map { effective($0) } }

    /// Applies a preset's sizing to a set of rules (Custom is returned unchanged).
    func effective(_ rules: Curator) -> Curator {
        var c = rules
        let mode = c.mode
        guard mode != .custom else { return c }
        let weeklyCosts = max(finances.lastWeek.costs, 100_000)
        let live = Double(max(1, liveMarketCodes.count))
        c.weeklyBudget = mode.revenueShare * max(0, finances.lastWeek.revenue) + mode.cashShare * max(0, finances.cash)
        c.cashReserve = max(2_000_000, mode.reserveWeeks * weeklyCosts)
        c.maxPricePerTitle = max(150_000, c.weeklyBudget * mode.carryWeeks)
        c.minQuality = mode.minQuality
        c.maxYears = mode.maxYears
        c.allowExclusive = mode != .passive
        c.targetCatalogSize = Int(mode == .passive ? 20 + 4 * live : mode == .moderate ? 30 + 6 * live : 60 + 8 * live)
        c.renewMaxPrice = max(c.maxPricePerTitle, 500_000)
        c.renewYears = 2
        c.autoRenew = true
        return c
    }

    /// Unspent allowance can pile up for this many weeks.
    var curatorCarryWeeks: Double { (curator?.mode ?? .custom) == .custom ? 3 : (curator?.mode.carryWeeks ?? 3) }

    /// Presets hold off when cash is running out.
    var curatorRunwayBlock: String? {
        guard let mode = curator?.mode, mode != .custom, let runway = finances.runwayWeeks,
              runway < mode.minRunwayWeeks else { return nil }
        return "Holding off: only \(Int(runway)) weeks of cash left (\(mode.title) needs \(Int(mode.minRunwayWeeks)))."
    }
}
