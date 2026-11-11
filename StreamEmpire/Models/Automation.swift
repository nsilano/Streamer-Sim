import Foundation

/// How readily the sim stops itself and waits for you.
enum PauseSensitivity: String, Codable, CaseIterable, Identifiable {
    case critical, important, everything
    var id: String { rawValue }

    var title: String {
        switch self {
        case .critical: return "Only disasters"
        case .important: return "Important"
        case .everything: return "Everything"
        }
    }

    var blurb: String {
        switch self {
        case .critical: return "Stops only for game over, running out of cash and servers at full capacity. Everything else shows on the Dashboard and in Chirp while the sim keeps running."
        case .important: return "Also stops for a short cash runway, server crashes and your own pending decisions."
        case .everything: return "Also stops for price wars, recalled or expired licenses and servers nearing full."
        }
    }

    /// Whether a pause reason (see `PauseCheck`) is serious enough to stop the sim at this setting.
    func stops(_ reasonID: String) -> Bool {
        if reasonID == "outcome" || reasonID == "cash" || reasonID.hasPrefix("load100-") { return true }
        switch self {
        case .critical:
            return false
        case .important:
            return reasonID == "runway" || reasonID.hasPrefix("crash-") || reasonID.hasPrefix("alert-") || reasonID == "expiring"
        case .everything:
            return true
        }
    }
}
