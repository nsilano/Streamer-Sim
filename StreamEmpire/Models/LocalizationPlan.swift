import Foundation

enum SubtitleMode: String, Codable, CaseIterable, Identifiable {
    case off, all
    var id: String { rawValue }
    var title: String { self == .off ? "Off" : "Every title" }
}

enum DubMode: String, Codable, CaseIterable, Identifiable {
    case off, top, all
    var id: String { rawValue }
    var title: String { self == .off ? "Off" : self == .top ? "Top titles" : "Every title" }
}

/// Set-and-forget dubbing and subtitles: each week the studio localizes your catalog for the languages of the
/// markets you operate in, spending at most the weekly budget.
struct LocalizationPlan: Codable, Equatable {
    var subtitles: SubtitleMode = .off
    var dubs: DubMode = .off
    var topCount = 20                     // how many titles per language "Top titles" dubbing covers
    var weeklyBudget = 1_000_000.0        // most the automatic localization may spend in a week
}
