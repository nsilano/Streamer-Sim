import Foundation

/// Read-only helpers that turn raw state into things the UI can show as bars and advice.
extension GameState {
    func mapStatus(_ code: String) -> MapStatus {
        switch markets[code]?.status ?? .notLaunched {
        case .live: return .live
        case .launching: return .launching
        case .notLaunched: return launchBlocker(code: code) == nil ? .available : .locked
        }
    }

    /// 0...1: how fresh a title still feels (1 = brand new).
    func freshness(of title: Title) -> Double { Formulas.freshness(ageWeeks: title.ageWeeks) }

    /// 0...1: how well a title suits the countries you serve (genre taste, language, freshness, quality).
    func marketFit(of title: Title) -> Double {
        let codes = markets.keys.sorted().filter { markets[$0]?.status != .notLaunched }
        guard !codes.isEmpty else { return 0 }
        var total = 0.0
        for code in codes {
            if let country = CountryData.country(code) { total += Formulas.titleAppeal(title, in: country) }
        }
        return min(1, total / Double(codes.count) / 0.8)
    }

    /// Threat a country's rivals feel from your share of its subscribers (0...1).
    func countryThreat(_ code: String) -> Double {
        let own = markets[code]?.subs.total ?? 0
        var total = own
        for rival in rivals { total += rival.subs[code] ?? 0 }
        guard total > 0 else { return 0 }
        return Formulas.dominanceThreat(playerShare: own / total)
    }

    /// The worst threat a rival feels in any live market where it competes with you.
    func threat(from rival: Rival) -> Double {
        var worst = 0.0
        for code in rival.subs.keys.sorted() {
            guard markets[code]?.isLive == true, (rival.subs[code] ?? 0) > 0 else { continue }
            worst = max(worst, countryThreat(code))
        }
        return worst
    }

    func advice() -> [Advice] {
        var items: [Advice] = []

        for region in Region.allCases {
            let subs = subscribers(in: region)
            guard subs > 0 else { continue }
            let load = cdnLoad(region)
            if load > 1.0 {
                items.append(Advice(id: "cdn-\(region.rawValue)", icon: "exclamationmark.triangle.fill", urgent: true,
                                    title: "Servers overloaded in \(region.displayName)",
                                    detail: "Viewers are buffering and cancelling. Add server capacity now."))
            } else if load > 0.85 {
                items.append(Advice(id: "cdn-\(region.rawValue)", icon: "server.rack", urgent: false,
                                    title: "\(region.displayName) servers are \(Int(load * 100))% full",
                                    detail: "Add capacity before you grow further, or viewers will start to buffer."))
            }
        }

        if finances.cash < 0 {
            items.append(Advice(id: "cash", icon: "banknote", urgent: true, title: "You're out of cash",
                                detail: "Raise funding in the Company tab or cut costs before the debt clock runs out."))
        } else if let runway = finances.runwayWeeks, runway < 8 {
            items.append(Advice(id: "runway", icon: "banknote", urgent: true,
                                title: "Only \(Int(runway)) weeks of cash left",
                                detail: "You're losing money every week. Raise funding or cut costs."))
        }

        if catalog.isEmpty {
            items.append(Advice(id: "catalog", icon: "film.stack", urgent: true, title: "License your first titles",
                                detail: "Nobody subscribes to an empty catalog. Browse the Licensing tab."))
        } else if catalog.count < 8 {
            items.append(Advice(id: "catalog", icon: "film.stack", urgent: false, title: "Grow your catalog",
                                detail: "A thin library means slow sign-ups. Aim for at least 10 titles."))
        }

        for department in Department.allCases where staff[department] > 0 && staff.payScale(department) < 0.9 {
            items.append(Advice(id: "pay-\(department.rawValue)", icon: "person.fill.xmark", urgent: false,
                                title: "\(department.displayName) staff may quit",
                                detail: "Pay is below market. Raise it to Fair or Generous to keep your team."))
        }

        if totalSubscribers > 20_000 {
            for platform in [Platform.ios, .android, .smartTV]
            where !platforms.contains(platform) && !builds.contains(where: { $0.platform == platform })
                && finances.cash > platform.unlockCost * 3 {
                items.append(Advice(id: "platform-\(platform.rawValue)", icon: "iphone.gen3", urgent: false,
                                    title: "Launch the \(platform.displayName)",
                                    detail: "+\(Int(platform.reachBonus * 100)) points of reach, so more people can find and watch you."))
                break
            }
        }

        return items.sorted { ($0.urgent ? 0 : 1) < ($1.urgent ? 0 : 1) }
    }
}

struct Advice: Identifiable, Equatable {
    var id: String
    var icon: String
    var urgent: Bool
    var title: String
    var detail: String
}
