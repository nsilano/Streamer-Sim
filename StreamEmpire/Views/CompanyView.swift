import SwiftUI

struct CompanyView: View {
    @EnvironmentObject var store: GameStore

    var body: some View {
        NavigationStack {
            ScrollView {
                if let state = store.state {
                    VStack(alignment: .leading, spacing: 14) {
                        ScreenHeader(title: "Company", subtitle: "\(state.companyName) · \(GameCalendar.dateText(week: state.week)) · Week \(state.week)") {
                            Button { store.showSettings = true } label: {
                                Image(systemName: "gearshape.fill").font(.title3).foregroundStyle(.white.opacity(0.85))
                                    .padding(10).background(Circle().fill(Color.white.opacity(0.10)))
                            }
                        }
                        cashCard(state)
                        hubGrid([
                            HubTile(icon: "magnifyingglass.circle.fill", title: "Finances", subtitle: "Spending, trends, P&L", tint: Theme.magenta) { AnyView(FinanceView()) },
                            HubTile(icon: "building.columns.fill", title: "Funding", subtitle: "Loans, investors, IPO", tint: Theme.teal) { AnyView(FundingView()) },
                            HubTile(icon: "chart.bar.doc.horizontal.fill", title: "Earnings", subtitle: "Quarters, buybacks, FX", tint: Theme.amber) { AnyView(BusinessView(tab: .earnings)) },
                            HubTile(icon: "server.rack", title: "Tech & team", subtitle: "Apps, servers, staff", tint: Theme.teal) { AnyView(TechStaffView()) },
                            HubTile(icon: "iphone.gen3", title: "Product", subtitle: "Features, ad load", tint: Theme.violet) { AnyView(BusinessView(tab: .product)) },
                            HubTile(icon: "tag.fill", title: "Prices", subtitle: "Global and per country", tint: Theme.amber) { AnyView(PricesView()) },
                            HubTile(icon: "captions.bubble.fill", title: "Dubs & subs", subtitle: "Auto or one tap", tint: Theme.teal) { AnyView(LocalizationView()) },
                            HubTile(icon: "megaphone.fill", title: "Promotions", subtitle: state.promotions.isEmpty ? "Short campaigns" : "\(state.promotions.count) running", tint: Theme.magenta) { AnyView(PromotionsView()) },
                            HubTile(icon: "list.bullet.clipboard.fill", title: "Policies", subtitle: "Reputation \(Int(state.brandTrust))", tint: Theme.violet) { AnyView(PoliciesView()) },
                            HubTile(icon: "shippingbox.fill", title: "Deals", subtitle: "Sports, bundles, buys", tint: Theme.good) { AnyView(BusinessView(tab: .deals)) },
                        ])
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

    private func hubGrid(_ tiles: [HubTile]) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            ForEach(tiles) { tile in
                NavigationLink { tile.destination() } label: { tile }.buttonStyle(.plain)
            }
        }
    }

    private func goalsCard(_ state: GameState) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(text: "Goals", icon: "flag.checkered", tint: Theme.good)
            LabeledValue(label: "#1 in the world", value: state.rank == 1 ? "Leading!" : "Rank #\(state.rank)")
            goalRow("Go public (IPO)", done: state.goals.contains("ipo"))
            goalRow("$10B annual revenue (\(Format.money(state.finances.annualizedRevenue)))", done: state.goals.contains("revenue10B"))
            goalRow("All \(CountryData.all.count) markets (\(state.liveMarketCodes.count)/\(CountryData.all.count))", done: state.goals.contains("allMarkets"))
            goalRow("Take over a rival", done: state.goals.contains("takeover"))
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


/// Ownership, loans, investors, the IPO and stakes in rivals, in one place.
struct FundingView: View {
    @EnvironmentObject var store: GameStore
    @State private var loanAmount: Double = 5_000_000
    @State private var loanTerm: Int = 104
    @State private var roundPercent: Double = 0.10

    var body: some View {
        ScrollView {
            if let state = store.state {
                VStack(alignment: .leading, spacing: 14) {
                    ownershipCard(state)
                    loansCard(state)
                    investorsCard(state)
                    ipoCard(state)
                    investmentsCard(state)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .artScreen()
        .navigationTitle("Funding")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Funding

    @ViewBuilder
    private func investmentsCard(_ state: GameState) -> some View {
        let held = state.stakes.keys.sorted()
        if !held.isEmpty || state.takeover != nil || !state.acquiredRivals.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle(text: "Investments in rivals", icon: "building.columns.circle.fill", tint: Theme.danger)
                if let bid = state.takeover, let rival = state.rivals.first(where: { $0.id == bid.rivalID }) {
                    Label("Hostile bid for \(rival.name): vote in \(bid.weeksLeft) week\(bid.weeksLeft == 1 ? "" : "s")",
                          systemImage: "flag.fill").font(.footnote.weight(.semibold)).foregroundStyle(Theme.amber)
                }
                ForEach(held, id: \.self) { id in
                    if let rival = state.rivals.first(where: { $0.id == id }) {
                        let value = state.stakeValue(in: id)
                        let gain = value - (state.stakeBasis[id] ?? value)
                        HStack {
                            RivalBadge(name: rival.name, id: rival.id, size: 30)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(rival.name).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                                Text("\(Format.percent1(state.stake(in: id))) stake").font(.caption2).foregroundStyle(Theme.text2)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 1) {
                                Text(Format.money(value)).font(Theme.number(15)).foregroundStyle(.white)
                                Text("\(gain >= 0 ? "+" : "-")\(Format.money(abs(gain)))").font(.caption2).foregroundStyle(gain.profitColor)
                            }
                        }
                    }
                }
                if !held.isEmpty { LabeledValue(label: "Total stake value", value: Format.money(state.totalStakeValue)) }
                if !state.acquiredRivals.isEmpty {
                    Text("Acquired: \(state.acquiredRivals.joined(separator: ", "))").font(.caption).foregroundStyle(Theme.good)
                }
            }
            .artCard(tint: Theme.danger)
        }
    }

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

}
