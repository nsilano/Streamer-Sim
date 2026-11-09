import SwiftUI

private let startingRivals = RivalData.initialRivals()

struct NewGameView: View {
    @EnvironmentObject var store: GameStore
    @State private var companyName = ""
    @State private var selected = "IE"
    @State private var search = ""
    @State private var showHelp = false
    @State private var difficulty: Difficulty = .medium

    private struct RegionGroup: Identifiable {
        let region: Region
        let countries: [Country]
        var id: String { region.rawValue }
    }

    private var visibleRegions: [RegionGroup] {
        Region.allCases.compactMap { region in
            let countries = CountryData.starters.filter {
                $0.region == region && (search.isEmpty || $0.name.localizedCaseInsensitiveContains(search))
            }
            return countries.isEmpty ? nil : RegionGroup(region: region, countries: countries)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    VStack(alignment: .leading, spacing: 8) {
                        SectionTitle(text: "Your company", icon: "building.2.fill")
                        TextField("Company name", text: $companyName)
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.08)))
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        SectionTitle(text: "Difficulty", icon: "speedometer", tint: Theme.amber)
                        HStack(spacing: 8) {
                            ForEach(Difficulty.allCases) { level in
                                Button { difficulty = level } label: {
                                    VStack(spacing: 4) {
                                        Text(level.title).font(.subheadline.weight(.heavy)).foregroundStyle(.white)
                                        Text(level == .medium ? "Standard costs" : "\(Int(abs(level.costMultiplier - 1) * 100))% \(level.costMultiplier < 1 ? "cheaper" : "costlier")")
                                            .font(.caption2).foregroundStyle(Theme.text2)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(RoundedRectangle(cornerRadius: 14).fill(difficulty == level ? Theme.magenta.opacity(0.35) : Color.white.opacity(0.07)))
                                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(difficulty == level ? Theme.magenta : Color.clear, lineWidth: 2))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        Text(difficulty.blurb).font(.caption).foregroundStyle(Theme.text2)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        SectionTitle(text: "Choose your home market", icon: "globe.europe.africa.fill", tint: Theme.teal)
                        HStack {
                            Image(systemName: "magnifyingglass").foregroundStyle(Theme.text2)
                            TextField("Search countries", text: $search)
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.08)))
                    }
                    ForEach(visibleRegions) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(group.region.displayName).font(Theme.display(20)).foregroundStyle(.white)
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                                ForEach(group.countries) { country in
                                    Button { selected = country.code } label: { tile(country) }
                                        .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    Color.clear.frame(height: 150)
                }
                .padding(.horizontal, 16)
            }
            .artScreen()
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .bottom) { startBar }
            .sheet(isPresented: $showHelp) { HowToPlayView() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Spacer()
                Button("How to play") { showHelp = true }.buttonStyle(SoftButtonStyle())
            }
            Text("STREAM")
                .font(.system(size: 46, weight: .black, design: .serif)).tracking(6)
                .foregroundStyle(Theme.accentGradient)
            Text("EMPIRE")
                .font(.system(size: 46, weight: .black, design: .serif)).tracking(6).foregroundStyle(.white)
                .padding(.top, -14)
            Text("Found a streaming service, win the world. You start with \(Format.money(GameState.startingCash)) and an empty catalog.")
                .font(.footnote).foregroundStyle(Theme.text2)
        }
    }

    private func tile(_ country: Country) -> some View {
        let isSelected = selected == country.code
        return VStack(alignment: .leading, spacing: 4) {
            Text(country.flag).font(.system(size: 34))
            Text(country.name).font(.subheadline.weight(.bold)).foregroundStyle(.white).lineLimit(1)
            Text(country.sizeHint).font(.caption2).foregroundStyle(Theme.amber)
            Text(country.incomeHint).font(.caption2).foregroundStyle(Theme.text2).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .artCard(tint: isSelected ? Theme.magenta : Theme.violet.opacity(0.4))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isSelected ? Theme.magenta : Color.clear, lineWidth: 2)
        )
    }

    private var startBar: some View {
        let country = CountryData.country(selected)
        return VStack(spacing: 10) {
            if let country {
                let rivalSubs = startingRivals.reduce(0.0) { $0 + ($1.subs[country.code] ?? 0) }
                let fill = rivalSubs / country.subscriberCeiling
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("\(country.flag) \(country.name)").font(.headline).foregroundStyle(.white)
                        Spacer()
                        Pill(text: country.sizeHint, tint: Theme.amber)
                        Pill(text: country.language.displayName, tint: Theme.teal)
                    }
                    StatBar(label: "Market already taken by rivals", value: fill, text: Format.percent(fill),
                            tint: fill > 0.6 ? Theme.danger : Theme.violet, compact: true)
                    Text("\(Format.count(country.subscriberCeiling)) subscriptions up for grabs · fair price \(String(format: "$%.0f", country.priceTolerance))/mo")
                        .font(.caption2).foregroundStyle(Theme.text2)
                }
            }
            Button("Found the company") {
                store.newGame(companyName: companyName, country: selected, difficulty: difficulty)
            }
            .buttonStyle(GlowButtonStyle())
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .overlay(Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1), alignment: .top)
    }
}
