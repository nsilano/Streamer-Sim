import SwiftUI

struct CompanyView: View {
    @EnvironmentObject var store: GameStore
    @State private var confirmReset = false

    var body: some View {
        NavigationStack {
            List {
                if let state = store.state {
                    let fin = state.finances
                    let week = fin.lastWeek
                    Section("Cash") {
                        LabeledValue(label: "Cash", value: Format.money(fin.cash),
                                     tint: fin.cash >= 0 ? .primary : .red)
                        LabeledValue(label: "Weekly profit / loss", value: Format.money(week.profit),
                                     tint: week.profit.profitColor)
                        LabeledValue(label: "Cash runway",
                                     value: fin.runwayWeeks.map { "\(Int($0)) weeks" } ?? "Profitable")
                        LabeledValue(label: "Annualized revenue", value: Format.money(fin.annualizedRevenue))
                    }
                    Section("Last week") {
                        LabeledValue(label: "Subscription revenue", value: Format.money(week.subscriptionRevenue))
                        LabeledValue(label: "Ad revenue", value: Format.money(week.adRevenue))
                        LabeledValue(label: "Licensing", value: "-" + Format.money(week.licensing))
                        LabeledValue(label: "Streaming / CDN", value: "-" + Format.money(week.streaming))
                        LabeledValue(label: "Staff", value: "-" + Format.money(week.staff))
                        LabeledValue(label: "Marketing", value: "-" + Format.money(week.marketing))
                        LabeledValue(label: "Country operations", value: "-" + Format.money(week.operations))
                    }
                    Section("Coming soon") {
                        Text("Funding: loans, investors, IPO (Phase 3)")
                        Text("Staff departments (Phase 4)")
                        Text("Platforms & infrastructure (Phase 4)")
                    }
                    .foregroundStyle(.secondary)
                    Section {
                        Button("Abandon company & start over", role: .destructive) { confirmReset = true }
                    }
                }
            }
            .navigationTitle("Company")
            .confirmationDialog("Delete this save and start a new game?", isPresented: $confirmReset,
                                titleVisibility: .visible) {
                Button("Start over", role: .destructive) { store.resetGame() }
            }
        }
    }
}
