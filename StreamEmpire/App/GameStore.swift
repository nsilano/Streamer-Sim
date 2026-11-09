import SwiftUI

/// Bridges the pure game state to SwiftUI. Autosaves after every change.
@MainActor
final class GameStore: ObservableObject {
    @Published private(set) var state: GameState?
    @Published var showReport = false
    @Published var errorMessage: String?
    @Published var autoAdvance = false {
        didSet { autoAdvance ? startAutoAdvance() : stopAutoAdvance() }
    }

    private var autoTask: Task<Void, Never>?

    init() {
        state = SaveManager.load()
    }

    func newGame(companyName: String, country: String) {
        let name = companyName.trimmingCharacters(in: .whitespaces)
        let seed = UInt64.random(in: 1...UInt64.max)
        state = GameState.newGame(startCountry: country,
                                  companyName: name.isEmpty ? "Stream Empire" : name,
                                  seed: seed)
        persist()
    }

    func resetGame() {
        autoAdvance = false
        SaveManager.delete()
        state = nil
    }

    func nextWeek(showReport: Bool = true) {
        guard let current = state, current.outcome == .playing else { return }
        state = SimulationEngine.advanceWeek(current)
        persist()
        // Stop auto-advance when the game ends or a decision is waiting.
        if state?.outcome != .playing || state?.pendingEvent != nil { autoAdvance = false }
        if showReport && state?.pendingEvent == nil { self.showReport = true }
    }

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
                try? await Task.sleep(nanoseconds: 700_000_000)
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
