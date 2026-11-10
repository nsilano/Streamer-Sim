import Foundation

/// A goal with a deadline, picked on the new-game screen. Sandbox is the open-ended game.
enum Scenario: String, Codable, CaseIterable, Identifiable {
    case sandbox, tenMillion, profitable, dethrone
    var id: String { rawValue }

    var title: String {
        switch self {
        case .sandbox: return "Sandbox"
        case .tenMillion: return "10M in 3 years"
        case .profitable: return "Profit in 2 years"
        case .dethrone: return "Dethrone the king"
        }
    }

    var blurb: String {
        switch self {
        case .sandbox: return "No deadline. Build the biggest streaming service on Earth."
        case .tenMillion: return "Reach 10 million subscribers within 156 weeks."
        case .profitable: return "Be profitable for 8 straight weeks with 500K+ subscribers within 104 weeks."
        case .dethrone: return "Become #1 in the world within 8 years (416 weeks)."
        }
    }

    /// Weeks you get, or nil for no deadline.
    var deadline: Int? {
        switch self {
        case .sandbox: return nil
        case .tenMillion: return 156
        case .profitable: return 104
        case .dethrone: return 416
        }
    }
}
