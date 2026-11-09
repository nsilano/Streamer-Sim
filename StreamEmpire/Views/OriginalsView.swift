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
                    Label("Commission an original", systemImage: "plus.circle.fill")
                }
                .disabled(state.projects.count >= Formulas.maxConcurrentProjects)
            }
            Section("In production (\(state.projects.count)/\(Formulas.maxConcurrentProjects))") {
                if state.projects.isEmpty {
                    Text("Nothing in production.").foregroundStyle(.secondary)
                }
                ForEach(state.projects) { project in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(project.name).font(.headline)
                        Text("\(project.kind.displayName) · \(project.genre.displayName) · \(project.language.displayName) · \(Format.money(project.budget))")
                            .font(.caption).foregroundStyle(.secondary)
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

    private var range: ClosedRange<Double> { Formulas.budgetRange(kind) }
    private var expected: Double {
        Formulas.expectedOriginalQuality(kind: kind, budget: min(max(budget, range.lowerBound), range.upperBound), weeks: weeks)
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
                Section("Budget & schedule") {
                    Stepper(value: $budget, in: range, step: kind == .movie ? 500_000 : 2_000_000) {
                        LabeledValue(label: "Budget", value: Format.money(budget))
                    }
                    Stepper(value: $weeks, in: Formulas.productionWeeksRange) {
                        LabeledValue(label: "Production", value: "\(weeks) weeks")
                    }
                    LabeledValue(label: "Weekly cost", value: Format.money(budget / Double(weeks)))
                    LabeledValue(label: "Expected quality", value: String(format: "~%.0f (±22)", expected))
                    Text("Bigger budgets and longer schedules raise quality, but hits are never guaranteed.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section {
                    Button("Start production") {
                        store.perform {
                            try $0.commissionOriginal(kind: kind, genre: genre, language: language,
                                                      budget: budget, weeks: weeks)
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
