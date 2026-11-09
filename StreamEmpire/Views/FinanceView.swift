import SwiftUI
import Charts

struct SpendPoint: Identifiable {
    let id: String
    let week: Int
    let category: String
    let amount: Double
}

/// Where the money goes, and why you're losing it.
struct FinanceView: View {
    @EnvironmentObject var store: GameStore

    private static let palette: [Color] = [Theme.amber, Theme.magenta, Theme.teal, Theme.violet, Theme.danger, Theme.good, Color.gray]

    var body: some View {
        ScrollView {
            if let state = store.state {
                VStack(alignment: .leading, spacing: 14) {
                    summary(state)
                    ForEach(Array(state.diagnosis().prefix(6))) { AdviceBanner(advice: $0) }
                    breakdown(state)
                    history(state)
                    countries(state)
                    lifetime(state)
                }
                .padding(16)
            }
        }
        .artScreen()
        .navigationTitle("Finances")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Summary

    private func summary(_ state: GameState) -> some View {
        let w = state.finances.lastWeek
        return VStack(spacing: 12) {
            HStack(spacing: 12) {
                BigStat(title: "Revenue / wk", value: Format.money(w.revenue), tint: Theme.good)
                BigStat(title: "Spending / wk", value: Format.money(w.costs), tint: Theme.danger)
            }
            BigStat(title: w.profit >= 0 ? "Profit last week" : "Loss last week", value: Format.money(w.profit),
                    subtitle: w.revenue > 0 ? "Costs are \(Int(w.costs / w.revenue * 100))% of revenue" : "No revenue yet",
                    tint: w.profit.profitColor)
        }
    }

    // MARK: Breakdown

    private func breakdown(_ state: GameState) -> some View {
        let lines = state.costBreakdown()
        let biggest = max(1, lines.first?.amount ?? 1)
        return VStack(alignment: .leading, spacing: 12) {
            SectionTitle(text: "Where it went last week", icon: "chart.bar.xaxis", tint: Theme.magenta)
            if lines.isEmpty {
                Text("No spending recorded yet.").font(.footnote).foregroundStyle(Theme.text2)
            }
            ForEach(lines) { line in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: line.category.icon).foregroundStyle(Theme.magenta).frame(width: 22)
                        Text(line.category.displayName).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                        Spacer()
                        Text(Format.money(line.amount)).font(Theme.number(15)).foregroundStyle(.white)
                    }
                    StatBar(label: "\(Int(line.shareOfCosts * 100))% of spending · \(Int(line.shareOfRevenue * 100))% of revenue",
                            value: line.amount / biggest, text: changeText(line), tint: changeTint(line), height: 5, compact: true)
                }
            }
        }
        .artCard(tint: Theme.magenta)
    }

    private func changeText(_ line: CostLine) -> String {
        guard abs(line.change) > 1 else { return "no change" }
        return "\(line.change > 0 ? "▲" : "▼") \(Format.money(abs(line.change))) vs prior week"
    }

    private func changeTint(_ line: CostLine) -> Color {
        if line.change > line.previous * 0.25 && line.change > 5_000 { return Theme.danger }
        return Theme.violet
    }

    // MARK: Chart

    private func history(_ state: GameState) -> some View {
        let weeks = Array(state.finances.history.suffix(12))
        let startWeek = state.week - weeks.count
        let top = CostCategory.allCases
            .map { category in (category, weeks.reduce(0) { $0 + category.amount(in: $1) }) }
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
        let main = Array(top.prefix(6).map { $0.0 })
        var points: [SpendPoint] = []
        for (index, week) in weeks.enumerated() {
            var other = 0.0
            for category in CostCategory.allCases {
                let amount = category.amount(in: week)
                if main.contains(category) {
                    points.append(SpendPoint(id: "\(index)-\(category.rawValue)", week: startWeek + index, category: category.displayName, amount: amount))
                } else {
                    other += amount
                }
            }
            if other > 0 { points.append(SpendPoint(id: "\(index)-rest", week: startWeek + index, category: "Everything else", amount: other)) }
        }
        let names = main.map { $0.displayName } + (top.count > 6 ? ["Everything else"] : [])
        return VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "Spending over time", icon: "chart.bar.fill", tint: Theme.violet)
            if weeks.count < 2 {
                Text("Play a couple of weeks to see the trend.").font(.footnote).foregroundStyle(Theme.text2)
            } else {
                Chart(points) { point in
                    BarMark(x: .value("Week", point.week), y: .value("Spend", point.amount))
                        .foregroundStyle(by: .value("Category", point.category))
                }
                .chartForegroundStyleScale(domain: names, range: Array(Self.palette.prefix(names.count)))
                .chartYAxis {
                    AxisMarks { mark in
                        AxisGridLine().foregroundStyle(Color.white.opacity(0.08))
                        AxisValueLabel { if let v = mark.as(Double.self) { Text(Format.money(v)).foregroundStyle(Theme.text2) } }
                    }
                }
                .chartLegend(position: .bottom, alignment: .leading, spacing: 8)
                .frame(height: 220)
            }
        }
        .artCard(tint: Theme.violet)
    }

    // MARK: Countries

    private func countries(_ state: GameState) -> some View {
        let markets = (state.lastReport?.markets ?? []).sorted { $0.profit < $1.profit }
        let scale = max(1, markets.map { max($0.revenue, $0.costs) }.max() ?? 1)
        return VStack(alignment: .leading, spacing: 12) {
            SectionTitle(text: "Country by country", icon: "globe", tint: Theme.teal)
            Text("Each country's income against what it costs to stream, run and market there. Company-wide costs like staff aren't included.")
                .font(.caption2).foregroundStyle(Theme.text2)
            if markets.isEmpty { Text("No data yet.").font(.footnote).foregroundStyle(Theme.text2) }
            ForEach(markets) { market in
                let country = CountryData.country(market.id)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("\(country?.flag ?? "") \(country?.name ?? market.id)").font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                        Spacer()
                        Text("\(market.profit >= 0 ? "+" : "-")\(Format.money(abs(market.profit)))")
                            .font(Theme.number(14)).foregroundStyle(market.profit.profitColor)
                    }
                    StatBar(label: "Earns", value: market.revenue / scale, text: Format.money(market.revenue), tint: Theme.good, height: 4, compact: true)
                    StatBar(label: "Costs", value: market.costs / scale, text: Format.money(market.costs), tint: Theme.danger, height: 4, compact: true)
                }
            }
        }
        .artCard(tint: Theme.teal)
    }

    // MARK: Lifetime

    private func lifetime(_ state: GameState) -> some View {
        let total = state.finances.lifetime
        let lines = CostCategory.allCases.map { ($0, $0.amount(in: total)) }.filter { $0.1 > 0 }.sorted { $0.1 > $1.1 }
        let biggest = max(1, lines.first?.1 ?? 1)
        return VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "Since day one", icon: "calendar", tint: Theme.amber)
            LabeledValue(label: "Total revenue", value: Format.money(total.revenue), tint: Theme.good)
            LabeledValue(label: "Total spending", value: Format.money(total.costs), tint: Theme.danger)
            LabeledValue(label: "Net", value: Format.money(total.profit), tint: total.profit.profitColor)
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                StatBar(label: line.0.displayName, value: line.1 / biggest, text: Format.money(line.1), tint: Theme.amber, height: 4, compact: true)
            }
        }
        .artCard(tint: Theme.amber)
    }
}
