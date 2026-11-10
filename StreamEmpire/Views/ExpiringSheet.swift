import SwiftUI

/// Opens (and stops the sim) when expiry alerts are set to Stop and licenses near expiry, so you can renew before they go.
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
                        Text("The sim is paused. These didn't renew automatically (too pricey for your auto-renew setting, or auto-renew is off). Renew now to keep them, or let them go.")
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
                        RenewalModePicker(state: state)
                        ForEach(expiring) { title in
                            VStack(alignment: .leading, spacing: 4) {
                                if let reason = state.renewalBlock(title), state.renewalMode != .off {
                                    Text("Not auto-renewed: \(reason).").font(.caption).foregroundStyle(Theme.amber)
                                }
                                RenewCard(title: title, state: state, onDone: nil)
                            }
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
