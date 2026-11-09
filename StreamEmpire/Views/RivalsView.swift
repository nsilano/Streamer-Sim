import SwiftUI

struct RivalsView: View {
    @EnvironmentObject var store: GameStore

    var body: some View {
        NavigationStack {
            List {
                if let state = store.state {
                    Section("Global leaderboard") {
                        ForEach(Array(state.leaderboard.enumerated()), id: \.element.id) { index, entry in
                            if let rival = state.rivals.first(where: { $0.id == entry.id }) {
                                NavigationLink {
                                    RivalDetailView(rival: rival)
                                } label: { row(index + 1, entry) }
                            } else {
                                row(index + 1, entry)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Rivals")
        }
    }

    private func row(_ rank: Int, _ entry: LeaderboardEntry) -> some View {
        HStack {
            Text("\(rank)").font(.title3.bold()).frame(width: 28)
            Text(entry.name).fontWeight(entry.isPlayer ? .bold : .regular)
            Spacer()
            Text(Format.count(entry.subs)).monospacedDigit()
        }
        .listRowBackground(entry.isPlayer ? Color.accentColor.opacity(0.15) : nil)
    }
}

struct RivalDetailView: View {
    let rival: Rival

    var body: some View {
        List {
            Section("Overview") {
                LabeledValue(label: "Personality", value: rival.personality.displayName)
                LabeledValue(label: "Global subscribers", value: Format.count(rival.totalSubs))
                LabeledValue(label: "Cash", value: Format.money(rival.cash))
                LabeledValue(label: "Catalog strength", value: String(format: "%.0f / 100", rival.catalogStrength))
            }
            Section("In your markets") {
                ForEach(rival.subs.keys.sorted(), id: \.self) { code in
                    LabeledValue(label: "\(CountryData.country(code)?.flag ?? "") \(CountryData.country(code)?.name ?? code)",
                                 value: Format.count(rival.subs[code] ?? 0))
                }
            }
        }
        .navigationTitle(rival.name)
    }
}
