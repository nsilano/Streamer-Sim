import SwiftUI
import Charts

struct StatCard: View {
    let title: String
    let value: String
    var subtitle: String? = nil
    var tint: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title3.bold()).foregroundStyle(tint).minimumScaleFactor(0.6).lineLimit(1)
            if let subtitle {
                Text(subtitle).font(.caption2).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct LabeledValue: View {
    let label: String
    let value: String
    var tint: Color = .primary

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value).foregroundStyle(tint).monospacedDigit()
        }
    }
}

extension Double {
    var profitColor: Color { self >= 0 ? .green : .red }
}


/// Subscribers / profit / cash over the last weeks of reports.
struct TrendCard: View {
    enum Metric: String, CaseIterable, Identifiable {
        case subs = "Subscribers", profit = "Profit", cash = "Cash"
        var id: String { rawValue }
    }

    let reports: [WeeklyReport]
    @State private var metric: Metric = .subs

    private func value(_ report: WeeklyReport) -> Double {
        switch metric {
        case .subs: return report.totalSubs
        case .profit: return report.financials.profit
        case .cash: return report.cashEnd
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Metric", selection: $metric) {
                ForEach(Metric.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            Chart(reports, id: \.week) { report in
                LineMark(x: .value("Week", report.week), y: .value(metric.rawValue, value(report)))
                    .interpolationMethod(.monotone)
            }
            .chartYAxis {
                AxisMarks { mark in
                    AxisGridLine()
                    AxisValueLabel {
                        if let v = mark.as(Double.self) {
                            Text(metric == .subs ? Format.count(v) : Format.money(v))
                        }
                    }
                }
            }
            .frame(height: 140)
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
