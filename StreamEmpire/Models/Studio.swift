import Foundation

/// An in-house production studio.
struct Studio: Codable, Identifiable, Equatable {
    var id: Int
    var name: String
    var specialty: Genre
    var level: Int              // 1...5
    var experience: Double      // 0...100, grows with every release
    var foundedWeek: Int

    /// Productions this studio can run at once.
    var slots: Int { level + 1 }
}
