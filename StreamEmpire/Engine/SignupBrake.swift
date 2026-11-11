import Foundation

/// An emergency brake on new subscribers, for when servers are close to falling over.
extension GameState {
    static let allScope = "all"

    func signupsPaused(in region: Region) -> Bool {
        pausedSignups.contains(GameState.allScope) || pausedSignups.contains(region.rawValue)
    }

    var anySignupsPaused: Bool { !pausedSignups.isEmpty }

    /// Human-readable list of where sign-ups are shut off.
    var pausedSignupsText: String {
        if pausedSignups.contains(GameState.allScope) { return "everywhere" }
        return pausedSignups.compactMap { Region(rawValue: $0)?.displayName }.sorted().joined(separator: ", ")
    }

    /// Shuts off (or reopens) new sign-ups everywhere ("all") or in one region. Existing subscribers stay and keep paying.
    mutating func setSignupsPaused(scope: String, paused: Bool) throws {
        guard outcome == .playing else { throw ActionError.gameOver }
        guard scope == GameState.allScope || Region(rawValue: scope) != nil else { throw ActionError.invalidAmount }
        let was = pausedSignups.contains(scope)
        guard was != paused else { return }
        if paused { pausedSignups.append(scope) } else { pausedSignups.removeAll { $0 == scope } }
        let where_ = scope == GameState.allScope ? "everywhere" : (Region(rawValue: scope)?.displayName ?? scope)
        addNews(.you, paused ? "\(companyName) pauses new sign-ups \(scope == GameState.allScope ? "worldwide" : "in \(where_)")"
                              : "\(companyName) reopens sign-ups \(scope == GameState.allScope ? "worldwide" : "in \(where_)")",
                paused ? "Existing subscribers are unaffected. Remember to switch it off when the servers can cope."
                       : "New customers can join again.")
    }
}
