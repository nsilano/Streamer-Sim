import SwiftUI

struct RivalsView: View {
    @EnvironmentObject var store: GameStore

    var body: some View {
        NavigationStack {
            List {
                if let state = store.state {
                    let board = state.leaderboard
                    let total = max(1, board.reduce(0) { $0 + $1.subs })
                    let leader = board.first?.subs ?? 0
                    Section("Global leaderboard") {
                        ForEach(Array(board.enumerated()), id: \.element.id) { index, entry in
                            let delta = entry.subs - (state.previousSubs[entry.id] ?? entry.subs)
                            if let rival = state.rivals.first(where: { $0.id == entry.id }) {
                                NavigationLink {
                                    RivalDetailView(rival: rival)
                                } label: { row(index + 1, entry, share: entry.subs / total, delta: delta) }
                            } else {
                                row(index + 1, entry, share: entry.subs / total, delta: delta)
                            }
                        }
                    }
                    if let me = board.first(where: { $0.isPlayer }), me.subs < leader {
                        Section {
                            LabeledValue(label: "Gap to #1", value: Format.count(leader - me.subs), tint: .orange)
                        }
                    }
                }
            }
            .navigationTitle("Rivals")
        }
    }

    private func row(_ rank: Int, _ entry: LeaderboardEntry, share: Double, delta: Double) -> some View {
        HStack {
            Text("\(rank)").font(.title3.bold()).frame(width: 28)
            VStack(alignment: .leading) {
                Text(entry.name).fontWeight(entry.isPlayer ? .bold : .regular)
                Text("\(Format.percent(share)) of all subs").font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text(Format.count(entry.subs)).monospacedDigit()
                Text("\(delta >= 0 ? "+" : "-")\(Format.count(abs(delta)))/wk")
                    .font(.caption2).foregroundStyle(delta >= 0 ? .green : .red)
            }
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
                LabeledValue(label: "Countries", value: "\(rival.countryCount) / \(CountryData.all.count)")
                LabeledValue(label: "Pricing", value: rival.priceLevel < 0.95 ? "Cutting prices" : rival.priceLevel > 1.05 ? "Raised prices" : "Normal")
            }
            Section("By country") {
                ForEach(rival.subs.keys.sorted { (rival.subs[$0] ?? 0) > (rival.subs[$1] ?? 0) }, id: \.self) { code in
                    LabeledValue(label: "\(CountryData.country(code)?.flag ?? "") \(CountryData.country(code)?.name ?? code)",
                                 value: Format.count(rival.subs[code] ?? 0))
                }
            }
        }
        .navigationTitle(rival.name)
    }
}
