import SwiftUI

struct TitleRef: Identifiable, Equatable {
    let id: Int
}

struct ContentTabView: View {
    enum Section: String, CaseIterable, Identifiable {
        case licensing = "Licensing", catalog = "Catalog", originals = "Originals"
        var id: String { rawValue }
    }

    enum Sort: String, CaseIterable, Identifiable {
        case fit = "Best fit", quality = "Quality", popularity = "Popularity", cheapest = "Cheapest", ending = "Ending soon"
        var id: String { rawValue }
    }

    @EnvironmentObject var store: GameStore
    @State private var section: Section = .licensing
    @State private var sort: Sort = .fit
    @State private var detail: TitleRef?
    @State private var showCurator = false

    private let columns = [GridItem(.adaptive(minimum: 140), spacing: 12, alignment: .top)]

    var body: some View {
        NavigationStack {
            ScrollView {
                if let state = store.state {
                    VStack(alignment: .leading, spacing: 14) {
                        ScreenHeader(title: "Content", subtitle: "\(state.catalog.count) titles · \(state.projects.count) in production")
                        Picker("Section", selection: $section) {
                            ForEach(Section.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)

                        switch section {
                        case .licensing: licensing(state)
                        case .catalog: catalog(state)
                        case .originals: OriginalsView(state: state, onOpen: { detail = TitleRef(id: $0) })
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
            .artScreen()
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $detail) { ref in TitleDetailSheet(titleID: ref.id) }
            .sheet(isPresented: $showCurator) { CuratorSheet() }
        }
    }

    // MARK: Licensing

    private func licensing(_ state: GameState) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            curatorCard(state)
            HStack {
                SectionTitle(text: "On the market", icon: "tag.fill", tint: Theme.amber)
                Menu {
                    Picker("Sort", selection: $sort) { ForEach(Sort.allCases) { Text($0.rawValue).tag($0) } }
                } label: {
                    Label(sort.rawValue, systemImage: "arrow.up.arrow.down").font(.caption.weight(.semibold))
                }
            }
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(sorted(state.licenseMarket, state)) { title in
                    Button { detail = TitleRef(id: title.id) } label: {
                        TitleCell(title: title, state: state, priceText: Format.money(state.licensePrice(title)),
                                  footnote: "Offer ends in \(title.listingWeeksLeft) wk")
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func sorted(_ titles: [Title], _ state: GameState) -> [Title] {
        switch sort {
        case .fit: return titles.sorted { state.marketFit(of: $0) > state.marketFit(of: $1) }
        case .quality: return titles.sorted { $0.quality > $1.quality }
        case .popularity: return titles.sorted { $0.popularity > $1.popularity }
        case .cheapest: return titles.sorted { state.licensePrice($0) < state.licensePrice($1) }
        case .ending: return titles.sorted { $0.listingWeeksLeft < $1.listingWeeksLeft }
        }
    }

    private func curatorCard(_ state: GameState) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "Licensing manager", icon: "person.crop.rectangle.stack.fill", tint: Theme.teal)
            if let curator = state.curator {
                HStack {
                    Pill(text: curator.enabled ? "Active" : "Paused", tint: curator.enabled ? Theme.good : Theme.amber)
                    Text("\(Format.money(Curator.weeklySalary))/wk salary").font(.caption).foregroundStyle(Theme.text2)
                }
                Text("Buys up to \(Format.money(curator.weeklyBudget)) a week of titles with quality \(curator.minQuality)+ until your catalog reaches \(curator.targetCatalogSize), keeping \(Format.money(curator.cashReserve)) in the bank.")
                    .font(.footnote).foregroundStyle(Theme.text2)
                HStack {
                    Button("Edit rules") { showCurator = true }.buttonStyle(SoftButtonStyle(tint: Theme.teal))
                    Button(curator.enabled ? "Pause" : "Resume") {
                        var updated = curator
                        updated.enabled.toggle()
                        store.perform { try $0.updateCurator(updated) }
                    }
                    .buttonStyle(SoftButtonStyle(tint: Theme.amber))
                    Button("Dismiss") { store.perform { $0.fireCurator() } }
                        .buttonStyle(SoftButtonStyle(tint: Theme.danger))
                }
            } else {
                Text("Hire a manager to keep your library growing on autopilot. You set the budget, quality bar, genres and limits; they shop the market every week.")
                    .font(.footnote).foregroundStyle(Theme.text2)
                Button("Hire · \(Format.money(Curator.hireCost)) + \(Format.money(Curator.weeklySalary))/wk") {
                    store.perform { try $0.hireCurator() }
                    showCurator = true
                }
                .buttonStyle(GlowButtonStyle(tint: Theme.teal))
                .disabled(state.finances.cash < Curator.hireCost)
            }
        }
        .artCard(tint: Theme.teal)
    }

    // MARK: Catalog

    @ViewBuilder
    private func catalog(_ state: GameState) -> some View {
        if state.catalog.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "film").font(.largeTitle).foregroundStyle(Theme.text2)
                Text("Your catalog is empty").font(.headline).foregroundStyle(.white)
                Text("License titles from the Licensing tab, or produce your own originals.")
                    .font(.footnote).foregroundStyle(Theme.text2).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .artCard()
        } else {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(state.catalog.sorted { $0.quality > $1.quality }) { title in
                    Button { detail = TitleRef(id: title.id) } label: {
                        TitleCell(title: title, state: state, priceText: nil,
                                  footnote: title.weeksRemaining.map { "\($0) wks left" } ?? "Yours forever")
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

/// Poster with bars underneath.
struct TitleCell: View {
    let title: Title
    let state: GameState
    var priceText: String?
    var footnote: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            PosterView(title: title)
            Text(title.name).font(.caption.weight(.bold)).foregroundStyle(.white).lineLimit(1)
            StatBar(label: "Quality", value: Double(title.quality) / 100, tint: Theme.amber, height: 4, compact: true)
            StatBar(label: "Popularity", value: Double(title.popularity) / 100, tint: Theme.magenta, height: 4, compact: true)
            StatBar(label: "Fits your markets", value: state.marketFit(of: title), tint: Theme.violet, height: 4, compact: true)
            HStack {
                if let priceText { Pill(text: priceText, tint: Theme.amber) }
                if let footnote { Text(footnote).font(.system(size: 10)).foregroundStyle(Theme.text2) }
            }
        }
    }
}

/// Full details for one title, with buy / localize actions.
struct TitleDetailSheet: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.dismiss) private var dismiss
    let titleID: Int
    @State private var showLocalize = false

    var body: some View {
        NavigationStack {
            ScrollView {
                if let state = store.state, let title = find(state) {
                    let owned = state.catalog.contains { $0.id == titleID }
                    VStack(spacing: 16) {
                        PosterView(title: title, cornerRadius: 16)
                            .frame(width: 210)
                            .padding(.top, 6)
                        VStack(spacing: 6) {
                            Text(title.name).font(Theme.display(24)).foregroundStyle(.white).multilineTextAlignment(.center)
                            HStack(spacing: 6) {
                                Pill(text: title.kind.displayName, tint: Theme.violet)
                                Pill(text: title.genre.displayName, tint: Theme.magenta)
                                Pill(text: title.language.displayName, tint: Theme.teal)
                                Pill(text: ageText(title), tint: Theme.amber)
                            }
                        }
                        bars(title, state)
                        topMarkets(title, state)
                        if owned { ownedCard(title) } else { licenseCard(title, state) }
                    }
                    .padding(16)
                }
            }
            .artScreen()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Done") { dismiss() } }
            .sheet(isPresented: $showLocalize) { LocalizeView(titleID: titleID) }
        }
    }

    private func find(_ state: GameState) -> Title? {
        state.catalog.first { $0.id == titleID } ?? state.licenseMarket.first { $0.id == titleID }
    }

    private func ageText(_ title: Title) -> String {
        title.ageWeeks < 4 ? "New release" : title.ageWeeks < 52 ? "\(title.ageWeeks) wks old" : "\(title.ageWeeks / 52) yr old"
    }

    private func bars(_ title: Title, _ state: GameState) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(text: "How good is it?", icon: "star.fill", tint: Theme.amber)
            StatBar(label: "Quality", value: Double(title.quality) / 100, tint: Theme.amber)
            Text("Critic and audience scores. Better titles pull in more subscribers.").font(.caption2).foregroundStyle(Theme.text2)
            StatBar(label: "Popularity", value: Double(title.popularity) / 100, tint: Theme.magenta)
            Text("How many people want to watch it. Pairs with quality for appeal.").font(.caption2).foregroundStyle(Theme.text2)
            StatBar(label: "Freshness", value: state.freshness(of: title), tint: Theme.teal)
            Text("New releases get a boost; older titles slowly lose pull.").font(.caption2).foregroundStyle(Theme.text2)
            StatBar(label: "Fit for your markets", value: state.marketFit(of: title), tint: Theme.violet)
            Text("How well its genre and language suit the countries you serve.").font(.caption2).foregroundStyle(Theme.text2)
        }
        .artCard(tint: Theme.amber)
    }

    private func topMarkets(_ title: Title, _ state: GameState) -> some View {
        let rows = state.liveMarketCodes.compactMap { code -> (Country, Double)? in
            guard let country = CountryData.country(code) else { return nil }
            return (country, min(1, Formulas.titleAppeal(title, in: country) / 0.8))
        }.sorted { $0.1 > $1.1 }.prefix(4)
        return VStack(alignment: .leading, spacing: 8) {
            SectionTitle(text: "Best in your markets", icon: "globe", tint: Theme.violet)
            ForEach(Array(rows), id: \.0.code) { row in
                StatBar(label: "\(row.0.flag) \(row.0.name)", value: row.1, tint: Theme.violet, height: 5, compact: true)
            }
        }
        .artCard(tint: Theme.violet)
    }

    private func licenseCard(_ title: Title, _ state: GameState) -> some View {
        let price = state.licensePrice(title)
        return VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "License terms", icon: "signature", tint: Theme.teal)
            if let license = title.license {
                LabeledValue(label: "Price", value: Format.money(price))
                LabeledValue(label: "Length", value: "\(license.years) year\(license.years == 1 ? "" : "s")")
                LabeledValue(label: "Exclusive", value: license.exclusive ? "Yes (+15% appeal)" : "No")
                LabeledValue(label: "Offer ends in", value: "\(title.listingWeeksLeft) weeks")
            }
            Button("Buy for \(Format.money(price))") {
                store.perform { try $0.buyLicense(titleID: titleID) }
                dismiss()
            }
            .buttonStyle(GlowButtonStyle(tint: Theme.teal))
            .disabled(state.finances.cash < price)
        }
        .artCard(tint: Theme.teal)
    }

    private func ownedCard(_ title: Title) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "In your catalog", icon: "checkmark.seal.fill", tint: Theme.good)
            LabeledValue(label: "Rights", value: title.weeksRemaining.map { "\($0) weeks left" } ?? "Owned forever, worldwide")
            if !title.dubs.isEmpty { LabeledValue(label: "Dubbed", value: title.dubs.map(\.displayName).joined(separator: ", ")) }
            if !title.subtitles.isEmpty { LabeledValue(label: "Subtitled", value: title.subtitles.map(\.displayName).joined(separator: ", ")) }
            Button("Add dubbing or subtitles") { showLocalize = true }.buttonStyle(SoftButtonStyle(tint: Theme.violet))
        }
        .artCard(tint: Theme.good)
    }
}

/// Rules for the licensing manager.
struct CuratorSheet: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft = Curator()
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Manager is active", isOn: $draft.enabled).tint(Theme.magenta)
                } footer: {
                    Text("Each week your manager buys the best-value titles that pass every rule below, up to 3 purchases.")
                }
                Section("Spending") {
                    Stepper(value: $draft.weeklyBudget, in: 0...20_000_000, step: 100_000) {
                        LabeledValue(label: "Max per week", value: Format.money(draft.weeklyBudget))
                    }
                    Stepper(value: $draft.maxPricePerTitle, in: 100_000...50_000_000, step: 100_000) {
                        LabeledValue(label: "Max price per title", value: Format.money(draft.maxPricePerTitle))
                    }
                    Stepper(value: $draft.cashReserve, in: 0...100_000_000, step: 500_000) {
                        LabeledValue(label: "Always keep in the bank", value: Format.money(draft.cashReserve))
                    }
                }
                Section("What to buy") {
                    Stepper(value: $draft.minQuality, in: 0...100, step: 5) {
                        LabeledValue(label: "Minimum quality", value: "\(draft.minQuality)")
                    }
                    Stepper(value: $draft.maxYears, in: 1...5) {
                        LabeledValue(label: "Longest license", value: "\(draft.maxYears) yr")
                    }
                    Stepper(value: $draft.targetCatalogSize, in: 0...200, step: 5) {
                        LabeledValue(label: "Stop at catalog size", value: "\(draft.targetCatalogSize)")
                    }
                    Toggle("Movies", isOn: $draft.allowMovies)
                    Toggle("Series", isOn: $draft.allowSeries)
                    Toggle("Allow exclusives", isOn: $draft.allowExclusive)
                    Toggle("Only languages I serve (and English)", isOn: $draft.onlyMyLanguages)
                }
                Section {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 8)], spacing: 8) {
                        ForEach(Genre.allCases) { genre in
                            let on = draft.genres.contains(genre)
                            Button {
                                if on { draft.genres.removeAll { $0 == genre } } else { draft.genres.append(genre) }
                            } label: {
                                Text(genre.displayName).font(.caption.weight(.bold))
                                    .frame(maxWidth: .infinity).padding(.vertical, 8)
                                    .background(Capsule().fill(on ? Theme.magenta.opacity(0.4) : Color.white.opacity(0.08)))
                                    .overlay(Capsule().stroke(on ? Theme.magenta : Color.clear, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } header: {
                    Text("Genres")
                } footer: {
                    Text(draft.genres.isEmpty ? "None selected means any genre." : "Only these genres.")
                }
            }
            .artScreen()
            .navigationTitle("Manager rules")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.perform { try $0.updateCurator(draft) }
                        dismiss()
                    }
                }
            }
            .onAppear {
                if !loaded, let current = store.state?.curator { draft = current; loaded = true }
            }
        }
    }
}

/// Add subtitles or dubbing to a catalog title.
struct LocalizeView: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.dismiss) private var dismiss
    let titleID: Int

    var body: some View {
        NavigationStack {
            ScrollView {
                if let state = store.state, let title = state.catalog.first(where: { $0.id == titleID }) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Dubbing counts almost like native-language content and helps local-content quotas. Subtitles help less but cost less.")
                            .font(.footnote).foregroundStyle(Theme.text2)
                        ForEach(targetLanguages(state: state, title: title), id: \.self) { language in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(language.displayName).font(.headline).foregroundStyle(.white)
                                HStack {
                                    action("Subtitles", Formulas.subtitleCost(title.kind), done: title.subtitles.contains(language)) {
                                        store.perform { try $0.localizeTitle(titleID: titleID, language: language, dub: false) }
                                    }
                                    action("Dub", Formulas.dubCost(title.kind), done: title.dubs.contains(language)) {
                                        store.perform { try $0.localizeTitle(titleID: titleID, language: language, dub: true) }
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .artCard(tint: Theme.violet)
                        }
                    }
                    .padding(16)
                }
            }
            .artScreen()
            .navigationTitle("Localize")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Done") { dismiss() } }
        }
    }

    private func action(_ label: String, _ cost: Double, done: Bool, run: @escaping () -> Void) -> some View {
        Button(done ? "\(label) ✓" : "\(label) · \(Format.money(cost))", action: run)
            .buttonStyle(SoftButtonStyle(tint: done ? Theme.good : Theme.violet))
            .disabled(done)
    }

    private func targetLanguages(state: GameState, title: Title) -> [Language] {
        var set = Set<Language>()
        for code in state.markets.keys.sorted() where state.markets[code]?.status != .notLaunched {
            if let language = CountryData.country(code)?.language { set.insert(language) }
        }
        return set.filter { $0 != title.language }.sorted { $0.rawValue < $1.rawValue }
    }
}
