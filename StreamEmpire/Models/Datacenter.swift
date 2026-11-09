import Foundation

/// A datacenter you own in one region. It streams for subscribers there once built.
struct Datacenter: Codable, Identifiable, Equatable {
    var id: Int
    var name: String
    var region: Region
    var level: Int              // 1...5
    var weeksToBuild: Int       // 0 = online

    var isOnline: Bool { weeksToBuild <= 0 }
    var capacity: Double { isOnline ? Formulas.datacenterCapacity(level: level) : 0 }
}
