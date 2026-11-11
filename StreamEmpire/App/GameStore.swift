import SwiftUI

/// Bridges the pure game state to SwiftUI. Autosaves after every change.
@MainActor
final class GameStore: ObservableObject {
    @Published private(set) var state: GameState?
    @Published var showReport = false
    @Published var showSettings = false
    @Published var showExpiring = false
    @Published var pauseReasons: [PauseReason] = []   // why auto-advance stopped; stays until dismissed or resumed
    @Published var errorMessage: String?
    @Published var autoSpeed: Double = 0.5        // seconds per week (2x)
    @Published var autoAdvance = false {
        didSet {
            if autoAdvance { pauseReasons = [] }
            autoAdvance ? startAutoAdvance() : stopAutoAdvance()
        }
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
        state?.renewalMode = .standard     // reasonable renewals happen by themselves
        state?.expiryAlerts = .show        // expiring titles are shown, not forced on you
        state?.pauseSensitivity = .critical  // only disasters stop the sim
        state?.autoScale = true            // servers scale themselves
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

    func dismissPause() { pauseReasons = [] }

    func resetGame() {
        autoAdvance = false
        showSettings = false
        showReport = false
        saveTask?.cancel()
        saveTask = nil
        SaveManager.delete()
        state = nil
    }

    func nextWeek(showReport: Bool = true) {
        guard let current = state, current.outcome == .playing else { return }
        defer { recordBestScore() }
        let next = SimulationEngine.advanceWeek(current)
        state = next
        persist()
        // Anything major stops the sim and stays on screen until you react.
        let reasons = PauseCheck.reasons(before: current, after: next).filter { next.pauseSensitivity.stops($0.id) }
        if !reasons.isEmpty {
            autoAdvance = false
            pauseReasons = reasons
        }
        let expiring = !next.newlyExpiring.isEmpty
        if expiring {
            state?.lastExpiryStopWeek = next.week
            persist()
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

    private var saveTask: Task<Void, Never>?

    /// Autosaves after every change. Huge libraries (thousands of titles) make a save slow, so those are
    /// batched: the latest state is written at most once every couple of seconds.
    private func persist() {
        guard let state else { return }
        if state.catalog.count < 1_500 {
            saveTask?.cancel()
            try? SaveManager.save(state)
            return
        }
        guard saveTask == nil else { return }
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard let self else { return }
            self.saveTask = nil
            if let latest = self.state { try? SaveManager.save(latest) }
        }
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
