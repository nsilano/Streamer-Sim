import SwiftUI

/// Opens (and stops the sim) when licenses cross 12 or 4 weeks left, so you can renew before they go.
struct ExpiringSheet: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.dismiss) private var dismiss
    @State private var years = 2

    var body: some View {
        NavigationStack {
            ScrollView {
                if let state = store.state {
                    VStack(alignment: .leading, spacing: 12) {
                        let expiring = state.expiringTitles
                        Label("\(expiring.count) license\(expiring.count == 1 ? "" : "s") expiring", systemImage: "clock.badge.exclamationmark.fill")
                            .font(Theme.display(24)).foregroundStyle(Theme.danger)
                        Text("The sim is paused. Renew now to keep these titles, or let them go.")
                            .font(.footnote).foregroundStyle(Theme.text2)
                        if !expiring.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Stepper(value: $years, in: 1...5) {
                                    LabeledValue(label: "Renew all for", value: "\(years) year\(years == 1 ? "" : "s")")
                                }
                                let total = state.renewAllPrice(years: years)
                                Button("Renew all · \(Format.money(total))") {
                                    store.perform { _ = try $0.renewAll(years: years) }
                                }
                                .buttonStyle(GlowButtonStyle(tint: Theme.danger))
                                .disabled(state.finances.cash < (expiring.map { state.renewalPrice($0, years: years) }.min() ?? .infinity))
                                if state.finances.cash < total {
                                    Text("Not enough cash for all of them: Renew all keeps as many as you can afford, cheapest first.")
                                        .font(.caption).foregroundStyle(Theme.amber)
                                }
                            }
                            .artCard(tint: Theme.danger)
                        }
                        Toggle(isOn: Binding(get: { state.autoRenewAll },
                                             set: { on in store.perform { $0.autoRenewAll = on } })) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Always auto-renew").foregroundStyle(.white)
                                Text("Every license is renewed for 2 years two weeks before it expires, if you have the cash.")
                                    .font(.caption).foregroundStyle(Theme.text2)
                            }
                        }
                        .tint(Theme.good)
                        .artCard(tint: Theme.good)
                        ForEach(expiring) { title in
                            RenewCard(title: title, state: state, onDone: nil)
                        }
                    }
                    .padding(16)
                }
            }
            .artScreen()
            .navigationTitle("Expiring licenses")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Done") { dismiss() } }
        }
    }
}
