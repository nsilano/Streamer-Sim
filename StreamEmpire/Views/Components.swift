import SwiftUI
import Charts

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
        VStack(alignment: .leading, spacing: 10) {
            Picker("Metric", selection: $metric) {
                ForEach(Metric.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            Chart(reports, id: \.week) { report in
                LineMark(x: .value("Week", report.week), y: .value(metric.rawValue, value(report)))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(Theme.accentGradient)
                AreaMark(x: .value("Week", report.week), y: .value(metric.rawValue, value(report)))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(LinearGradient(colors: [Theme.magenta.opacity(0.30), Color.clear],
                                                    startPoint: .top, endPoint: .bottom))
            }
            .chartYAxis {
                AxisMarks { mark in
                    AxisGridLine().foregroundStyle(Color.white.opacity(0.08))
                    AxisValueLabel {
                        if let v = mark.as(Double.self) {
                            Text(metric == .subs ? Format.count(v) : Format.money(v))
                                .foregroundStyle(Theme.text2)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks { _ in AxisValueLabel().foregroundStyle(Theme.text2) }
            }
            .frame(height: 150)
        }
        .artCard()
    }
}


/// A horizontal bar split into coloured segments (values are fractions that should sum to <= 1).
struct StackedBar: View {
    struct Segment: Identifiable {
        let id: String
        let value: Double
        let color: Color
    }

    let segments: [Segment]
    var height: CGFloat = 12

    var body: some View {
        GeometryReader { proxy in
            HStack(spacing: 1) {
                ForEach(segments) { segment in
                    Rectangle()
                        .fill(segment.color)
                        .frame(width: max(0, proxy.size.width * CGFloat(min(max(segment.value, 0), 1))))
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.10))
            .clipShape(Capsule())
        }
        .frame(height: height)
    }
}
