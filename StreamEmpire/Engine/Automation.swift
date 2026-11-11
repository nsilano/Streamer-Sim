import Foundation

extension GameState {
    /// Rents cloud capacity where servers run hot and returns it where it sits idle, so you don't have to watch load.
    /// Rents at most one block per region per week and only while the cash cushion is healthy.
    mutating func autoScaleCloud() {
        guard autoScale, outcome == .playing else { return }
        for region in Region.allCases {
            let hasLiveMarket = markets.contains { code, market in
                market.isLive && CountryData.country(code)?.region == region
            }
            guard hasLiveMarket else { continue }
            let units = cloudUnits[region.rawValue] ?? 0
            let load = effectiveLoad(region)
            if load >= 0.85, units < Formulas.maxCloudUnits, finances.cash > cloudUnitPrice * 12 {
                cloudUnits[region.rawValue] = units + 1
            } else if load < 0.45, units > 0 {
                cloudUnits[region.rawValue] = units - 1
            }
        }
    }
}
