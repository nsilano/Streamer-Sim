import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var store: GameStore

    var body: some View {
        NavigationStack {
            ScrollView {
                if let state = store.state {
                    VStack(spacing: 16) {
                        let fin = state.finances
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            StatCard(title: "Cash", value: Format.money(fin.cash),
                                     subtitle: runwayText(fin), tint: fin.cash >= 0 ? .primary : .red)
                            StatCard(title: "Global subscribers", value: Format.count(state.totalSubscribers))
                            StatCard(title: "Weekly revenue", value: Format.money(fin.lastWeek.revenue))
                            StatCard(title: "Weekly profit", value: Format.money(fin.lastWeek.profit),
                                     tint: fin.lastWeek.profit.profitColor)
                            StatCard(title: "Global rank", value: "#\(state.rank)",
                                     subtitle: "of \(state.rivals.count + 1) streamers")
                            StatCard(title: "Week", value: "\(state.week)")
                        }

                        if state.catalog.isEmpty {
                            Label("Your catalog is empty. License some titles in the Content tab to start attracting subscribers.",
                                  systemImage: "lightbulb")
                                .font(.footnote)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(.yellow.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
                        }

                        controls
                        if let report = state.lastReport {
                            ReportSummaryCard(report: report)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle(store.state?.companyName ?? "Dashboard")
            .sheet(isPresented: $store.showReport) {
                if let report = store.state?.lastReport {
                    WeeklyReportView(report: report)
                }
            }
        }
    }

    private var controls: some View {
        VStack(spacing: 8) {
            Button {
                store.nextWeek()
            } label: {
                Label("Next Week", systemImage: "forward.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .disabled(store.autoAdvance || store.state?.pendingEvent != nil)

            if let event = store.state?.pendingEvent {
                Label("Decision needed: \(event.headline)", systemImage: "exclamationmark.bubble.fill")
                    .font(.footnote).foregroundStyle(.orange)
            }

            Toggle("Auto-advance", isOn: $store.autoAdvance)
        }
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
            Text("Last week (week \(report.week))").font(.headline)
            LabeledValue(label: "New subscribers", value: "+\(Format.count(report.newSubs))", tint: .green)
            LabeledValue(label: "Churned", value: "-\(Format.count(report.churned))", tint: .red)
            LabeledValue(label: "Revenue", value: Format.money(report.financials.revenue))
            LabeledValue(label: "Costs", value: Format.money(report.financials.costs))
            LabeledValue(label: "Profit", value: Format.money(report.financials.profit),
                         tint: report.financials.profit.profitColor)
            ForEach(report.events) { event in
                Text("• \(event.headline)").font(.footnote).foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct WeeklyReportView: View {
    @Environment(\.dismiss) private var dismiss
    let report: WeeklyReport

    var body: some View {
        NavigationStack {
            List {
                Section("Subscribers") {
                    LabeledValue(label: "New", value: "+\(Format.count(report.newSubs))", tint: .green)
                    LabeledValue(label: "Churned", value: "-\(Format.count(report.churned))", tint: .red)
                    LabeledValue(label: "Total", value: Format.count(report.totalSubs))
                    LabeledValue(label: "Rank", value: "#\(report.rank)")
                }
                Section("Money") {
                    let f = report.financials
                    LabeledValue(label: "Subscription revenue", value: Format.money(f.subscriptionRevenue))
                    LabeledValue(label: "Ad revenue", value: Format.money(f.adRevenue))
                    LabeledValue(label: "Licensing", value: "-" + Format.money(f.licensing))
                    LabeledValue(label: "Streaming / CDN", value: "-" + Format.money(f.streaming))
                    LabeledValue(label: "Staff", value: "-" + Format.money(f.staff))
                    LabeledValue(label: "Marketing", value: "-" + Format.money(f.marketing))
                    LabeledValue(label: "Country operations", value: "-" + Format.money(f.operations))
                    if f.launch > 0 {
                        LabeledValue(label: "Market launches", value: "-" + Format.money(f.launch))
                    }
                    if f.originals > 0 { LabeledValue(label: "Originals", value: "-" + Format.money(f.originals)) }
                    if f.localization > 0 { LabeledValue(label: "Dubbing & subtitles", value: "-" + Format.money(f.localization)) }
                    if f.interest > 0 { LabeledValue(label: "Loan interest", value: "-" + Format.money(f.interest)) }
                    if f.fines > 0 { LabeledValue(label: "Regulatory fines", value: "-" + Format.money(f.fines)) }
                    if f.other > 0 { LabeledValue(label: "Event costs", value: "-" + Format.money(f.other)) }
                    LabeledValue(label: "Profit / loss", value: Format.money(f.profit), tint: f.profit.profitColor)
                    LabeledValue(label: "Cash", value: Format.money(report.cashEnd))
                }
                if !report.markets.isEmpty {
                    Section("By market") {
                        ForEach(report.markets) { m in
                            LabeledValue(label: "\(CountryData.country(m.id)?.flag ?? "") \(CountryData.country(m.id)?.name ?? m.id)",
                                         value: "\(Format.count(m.subs)) (\(m.newSubs - m.churned >= 0 ? "+" : "")\(Format.count(m.newSubs - m.churned)))")
                        }
                    }
                }
                if !report.events.isEmpty {
                    Section("Events") {
                        ForEach(report.events) { e in
                            VStack(alignment: .leading) {
                                Text(e.headline).bold()
                                Text(e.detail).font(.footnote).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Week \(report.week) report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Done") { dismiss() } }
        }
    }
}
