import Foundation

/// Autosave to a single JSON file in the app's Documents directory.
enum SaveManager {
    static var defaultURL: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return dir.appendingPathComponent("stream-empire-save.json")
    }

    static func save(_ state: GameState, to url: URL = defaultURL) throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(state)
        try data.write(to: url, options: .atomic)
    }

    /// Returns nil if there is no save or it can't be read.
    static func load(from url: URL = defaultURL) -> GameState? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        guard let state = try? JSONDecoder().decode(GameState.self, from: data),
              state.version == GameState.currentVersion else { return nil }
        return state
    }

    static func delete(at url: URL = defaultURL) {
        try? FileManager.default.removeItem(at: url)
    }
}
