import SwiftUI

struct OriginalsView: View {
    @EnvironmentObject var store: GameStore
    let state: GameState
    @State private var showCommission = false

    var body: some View {
        List {
            Section {
                Button {
                    showCommission = true
                } label: {
                    Label("Start a production", systemImage: "plus.circle.fill")
                }
            }
            StudiosSection(state: state)
            Section("In production (\(state.projects.count))") {
                if state.projects.isEmpty {
                    Text("Nothing in production.").foregroundStyle(.secondary)
                }
                ForEach(state.projects) { project in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(project.name).font(.headline)
                        Text("\(project.kind.displayName) · \(project.genre.displayName) · \(project.language.displayName) · \(Format.money(project.budget))")
                            .font(.caption).foregroundStyle(.secondary)
                        Text(state.studios.first(where: { $0.id == project.studioID })?.name ?? "Outsourced")
                            .font(.caption2).foregroundStyle(.tint)
                        ProgressView(value: project.progress)
                        Text("\(project.weeksLeft) weeks left · \(Format.money(project.weeklyCost))/wk")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
            let released = state.catalog.filter { $0.isOriginal }
            if !released.isEmpty {
                Section("Released originals") {
                    ForEach(released) { TitleRow(title: $0, trailing: "Yours forever") }
                }
            }
        }
        .sheet(isPresented: $showCommission) { CommissionView() }
    }
}

struct CommissionView: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.dismiss) private var dismiss
    @State private var kind: TitleKind = .series
    @State private var genre: Genre = .drama
    @State private var language: Language = .english
    @State private var budget: Double = 10_000_000
    @State private var weeks: Int = 40
    @State private var studioID: Int?

    private var range: ClosedRange<Double> { Formulas.budgetRange(kind) }
    private var expected: Double {
        Formulas.expectedOriginalQuality(kind: kind, budget: min(max(budget, range.lowerBound), range.upperBound), weeks: weeks)
            + Formulas.originalQualityBonus(contentLevel: store.state?.staff.effectiveLevel(.content) ?? 0)
            + studioQualityBonus
    }

    private var chosenStudio: Studio? { store.state?.studios.first { $0.id == studioID } }

    private var studioQualityBonus: Double {
        guard let state = store.state, let studio = chosenStudio else { return 0 }
        return state.studioBonus(for: studio, genre: genre)
    }

    private var costFactor: Double {
        chosenStudio.map { Formulas.inHouseCostFactor(level: $0.level) } ?? 1.0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $kind) {
                        Text("Movie").tag(TitleKind.movie)
                        Text("Series").tag(TitleKind.series)
                    }
                    .pickerStyle(.segmented)
                    Picker("Genre", selection: $genre) {
                        ForEach(Genre.allCases) { Text($0.displayName).tag($0) }
                    }
                    Picker("Language", selection: $language) {
                        ForEach(Language.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                }
                Section("Produced by") {
                    Picker("Produced by", selection: $studioID) {
                        Text("Outsourced").tag(Int?.none)
                        ForEach((store.state?.studios ?? []).filter { (store.state?.freeSlots(at: $0) ?? 0) > 0 }) { studio in
                            Text("\(studio.name) (L\(studio.level))").tag(Int?.some(studio.id))
                        }
                    }
                    if let studio = chosenStudio {
                        Text("In-house cost: \(Format.percent(costFactor)) of the budget · \(studio.specialty.displayName) specialty\(studio.specialty == genre ? " (bonus!)" : "")")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                Section("Budget & schedule") {
                    Stepper(value: $budget, in: range, step: kind == .movie ? 500_000 : 2_000_000) {
                        LabeledValue(label: "Budget", value: Format.money(budget))
                    }
                    Stepper(value: $weeks, in: Formulas.productionWeeksRange) {
                        LabeledValue(label: "Production", value: "\(weeks) weeks")
                    }
                    LabeledValue(label: "Weekly cost", value: Format.money(budget * costFactor / Double(weeks)))
                    LabeledValue(label: "Expected quality", value: String(format: "~%.0f (±22)", expected))
                    Text("Bigger budgets and longer schedules raise quality, but hits are never guaranteed.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section {
                    Button("Start production") {
                        store.perform {
                            try $0.commissionOriginal(kind: kind, genre: genre, language: language,
                                                      budget: budget, weeks: weeks, studioID: studioID)
                        }
                        dismiss()
                    }
                }
            }
            .navigationTitle("New original")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Cancel") { dismiss() } }
            .onChange(of: kind) { _, newKind in
                budget = min(max(budget, Formulas.budgetRange(newKind).lowerBound), Formulas.budgetRange(newKind).upperBound)
                weeks = min(weeks, 52)
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
            if let state = store.state, let title = state.catalog.first(where: { $0.id == titleID }) {
                let languages = targetLanguages(state: state, title: title)
                List {
                    Section("\(title.name) · \(title.language.displayName)") {
                        ForEach(languages, id: \.self) { language in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(language.displayName).font(.headline)
                                HStack {
                                    action("Subtitles", Formulas.subtitleCost(title.kind),
                                           done: title.subtitles.contains(language)) {
                                        store.perform { try $0.localizeTitle(titleID: titleID, language: language, dub: false) }
                                    }
                                    action("Dub", Formulas.dubCost(title.kind),
                                           done: title.dubs.contains(language)) {
                                        store.perform { try $0.localizeTitle(titleID: titleID, language: language, dub: true) }
                                    }
                                }
                            }
                        }
                    }
                    Section {
                        Text("Dubbing counts almost like native-language content (and helps local quotas); subtitles help less.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .navigationTitle("Localize")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { Button("Done") { dismiss() } }
            }
        }
    }

    private func action(_ label: String, _ cost: Double, done: Bool, run: @escaping () -> Void) -> some View {
        Button(done ? "\(label) ✓" : "\(label) \(Format.money(cost))", action: run)
            .buttonStyle(.bordered)
            .disabled(done)
    }

    /// Languages of countries where you are live or launching, other than the title's own.
    private func targetLanguages(state: GameState, title: Title) -> [Language] {
        var set = Set<Language>()
        for (code, market) in state.markets where market.status != .notLaunched {
            if let language = CountryData.country(code)?.language { set.insert(language) }
        }
        return set.filter { $0 != title.language }.sorted { $0.rawValue < $1.rawValue }
    }
}

/// Found, upgrade and review in-house studios.
struct StudiosSection: View {
    @EnvironmentObject var store: GameStore
    let state: GameState
    @State private var specialty: Genre = .drama

    var body: some View {
        Section {
            ForEach(state.studios) { studio in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(studio.name).font(.headline)
                        Spacer()
                        Text("Level \(studio.level)/\(Formulas.maxStudioLevel)").foregroundStyle(.secondary)
                    }
                    Text("\(studio.specialty.displayName) specialty · \(state.freeSlots(at: studio))/\(studio.slots) slots free · \(Format.money(Formulas.studioUpkeep(level: studio.level) * state.staff.studioPay))/wk")
                        .font(.caption).foregroundStyle(.secondary)
                    ProgressView(value: studio.experience, total: 100)
                    Text("Experience \(Int(studio.experience))/100").font(.caption2).foregroundStyle(.secondary)
                    if studio.level < Formulas.maxStudioLevel {
                        let cost = Formulas.studioUpgradeCost(currentLevel: studio.level)
                        Button("Upgrade (\(Format.money(cost)))") {
                            store.perform { try $0.upgradeStudio(id: studio.id) }
                        }
                        .buttonStyle(.bordered)
                        .disabled(state.finances.cash < cost)
                    }
                }
            }
            if state.studios.count < Formulas.maxStudios {
                Picker("Specialty", selection: $specialty) {
                    ForEach(Genre.allCases) { Text($0.displayName).tag($0) }
                }
                Button("Found a studio (\(Format.money(Formulas.studioFoundingCost)))") {
                    store.perform { try $0.foundStudio(specialty: specialty) }
                }
                .disabled(state.finances.cash < Formulas.studioFoundingCost)
            }
        } header: {
            Text("Your studios (\(state.studios.count)/\(Formulas.maxStudios))")
        } footer: {
            Text("In-house productions cost less than outsourcing and get quality bonuses from studio level, experience, a matching genre specialty and well-paid crews. Set crew pay under Company > Tech & staff.")
        }
    }
}
