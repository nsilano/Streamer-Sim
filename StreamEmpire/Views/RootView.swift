import SwiftUI

struct RootView: View {
    @EnvironmentObject var store: GameStore

    var body: some View {
        Group {
            if let state = store.state {
                TabView {
                    DashboardView()
                        .tabItem { Label("Dashboard", systemImage: "chart.line.uptrend.xyaxis") }
                    MarketsView()
                        .tabItem { Label("Markets", systemImage: "globe") }
                    ContentTabView()
                        .tabItem { Label("Content", systemImage: "film.stack") }
                    RivalsView()
                        .tabItem { Label("Rivals", systemImage: "trophy") }
                    CompanyView()
                        .tabItem { Label("Company", systemImage: "building.2") }
                }
                .sheet(isPresented: Binding(get: { state.pendingEvent != nil && state.outcome == .playing },
                                            set: { _ in })) {
                    if let event = store.state?.pendingEvent {
                        DecisionView(event: event)
                            .interactiveDismissDisabled()
                    }
                }
                .alert(item: outcomeBinding(state)) { outcome in
                    Alert(title: Text(outcome.title), message: Text(outcome.message),
                          dismissButton: .default(Text("New Game")) { store.resetGame() })
                }
            } else {
                NewGameView()
            }
        }
        .alert("Can't do that", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.errorMessage ?? "")
        }
    }

    private func outcomeBinding(_ state: GameState) -> Binding<OutcomeAlert?> {
        Binding(
            get: { OutcomeAlert(state.outcome, companyName: state.companyName) },
            set: { _ in })
    }
}

struct OutcomeAlert: Identifiable {
    let id: String
    let title: String
    let message: String

    init?(_ outcome: GameOutcome, companyName: String) {
        switch outcome {
        case .playing: return nil
        case .won:
            id = "won"; title = "You win!"
            message = "\(companyName) is the #1 streaming platform in the world."
        case .lost:
            id = "lost"; title = "Game over"
            message = "\(companyName) ran out of money."
        }
    }
}
