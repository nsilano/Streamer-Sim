import SwiftUI

/// Blocking sheet for choice events.
struct DecisionView: View {
    @EnvironmentObject var store: GameStore
    let event: GameEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: event.kind == .warning ? "exclamationmark.triangle.fill" : "newspaper.fill")
                .font(.largeTitle).foregroundStyle(event.kind == .warning ? Theme.danger : Theme.amber)
                .padding(.top, 24)
            Text(event.headline).font(Theme.display(28)).foregroundStyle(.white)
            Text(event.detail).foregroundStyle(Theme.text2)
            Spacer(minLength: 8)
            ForEach(event.choices) { choice in
                Button {
                    store.perform { try $0.resolveEvent(choiceID: choice.id) }
                } label: {
                    Text(choice.label).multilineTextAlignment(.center)
                }
                .buttonStyle(GlowButtonStyle(tint: Theme.magenta))
            }
            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ArtBackground())
        .preferredColorScheme(.dark)
    }
}
