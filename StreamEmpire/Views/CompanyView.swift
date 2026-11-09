import SwiftUI

struct CompanyView: View {
    @EnvironmentObject var store: GameStore
    @State private var confirmReset = false
    @State private var loanAmount: Double = 5_000_000
    @State private var loanTerm: Int = 104
    @State private var roundPercent: Double = 0.10

    var body: some View {
        NavigationStack {
            List {
                if let state = store.state {
                    financeSections(state)
                    fundingSections(state)
                    goalsSection(state)
                    Section("Coming soon") {
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

    // MARK: Finances

    @ViewBuilder
    private func financeSections(_ state: GameState) -> some View {
        let fin = state.finances
        let week = fin.lastWeek
        Section("Cash") {
            LabeledValue(label: "Cash", value: Format.money(fin.cash), tint: fin.cash >= 0 ? .primary : .red)
            LabeledValue(label: "Weekly profit / loss", value: Format.money(week.profit), tint: week.profit.profitColor)
            LabeledValue(label: "Cash runway", value: fin.runwayWeeks.map { "\(Int($0)) weeks" } ?? "Profitable")
            LabeledValue(label: "Annualized revenue", value: Format.money(fin.annualizedRevenue))
            LabeledValue(label: "Debt", value: Format.money(state.outstandingDebt))
        }
        Section("Last week") {
            LabeledValue(label: "Subscription revenue", value: Format.money(week.subscriptionRevenue))
            LabeledValue(label: "Ad revenue", value: Format.money(week.adRevenue))
            LabeledValue(label: "Licensing", value: "-" + Format.money(week.licensing))
            LabeledValue(label: "Originals", value: "-" + Format.money(week.originals))
            LabeledValue(label: "Dubbing & subtitles", value: "-" + Format.money(week.localization))
            LabeledValue(label: "Streaming / CDN", value: "-" + Format.money(week.streaming))
            LabeledValue(label: "Staff", value: "-" + Format.money(week.staff))
            LabeledValue(label: "Marketing", value: "-" + Format.money(week.marketing))
            LabeledValue(label: "Country operations", value: "-" + Format.money(week.operations))
            LabeledValue(label: "Loan interest", value: "-" + Format.money(week.interest))
            LabeledValue(label: "Regulatory fines", value: "-" + Format.money(week.fines))
            LabeledValue(label: "Event costs", value: "-" + Format.money(week.other))
        }
    }

    // MARK: Funding

    @ViewBuilder
    private func fundingSections(_ state: GameState) -> some View {
        Section("Ownership") {
            LabeledValue(label: "You own", value: Format.percent(state.equity.ownership))
            LabeledValue(label: "Company valuation", value: Format.money(state.valuation))
        }

        Section("Loans") {
            LabeledValue(label: "Available credit", value: Format.money(state.creditRoom))
            ForEach(state.loans) { loan in
                VStack(alignment: .leading, spacing: 4) {
                    LabeledValue(label: "Balance", value: Format.money(loan.balance))
                    Text("\(Format.percent(loan.annualRate)) interest · \(Format.money(loan.weeklyPrincipal))/wk principal")
                        .font(.caption).foregroundStyle(.secondary)
                    Button("Repay in full (\(Format.money(loan.balance)))") {
                        store.perform { try $0.repayLoan(id: loan.id, amount: loan.balance) }
                    }
                    .font(.footnote)
                    .disabled(state.finances.cash < loan.balance)
                }
            }
            Stepper(value: $loanAmount, in: 250_000...500_000_000, step: loanAmount >= 20_000_000 ? 5_000_000 : 1_000_000) {
                LabeledValue(label: "Amount", value: Format.money(loanAmount))
            }
            Picker("Term", selection: $loanTerm) {
                Text("1 yr").tag(52); Text("2 yrs").tag(104); Text("4 yrs").tag(208)
            }
            .pickerStyle(.segmented)
            Text("Rate: \(Format.percent(Formulas.loanRate(profitable: state.finances.recentWeeklyProfit >= 0))) a year, repaid weekly. Lenders lend against your revenue.")
                .font(.footnote).foregroundStyle(.secondary)
            Button("Take loan") {
                store.perform { try $0.takeLoan(amount: loanAmount, termWeeks: loanTerm) }
            }
            .disabled(loanAmount > state.creditRoom)
        }

        Section("Investors") {
            if let reason = state.roundBlocker {
                Text(reason).font(.footnote).foregroundStyle(.secondary)
            } else {
                Stepper(value: $roundPercent, in: 0.05...0.25, step: 0.05) {
                    LabeledValue(label: "Sell", value: Format.percent(roundPercent))
                }
                LabeledValue(label: "You receive", value: Format.money(state.valuation * roundPercent))
                Button("Raise funding round") {
                    store.perform { try $0.raiseRound(percent: roundPercent) }
                }
            }
        }

        Section("IPO") {
            if let reason = state.ipoBlocker {
                Text(reason).font(.footnote).foregroundStyle(.secondary)
            } else {
                LabeledValue(label: "Sell 15% at", value: Format.money(state.valuation * 1.4))
                LabeledValue(label: "You receive", value: Format.money(state.valuation * 1.4 * 0.15))
                Button("Go public") { store.perform { try $0.launchIPO() } }
            }
        }
    }

    // MARK: Goals

    @ViewBuilder
    private func goalsSection(_ state: GameState) -> some View {
        Section("Goals") {
            LabeledValue(label: "#1 in the world", value: state.rank == 1 ? "Leading!" : "Rank #\(state.rank)")
            goalRow("Go public (IPO)", done: state.goals.contains("ipo"))
            goalRow("$10B annual revenue (\(Format.money(state.finances.annualizedRevenue)))",
                    done: state.goals.contains("revenue10B"))
            goalRow("All 30 markets (\(state.liveMarketCodes.count)/30)", done: state.goals.contains("allMarkets"))
        }
    }

    private func goalRow(_ title: String, done: Bool) -> some View {
        HStack {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(done ? .green : .secondary)
            Text(title)
        }
    }
}
