import Foundation

/// Random weekly events. They are rare, never block the game, and appear as a red alert you can act on or ignore.
enum RandomEvents {
    static let weeklyChance = 0.03
    static let firstEventWeek = 12          // nothing happens in the first quarter
    static let firstNegativeWeek = 24       // and nothing costly for the first half year
    static let minGapWeeks = 12             // at least this long between any two events
    static let alertLastsWeeks = 6          // an ignored alert resolves itself (mildly) after this

    /// One week of revenue (min $200k): the scale for event costs.
    static func unit(_ s: GameState) -> Double { max(200_000, s.finances.lastWeek.revenue) }

    /// Regulation costs shrink with the Legal department.
    static func regulationUnit(_ s: GameState) -> Double {
        max(50_000, s.finances.lastWeek.revenue) * Formulas.regulationCostMultiplier(legalLevel: s.staff.effectiveLevel(.legal))
    }

    /// Maybe starts an event. Returns it so it shows up in the weekly report.
    static func roll(_ s: inout GameState) -> GameEvent? {
        guard s.eventsEnabled, s.pendingEvent == nil, s.week >= firstEventWeek,
              s.week - s.lastEventWeek >= minGapWeeks, s.rng.chance(weeklyChance) else { return nil }
        var options: [(String, Double)] = [("merger", 6)]
        if !s.catalog.isEmpty { options.append(("viral", 10)) }
        // Costly events only happen to services that are established and can afford to respond.
        let canAfford = s.finances.cash >= 3 * unit(s)
        if s.week >= firstNegativeWeek, canAfford, s.totalSubscribers > 5_000 {
            options += [("outage", 10), ("password", 6), ("piracy", 8)]
            if !s.projects.isEmpty { options.append(("strike", 5)) }
            if s.recessionWeeksLeft == 0, s.week >= 40 { options.append(("recession", 3)) }
        }
        let event = create(s.rng.pickWeighted(options), &s)
        s.lastEventWeek = s.week
        return event
    }

    /// An alert nobody dealt with settles itself with its mild default.
    static func resolveExpired(_ s: inout GameState) {
        guard let event = s.pendingEvent, event.expiresWeek > 0, s.week >= event.expiresWeek,
              !event.defaultChoice.isEmpty else { return }
        try? resolve(&s, choiceID: event.defaultChoice)
    }

    static func create(_ key: String, _ s: inout GameState) -> GameEvent {
        let u = unit(s)
        let ru = regulationUnit(s)
        switch key {
        case "viral":
            let index = s.rng.nextInt(in: 0...(s.catalog.count - 1))
            s.catalog[index].popularity = min(100, s.catalog[index].popularity + 25)
            s.catalog[index].ageWeeks = 0
            var detail = "Social media can't stop talking about it. Popularity jumps and it counts as a fresh release again."
            if let region = s.busiestRegion {
                s.surges[region.rawValue] = 2
                detail += " Traffic is surging in \(region.displayName) for two weeks: make sure your servers can take it."
            }
            return s.makeEvent(.news, "\"\(s.catalog[index].name)\" goes viral!", detail)
        case "merger":
            let index = s.rng.nextInt(in: 0...(s.rivals.count - 1))
            s.rivals[index].catalogStrength = min(100, s.rivals[index].catalogStrength + 8)
            s.addNews(.industry, "\(s.rivals[index].name) buys a studio",
                      "A production house joins \(s.rivals[index].name), and its catalog just got stronger.", rival: s.rivals[index].id)
            return s.makeEvent(.news, "\(s.rivals[index].name) buys a studio",
                               "\(s.rivals[index].name) merged with a production house and its catalog just got stronger.")
        case "outage":
            return decide(key, &s, .warning, "Major outage",
                          "Streams are failing worldwide and social media is furious.",
                          [("fix", "Emergency fix (\(Format.money(u / 2)))"), ("wait", "Ride it out (lose ~1% of subscribers)")])
        case "password":
            return decide(key, &s, .news, "Password-sharing crackdown?",
                          "Your team proposes cracking down on shared accounts.",
                          [("crack", "Crack down (risky)"), ("friendly", "Stay subscriber-friendly")])
        case "regulation":
            s.lastRegulationWeek = s.week
            return decide(key, &s, .news, "New content regulation",
                          "Lawmakers are tightening streaming rules, and compliance isn't free.",
                          [("lobby", "Lobby against it (\(Format.money(2 * ru)), may backfire)"),
                           ("comply", "Comply (\(Format.money(ru)))")])
        case "strike":
            return decide(key, &s, .warning, "Actor strike",
                          "Performers walked out and your productions are affected.",
                          [("wait", "Wait it out (+6 weeks on every production)"),
                           ("pay", "Meet their demands (+15% of budgets)")])
        case "piracy":
            return decide(key, &s, .warning, "Piracy spike",
                          "Your hit shows are all over pirate sites.",
                          [("fight", "Fund anti-piracy (\(Format.money(u / 2)))"), ("ignore", "Ignore it (lose ~1% of subscribers)")])
        default: // recession
            return decide(key, &s, .warning, "Recession",
                          "Consumers are cutting subscriptions. Sign-ups slow and churn rises until it passes.",
                          [("promo", "Run a retention promo (\(Format.money(u)), shorter downturn)"),
                           ("hold", "Hold the line (26-week downturn)")])
        }
    }

    private static func decide(_ key: String, _ s: inout GameState, _ kind: EventKind, _ headline: String,
                               _ detail: String, _ choices: [(String, String)]) -> GameEvent {
        var event = s.makeEvent(kind, headline, detail)
        event.key = key
        event.choices = choices.map { EventChoice(id: $0.0, label: $0.1) }
        event.expiresWeek = s.week + alertLastsWeeks
        event.defaultChoice = defaultChoice(for: key)
        s.pendingEvent = event
        return event
    }

    /// What happens if you never respond: always the free, mild option.
    static func defaultChoice(for key: String) -> String {
        switch key {
        case "outage": return "wait"
        case "password": return "friendly"
        case "strike": return "wait"
        case "piracy": return "ignore"
        case "regulation": return "comply"
        default: return "hold"
        }
    }

    private static func spend(_ s: inout GameState, _ amount: Double) {
        s.finances.cash -= amount
        s.finances.ledger.other += amount
    }

    private static func scaleSubs(_ s: inout GameState, _ factor: Double) {
        for code in s.markets.keys.sorted() {
            guard var market = s.markets[code], market.isLive else { continue }
            for tier in Tier.allCases { market.subs[tier] *= factor }
            s.markets[code] = market
        }
    }

    private static func shiftAwareness(_ s: inout GameState, _ delta: Double) {
        for code in s.markets.keys.sorted() {
            guard var market = s.markets[code], market.isLive else { continue }
            market.awareness = Formulas.clamp(market.awareness + delta, 0, 1)
            s.markets[code] = market
        }
    }

    /// Applies the player's choice and queues the outcome for the next report.
    static func resolve(_ s: inout GameState, choiceID: String) throws {
        guard let event = s.pendingEvent else { throw ActionError.noPendingEvent }
        guard event.choices.contains(where: { $0.id == choiceID }) else { throw ActionError.unknownChoice }
        let u = unit(s)
        var headline = ""
        var detail = ""

        switch (event.key, choiceID) {
        case ("outage", "fix"):
            spend(&s, u / 2)
            (headline, detail) = ("Outage fixed", "Engineers restored service quickly. Cost \(Format.money(u / 2)).")
        case ("outage", _):
            scaleSubs(&s, 0.99); shiftAwareness(&s, -0.02)
            (headline, detail) = ("Outage hurt the brand", "About 1% of subscribers left and awareness dipped.")
        case ("password", "crack"):
            if s.rng.chance(0.7) {
                scaleSubs(&s, 1.04)
                (headline, detail) = ("Crackdown converts sharers", "Roughly 4% more paying subscribers.")
            } else {
                scaleSubs(&s, 0.94)
                (headline, detail) = ("Crackdown backfires", "Customers revolted and 6% of subscribers cancelled.")
            }
        case ("password", _):
            shiftAwareness(&s, 0.02)
            (headline, detail) = ("Goodwill gained", "Staying friendly earned some positive press.")
        case ("regulation", "lobby"):
            let ru = regulationUnit(s)
            if s.rng.chance(Formulas.lobbySuccessChance(legalLevel: s.staff.effectiveLevel(.legal))) {
                spend(&s, 2 * ru)
                (headline, detail) = ("Lobbying worked", "The rules were softened. Cost \(Format.money(2 * ru)).")
            } else {
                spend(&s, 5 * ru)
                (headline, detail) = ("Lobbying failed", "The rules passed anyway. Total cost \(Format.money(5 * ru)).")
            }
        case ("regulation", _):
            let ru = regulationUnit(s)
            spend(&s, ru)
            (headline, detail) = ("Compliance done", "Legal work cost \(Format.money(ru)).")
        case ("strike", "pay"):
            let cost = 0.15 * s.projects.reduce(0) { $0 + $1.budget }
            spend(&s, cost)
            (headline, detail) = ("Strike averted", "Productions stay on schedule. Cost \(Format.money(cost)).")
        case ("strike", _):
            for i in s.projects.indices {
                s.projects[i].weeksLeft += 6
                s.projects[i].weeksTotal += 6
            }
            (headline, detail) = ("Productions delayed", "Every production slips six weeks.")
        case ("piracy", "fight"):
            spend(&s, u / 2)
            (headline, detail) = ("Piracy contained", "Anti-piracy efforts cost \(Format.money(u / 2)).")
        case ("piracy", _):
            scaleSubs(&s, 0.99)
            (headline, detail) = ("Piracy bites", "About 1% of subscribers moved to pirate sites.")
        case ("recession", "promo"):
            spend(&s, u)
            s.recessionWeeksLeft = 12
            s.addNews(.industry, "A recession hits streaming", "Subscriptions are slowing across the industry.")
            (headline, detail) = ("Promo softens the blow", "The downturn should last about 12 weeks.")
        default:
            s.recessionWeeksLeft = 26
            s.addNews(.industry, "A recession hits streaming", "Subscriptions are slowing across the industry for about 26 weeks.")
            (headline, detail) = ("Recession begins", "Expect slower growth and more churn for about 26 weeks.")
        }

        s.pendingEvent = nil
        s.queuedEvents.append(s.makeEvent(.news, headline, detail))
        s.addNews(.you, headline, detail)
    }
}
