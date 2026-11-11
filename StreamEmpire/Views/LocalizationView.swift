import SwiftUI

/// Dubbing and subtitles for the whole catalog at once (Company > Dubs & subs): automatic rules plus one-tap buttons.
struct LocalizationView: View {
    @EnvironmentObject var store: GameStore

    var body: some View {
        ScrollView {
            if let state = store.state {
                VStack(alignment: .leading, spacing: 14) {
                    autoCard(state)
                    nowCard(state)
                    coverageCard(state)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .artScreen()
        .navigationTitle("Dubs & subtitles")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func setPlan(_ change: @escaping (inout LocalizationPlan) -> Void) {
        store.perform { s in
            var plan = s.localization
            change(&plan)
            s.localization = plan
        }
    }

    // MARK: Automatic

    private func autoCard(_ state: GameState) -> some View {
        let plan = state.localization
        return VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "Automatic", icon: "wand.and.stars", tint: Theme.teal)
            Text("Set it once. Every week your localization team works through the catalog for the languages of the countries you operate in, within the weekly budget.")
                .font(.footnote).foregroundStyle(Theme.text2)
            Text("Subtitles").font(.subheadline.weight(.semibold)).foregroundStyle(.white)
            Picker("Subtitles", selection: Binding(get: { plan.subtitles }, set: { v in setPlan { $0.subtitles = v } })) {
                ForEach(SubtitleMode.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            Text("Dubbing").font(.subheadline.weight(.semibold)).foregroundStyle(.white)
            Picker("Dubbing", selection: Binding(get: { plan.dubs }, set: { v in setPlan { $0.dubs = v } })) {
                ForEach(DubMode.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            if plan.dubs == .top {
                Stepper(value: Binding(get: { plan.topCount }, set: { v in setPlan { $0.topCount = v } }), in: 5...200, step: 5) {
                    Text("Top \(plan.topCount) titles per language")
                        .font(.subheadline).foregroundStyle(.white)
                }
            }
            NumberFieldRow(label: "Weekly budget", value: Binding(get: { plan.weeklyBudget }, set: { v in setPlan { $0.weeklyBudget = v } }),
                           range: 0...50_000_000, isMoney: true)
            Text("Dubbing costs several times more than subtitles and lifts appeal more. A dubbed title counts as subtitled too.")
                .font(.caption).foregroundStyle(Theme.text2)
            if let status = state.localizationStatus {
                Text(status).font(.caption).foregroundStyle(Theme.teal)
            }
        }
        .artCard(tint: Theme.teal)
    }

    // MARK: One tap

    private func nowCard(_ state: GameState) -> some View {
        let subs = state.localizeAllPrice(dub: false)
        let subCount = state.localizeAllCount(dub: false)
        let top = state.localization.topCount
        let dubs = state.localizeAllPrice(dub: true, limit: top)
        let dubCount = state.localizeAllCount(dub: true, limit: top)
        return VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "Do it now", icon: "bolt.fill", tint: Theme.amber)
            Text("Everything in one go, for every language you operate in.").font(.footnote).foregroundStyle(Theme.text2)
            Button("Subtitle the whole catalog · \(subCount) jobs · \(Format.money(subs))") {
                store.perform { _ = try $0.localizeAll(dub: false) }
            }
            .buttonStyle(GlowButtonStyle(tint: Theme.teal))
            .disabled(subCount == 0 || state.finances.cash < subs)
            Button("Dub the top \(top) titles per language · \(Format.money(dubs))") {
                store.perform { _ = try $0.localizeAll(dub: true, limit: top) }
            }
            .buttonStyle(SoftButtonStyle(tint: Theme.amber))
            .disabled(dubCount == 0 || state.finances.cash < dubs)
            if subCount == 0 { Text("Every title already has subtitles in your markets' languages.").font(.caption).foregroundStyle(Theme.good) }
        }
        .artCard(tint: Theme.amber)
    }

    // MARK: Coverage

    private func coverageCard(_ state: GameState) -> some View {
        let rows = state.localizationCoverage()
        return VStack(alignment: .leading, spacing: 8) {
            SectionTitle(text: "Coverage", icon: "globe", tint: Theme.violet)
            if rows.isEmpty { Text("Launch a market to see its language.").font(.footnote).foregroundStyle(Theme.text2) }
            ForEach(rows, id: \.language) { row in
                StatBar(label: "\(row.flag) \(row.language.displayName)", value: row.needed == 0 ? 1 : Double(row.subtitled) / Double(row.needed),
                        text: "\(row.subtitled)/\(row.needed) · \(row.dubbed) dubbed", tint: Theme.violet, compact: true)
            }
        }
        .artCard(tint: Theme.violet)
    }
}
