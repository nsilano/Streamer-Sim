import SwiftUI

/// Parses "2500000", "2,500,000", "$2.5m", "750k" into a number. Returns nil if it isn't one.
func parseAmount(_ text: String) -> Double? {
    var t = text.lowercased().filter { !" ,$".contains($0) }
    guard !t.isEmpty else { return nil }
    var factor = 1.0
    if t.hasSuffix("k") { factor = 1_000; t.removeLast() }
    else if t.hasSuffix("m") { factor = 1_000_000; t.removeLast() }
    else if t.hasSuffix("b") { factor = 1_000_000_000; t.removeLast() }
    guard let value = Double(t) else { return nil }
    return value * factor
}

/// A label with a typed number on the right. The value is clamped to `range` when you finish typing.
struct NumberFieldRow: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var isMoney = false
    var suffix = ""

    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack {
            Text(label).foregroundStyle(Theme.text2)
            Spacer()
            if isMoney { Text("$").foregroundStyle(Theme.text2) }
            TextField("0", text: $text)
                .keyboardType(isMoney ? .decimalPad : .numberPad)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .frame(maxWidth: 140)
                .focused($focused)
                .onChange(of: text) { _, new in
                    if let parsed = parseAmount(new) { value = min(range.upperBound, max(range.lowerBound, parsed)) }
                }
                .onChange(of: focused) { _, isFocused in if !isFocused { text = format(value) } }
                .onSubmit { text = format(value) }
            if !suffix.isEmpty { Text(suffix).foregroundStyle(Theme.text2) }
        }
        .font(.subheadline)
        .onAppear { text = format(value) }
    }

    private func format(_ v: Double) -> String { String(Int(v.rounded())) }
}

/// Whole-number version of `NumberFieldRow`.
struct IntFieldRow: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    var suffix = ""

    var body: some View {
        NumberFieldRow(label: label,
                       value: Binding(get: { Double(value) }, set: { value = Int($0.rounded()) }),
                       range: Double(range.lowerBound)...Double(range.upperBound), suffix: suffix)
    }
}
