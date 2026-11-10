import Foundation

enum Scenarios {
    struct Verdict { var won: Bool; var text: String }

    /// Win or lose a scenario, or nil while it is still open. `dethrone` uses the normal #1 rule plus a deadline.
    static func verdict(_ s: GameState, totalSubs: Double) -> Verdict? {
        guard let deadline = s.scenario.deadline else { return nil }
        switch s.scenario {
        case .tenMillion:
            if totalSubs >= 10_000_000 { return Verdict(won: true, text: "You reached 10 million subscribers.") }
        case .profitable:
            let recent = s.finances.profitHistory.suffix(8)
            if totalSubs >= 500_000, recent.count == 8, recent.allSatisfy({ $0 > 0 }) {
                return Verdict(won: true, text: "Eight profitable weeks in a row with \(Format.count(totalSubs)) subscribers.")
            }
        default:
            break
        }
        if s.week >= deadline {
            return Verdict(won: false, text: "Time ran out: the \(s.scenario.title) challenge needed to be done within \(deadline) weeks.")
        }
        return nil
    }

    /// Points for a finished scenario: audience, cash, and weeks left on the clock.
    static func score(_ s: GameState) -> Int {
        let subs = s.totalSubscribers / 1_000
        let cash = max(0, s.finances.cash) / 100_000
        let timeBonus = Double(max(0, (s.scenario.deadline ?? s.week) - s.week)) * 5
        return Int(subs + cash + timeBonus)
    }
}
