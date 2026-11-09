import SwiftUI

struct OriginalsView: View {
    @EnvironmentObject var store: GameStore
    let state: GameState
    var onOpen: (Int) -> Void
    @State private var showCommission = false

    private let columns = [GridItem(.adaptive(minimum: 140), spacing: 12, alignment: .top)]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button { showCommission = true } label: {
                Label("Start a production", systemImage: "plus.circle.fill")
            }
            .buttonStyle(GlowButtonStyle(tint: Theme.magenta))

            StudiosSection(state: state)
            productionList
            released
        }
        .sheet(isPresented: $showCommission) { CommissionView() }
    }

    private var productionList: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "In production (\(state.projects.count))", icon: "clapperboard.fill", tint: Theme.amber)
            if state.projects.isEmpty {
                Text("Nothing in production. Start a movie or series above.").font(.footnote).foregroundStyle(Theme.text2)
            }
            ForEach(state.projects) { project in
                HStack(spacing: 12) {
                    PosterView(title: placeholder(project), showsText: false, cornerRadius: 8).frame(width: 64)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(project.name).font(.headline).foregroundStyle(.white)
                        Text("\(project.kind.displayName) · \(project.genre.displayName) · \(project.language.displayName)")
                            .font(.caption).foregroundStyle(Theme.text2)
                        Pill(text: state.studios.first(where: { $0.id == project.studioID })?.name ?? "Outsourced", tint: Theme.violet)
                        StatBar(label: "\(project.weeksLeft) weeks left", value: project.progress,
                                text: "\(Format.money(project.weeklyCost))/wk", tint: Theme.amber, height: 5, compact: true)
                    }
                }
                .artCard(tint: Theme.amber)
            }
        }
    }

    private func placeholder(_ project: OriginalProject) -> Title {
        Title(id: project.id, name: project.name, kind: project.kind, genre: project.genre, language: project.language,
              quality: 0, popularity: 0, ageWeeks: 0, isOriginal: true, license: nil, weeksRemaining: nil, listingWeeksLeft: 0)
    }

    @ViewBuilder
    private var released: some View {
        let originals = state.catalog.filter { $0.isOriginal }
        if !originals.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle(text: "Released originals", icon: "star.circle.fill", tint: Theme.good)
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(originals) { title in
                        Button { onOpen(title.id) } label: {
                            TitleCell(title: title, state: state, priceText: nil, footnote: "Yours forever")
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
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
    private var chosenStudio: Studio? { store.state?.studios.first { $0.id == studioID } }
    private var costFactor: Double { chosenStudio.map { Formulas.inHouseCostFactor(level: $0.level) } ?? 1.0 }

    private var expected: Double {
        let clamped = min(max(budget, range.lowerBound), range.upperBound)
        var value = Formulas.expectedOriginalQuality(kind: kind, budget: clamped, weeks: weeks)
        value += Formulas.originalQualityBonus(contentLevel: store.state?.staff.effectiveLevel(.content) ?? 0)
        if let state = store.state, let studio = chosenStudio { value += state.studioBonus(for: studio, genre: genre) }
        return min(100, value)
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
                    Picker("Genre", selection: $genre) { ForEach(Genre.allCases) { Text($0.displayName).tag($0) } }
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
                        Text("In-house: \(Format.percent(costFactor)) of the budget, \(studio.specialty.displayName) specialty\(studio.specialty == genre ? " (bonus!)" : "")")
                            .font(.footnote).foregroundStyle(Theme.text2)
                    }
                }
                Section("Budget & schedule") {
                    Stepper(value: $budget, in: range, step: kind == .movie ? 500_000 : 2_000_000) {
                        LabeledValue(label: "Budget", value: Format.money(budget))
                    }
                    Stepper(value: $weeks, in: Formulas.productionWeeksRange) {
                        LabeledValue(label: "Production", value: "\(weeks) weeks")
                    }
                    LabeledValue(label: "Weekly cost", value: Format.money(budget * costFactor * (store.state?.costScale ?? 1) / Double(weeks)))
                    StatBar(label: "Expected quality (±22)", value: expected / 100, text: String(format: "~%.0f", expected),
                            tint: Theme.amber)
                    Text("Bigger budgets and longer schedules raise quality, but hits are never guaranteed.")
                        .font(.footnote).foregroundStyle(Theme.text2)
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
            .artScreen()
            .navigationTitle("New production")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Cancel") { dismiss() } }
            .onChange(of: kind) { _, newKind in
                let r = Formulas.budgetRange(newKind)
                budget = min(max(budget, r.lowerBound), r.upperBound)
            }
        }
    }
}

/// Found, upgrade and review in-house studios.
struct StudiosSection: View {
    @EnvironmentObject var store: GameStore
    let state: GameState
    @State private var specialty: Genre = .drama

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "Your studios (\(state.studios.count)/\(Formulas.maxStudios))", icon: "building.columns.fill", tint: Theme.violet)
            if state.studios.isEmpty {
                Text("Studios make shows in-house: cheaper than outsourcing, and they get better with every release.")
                    .font(.footnote).foregroundStyle(Theme.text2)
            }
            ForEach(state.studios) { studio in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(studio.name).font(.headline).foregroundStyle(.white)
                        Spacer()
                        PipRow(level: studio.level, max: Formulas.maxStudioLevel, tint: Theme.violet)
                    }
                    Text("\(studio.specialty.displayName) specialty · \(state.freeSlots(at: studio))/\(studio.slots) slots free · \(Format.money(state.studioUpkeepPrice(studio)))/wk")
                        .font(.caption).foregroundStyle(Theme.text2)
                    StatBar(label: "Experience", value: studio.experience / 100, text: "\(Int(studio.experience))/100", tint: Theme.violet, height: 5, compact: true)
                    if studio.level < Formulas.maxStudioLevel {
                        let cost = state.studioUpgradePrice(studio)
                        Button("Upgrade · \(Format.money(cost))") { store.perform { try $0.upgradeStudio(id: studio.id) } }
                            .buttonStyle(SoftButtonStyle(tint: Theme.violet))
                            .disabled(state.finances.cash < cost)
                    }
                }
                .artCard(tint: Theme.violet)
            }
            if state.studios.count < Formulas.maxStudios {
                HStack {
                    Picker("Specialty", selection: $specialty) { ForEach(Genre.allCases) { Text($0.displayName).tag($0) } }
                    Spacer()
                    Button("Found · \(Format.money(state.studioFoundingPrice))") {
                        store.perform { try $0.foundStudio(specialty: specialty) }
                    }
                    .buttonStyle(SoftButtonStyle(tint: Theme.violet))
                    .disabled(state.finances.cash < state.studioFoundingPrice)
                }
            }
        }
    }
}
