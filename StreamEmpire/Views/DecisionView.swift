import SwiftUI

/// Blocking sheet for choice events.
struct DecisionView: View {
    @EnvironmentObject var store: GameStore
    let event: GameEvent

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(event.headline).font(.title2.bold())
                Text(event.detail).foregroundStyle(.secondary)
                Spacer(minLength: 8)
                ForEach(event.choices) { choice in
                    Button {
                        store.perform { try $0.resolveEvent(choiceID: choice.id) }
                    } label: {
                        Text(choice.label).frame(maxWidth: .infinity).padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                }
                Spacer()
            }
            .padding()
            .navigationTitle("Decision")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
