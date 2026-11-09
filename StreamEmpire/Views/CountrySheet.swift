import SwiftUI

/// Everything about one country: your service overall, your business there, the market, plans and rivals.
struct CountrySheet: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.dismiss) private var dismiss
    let code: String

    var body: some View {
        NavigationStack {
            ScrollView {
                if let state = store.state, let country = CountryData.country(code), let market = state.markets[code] {
                    VStack(alignment: .leading, spacing: 14) {
                        hero(country, market, state)
                        serviceCard(state)
                        switch market.status {
                        case .notLaunched: launchCard(country, state)
                        case .launching(let weeks): launchingCard(weeks)
                        case .live:
                            hereCard(country, market)
                            plansCard(country, market, state)
                            marketingCard(country, market)
                        }
                        marketCard(country)
                        rivalsCard(country, state)
                    }
                    .padding(16)
                }
            }
            .artScreen()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Done") { dismiss() } }
        }
    }

    // MARK: Hero & service

    private func hero(_ country: Country, _ market: MarketState, _ state: GameState) -> some View {
        let status = state.mapStatus(code)
        return HStack(spacing: 14) {
            Text(country.flag).font(.system(size: 54))
            VStack(alignment: .leading, spacing: 5) {
                Text(country.name).font(Theme.display(28)).foregroundStyle(.white)
                HStack(spacing: 6) {
                    Pill(text: MapPalette.name(status), tint: MapPalette.color(status))
                    Pill(text: country.region.displayName, tint: Theme.teal)
                    Pill(text: country.language.displayName, tint: Theme.amber)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func serviceCard(_ state: GameState) -> some View {
        let worst = Region.allCases.map { (region: $0, load: state.serverLoad($0)) }.max { $0.load < $1.load }
        return VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "Your service overall", icon: "play.rectangle.fill", tint: Theme.magenta)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                tile("Subscribers", Format.count(state.totalSubscribers))
                tile("Revenue / wk", Format.money(state.finances.lastWeek.revenue))
                tile("Global rank", "#\(state.rank)")
                tile("Markets", "\(state.liveMarketCodes.count)")
                tile("Catalog", "\(state.catalog.count)")
                tile("Reach", Format.percent(state.platformReach))
            }
            if let worst, worst.load > 0 {
                StatBar(label: "Busiest servers (\(worst.region.displayName))", value: min(1, worst.load),
                        text: Format.percent(worst.load),
                        tint: worst.load > 1 ? Theme.danger : (worst.load > 0.85 ? Theme.amber : Theme.good), compact: true)
            }
        }
        .artCard(tint: Theme.magenta)
    }

    private func tile(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased()).font(.system(size: 9, weight: .heavy)).tracking(0.8).foregroundStyle(Theme.text2)
            Text(value).font(Theme.number(17)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Launch

    private func launchCard(_ country: Country, _ state: GameState) -> some View {
        let blocker = state.launchBlocker(code: code)
        return VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "Launch here", icon: "paperplane.fill", tint: Theme.violet)
            LabeledValue(label: "Launch cost", value: Format.money(country.launchCost))
            LabeledValue(label: "Setup time", value: "4 weeks")
            if let blocker {
                Label(blocker, systemImage: "lock.fill").font(.footnote).foregroundStyle(Theme.amber)
            }
            Button("Launch in \(country.name)") {
                store.perform { try $0.launchMarket(code: code) }
            }
            .buttonStyle(GlowButtonStyle(tint: Theme.violet))
            .disabled(blocker != nil)
        }
        .artCard(tint: Theme.violet)
    }

    private func launchingCard(_ weeks: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(text: "Launching", icon: "hourglass", tint: Theme.amber)
            Text("Going live in \(weeks) week\(weeks == 1 ? "" : "s").").foregroundStyle(.white)
            StatBar(label: "Setup", value: Double(4 - weeks) / 4, text: "\(4 - weeks)/4 weeks", tint: Theme.amber)
        }
        .artCard(tint: Theme.amber)
    }

    // MARK: Live business

    private func hereCard(_ country: Country, _ market: MarketState) -> some View {
        let total = market.subs.total
        let share = total / country.subscriberCeiling
        return VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "Your business here", icon: "chart.bar.fill", tint: Theme.teal)
            HStack {
                BigStat(title: "Subscribers", value: Format.count(total))
                BigStat(title: "Market share", value: Format.percent(share), subtitle: "of all streaming subs")
            }
            StatBar(label: "Brand awareness", value: market.awareness, tint: Theme.magenta)
            if total > 0 {
                Text("Plan mix").font(.caption).foregroundStyle(Theme.text2)
                StackedBar(segments: [
                    .init(id: "ad", value: market.subs.ad / total, color: Theme.amber),
                    .init(id: "std", value: market.subs.standard / total, color: Theme.teal),
                    .init(id: "prem", value: market.subs.premium / total, color: Theme.magenta),
                ])
                HStack(spacing: 12) {
                    mixLegend("Ad-supported", market.subs.ad, Theme.amber)
                    mixLegend("Standard", market.subs.standard, Theme.teal)
                    mixLegend("Premium", market.subs.premium, Theme.magenta)
                }
            }
        }
        .artCard(tint: Theme.teal)
    }

    private func mixLegend(_ name: String, _ value: Double, _ color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text("\(name) \(Format.count(value))").font(.caption2).foregroundStyle(Theme.text2)
        }
    }

    // MARK: Plans (tiers)

    private func plansCard(_ country: Country, _ market: MarketState, _ state: GameState) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(text: "Subscription plans", icon: "rectangle.stack.fill", tint: Theme.amber)
            ForEach(Tier.allCases) { tier in
                tierRow(tier, country, market, state)
                if tier != .premium { Divider().overlay(Color.white.opacity(0.10)) }
            }
            Button("Reset prices to fair") {
                let fair = CountryData.defaultPrices(for: country)
                store.perform { try $0.setPrices(code: code, prices: fair) }
            }
            .buttonStyle(SoftButtonStyle(tint: Theme.amber))
            Text(priceHint(market, country)).font(.caption).foregroundStyle(Theme.text2)
        }
        .artCard(tint: Theme.amber)
    }

    private func tierRow(_ tier: Tier, _ country: Country, _ market: MarketState, _ state: GameState) -> some View {
        let isLive = market.liveTiers.contains(tier)
        let build = market.tierBuilds.first { $0.tier == tier }
        let cost = Formulas.tierLaunchCost(tier, in: country)
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(tier.displayName).font(.headline).foregroundStyle(.white)
                Spacer()
                if isLive {
                    Pill(text: "Live", tint: Theme.good, icon: "checkmark")
                } else if let build {
                    Pill(text: "Setting up · \(build.weeksLeft) wk", tint: Theme.amber, icon: "hourglass")
                } else {
                    Pill(text: "Not launched", tint: Theme.text2)
                }
            }
            Text(Formulas.tierBlurb(tier)).font(.caption).foregroundStyle(Theme.text2)
            if isLive {
                Stepper(value: priceBinding(tier, market), in: 0...100, step: 0.5) {
                    LabeledValue(label: "Monthly price", value: String(format: "$%.2f", market.prices[tier]))
                }
            } else if build == nil {
                Button("Launch \(tier.displayName) · \(Format.money(cost)) · \(Formulas.tierLaunchWeeks(tier)) weeks") {
                    store.perform { try $0.launchTier(tier, code: code) }
                }
                .buttonStyle(SoftButtonStyle(tint: Theme.violet))
                .disabled(state.finances.cash < cost)
            }
        }
    }

    private func priceHint(_ market: MarketState, _ country: Country) -> String {
        let ratio = market.prices.standard / country.priceTolerance
        let fair = String(format: "$%.2f", country.priceTolerance)
        if ratio > 1.3 { return "Standard is well above the fair price (\(fair)): expect slow sign-ups and high churn." }
        if ratio > 1.05 { return "Standard is above the fair price (\(fair))." }
        if ratio < 0.7 { return "Standard is far below the fair price (\(fair)): fast sign-ups, thin margins." }
        return "Standard is near the fair price (\(fair))."
    }

    private func priceBinding(_ tier: Tier, _ market: MarketState) -> Binding<Double> {
        Binding(
            get: { market.prices[tier] },
            set: { newValue in
                var prices = market.prices
                prices[tier] = newValue
                store.perform { try $0.setPrices(code: code, prices: prices) }
            })
    }

    private func marketingCard(_ country: Country, _ market: MarketState) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(text: "Marketing", icon: "megaphone.fill", tint: Theme.magenta)
            Stepper(value: Binding(get: { market.marketingBudget },
                                   set: { v in store.perform { try $0.setMarketing(code: code, weeklyBudget: v) } }),
                    in: 0...1_000_000, step: 5_000) {
                LabeledValue(label: "Weekly budget", value: Format.money(market.marketingBudget))
            }
            Text("Marketing builds awareness, which fades without spending. A great catalog makes it work much harder.")
                .font(.caption).foregroundStyle(Theme.text2)
        }
        .artCard(tint: Theme.magenta)
    }

    // MARK: Market & rivals

    private func marketCard(_ country: Country) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "The market", icon: "globe", tint: Theme.violet)
            LabeledValue(label: "Broadband households", value: String(format: "%.1fM", country.households))
            LabeledValue(label: "Subscriptions it can hold", value: Format.count(country.subscriberCeiling))
            LabeledValue(label: "Subscriptions per household", value: String(format: "%.1f", country.subscriptionsPerHousehold))
            LabeledValue(label: "Fair monthly price", value: String(format: "$%.2f", country.priceTolerance))
            StatBar(label: "Ad market strength", value: country.adStrength, tint: Theme.amber, compact: true)
            StatBar(label: "Regulatory risk", value: country.regulatoryRisk,
                    tint: country.regulatoryRisk > 0.25 ? Theme.danger : Theme.good, compact: true)
            StatBar(label: "Local content quota", value: country.localQuota, tint: Theme.teal, compact: true)
            Text("What people like to watch").font(.caption.weight(.bold)).foregroundStyle(.white).padding(.top, 4)
            ForEach(Genre.allCases) { genre in
                StatBar(label: genre.displayName, value: min(1, country.taste(genre) / 2.0),
                        text: String(format: "%.1fx", country.taste(genre)), tint: Theme.violet, height: 5, compact: true)
            }
        }
        .artCard(tint: Theme.violet)
    }

    private func rivalsCard(_ country: Country, _ state: GameState) -> some View {
        let ceiling = country.subscriberCeiling
        let present = state.rivals.filter { ($0.subs[code] ?? 0) > 0 }.sorted { ($0.subs[code] ?? 0) > ($1.subs[code] ?? 0) }
        let mine = state.markets[code]?.subs.total ?? 0
        var segments: [StackedBar.Segment] = []
        if mine > 0 { segments.append(.init(id: "me", value: mine / ceiling, color: Theme.magenta)) }
        for (index, rival) in present.enumerated() {
            let hue = Double(index) / Double(max(1, present.count))
            segments.append(.init(id: rival.id, value: (rival.subs[code] ?? 0) / ceiling,
                                  color: Color(hue: 0.55 + hue * 0.4, saturation: 0.45, brightness: 0.85)))
        }
        return VStack(alignment: .leading, spacing: 8) {
            SectionTitle(text: "Who you're up against", icon: "person.3.fill", tint: Theme.danger)
            if present.isEmpty {
                Text("No rivals have launched here yet.").font(.footnote).foregroundStyle(Theme.text2)
            } else {
                StackedBar(segments: segments)
                Text("Pink is you. The unfilled part of the bar is room still up for grabs.")
                    .font(.caption2).foregroundStyle(Theme.text2)
                ForEach(present.prefix(8)) { rival in
                    HStack {
                        Text(rival.name).font(.subheadline).foregroundStyle(.white)
                        if rival.priceLevel < 0.95 { Pill(text: "Price cuts", tint: Theme.danger) }
                        Spacer()
                        Text("\(Format.count(rival.subs[code] ?? 0)) · \(Format.percent((rival.subs[code] ?? 0) / ceiling))")
                            .font(.caption).foregroundStyle(Theme.text2).monospacedDigit()
                    }
                }
            }
        }
        .artCard(tint: Theme.danger)
    }
}
