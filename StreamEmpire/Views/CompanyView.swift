import SwiftUI

struct CompanyView: View {
    @EnvironmentObject var store: GameStore
    @State private var loanAmount: Double = 5_000_000
    @State private var loanTerm: Int = 104
    @State private var roundPercent: Double = 0.10

    var body: some View {
        NavigationStack {
            ScrollView {
                if let state = store.state {
                    VStack(alignment: .leading, spacing: 14) {
                        ScreenHeader(title: "Company", subtitle: state.companyName) {
                            Button { store.showSettings = true } label: {
                                Image(systemName: "gearshape.fill").font(.title3).foregroundStyle(.white.opacity(0.85))
                                    .padding(10).background(Circle().fill(Color.white.opacity(0.10)))
                            }
                        }
                        cashCard(state)
                        NavigationLink {
                            FinanceView()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "magnifyingglass.circle.fill").font(.title2).foregroundStyle(Theme.magenta)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Where is my money going?").font(.headline).foregroundStyle(.white)
                                    Text("Ranked spending, trends, country profit and why you're losing money")
                                        .font(.caption).foregroundStyle(Theme.text2)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(Theme.text2)
                            }
                            .artCard(tint: Theme.magenta)
                        }
                        costsCard(state)
                        NavigationLink {
                            TechStaffView()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "server.rack").font(.title2).foregroundStyle(Theme.teal)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Tech, servers & team").font(.headline).foregroundStyle(.white)
                                    Text("Apps, datacenters, staff and pay").font(.caption).foregroundStyle(Theme.text2)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(Theme.text2)
                            }
                            .artCard(tint: Theme.teal)
                        }
                        ownershipCard(state)
                        loansCard(state)
                        investorsCard(state)
                        ipoCard(state)
                        goalsCard(state)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
            .artScreen()
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    // MARK: Finances

    private func cashCard(_ state: GameState) -> some View {
        let fin = state.finances
        return VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "Money", icon: "banknote.fill", tint: Theme.amber)
            Text(Format.money(fin.cash)).font(Theme.number(36)).foregroundStyle(fin.cash >= 0 ? .white : Theme.danger)
            LabeledValue(label: "Weekly profit / loss", value: Format.money(fin.lastWeek.profit), tint: fin.lastWeek.profit.profitColor)
            LabeledValue(label: "Cash runway", value: fin.runwayWeeks.map { "\(Int($0)) weeks" } ?? "Profitable")
            LabeledValue(label: "Annualized revenue", value: Format.money(fin.annualizedRevenue))
            LabeledValue(label: "Debt (loans)", value: Format.money(state.outstandingDebt))
            VStack(alignment: .leading, spacing: 4) {
                let used = fin.cash < 0 ? min(1, -fin.cash / state.overdraftLimit) : 0
                StatBar(label: "Overdraft limit: \(Format.money(state.overdraftLimit))", value: used,
                        text: fin.cash < 0 ? Format.percent(used) + " used" : "Unused",
                        tint: used > 0.7 ? Theme.danger : (used > 0 ? Theme.amber : Theme.good), compact: true)
                Text("If cash falls below minus \(Format.money(state.overdraftLimit)), lenders pull the plug and you go bankrupt. The limit grows with your revenue.")
                    .font(.caption2).foregroundStyle(Theme.text2)
            }
        }
        .artCard(tint: Theme.amber)
    }

    private func costsCard(_ state: GameState) -> some View {
        let w = state.finances.lastWeek
        let rows: [(String, Double, Color)] = [
            ("Licensing", w.licensing, Theme.amber), ("Originals", w.originals, Theme.magenta),
            ("Dubbing & subtitles", w.localization, Theme.violet), ("Streaming", w.streaming, Theme.teal),
            ("Staff & overhead", w.staff, Theme.violet), ("Marketing", w.marketing, Theme.magenta),
            ("Country operations", w.operations, Theme.teal), ("Servers & apps", w.tech, Theme.teal),
            ("Studios", w.studios, Theme.violet), ("Launches", w.launch, Theme.amber),
            ("Loan interest", w.interest, Theme.danger), ("Regulatory fines", w.fines, Theme.danger),
            ("Hiring & events", w.other, Theme.amber),
        ].filter { $0.1 > 0 }
        let biggest = max(1, rows.map { $0.1 }.max() ?? 1)
        return VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "Where the money goes (last week)", icon: "chart.bar.xaxis", tint: Theme.magenta)
            LabeledValue(label: "Subscriptions", value: Format.money(w.subscriptionRevenue), tint: Theme.good)
            LabeledValue(label: "Ads", value: Format.money(w.adRevenue), tint: Theme.good)
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                StatBar(label: row.0, value: row.1 / biggest, text: Format.money(row.1), tint: row.2, height: 5, compact: true)
            }
        }
        .artCard(tint: Theme.magenta)
    }

    // MARK: Funding

    private func ownershipCard(_ state: GameState) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(text: "Ownership", icon: "chart.pie.fill", tint: Theme.violet)
            StatBar(label: "You own", value: state.equity.ownership, text: Format.percent(state.equity.ownership), tint: Theme.violet)
            LabeledValue(label: "Company valuation", value: Format.money(state.valuation))
        }
        .artCard(tint: Theme.violet)
    }

    private func loansCard(_ state: GameState) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "Loans", icon: "building.columns.fill", tint: Theme.teal)
            LabeledValue(label: "Available credit", value: Format.money(state.creditRoom))
            ForEach(state.loans) { loan in
                VStack(alignment: .leading, spacing: 4) {
                    LabeledValue(label: "Balance", value: Format.money(loan.balance))
                    Text("\(Format.percent(loan.annualRate)) interest · \(Format.money(loan.weeklyPrincipal))/wk principal")
                        .font(.caption).foregroundStyle(Theme.text2)
                    Button("Repay in full") { store.perform { try $0.repayLoan(id: loan.id, amount: loan.balance) } }
                        .buttonStyle(SoftButtonStyle(tint: Theme.teal))
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
            Text("Rate: \(Format.percent(state.loanRate)) a year, repaid weekly. Lenders lend against your revenue.")
                .font(.caption).foregroundStyle(Theme.text2)
            Button("Take loan") { store.perform { try $0.takeLoan(amount: loanAmount, termWeeks: loanTerm) } }
                .buttonStyle(GlowButtonStyle(tint: Theme.teal))
                .disabled(loanAmount > state.creditRoom)
        }
        .artCard(tint: Theme.teal)
    }

    private func investorsCard(_ state: GameState) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "Investors", icon: "person.2.fill", tint: Theme.magenta)
            if let reason = state.roundBlocker {
                Text(reason).font(.footnote).foregroundStyle(Theme.text2)
            } else {
                Stepper(value: $roundPercent, in: 0.05...0.25, step: 0.05) {
                    LabeledValue(label: "Sell", value: Format.percent(roundPercent))
                }
                LabeledValue(label: "You receive", value: Format.money(state.valuation * roundPercent))
                Button("Raise funding round") { store.perform { try $0.raiseRound(percent: roundPercent) } }
                    .buttonStyle(GlowButtonStyle(tint: Theme.magenta))
            }
        }
        .artCard(tint: Theme.magenta)
    }

    private func ipoCard(_ state: GameState) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "IPO", icon: "bell.fill", tint: Theme.amber)
            if let reason = state.ipoBlocker {
                Text(reason).font(.footnote).foregroundStyle(Theme.text2)
            } else {
                LabeledValue(label: "Sell 15% at", value: Format.money(state.valuation * 1.4))
                LabeledValue(label: "You receive", value: Format.money(state.valuation * 1.4 * 0.15))
                Button("Go public") { store.perform { try $0.launchIPO() } }.buttonStyle(GlowButtonStyle(tint: Theme.amber))
            }
        }
        .artCard(tint: Theme.amber)
    }

    private func goalsCard(_ state: GameState) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(text: "Goals", icon: "flag.checkered", tint: Theme.good)
            LabeledValue(label: "#1 in the world", value: state.rank == 1 ? "Leading!" : "Rank #\(state.rank)")
            goalRow("Go public (IPO)", done: state.goals.contains("ipo"))
            goalRow("$10B annual revenue (\(Format.money(state.finances.annualizedRevenue)))", done: state.goals.contains("revenue10B"))
            goalRow("All 30 markets (\(state.liveMarketCodes.count)/30)", done: state.goals.contains("allMarkets"))
        }
        .artCard(tint: Theme.good)
    }

    private func goalRow(_ title: String, done: Bool) -> some View {
        HStack {
            Image(systemName: done ? "checkmark.circle.fill" : "circle").foregroundStyle(done ? Theme.good : Theme.text2)
            Text(title).font(.subheadline).foregroundStyle(.white)
        }
    }
}
