import SwiftUI

/// "What should I do next?" in one list.
struct AdvisorView: View {
    @EnvironmentObject var store: GameStore

    var body: some View {
        ScrollView {
            if let state = store.state {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Ranked by urgency. These are suggestions, not orders.").font(.footnote).foregroundStyle(Theme.text2)
                    let items = state.recommendations()
                    if items.isEmpty {
                        Text("Nothing urgent. Keep growing!").foregroundStyle(.white).artCard(tint: Theme.good)
                    }
                    ForEach(items) { AdviceBanner(advice: $0) }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .artScreen()
        .navigationTitle("Advisor")
        .navigationBarTitleDisplayMode(.inline)
    }
}
