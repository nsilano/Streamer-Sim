import Foundation

/// Something big enough that auto-advance must stop and wait for the player.
struct PauseReason: Identifiable, Equatable {
    var id: String
    var icon: String
    var title: String
    var detail: String
    var region: String? = nil      // set when a one-tap "pause sign-ups here" makes sense
}

/// Compares the week before and after and lists what the player needs to react to.
enum PauseCheck {
    static let loadWarning = 0.9

    static func reasons(before: GameState, after: GameState) -> [PauseReason] {
        var out: [PauseReason] = []
        if after.outcome != .playing {
            out.append(PauseReason(id: "outcome", icon: "flag.checkered", title: "Game over", detail: after.lossReason ?? "The game has ended."))
        }
        let expiring = after.newlyExpiring
        if !expiring.isEmpty {
            let names = expiring.prefix(3).map { title -> String in
                let why = after.renewalBlock(title).map { ": \($0.lowercased())" } ?? ""
                return "\"\(title.name)\" (\(title.weeksRemaining ?? 0) wks\(why))"
            }.joined(separator: ", ")
            out.append(PauseReason(id: "expiring", icon: "clock.badge.exclamationmark.fill",
                                   title: "\(expiring.count) license\(expiring.count == 1 ? "" : "s") expiring",
                                   detail: "\(names)\(expiring.count > 3 ? " and more" : ""). Renew them or they leave your catalog."))
        }
        for region in Region.allCases {
            let was = before.effectiveLoad(region), now = after.effectiveLoad(region)
            if was < 1, now >= 1 {
                out.append(PauseReason(id: "load100-\(region.rawValue)", icon: "exclamationmark.triangle.fill",
                                       title: "Servers overloaded in \(region.displayName)",
                                       detail: "Load is \(Format.percent(now)) of capacity. Viewers are buffering and cancelling, and a crash is likely. Pause sign-ups below, or rent cloud capacity / build a datacenter (Company > Tech & team).",
                                       region: region.rawValue))
            } else if was < loadWarning, now >= loadWarning {
                out.append(PauseReason(id: "load90-\(region.rawValue)", icon: "server.rack",
                                       title: "Servers nearly full in \(region.displayName)",
                                       detail: "Load is \(Format.percent(now)) of capacity. Add capacity before you grow further (Company > Tech & team), or pause sign-ups here if it keeps climbing.",
                                       region: region.rawValue))
            }
        }
        for event in after.lastReport?.events ?? [] {
            if event.headline.hasPrefix("Servers crashed") {
                out.append(PauseReason(id: "crash-\(event.id)", icon: "bolt.trianglebadge.exclamationmark.fill", title: event.headline, detail: event.detail))
            } else if event.headline.contains("declares a price war") {
                out.append(PauseReason(id: "war-\(event.id)", icon: "tag.slash.fill", title: event.headline, detail: event.detail))
            } else if event.kind == .licenseLost && event.headline.contains("pulled by") {
                out.append(PauseReason(id: "recall-\(event.id)", icon: "film.stack", title: event.headline, detail: event.detail))
            } else if event.headline == "License expired" {
                out.append(PauseReason(id: "expired-\(event.id)", icon: "xmark.circle.fill", title: "A license expired", detail: event.detail))
            }
        }
        if before.finances.cash >= 0, after.finances.cash < 0 {
            out.append(PauseReason(id: "cash", icon: "banknote", title: "You're out of cash",
                                   detail: "Cash is \(Format.money(after.finances.cash)). Past your \(Format.money(after.overdraftLimit)) limit, or 8 weeks in debt with no funding, and it's game over. Raise money or cut costs."))
        } else if let runway = after.finances.runwayWeeks, runway < 8, (before.finances.runwayWeeks ?? 99) >= 8 {
            out.append(PauseReason(id: "runway", icon: "hourglass", title: "Only \(Int(runway)) weeks of cash left",
                                   detail: "You're losing money every week. Raise funding or cut costs (Company)."))
        }
        if let event = after.pendingEvent, event.id != before.pendingEvent?.id {
            out.append(PauseReason(id: "alert-\(event.id)", icon: "exclamationmark.bubble.fill", title: event.headline, detail: event.detail))
        }
        return out
    }
}
