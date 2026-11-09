import SwiftUI

/// Non-blocking red alert shown on the Dashboard. The sim keeps running; if the
/// player ignores it, the default choice is applied when it expires.
struct AlertCard: View {
    @EnvironmentObject var store: GameStore
    let event: GameEvent
    let week: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(event.headline, systemImage: "exclamationmark.triangle.fill")
                .font(.headline).foregroundStyle(Theme.danger)
            Text(event.detail).font(.footnote).foregroundStyle(Theme.text2)
            if event.expiresWeek > week {
                Text("Resolves on its own in \(event.expiresWeek - week) wk if ignored.")
                    .font(.caption2).foregroundStyle(Theme.text2)
            }
            ForEach(event.choices) { choice in
                Button {
                    store.perform { try $0.resolveEvent(choiceID: choice.id) }
                } label: {
                    Text(choice.label).multilineTextAlignment(.center).frame(maxWidth: .infinity)
                }
                .buttonStyle(SoftButtonStyle())
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.danger.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.danger.opacity(0.7), lineWidth: 1))
    }
}
