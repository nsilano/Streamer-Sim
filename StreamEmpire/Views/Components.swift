import SwiftUI
import Charts

/// Subscribers, revenue, profit and cash over the past year or the whole company history, on a calendar axis.
struct TrendCard: View {
    enum Metric: String, CaseIterable, Identifiable {
        case subs = "Subscribers", revenue = "Revenue", profit = "Profit", cash = "Cash"
        var id: String { rawValue }
    }
    enum Span: String, CaseIterable, Identifiable {
        case year = "Past year", all = "All time"
        var id: String { rawValue }
    }

    let points: [TrendPoint]
    @State private var metric: Metric = .subs
    @State private var span: Span = .year

    private func value(_ p: TrendPoint) -> Double {
        switch metric {
        case .subs: return p.subs
        case .revenue: return p.revenue
        case .profit: return p.profit
        case .cash: return p.cash
        }
    }

    private func label(_ v: Double) -> String { metric == .subs ? Format.count(v) : Format.money(v) }

    var body: some View {
        let shown = span == .year ? Array(points.suffix(52)) : points
        let first = shown.first, last = shown.last
        VStack(alignment: .leading, spacing: 10) {
            Picker("Metric", selection: $metric) {
                ForEach(Metric.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            Picker("Span", selection: $span) {
                ForEach(Span.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            if let first, let last {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(label(value(last))).font(Theme.number(22)).foregroundStyle(.white)
                        Text("\(metric.rawValue) in \(Format.stamp(week: last.week))").font(.caption2).foregroundStyle(Theme.text2)
                    }
                    Spacer()
                    let change = value(last) - value(first)
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(change >= 0 ? "+" : "-")\(label(abs(change)))").font(.subheadline.weight(.bold))
                            .foregroundStyle(change >= 0 ? Theme.good : Theme.danger)
                        Text("since \(GameCalendar.dateText(week: first.week))").font(.caption2).foregroundStyle(Theme.text2)
                    }
                }
            }
            Chart {
                ForEach(shown, id: \.week) { p in
                    if metric == .profit {
                        BarMark(x: .value("Date", GameCalendar.date(week: p.week), unit: .weekOfYear),
                                y: .value(metric.rawValue, p.profit))
                            .foregroundStyle(p.profit >= 0 ? Theme.good : Theme.danger)
                    } else {
                        AreaMark(x: .value("Date", GameCalendar.date(week: p.week)), y: .value(metric.rawValue, value(p)))
                            .interpolationMethod(.monotone)
                            .foregroundStyle(LinearGradient(colors: [Theme.magenta.opacity(0.30), Color.clear],
                                                            startPoint: .top, endPoint: .bottom))
                        LineMark(x: .value("Date", GameCalendar.date(week: p.week)), y: .value(metric.rawValue, value(p)))
                            .interpolationMethod(.monotone)
                            .foregroundStyle(Theme.accentGradient)
                            .lineStyle(StrokeStyle(lineWidth: 2.5))
                    }
                }
                if metric == .profit || metric == .cash {
                    RuleMark(y: .value("Zero", 0)).foregroundStyle(Color.white.opacity(0.35))
                }
            }
            .chartXScale(domain: (first.map { GameCalendar.date(week: $0.week) } ?? GameCalendar.date(week: 1))
                         ... (last.map { GameCalendar.date(week: max($0.week, (first?.week ?? 1) + 1)) } ?? GameCalendar.date(week: 2)))
            .chartYAxis {
                AxisMarks(position: .trailing) { mark in
                    AxisGridLine().foregroundStyle(Color.white.opacity(0.08))
                    AxisValueLabel {
                        if let v = mark.as(Double.self) { Text(label(v)).foregroundStyle(Theme.text2) }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                    AxisGridLine().foregroundStyle(Color.white.opacity(0.05))
                    AxisValueLabel(format: span == .year ? .dateTime.month(.abbreviated) : .dateTime.month(.abbreviated).year(.twoDigits))
                        .foregroundStyle(Theme.text2)
                }
            }
            .frame(height: 190)
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

/// A compact navigation tile for hub screens.
struct HubTile: View, Identifiable {
    let icon: String
    let title: String
    let subtitle: String
    let tint: Color
    let destination: () -> AnyView
    var id: String { title }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.title3).foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(RoundedRectangle(cornerRadius: 10).fill(tint.opacity(0.18)))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.bold)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.75)
                Text(subtitle).font(.caption2).foregroundStyle(Theme.text2).lineLimit(1).minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 14).fill(tint.opacity(0.12)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(tint.opacity(0.35), lineWidth: 1))
    }
}
