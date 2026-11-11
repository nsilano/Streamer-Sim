import Foundation

extension GameState {
    /// What to do next, most urgent first: your warnings plus opportunities worth acting on.
    func recommendations() -> [Advice] {
        var items = advice().filter { $0.id != "expiring" }
        let expiring = advice().filter { $0.id == "expiring" }

        // Best new market to open: big, can pay, cheap to launch.
        let affordable = CountryData.all.filter {
            markets[$0.code]?.status == .notLaunched && launchBlocker(code: $0.code) == nil
                && finances.cash > 4 * launchPrice($0)
        }
        if let best = affordable.max(by: { value(of: $0) < value(of: $1) }) {
            items.append(Advice(id: "rec-launch-\(best.code)", icon: "globe.europe.africa.fill", urgent: false,
                                title: "Open \(best.name) \(best.flag)",
                                detail: "\(best.sizeHint), \(best.incomeHint.lowercased()). Launching costs \(Format.money(launchPrice(best))) and takes \(Formulas.marketLaunchWeeks) weeks."))
        }

        let live = liveMarketCodes
        if catalog.count < 6 * live.count + 6, !licenseMarket.isEmpty {
            items.append(Advice(id: "rec-catalog", icon: "film.stack", urgent: false, title: "Grow your catalog",
                                detail: "\(catalog.count) titles is thin for \(live.count) market\(live.count == 1 ? "" : "s"). More titles raise appeal and cut churn. Try renewals, a library deal or a licensing manager."))
        }

        for code in live {
            let market = markets[code]!
            if market.piracy > 0.15, let country = CountryData.country(code) {
                items.append(Advice(id: "rec-piracy-\(code)", icon: "eye.trianglebadge.exclamationmark.fill", urgent: false,
                                    title: "Piracy is costing you in \(country.name)",
                                    detail: "\(Format.percent(market.piracy)) of would-be customers pirate instead. Lower the price or add titles people want."))
            }
        }

        if anySignupsPaused {
            items.append(Advice(id: "rec-signups", icon: "person.crop.circle.badge.xmark", urgent: false,
                                title: "New sign-ups are paused \(pausedSignupsText)",
                                detail: "You're not gaining customers there. Switch it off (Dashboard or Company > Tech & team) once your servers have headroom."))
        }
        if !sportsOffers.isEmpty {
            items.append(Advice(id: "rec-sports", icon: "sportscourt.fill", urgent: false, title: "Sports rights are up for auction",
                                detail: "Live sport cuts churn in its region. See Company > Business."))
        }
        if !acquisitionOffers.isEmpty {
            items.append(Advice(id: "rec-acq", icon: "building.2.crop.circle.fill", urgent: false, title: "Something is for sale",
                                detail: "A film library or studio is on offer for a limited time. See Company > Business."))
        }
        if features.isEmpty, finances.cash > 5_000_000, totalSubscribers > 200_000 {
            items.append(Advice(id: "rec-features", icon: "iphone.gen3", urgent: false, title: "Improve the product",
                                detail: "Kids profiles, downloads, 4K and recommendations all reduce churn. See Company > Business."))
        }
        // Urgent first, expiring titles right behind them, then the rest in order.
        let urgent = items.filter(\.urgent)
        return urgent + expiring + items.filter { !$0.urgent }
    }

    private func value(of country: Country) -> Double {
        country.households * min(1.5, country.priceTolerance / 8) / max(0.1, launchPrice(country) / 1_000_000)
    }
}
