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
    var release: ReleaseStyle = .binge
    var star: StarTier = .none
    var sequelOf: Int? = nil       // id of the title this continues (next season or sequel)

    var progress: Double { 1 - Double(weeksLeft) / Double(max(1, weeksTotal)) }
}

/// Drop everything at once, or one episode a week.
enum ReleaseStyle: String, Codable, CaseIterable, Identifiable {
    case binge, weekly
    var id: String { rawValue }
    var displayName: String { self == .binge ? "Binge (all at once)" : "Weekly episodes" }
    var blurb: String {
        self == .binge ? "A big launch spike, then it fades faster."
                       : "A smaller launch, but it keeps people subscribed longer."
    }
}

/// A name above the title: costs more, lifts quality and popularity, and may take a cut of the revenue.
enum StarTier: String, Codable, CaseIterable, Identifiable {
    case none, rising, aList
    var id: String { rawValue }
    var displayName: String {
        switch self { case .none: return "No star"; case .rising: return "Rising star"; case .aList: return "A-list star" }
    }
    var costFactor: Double { self == .none ? 1.0 : self == .rising ? 1.12 : 1.35 }
    var qualityBonus: Double { self == .none ? 0 : self == .rising ? 4 : 9 }
    var popularityBonus: Int { self == .none ? 0 : self == .rising ? 5 : 12 }
    /// Share of the title's revenue paid to the star every week.
    var profitShare: Double { self == .none ? 0 : self == .rising ? 0.02 : 0.05 }
}
