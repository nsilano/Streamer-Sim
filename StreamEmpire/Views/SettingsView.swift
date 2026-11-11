import SwiftUI

/// Back out of a playthrough, restart it, or tweak how the game runs.
struct SettingsView: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.dismiss) private var dismiss
    @State private var confirm: Action?
    @State private var showHelp = false

    enum Action: String, Identifiable {
        case restartNew, restartSame, quit
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let state = store.state { playthrough(state) }
                    gameplay
                    about
                }
                .padding(16)
            }
            .artScreen()
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Done") { dismiss() } }
            .sheet(isPresented: $showHelp) { HowToPlayView() }
            .confirmationDialog(title(for: confirm), isPresented: Binding(get: { confirm != nil }, set: { if !$0 { confirm = nil } }),
                                titleVisibility: .visible) {
                if let action = confirm {
                    Button(buttonTitle(action), role: .destructive) { perform(action) }
                    Button("Cancel", role: .cancel) {}
                }
            } message: {
                Text(message(for: confirm))
            }
        }
    }

    private func playthrough(_ state: GameState) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(text: "This playthrough", icon: "arrow.triangle.2.circlepath")
            VStack(alignment: .leading, spacing: 4) {
                Text(state.companyName).font(Theme.display(22)).foregroundStyle(.white)
                let home = CountryData.country(state.startCountry)
                Text("\(home?.flag ?? "") \(home?.name ?? "Unknown") · week \(state.week) · \(Format.count(state.totalSubscribers)) subscribers")
                    .font(.footnote).foregroundStyle(Theme.text2)
                Pill(text: "\(state.difficulty.title) difficulty", tint: Theme.amber, icon: "speedometer")
            }
            Button { confirm = .restartNew } label: {
                Label("Restart in \(CountryData.country(state.startCountry)?.name ?? "the same country")", systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SoftButtonStyle(tint: Theme.amber))
            Text("Starts a brand-new random world with your company name and home market.")
                .font(.caption).foregroundStyle(Theme.text2)

            Button { confirm = .restartSame } label: {
                Label("Replay the exact same world", systemImage: "repeat").frame(maxWidth: .infinity)
            }
            .buttonStyle(SoftButtonStyle(tint: Theme.teal))
            Text("Same country and the same random seed, so the market and licenses start identical. Good for trying a different strategy.")
                .font(.caption).foregroundStyle(Theme.text2)

            Button { confirm = .quit } label: {
                Label("Quit to country select", systemImage: "rectangle.portrait.and.arrow.right").frame(maxWidth: .infinity)
            }
            .buttonStyle(SoftButtonStyle(tint: Theme.danger))
            Text("Abandons this playthrough and lets you pick a different home country.")
                .font(.caption).foregroundStyle(Theme.text2)
        }
        .artCard(tint: Theme.amber)
    }

    private var gameplay: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(text: "Gameplay", icon: "slider.horizontal.3", tint: Theme.teal)
            Text("Speed").font(.subheadline).foregroundStyle(.white)
            Picker("Speed", selection: $store.autoSpeed) {
                Text("1x").tag(1.0); Text("2x").tag(0.5); Text("4x").tag(0.25); Text("8x").tag(0.12)
            }
            .pickerStyle(.segmented)
            if let state = store.state {
                Text("Automation").font(.subheadline.weight(.semibold)).foregroundStyle(.white).padding(.top, 4)
                Picker("Stop the sim for", selection: Binding(get: { state.pauseSensitivity },
                                                               set: { value in store.perform { $0.pauseSensitivity = value } })) {
                    ForEach(PauseSensitivity.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                Text(state.pauseSensitivity.blurb).font(.caption).foregroundStyle(Theme.text2)
                Toggle(isOn: Binding(get: { state.autoScale }, set: { value in store.perform { $0.autoScale = value } })) {
                    Text("Scale servers automatically").font(.subheadline).foregroundStyle(.white)
                }
                .tint(Theme.teal)
                Text("Rents cloud capacity when a region passes 85% load and gives it back when it's quiet. Datacenters stay up to you.")
                    .font(.caption).foregroundStyle(Theme.text2)
            }
            Button { showHelp = true } label: {
                Label("How to play", systemImage: "questionmark.circle").frame(maxWidth: .infinity)
            }
            .buttonStyle(SoftButtonStyle())
        }
        .artCard(tint: Theme.teal)
    }

    private var about: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionTitle(text: "About", icon: "info.circle", tint: Theme.violet)
            Text("Your game saves automatically after every action. All companies, shows and rivals are fictional parodies.")
                .font(.footnote).foregroundStyle(Theme.text2)
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
            let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
            Text("Version \(version) (\(build))").font(.caption).foregroundStyle(Theme.text2)
        }
        .artCard()
    }

    // MARK: Confirmation

    private func title(for action: Action?) -> String {
        switch action {
        case .restartNew: return "Restart this playthrough?"
        case .restartSame: return "Replay the same world?"
        case .quit: return "Quit this playthrough?"
        case nil: return ""
        }
    }

    private func message(for action: Action?) -> String {
        switch action {
        case .restartNew, .restartSame: return "Your current progress will be lost."
        case .quit: return "Your current progress will be lost and you'll pick a new home country."
        case nil: return ""
        }
    }

    private func buttonTitle(_ action: Action) -> String {
        switch action {
        case .restartNew: return "Restart"
        case .restartSame: return "Replay"
        case .quit: return "Quit"
        }
    }

    private func perform(_ action: Action) {
        switch action {
        case .restartNew: store.restart(sameWorld: false); dismiss()
        case .restartSame: store.restart(sameWorld: true); dismiss()
        case .quit: store.resetGame()
        }
    }
}
