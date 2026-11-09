import Foundation

/// An original show/movie in production.
struct OriginalProject: Codable, Identifiable, Equatable {
    var id: Int
    var name: String
    var kind: TitleKind
    var genre: Genre
    var language: Language
    var budget: Double
    var weeksTotal: Int
    var weeksLeft: Int
    var weeklyCost: Double
    var studioID: Int? = nil       // nil = outsourced; otherwise produced in-house at that studio

    var progress: Double { 1 - Double(weeksLeft) / Double(max(1, weeksTotal)) }
}
