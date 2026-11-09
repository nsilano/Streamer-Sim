import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var store: GameStore

    var body: some View {
        NavigationStack {
            ScrollView {
                if let state = store.state {
                    VStack(alignment: .leading, spacing: 16) {
                        header(state)
                        hero(state)
                        statGrid(state)
                        ForEach(Array(state.advice().prefix(2))) { AdviceBanner(advice: $0) }
                        controls(state)
                        NavigationLink {
                            PromotionsView()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "megaphone.fill").font(.title3).foregroundStyle(Theme.magenta)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Run a promotion").font(.headline).foregroundStyle(.white)
                                    Text(state.promotions.isEmpty ? "Discounts, free trials and campaigns to win subscribers fast"
                                                                  : "\(state.promotions.count) running now")
                                        .font(.caption).foregroundStyle(Theme.text2)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(Theme.text2)
                            }
                            .artCard(tint: Theme.magenta)
                        }
                        if state.reportHistory.count > 1 { TrendCard(reports: state.reportHistory) }
                        topFive(state)
                        if let report = state.lastReport { ReportSummaryCard(report: report) }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
            .artScreen()
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $store.showReport) {
                if let report = store.state?.lastReport { WeeklyReportView(report: report) }
            }
        }
    }

    // MARK: Pieces

    private func header(_ state: GameState) -> some View {
        ScreenHeader(title: state.companyName, subtitle: "Week \(state.week) · Rank #\(state.rank) of \(state.rivals.count + 1)") {
            Button { store.showSettings = true } label: {
                Image(systemName: "gearshape.fill").font(.title3).foregroundStyle(.white.opacity(0.85))
                    .padding(10).background(Circle().fill(Color.white.opacity(0.10)))
            }
        }
    }

    private func hero(_ state: GameState) -> some View {
        let fin = state.finances
        return VStack(alignment: .leading, spacing: 10) {
            Text("CASH ON HAND").font(.caption2.weight(.heavy)).tracking(1.4).foregroundStyle(Theme.text2)
            Text(Format.money(fin.cash)).font(Theme.number(40)).foregroundStyle(fin.cash >= 0 ? .white : Theme.danger)
                .minimumScaleFactor(0.5).lineLimit(1)
            HStack(spacing: 8) {
                Pill(text: runwayText(fin), tint: fin.cash < 0 ? Theme.danger : (fin.runwayWeeks == nil ? Theme.good : Theme.amber),
                     icon: "clock")
                Pill(text: "\(fin.lastWeek.profit >= 0 ? "+" : "")\(Format.money(fin.lastWeek.profit)) / wk",
                     tint: fin.lastWeek.profit.profitColor, icon: "chart.line.uptrend.xyaxis")
            }
            NavigationLink {
                FinanceView()
            } label: {
                Label("See where the money goes", systemImage: "magnifyingglass").font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.magenta)
            }
            if fin.cash < 0 {
                let used = min(1, -fin.cash / state.overdraftLimit)
                StatBar(label: "Credit limit used (bankrupt at 100%)", value: used, text: Format.percent(used),
                        tint: Theme.danger)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .artCard(tint: Theme.magenta)
    }

    private func statGrid(_ state: GameState) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            BigStat(title: "Subscribers", value: Format.count(state.totalSubscribers), icon: "person.2.fill")
            BigStat(title: "Weekly revenue", value: Format.money(state.finances.lastWeek.revenue), icon: "dollarsign.circle.fill")
            BigStat(title: "Markets live", value: "\(state.liveMarketCodes.count) / \(CountryData.all.count)", icon: "globe")
            BigStat(title: "Catalog", value: "\(state.catalog.count) titles", subtitle: "\(state.projects.count) in production",
                    icon: "film.stack")
        }
    }

    private func controls(_ state: GameState) -> some View {
        VStack(spacing: 10) {
            Button {
                store.nextWeek()
            } label: {
                Label("Next week", systemImage: "forward.fill")
            }
            .buttonStyle(GlowButtonStyle())
            .disabled(store.autoAdvance)

            if let event = state.pendingEvent {
                AlertCard(event: event, week: state.week)
            }
            Toggle("Auto-advance", isOn: $store.autoAdvance).tint(Theme.magenta)
        }
        .artCard()
    }

    private func topFive(_ state: GameState) -> some View {
        let board = state.leaderboard
        let top = max(1, board.first?.subs ?? 1)
        return VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "Global race", icon: "trophy.fill", tint: Theme.amber)
            ForEach(Array(board.prefix(5).enumerated()), id: \.element.id) { index, entry in
                HStack(spacing: 10) {
                    Text("\(index + 1)").font(Theme.number(16)).foregroundStyle(Theme.text2).frame(width: 20)
                    StatBar(label: entry.name, value: entry.subs / top, text: Format.count(entry.subs),
                            tint: entry.isPlayer ? Theme.magenta : Theme.violet, compact: true)
                }
            }
            if let me = board.firstIndex(where: { $0.isPlayer }), me >= 5 {
                Text("You're #\(me + 1) with \(Format.count(board[me].subs)) subscribers.")
                    .font(.caption).foregroundStyle(Theme.text2)
            }
        }
        .artCard(tint: Theme.amber)
    }

    private func runwayText(_ fin: Finances) -> String {
        if fin.cash < 0 { return "In debt \(fin.weeksInDebt)/\(SimulationEngine.debtWeeksToLose) wks" }
        guard let weeks = fin.runwayWeeks else { return "Profitable" }
        return "Runway \(Int(weeks)) wks"
    }
}

struct ReportSummaryCard: View {
    let report: WeeklyReport

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(text: "Last week (week \(report.week))", icon: "doc.text.fill", tint: Theme.teal)
            LabeledValue(label: "New subscribers", value: "+\(Format.count(report.newSubs))", tint: Theme.good)
            LabeledValue(label: "Churned", value: "-\(Format.count(report.churned))", tint: Theme.danger)
            LabeledValue(label: "Revenue", value: Format.money(report.financials.revenue))
            LabeledValue(label: "Costs", value: Format.money(report.financials.costs))
            LabeledValue(label: "Profit", value: Format.money(report.financials.profit), tint: report.financials.profit.profitColor)
            ForEach(report.events) { event in
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: event.kind == .warning ? "exclamationmark.triangle.fill" : "sparkle")
                        .font(.caption2).foregroundStyle(event.kind == .warning ? Theme.danger : Theme.amber)
                    Text(event.headline).font(.footnote).foregroundStyle(Theme.text2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .artCard(tint: Theme.teal)
    }
}

struct WeeklyReportView: View {
    @Environment(\.dismiss) private var dismiss
    let report: WeeklyReport

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        BigStat(title: "New", value: "+\(Format.count(report.newSubs))", tint: Theme.good)
                        BigStat(title: "Churned", value: "-\(Format.count(report.churned))", tint: Theme.danger)
                    }
                    HStack(spacing: 12) {
                        BigStat(title: "Subscribers", value: Format.count(report.totalSubs))
                        BigStat(title: "Rank", value: "#\(report.rank)")
                    }
                    moneyCard
                    if !report.markets.isEmpty { marketsCard }
                    if !report.events.isEmpty { eventsCard }
                }
                .padding(16)
            }
            .artScreen()
            .navigationTitle("Week \(report.week)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Done") { dismiss() } }
        }
    }

    private var moneyCard: some View {
        let f = report.financials
        let lines: [(String, Double)] = [
            ("Licensing", f.licensing), ("Originals", f.originals), ("Dubbing & subtitles", f.localization),
            ("Streaming", f.streaming), ("Staff", f.staff), ("Marketing", f.marketing),
            ("Country operations", f.operations), ("Market & tier launches", f.launch),
            ("Servers & apps", f.tech), ("Studios", f.studios), ("Loan interest", f.interest),
            ("Regulatory fines", f.fines), ("Hiring & events", f.other),
        ].filter { $0.1 > 0 }
        return VStack(alignment: .leading, spacing: 8) {
            SectionTitle(text: "Money", icon: "banknote.fill", tint: Theme.amber)
            LabeledValue(label: "Subscription revenue", value: Format.money(f.subscriptionRevenue), tint: Theme.good)
            LabeledValue(label: "Ad revenue", value: Format.money(f.adRevenue), tint: Theme.good)
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                LabeledValue(label: line.0, value: "-" + Format.money(line.1))
            }
            Divider().overlay(Color.white.opacity(0.15))
            LabeledValue(label: "Profit / loss", value: Format.money(f.profit), tint: f.profit.profitColor)
            LabeledValue(label: "Cash", value: Format.money(report.cashEnd))
        }
        .artCard(tint: Theme.amber)
    }

    private var marketsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(text: "By market", icon: "globe", tint: Theme.teal)
            ForEach(report.markets) { m in
                let net = m.newSubs - m.churned
                LabeledValue(label: "\(CountryData.country(m.id)?.flag ?? "") \(CountryData.country(m.id)?.name ?? m.id)",
                             value: "\(Format.count(m.subs)) (\(net >= 0 ? "+" : "-")\(Format.count(abs(net))))",
                             tint: net >= 0 ? .white : Theme.danger)
            }
        }
        .artCard(tint: Theme.teal)
    }

    private var eventsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "What happened", icon: "sparkles", tint: Theme.magenta)
            ForEach(report.events) { e in
                VStack(alignment: .leading, spacing: 2) {
                    Text(e.headline).font(.subheadline.weight(.bold)).foregroundStyle(.white)
                    Text(e.detail).font(.caption).foregroundStyle(Theme.text2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .artCard(tint: Theme.magenta)
    }
}
