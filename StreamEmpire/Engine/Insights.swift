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
    func freshness(of title: Title) -> Double { Formulas.freshness(of: title) }

    /// 0...1: how well a title suits the countries you serve (genre taste, language, freshness, quality).
    func marketFit(of title: Title) -> Double {
        let codes = markets.keys.sorted().filter { markets[$0]?.status != .notLaunched }
        guard !codes.isEmpty else { return 0 }
        var total = 0.0
        for code in codes {
            if let country = CountryData.country(code), title.isAvailable(in: code) {
                total += Formulas.titleAppeal(title, in: country)
            }
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
            let load = serverLoad(region)
            if load > 1.0 {
                items.append(Advice(id: "servers-\(region.rawValue)", icon: "exclamationmark.triangle.fill", urgent: true,
                                    title: "Servers overloaded in \(region.displayName)",
                                    detail: "Viewers are buffering and the servers could crash. Rent cloud capacity now and build a datacenter."))
            } else if load > 0.85 {
                items.append(Advice(id: "servers-\(region.rawValue)", icon: "server.rack", urgent: false,
                                    title: "\(region.displayName) servers are \(Int(load * 100))% full",
                                    detail: "Add capacity before you grow further, or viewers will start to lag. A viral hit can spike traffic."))
            }
        }

        if finances.cash < 0 {
            let used = Int(-finances.cash / overdraftLimit * 100)
            items.append(Advice(id: "cash", icon: "banknote", urgent: true,
                                title: "In debt: \(used)% of your \(Format.money(overdraftLimit)) limit",
                                detail: "Past the limit, or after 8 weeks with no funding left, you go bankrupt. Raise funding or cut costs now."))
        } else if let runway = finances.runwayWeeks, runway < 8 {
            items.append(Advice(id: "runway", icon: "banknote", urgent: true,
                                title: "Only \(Int(runway)) weeks of cash left",
                                detail: "You're losing money every week. Raise funding or cut costs."))
        }

        let expiring = expiringTitles
        if !expiring.isEmpty {
            let soon = expiring.filter { ($0.weeksRemaining ?? 99) <= 8 }
            let names = expiring.prefix(3).map { "\"\($0.name)\"" }.joined(separator: ", ")
            items.append(Advice(id: "expiring", icon: "clock.badge.exclamationmark.fill", urgent: !soon.isEmpty,
                                title: "\(expiring.count) license\(expiring.count == 1 ? "" : "s") expiring soon",
                                detail: "\(names)\(expiring.count > 3 ? " and more" : "") will leave your catalog. Renew them in the Content tab, usually cheaper than a new deal."))
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
                && finances.cash > platformPrice(platform) * 3 {
                items.append(Advice(id: "platform-\(platform.rawValue)", icon: "iphone.gen3", urgent: false,
                                    title: "Launch the \(platform.displayName)",
                                    detail: "+\(Int(platform.reachBonus * 100)) points of reach, so more people can find and watch you."))
                break
            }
        }

        return items.sorted { ($0.urgent ? 0 : 1) < ($1.urgent ? 0 : 1) }
    }
}

/// One line of the "where does my money go" breakdown.
struct CostLine: Identifiable, Equatable {
    var id: String
    var category: CostCategory
    var amount: Double
    var previous: Double
    var shareOfCosts: Double
    var shareOfRevenue: Double
    var change: Double { amount - previous }
}

extension GameState {
    /// Last week's spending by category, biggest first, with change vs the week before.
    func costBreakdown() -> [CostLine] {
        let last = finances.lastWeek
        let before = finances.history.count >= 2 ? finances.history[finances.history.count - 2] : nil
        let totalCosts = max(1, last.costs)
        let revenue = max(1, last.revenue)
        return CostCategory.allCases.compactMap { category -> CostLine? in
            let amount = category.amount(in: last)
            guard amount > 0 else { return nil }
            return CostLine(id: category.rawValue, category: category, amount: amount,
                            previous: before.map { category.amount(in: $0) } ?? amount,
                            shareOfCosts: amount / totalCosts, shareOfRevenue: amount / revenue)
        }.sorted { $0.amount > $1.amount }
    }

    /// Countries that cost more to run than they earn, worst first (from last week's report).
    func losingMarkets() -> [MarketReport] {
        (lastReport?.markets ?? []).filter { $0.profit < 0 }.sorted { $0.profit < $1.profit }
    }

    /// Plain-language reasons you are (or aren't) losing money.
    func diagnosis() -> [Advice] {
        let last = finances.lastWeek
        var items: [Advice] = []
        guard finances.history.count >= 1 else {
            return [Advice(id: "wait", icon: "hourglass", urgent: false, title: "No data yet",
                           detail: "Play a week and your spending breakdown will appear here.")]
        }
        let lines = costBreakdown()
        if last.profit < 0 {
            let top = lines.prefix(3).map { "\($0.category.displayName) (\(Format.money($0.amount)))" }.joined(separator: ", ")
            items.append(Advice(id: "loss", icon: "arrow.down.right.circle.fill", urgent: true,
                                title: "You lost \(Format.money(-last.profit)) last week",
                                detail: "Revenue was \(Format.money(last.revenue)) against \(Format.money(last.costs)) of costs. Biggest costs: \(top)."))
        } else {
            items.append(Advice(id: "profit", icon: "arrow.up.right.circle.fill", urgent: false,
                                title: "You made \(Format.money(last.profit)) last week",
                                detail: "Revenue \(Format.money(last.revenue)) against \(Format.money(last.costs)) of costs."))
        }
        if let top = lines.first, top.shareOfCosts > 0.4 {
            items.append(Advice(id: "top-cost", icon: top.category.icon, urgent: false,
                                title: "\(top.category.displayName) is \(Int(top.shareOfCosts * 100))% of your spending",
                                detail: top.category == .staff && staff.employees.isEmpty
                                    ? "That's your core team: you, a small founding crew, an office and tools, \(Format.money(scaled(Formulas.baseStaffCostPerWeek)))/wk even before you hire anyone. Hires add salaries; overhead adds 4% of revenue."
                                    : "That's \(Format.money(top.amount)) last week\(last.revenue > 0 ? ", equal to \(Int(top.shareOfRevenue * 100))% of your revenue" : "")."))
        }
        for line in lines where line.previous > 0 && line.amount > line.previous * 1.5 && line.amount > 20_000 {
            items.append(Advice(id: "jump-\(line.id)", icon: "chart.line.uptrend.xyaxis", urgent: false,
                                title: "\(line.category.displayName) jumped to \(Format.money(line.amount))",
                                detail: "That's up \(Format.money(line.change)) from the week before."))
        }
        if last.revenue > 0 {
            if last.marketing / last.revenue > 0.3 {
                items.append(Advice(id: "marketing", icon: "megaphone.fill", urgent: false,
                                    title: "Marketing eats \(Int(last.marketing / last.revenue * 100))% of revenue",
                                    detail: "Check each country: marketing only pays off if your catalog is strong enough to keep new subscribers."))
            }
            if last.streaming / last.revenue > 0.2 {
                items.append(Advice(id: "streaming", icon: "antenna.radiowaves.left.and.right", urgent: false,
                                    title: "Hosting costs \(Int(last.streaming / last.revenue * 100))% of revenue",
                                    detail: "Each subscriber costs money to stream. Raise prices or favour higher-paying plans."))
            }
            if last.interest / last.revenue > 0.05 {
                items.append(Advice(id: "interest", icon: "percent", urgent: false,
                                    title: "Loan interest is \(Int(last.interest / last.revenue * 100))% of revenue",
                                    detail: "Consider repaying expensive loans when you have spare cash."))
            }
        }
        for market in losingMarkets().prefix(3) {
            let country = CountryData.country(market.id)
            items.append(Advice(id: "market-\(market.id)", icon: "flag.fill", urgent: false,
                                title: "\(country?.flag ?? "") \(country?.name ?? market.id) loses \(Format.money(-market.profit)) a week",
                                detail: "It earns \(Format.money(market.revenue)) but costs \(Format.money(market.costs)) to run, stream and market. Grow it, raise prices or trim marketing."))
        }
        return items
    }
}

struct Advice: Identifiable, Equatable {
    var id: String
    var icon: String
    var urgent: Bool
    var title: String
    var detail: String
}
