import SwiftUI

struct MarketsView: View {
    @EnvironmentObject var store: GameStore

    var body: some View {
        NavigationStack {
            List {
                if let state = store.state {
                    Section {
                        let live = state.liveMarketCodes.count
                        LabeledValue(label: "Live markets", value: "\(live) / \(CountryData.all.count)")
                        LabeledValue(label: "Global subscribers", value: Format.count(state.totalSubscribers))
                    }
                    ForEach(Region.allCases) { region in
                        let countries = CountryData.all.filter { $0.region == region }
                        if !countries.isEmpty {
                            Section(region.displayName) {
                                ForEach(countries) { country in
                                    NavigationLink(value: country.code) {
                                        MarketRow(country: country, market: state.markets[country.code],
                                                  locked: state.launchBlocker(code: country.code) != nil)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Markets")
            .navigationDestination(for: String.self) { code in
                MarketDetailView(code: code)
            }
        }
    }
}

struct MarketRow: View {
    let country: Country
    let market: MarketState?
    var locked = false

    var body: some View {
        HStack {
            Text(country.flag).font(.title)
            VStack(alignment: .leading) {
                Text(country.name)
                Text(statusText).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if let market, market.isLive {
                let share = market.subs.total / country.subscriberCeiling
                VStack(alignment: .trailing) {
                    Text(Format.count(market.subs.total)).bold()
                    Text("\(Format.percent(share)) of market").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var statusText: String {
        switch market?.status ?? .notLaunched {
        case .notLaunched:
            return locked ? "🔒 Locked · \(Format.money(country.launchCost))"
                          : "Not launched · \(Format.money(country.launchCost))"
        case .launching(let weeks): return "Launching · \(weeks) wk left"
        case .live: return "Live"
        }
    }
}

struct MarketDetailView: View {
    @EnvironmentObject var store: GameStore
    let code: String

    var body: some View {
        if let state = store.state, let country = CountryData.country(code), let market = state.markets[code] {
            List {
                Section("\(country.flag) \(country.name)") {
                    LabeledValue(label: "Region", value: country.region.displayName)
                    LabeledValue(label: "Language", value: country.language.displayName)
                    LabeledValue(label: "Broadband households", value: String(format: "%.1fM", country.households))
                    LabeledValue(label: "Subscriber ceiling", value: Format.count(country.subscriberCeiling))
                    LabeledValue(label: "Fair Standard price", value: String(format: "$%.2f", country.priceTolerance))
                    LabeledValue(label: "Ad market", value: Format.percent(country.adStrength))
                    LabeledValue(label: "Regulatory risk", value: Format.percent(country.regulatoryRisk))
                }

                switch market.status {
                case .notLaunched:
                    Section("Launch") {
                        LabeledValue(label: "Launch cost", value: Format.money(country.launchCost))
                        if let reason = state.launchBlocker(code: code) {
                            Label(reason, systemImage: "lock.fill").font(.footnote).foregroundStyle(.orange)
                        }
                        Text("Takes 4 weeks of setup before subscribers can join.")
                            .font(.footnote).foregroundStyle(.secondary)
                        Button("Launch in \(country.name)") {
                            store.perform { try $0.launchMarket(code: code) }
                        }
                    }
                case .launching(let weeks):
                    Section("Launching") {
                        Text("Going live in \(weeks) week\(weeks == 1 ? "" : "s").")
                    }
                case .live:
                    liveSections(country: country, market: market)
                }
                rivalSection(country: country, state: state)
            }
            .navigationTitle(country.name)
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder
    private func liveSections(country: Country, market: MarketState) -> some View {
        Section("Subscribers") {
            LabeledValue(label: "Total", value: Format.count(market.subs.total))
            ForEach(Tier.allCases) { tier in
                LabeledValue(label: tier.displayName, value: Format.count(market.subs[tier]))
            }
            LabeledValue(label: "Brand awareness", value: Format.percent(market.awareness))
        }
        Section("Pricing (per month)") {
            ForEach(Tier.allCases) { tier in
                Stepper(value: priceBinding(tier: tier, market: market), in: 0...100, step: 0.5) {
                    LabeledValue(label: tier.displayName, value: String(format: "$%.2f", market.prices[tier]))
                }
            }
            let ratio = market.prices.standard / country.priceTolerance
            Text(priceHint(ratio: ratio, fair: country.priceTolerance))
                .font(.footnote).foregroundStyle(.secondary)
            Button("Reset to suggested prices") {
                let suggested = CountryData.defaultPrices(for: country)
                store.perform { try $0.setPrices(code: code, prices: suggested) }
            }
        }
        Section("Marketing") {
            Stepper(value: marketingBinding(market: market), in: 0...1_000_000, step: 5_000) {
                LabeledValue(label: "Weekly budget", value: Format.money(market.marketingBudget))
            }
        }
    }

    private func priceHint(ratio: Double, fair: Double) -> String {
        let fairText = String(format: "$%.2f", fair)
        if ratio > 1.3 { return "Standard is well above the fair price (\(fairText)): expect slow sign-ups and high churn." }
        if ratio > 1.05 { return "Standard is above the fair price (\(fairText))." }
        if ratio < 0.7 { return "Standard is far below the fair price (\(fairText)): fast sign-ups, thin margins." }
        return "Standard is near the fair price (\(fairText))."
    }

    @ViewBuilder
    private func rivalSection(country: Country, state: GameState) -> some View {
        let ceiling = country.subscriberCeiling
        let present = state.rivals.filter { ($0.subs[code] ?? 0) > 0 }
            .sorted { ($0.subs[code] ?? 0) > ($1.subs[code] ?? 0) }
        Section("Rivals here") {
            if present.isEmpty {
                Text("No rivals have launched here yet.").foregroundStyle(.secondary)
            }
            ForEach(present) { rival in
                LabeledValue(label: rival.priceLevel < 0.95 ? "\(rival.name) (price cuts)" : rival.name,
                             value: "\(Format.count(rival.subs[code] ?? 0)) · \(Format.percent((rival.subs[code] ?? 0) / ceiling))")
            }
        }
    }

    private func priceBinding(tier: Tier, market: MarketState) -> Binding<Double> {
        Binding(
            get: { market.prices[tier] },
            set: { newValue in
                var prices = market.prices
                prices[tier] = newValue
                store.perform { try $0.setPrices(code: code, prices: prices) }
            })
    }

    private func marketingBinding(market: MarketState) -> Binding<Double> {
        Binding(
            get: { market.marketingBudget },
            set: { newValue in
                store.perform { try $0.setMarketing(code: code, weeklyBudget: newValue) }
            })
    }
}
