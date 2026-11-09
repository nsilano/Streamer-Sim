import Foundation

enum EventKind: String, Codable {
    case milestone, marketLive, licenseExpired, licenseLost, warning, news
}

struct EventChoice: Codable, Equatable, Identifiable {
    var id: String
    var label: String
}

/// Something that happened this week. Choice-based events arrive in Phase 3.
struct GameEvent: Codable, Identifiable, Equatable {
    var id: Int
    var week: Int
    var kind: EventKind
    var headline: String
    var detail: String
    var choices: [EventChoice] = []
    var key: String = ""          // identifies the event type for choice resolution
}
