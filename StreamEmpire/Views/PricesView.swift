import SwiftUI

/// All pricing in one place (Company > Prices): every country at once, a scale-to-fair-price slider, and each country's own prices.
struct PricesView: View {
    @EnvironmentObject var store: GameStore
    @State private var prices = TierSet(ad: 4.99, standard: 10.99, premium: 16.99)
    @State private var level = 1.0
    @State private var loaded = false

    var body: some View {
        ScrollView {
            if let state = store.state {
                VStack(alignment: .leading, spacing: 14) {
                    allMarketsCard
                    scaleCard
                    countriesCard(state)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .artScreen()
        .navigationTitle("Prices")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if !loaded, let state = store.state, let code = state.liveMarketCodes.first, let market = state.markets[code] {
                prices = market.prices
                loaded = true
            }
        }
    }

    private var allMarketsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(text: "Same price everywhere", icon: "dollarsign.circle.fill", tint: Theme.amber)
            Text("Type a monthly price in dollars and apply it to every country you've launched.")
                .font(.footnote).foregroundStyle(Theme.text2)
            ForEach(Tier.allCases) { tier in
                HStack {
                    Text(tier.displayName).foregroundStyle(.white)
                    Spacer()
                    PriceField(value: prices[tier]) { prices[tier] = $0 }
                }
            }
            Button("Apply to all my markets") { store.perform { try $0.applyPrices(prices) } }
                .buttonStyle(GlowButtonStyle(tint: Theme.amber))
        }
        .artCard(tint: Theme.amber)
    }

    private var scaleCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "Scale to each country", icon: "slider.horizontal.3", tint: Theme.teal)
            Text("A $10 plan is cheap in the US but dear in India. This sets every country to the same share of its own fair price.")
                .font(.footnote).foregroundStyle(Theme.text2)
            Text("\(Format.percent(level)) of fair price").font(Theme.number(24)).foregroundStyle(.white)
            Slider(value: $level, in: 0.4...2.0, step: 0.05).tint(Theme.teal)
            Text(hint).font(.caption).foregroundStyle(Theme.text2)
            Button("Apply scaled prices") { store.perform { try $0.applyPriceLevel(level) } }
                .buttonStyle(SoftButtonStyle(tint: Theme.teal))
        }
        .artCard(tint: Theme.teal)
    }

    private func countriesCard(_ state: GameState) -> some View {
        let codes = state.liveMarketCodes.sorted { (state.markets[$0]?.subs.total ?? 0) > (state.markets[$1]?.subs.total ?? 0) }
        return VStack(alignment: .leading, spacing: 12) {
            SectionTitle(text: "By country", icon: "globe.europe.africa.fill", tint: Theme.violet)
            if codes.isEmpty {
                Text("Launch a market to set its prices.").font(.footnote).foregroundStyle(Theme.text2)
            }
            ForEach(codes, id: \.self) { code in
                if let country = CountryData.country(code), let market = state.markets[code] {
                    countryRow(country, market)
                    if code != codes.last { Divider().overlay(Color.white.opacity(0.1)) }
                }
            }
        }
        .artCard(tint: Theme.violet)
    }

    private func countryRow(_ country: Country, _ market: MarketState) -> some View {
        let ratio = market.prices.standard / max(0.01, country.priceTolerance)
        let tone: Color = ratio > 1.3 ? Theme.danger : ratio > 1.05 ? Theme.amber : ratio < 0.7 ? Theme.teal : Theme.good
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(country.flag) \(country.name)").font(.subheadline.weight(.bold)).foregroundStyle(.white)
                Spacer()
                Text("Fair \(String(format: "$%.2f", country.priceTolerance)) · \(Format.percent(ratio))")
                    .font(.caption).foregroundStyle(tone)
            }
            ForEach(Tier.allCases.filter { market.liveTiers.contains($0) }) { tier in
                HStack {
                    Text(tier.displayName).font(.subheadline).foregroundStyle(Theme.text2)
                    Spacer()
                    PriceField(value: market.prices[tier]) { newValue in
                        var updated = market.prices
                        updated[tier] = newValue
                        store.perform { try $0.setPrices(code: country.code, prices: updated) }
                    }
                }
            }
        }
    }

    private var hint: String {
        if level > 1.3 { return "Well above fair: fat margins, but slow sign-ups and high churn." }
        if level > 1.05 { return "A bit above fair: more profit per subscriber, fewer sign-ups." }
        if level < 0.7 { return "Bargain pricing: fast growth, thin margins." }
        if level < 0.95 { return "A bit below fair: faster growth, a little less money." }
        return "At the fair price: balanced growth and income."
    }
}
