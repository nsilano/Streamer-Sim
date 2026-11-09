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
                        .tabItem { Label("Markets", systemImage: "globe.europe.africa.fill") }
                    ContentTabView()
                        .tabItem { Label("Content", systemImage: "film.stack") }
                    RivalsView()
                        .tabItem { Label("Rivals", systemImage: "trophy.fill") }
                    CompanyView()
                        .tabItem { Label("Company", systemImage: "building.2.fill") }
                }
                .tint(Theme.magenta)
                .sheet(isPresented: Binding(get: { state.pendingEvent != nil && state.outcome == .playing },
                                            set: { _ in })) {
                    if let event = store.state?.pendingEvent {
                        DecisionView(event: event).interactiveDismissDisabled()
                    }
                }
                .fullScreenCover(isPresented: Binding(get: { state.outcome != .playing }, set: { _ in })) {
                    if let current = store.state { GameOverView(state: current) }
                }
            } else {
                NewGameView()
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $store.showSettings) { SettingsView() }
        .alert("Can't do that", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.errorMessage ?? "")
        }
    }
}

/// Shown when you win or go bankrupt.
struct GameOverView: View {
    @EnvironmentObject var store: GameStore
    let state: GameState

    private var won: Bool { state.outcome == .won }

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: won ? "crown.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 54))
                .foregroundStyle(won ? Theme.amber : Theme.danger)
            Text(won ? "YOU'RE #1" : "BANKRUPT")
                .font(.system(size: 44, weight: .black, design: .serif)).tracking(5)
                .foregroundStyle(won ? Theme.amber : Theme.danger)
            Text(won ? "\(state.companyName) is the biggest streaming platform in the world."
                     : (state.lossReason ?? "\(state.companyName) ran out of money."))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 28)
            HStack(spacing: 12) {
                BigStat(title: "Weeks played", value: "\(state.week - 1)")
                BigStat(title: "Subscribers", value: Format.count(state.totalSubscribers))
            }
            .padding(.horizontal, 20)
            Spacer()
            VStack(spacing: 10) {
                Button("Restart in \(CountryData.country(state.startCountry)?.name ?? "the same country")") {
                    store.restart(sameWorld: false)
                }
                .buttonStyle(GlowButtonStyle())
                Button("Choose a different country") { store.resetGame() }
                    .buttonStyle(SoftButtonStyle())
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 30)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ArtBackground())
        .preferredColorScheme(.dark)
    }
}
