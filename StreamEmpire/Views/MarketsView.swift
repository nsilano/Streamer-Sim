import SwiftUI

struct CountryRef: Identifiable, Equatable {
    let id: String
}

struct MarketsView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case map = "Map", list = "List"
        var id: String { rawValue }
    }

    @EnvironmentObject var store: GameStore
    @State private var mode: Mode = .map
    @State private var selected: String?
    @State private var sheet: CountryRef?
    @State private var showPrices = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                if let state = store.state {
                    header(state)
                    Picker("View", selection: $mode) {
                        ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)

                    if mode == .map {
                        mapArea(state)
                    } else {
                        listArea(state)
                    }
                }
            }
            .artScreen()
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $sheet) { ref in CountrySheet(code: ref.id) }
            .sheet(isPresented: $showPrices) { PriceToolSheet() }
        }
    }

    // MARK: Header

    private func header(_ state: GameState) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ScreenHeader(title: "World", subtitle: "\(state.liveMarketCodes.count) of \(CountryData.all.count) markets live") {
                Button { showPrices = true } label: {
                    Label("Prices", systemImage: "tag.fill")
                }
                .buttonStyle(SoftButtonStyle(tint: Theme.amber))
            }
            HStack(spacing: 10) {
                miniStat("Subscribers", Format.count(state.totalSubscribers))
                miniStat("Rank", "#\(state.rank)")
                miniStat("Reach", Format.percent(state.platformReach))
            }
        }
        .padding(.horizontal, 16)
    }

    private func miniStat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased()).font(.system(size: 9, weight: .heavy)).tracking(1).foregroundStyle(Theme.text2)
            Text(value).font(Theme.number(17)).foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.07)))
    }

    // MARK: Map

    private func mapArea(_ state: GameState) -> some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(LinearGradient(colors: [Color(red: 0.05, green: 0.09, blue: 0.22), Color(red: 0.03, green: 0.05, blue: 0.14)],
                                         startPoint: .top, endPoint: .bottom))
                WorldMapView(state: state, selected: $selected)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.white.opacity(0.12), lineWidth: 1))
            .frame(maxHeight: 520)
            .padding(.horizontal, 12)

            legend

            if let code = selected, let country = CountryData.country(code) {
                selectionBar(country, state)
            } else {
                Text("Tap a country to see its stats. Pinch to zoom, drag to pan.")
                    .font(.caption).foregroundStyle(Theme.text2).padding(.bottom, 8)
            }
        }
    }

    private var legend: some View {
        HStack(spacing: 12) {
            ForEach([MapStatus.live, .launching, .available, .locked], id: \.rawValue) { status in
                HStack(spacing: 5) {
                    Circle().fill(MapPalette.color(status)).frame(width: 9, height: 9)
                    Text(MapPalette.name(status)).font(.caption2).foregroundStyle(Theme.text2)
                }
            }
        }
    }

    private func selectionBar(_ country: Country, _ state: GameState) -> some View {
        let status = state.mapStatus(country.code)
        let market = state.markets[country.code]
        return Button { sheet = CountryRef(id: country.code) } label: {
            HStack(spacing: 12) {
                Text(country.flag).font(.system(size: 34))
                VStack(alignment: .leading, spacing: 3) {
                    Text(country.name).font(.headline).foregroundStyle(.white)
                    HStack(spacing: 6) {
                        Pill(text: MapPalette.name(status), tint: MapPalette.color(status))
                        if status == .live, let market {
                            Text("\(Format.count(market.subs.total)) subs").font(.caption).foregroundStyle(Theme.text2)
                        } else {
                            Text("Launch \(Format.money(country.launchCost))").font(.caption).foregroundStyle(Theme.text2)
                        }
                    }
                }
                Spacer()
                Image(systemName: "chevron.up.circle.fill").font(.title2).foregroundStyle(Theme.magenta)
            }
            .artCard(tint: MapPalette.color(status))
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .buttonStyle(.plain)
    }

    // MARK: List

    private func listArea(_ state: GameState) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(Region.allCases) { region in
                    let countries = CountryData.all.filter { $0.region == region }
                    if !countries.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            SectionTitle(text: region.displayName, tint: Theme.teal)
                            ForEach(countries) { country in
                                Button { sheet = CountryRef(id: country.code) } label: { row(country, state) }
                                    .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
    }

    private func row(_ country: Country, _ state: GameState) -> some View {
        let status = state.mapStatus(country.code)
        let market = state.markets[country.code]
        return HStack(spacing: 12) {
            Text(country.flag).font(.title)
            VStack(alignment: .leading, spacing: 3) {
                Text(country.name).font(.subheadline.weight(.bold)).foregroundStyle(.white)
                HStack(spacing: 6) {
                    Pill(text: MapPalette.name(status), tint: MapPalette.color(status))
                    if status == .locked {
                        Image(systemName: "lock.fill").font(.caption2).foregroundStyle(Theme.text2)
                    }
                }
            }
            Spacer()
            if status == .live, let market {
                let share = market.subs.total / country.subscriberCeiling
                VStack(alignment: .trailing, spacing: 2) {
                    Text(Format.count(market.subs.total)).font(Theme.number(16)).foregroundStyle(.white)
                    Text("\(Format.percent(share)) of market").font(.caption2).foregroundStyle(Theme.text2)
                }
            } else {
                Text(Format.money(country.launchCost)).font(.caption).foregroundStyle(Theme.text2)
            }
        }
        .artCard(tint: MapPalette.color(status))
    }
}

/// Set every market's prices in one go.
struct PriceToolSheet: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.dismiss) private var dismiss
    @State private var level = 1.0

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Every country has a \"fair price\" people will happily pay. Move everything up or down at once; you can still fine-tune each country on its own page.")
                    .font(.footnote).foregroundStyle(Theme.text2)
                VStack(alignment: .leading, spacing: 10) {
                    Text("\(Format.percent(level)) of fair price").font(Theme.number(30)).foregroundStyle(.white)
                    Slider(value: $level, in: 0.4...2.0, step: 0.05).tint(Theme.magenta)
                    Text(hint).font(.caption).foregroundStyle(Theme.text2)
                }
                .artCard()
                Button("Apply to all my markets") {
                    store.perform { try $0.applyPriceLevel(level) }
                    dismiss()
                }
                .buttonStyle(GlowButtonStyle())
                Spacer()
            }
            .padding(16)
            .artScreen()
            .navigationTitle("Subscription prices")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Cancel") { dismiss() } }
        }
        .presentationDetents([.medium])
    }

    private var hint: String {
        if level > 1.3 { return "Well above fair: fat margins, but slow sign-ups and high churn." }
        if level > 1.05 { return "A bit above fair: more profit per subscriber, fewer sign-ups." }
        if level < 0.7 { return "Bargain pricing: fast growth, thin margins." }
        if level < 0.95 { return "A bit below fair: faster growth, a little less money." }
        return "At the fair price: balanced growth and income."
    }
}
