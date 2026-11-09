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

/// Type an exact dollar amount (e.g. 9.99). Commits when you tap Done or leave the field.
struct PriceField: View {
    let value: Double
    let onCommit: (Double) -> Void

    @State private var text = ""
    @FocusState private var focused: Bool

    private func format(_ v: Double) -> String { String(format: "%.2f", v) }

    private func commit() {
        let cleaned = text.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
        if let parsed = Double(cleaned), parsed >= 0 {
            let clamped = min(100, parsed)
            onCommit(clamped)
            text = format(clamped)
        } else {
            text = format(value)
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Button { onCommit(max(0, value - 0.5)) } label: { Image(systemName: "minus.circle.fill") }
                .buttonStyle(.plain).foregroundStyle(Theme.text2)
            HStack(spacing: 2) {
                Text("$").foregroundStyle(Theme.text2)
                TextField("0.00", text: $text)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.leading)
                    .focused($focused)
                    .frame(width: 64)
                    .font(Theme.number(17))
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.10)))
            Button { onCommit(min(100, value + 0.5)) } label: { Image(systemName: "plus.circle.fill") }
                .buttonStyle(.plain).foregroundStyle(Theme.text2)
        }
        .onAppear { text = format(value) }
        .onChange(of: value) { _, new in if !focused { text = format(new) } }
        .onChange(of: focused) { _, isFocused in if !isFocused { commit() } }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focused = false }
            }
        }
    }
}
