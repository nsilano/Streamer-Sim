import SwiftUI

/// Bridges the pure game state to SwiftUI. Autosaves after every change.
@MainActor
final class GameStore: ObservableObject {
    @Published private(set) var state: GameState?
    @Published var showReport = false
    @Published var showSettings = false
    @Published var showExpiring = false
    @Published var errorMessage: String?
    @Published var autoSpeed: Double = 0.7        // seconds per week
    @Published var autoAdvance = false {
        didSet { autoAdvance ? startAutoAdvance() : stopAutoAdvance() }
    }

    private var autoTask: Task<Void, Never>?

    init() {
        state = SaveManager.load()
    }

    func newGame(companyName: String, country: String, difficulty: Difficulty = .medium, scenario: Scenario = .sandbox) {
        let name = companyName.trimmingCharacters(in: .whitespaces)
        let seed = UInt64.random(in: 1...UInt64.max)
        state = GameState.newGame(startCountry: country,
                                  companyName: name.isEmpty ? "Stream Empire" : name,
                                  seed: seed, difficulty: difficulty, scenario: scenario)
        persist()
    }

    /// Starts the same company over in the same country. `sameWorld` replays the exact same random world.
    func restart(sameWorld: Bool) {
        guard let current = state else { return }
        autoAdvance = false
        showReport = false
        state = current.restarted(sameWorld: sameWorld, newSeed: UInt64.random(in: 1...UInt64.max))
        persist()
    }

    func resetGame() {
        autoAdvance = false
        showSettings = false
        showReport = false
        SaveManager.delete()
        state = nil
    }

    func nextWeek(showReport: Bool = true) {
        guard let current = state, current.outcome == .playing else { return }
        let hadAlert = current.pendingEvent?.id
        defer { recordBestScore() }
        state = SimulationEngine.advanceWeek(current)
        persist()
        // Stop auto-advance when the game ends or a NEW alert appears.
        let newAlert = state?.pendingEvent != nil && state?.pendingEvent?.id != hadAlert
        // Licenses crossing the 12- or 4-week line stop the sim and open the renewal sheet.
        let expiring = !(state?.newlyExpiring.isEmpty ?? true)
        if state?.outcome != .playing || newAlert || expiring { autoAdvance = false }
        if expiring {
            self.showReport = false
            showExpiring = true
        } else if showReport {
            self.showReport = true
        }
    }

    /// Remembers your best score per scenario on this device.
    private func recordBestScore() {
        guard let s = state, s.outcome == .won, s.score > 0 else { return }
        let key = "bestScore_\(s.scenario.rawValue)"
        if s.score > UserDefaults.standard.integer(forKey: key) { UserDefaults.standard.set(s.score, forKey: key) }
    }

    func bestScore(_ scenario: Scenario) -> Int { UserDefaults.standard.integer(forKey: "bestScore_\(scenario.rawValue)") }

    /// Applies a player action; surfaces failures as an alert message.
    func perform(_ action: (inout GameState) throws -> Void) {
        guard var current = state else { return }
        do {
            try action(&current)
            state = current
            persist()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func persist() {
        guard let state else { return }
        try? SaveManager.save(state)
    }

    private func startAutoAdvance() {
        autoTask?.cancel()
        autoTask = Task { [weak self] in
            while !Task.isCancelled {
                let seconds = self?.autoSpeed ?? 0.7
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                guard !Task.isCancelled else { break }
                self?.nextWeek(showReport: false)
            }
        }
    }

    private func stopAutoAdvance() {
        autoTask?.cancel()
        autoTask = nil
    }
}
