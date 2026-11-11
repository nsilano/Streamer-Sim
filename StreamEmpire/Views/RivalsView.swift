import SwiftUI

struct RivalRef: Identifiable, Equatable {
    let id: String
}

/// A coloured monogram standing in for a rival's logo.
struct RivalBadge: View {
    let name: String
    let id: String
    var size: CGFloat = 44

    private var hue: Double {
        var total = 0
        for scalar in id.unicodeScalars { total = (total &* 31 &+ Int(scalar.value)) % 360 }
        return Double(total) / 360
    }

    var body: some View {
        ZStack {
            Circle().fill(LinearGradient(colors: [Color(hue: hue, saturation: 0.7, brightness: 0.95),
                                                  Color(hue: (hue + 0.12).truncatingRemainder(dividingBy: 1), saturation: 0.8, brightness: 0.55)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
            Text(String(name.prefix(1)).uppercased())
                .font(.system(size: size * 0.5, weight: .black, design: .serif)).foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1))
    }
}

struct RivalsView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case standings = "Standings", news = "Chirp"
        var id: String { rawValue }
    }

    @EnvironmentObject var store: GameStore
    @State private var sheet: RivalRef?
    @State private var mode: Mode = .standings

    var body: some View {
        NavigationStack {
            ScrollView {
                if let state = store.state {
                    let board = state.leaderboard
                    let total = max(1, board.reduce(0) { $0 + $1.subs })
                    let leader = board.first?.subs ?? 0
                    VStack(alignment: .leading, spacing: 12) {
                        ScreenHeader(title: "Rivals", subtitle: "\(GameCalendar.dateText(week: state.week)) · Week \(state.week) · \(state.rivals.count) competitors · you are #\(state.rank)")
                        Picker("View", selection: $mode) {
                            ForEach(Mode.allCases) { m in
                                Text(m == .news && state.unreadNewsCount > 0 ? "Chirp (\(state.unreadNewsCount))" : m.rawValue).tag(m)
                            }
                        }
                        .pickerStyle(.segmented)
                        if mode == .news {
                            NewsFeedView(state: state)
                        } else {
                        if let me = board.first(where: { $0.isPlayer }), me.subs < leader {
                            AdviceBanner(advice: Advice(id: "gap", icon: "flag.checkered", urgent: false,
                                                        title: "\(Format.count(leader - me.subs)) subscribers behind #1",
                                                        detail: "Overtake every rival in global subscribers (from week 52) to win."))
                        }
                        ForEach(Array(board.enumerated()), id: \.element.id) { index, entry in
                            let delta = entry.subs - (state.previousSubs[entry.id] ?? entry.subs)
                            if let rival = state.rivals.first(where: { $0.id == entry.id }) {
                                Button { sheet = RivalRef(id: rival.id) } label: {
                                    row(index + 1, entry, share: entry.subs / total, delta: delta, top: leader,
                                        rival: rival, threat: state.threat(from: rival))
                                }
                                .buttonStyle(.plain)
                            } else {
                                row(index + 1, entry, share: entry.subs / total, delta: delta, top: leader, rival: nil, threat: 0)
                            }
                        }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
            .artScreen()
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $sheet) { ref in RivalDetailSheet(rivalID: ref.id) }
        }
    }

    private func row(_ rank: Int, _ entry: LeaderboardEntry, share: Double, delta: Double, top: Double,
                     rival: Rival?, threat: Double) -> some View {
        HStack(spacing: 12) {
            Text("\(rank)").font(Theme.number(20)).foregroundStyle(rank == 1 ? Theme.amber : Theme.text2).frame(width: 26)
            if entry.isPlayer {
                ZStack {
                    Circle().fill(Theme.accentGradient)
                    Image(systemName: "play.fill").foregroundStyle(.white)
                }
                .frame(width: 44, height: 44)
            } else {
                RivalBadge(name: entry.name, id: entry.id)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(entry.name).font(.headline).foregroundStyle(.white)
                    if entry.isPlayer { Pill(text: "YOU", tint: Theme.magenta) }
                    if let rival, rival.priceLevel < 0.9, threat > 0.2 { Pill(text: "Targeting you", tint: Theme.danger, icon: "flame.fill") }
                    else if let rival, rival.priceLevel < 0.9 { Pill(text: "Price cuts", tint: Theme.amber) }
                }
                StatBar(label: "\(Format.percent(share)) of all subs", value: top > 0 ? entry.subs / top : 0,
                        text: Format.count(entry.subs), tint: entry.isPlayer ? Theme.magenta : Theme.violet, height: 5, compact: true)
                Text("\(delta >= 0 ? "+" : "-")\(Format.count(abs(delta))) this week")
                    .font(.caption2).foregroundStyle(delta >= 0 ? Theme.good : Theme.danger)
            }
        }
        .artCard(tint: entry.isPlayer ? Theme.magenta : Theme.violet)
    }
}

struct RivalDetailSheet: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.dismiss) private var dismiss
    let rivalID: String
    @State private var premium = 0.5

    var body: some View {
        NavigationStack {
            ScrollView {
                if let state = store.state, let rival = state.rivals.first(where: { $0.id == rivalID }) {
                    let threat = state.threat(from: rival)
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 14) {
                            RivalBadge(name: rival.name, id: rival.id, size: 64)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(rival.name).font(Theme.display(28)).foregroundStyle(.white)
                                Pill(text: rival.personality.displayName, tint: Theme.violet)
                            }
                        }
                        HStack(spacing: 12) {
                            BigStat(title: "Subscribers", value: Format.count(rival.totalSubs))
                            BigStat(title: "Cash", value: Format.money(rival.cash))
                        }
                        VStack(alignment: .leading, spacing: 10) {
                            SectionTitle(text: "Strength", icon: "bolt.fill", tint: Theme.amber)
                            StatBar(label: "Catalog strength", value: rival.catalogStrength / 100, tint: Theme.amber)
                            StatBar(label: "Pricing (below the bar = discounts)", value: min(1, rival.priceLevel / 1.15),
                                    text: pricingText(rival), tint: rival.priceLevel < 0.95 ? Theme.danger : Theme.teal)
                            StatBar(label: "Feels threatened by you", value: threat, text: Format.percent(threat),
                                    tint: threat > 0.3 ? Theme.danger : Theme.good)
                            LabeledValue(label: "Countries", value: "\(rival.countryCount) / \(CountryData.all.count)")
                        }
                        .artCard(tint: Theme.amber)
                        investCard(state, rival)
                        regions(rival)
                        topCountries(rival)
                    }
                    .padding(16)
                }
            }
            .artScreen()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Done") { dismiss() } }
        }
    }

    // MARK: Shares & takeover

    private func investCard(_ state: GameState, _ rival: Rival) -> some View {
        let stake = state.stake(in: rival.id)
        let cap = state.marketCap(rival)
        let bidHere = state.takeover?.rivalID == rival.id
        return VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "Invest & take over", icon: "chart.line.uptrend.xyaxis", tint: Theme.danger)
            LabeledValue(label: "Market value", value: Format.money(cap))
            StatBar(label: "Investor mood", value: min(1, rival.sentiment / 1.6), text: String(format: "%.0f%%", rival.sentiment * 100),
                    tint: rival.sentiment >= 1 ? Theme.good : Theme.amber, height: 5, compact: true)
            StatBar(label: "Your stake", value: stake, text: Format.percent1(stake), tint: Theme.magenta)
            if stake > 0 {
                LabeledValue(label: "Stake worth", value: Format.money(state.stakeValue(in: rival.id)))
            }
            if rival.poisonPill {
                Label("Poison pill active: shares cost 60% more", systemImage: "shield.lefthalf.filled").font(.caption).foregroundStyle(Theme.amber)
            }
            Text("Buying shares pushes the price up. Past 5% you must disclose; past 20% the board defends itself.")
                .font(.caption2).foregroundStyle(Theme.text2)
            HStack {
                ForEach([0.01, 0.05, 0.10], id: \.self) { pct in
                    let cost = state.sharePrice(rival, percent: pct)
                    Button("+\(Int(pct * 100))% · \(Format.money(cost))") {
                        store.perform { try $0.buyShares(rivalID: rival.id, percent: pct) }
                    }
                    .buttonStyle(SoftButtonStyle(tint: Theme.teal))
                    .disabled(state.finances.cash < cost || stake + pct > Formulas.openMarketLimit + 1e-9)
                }
            }
            if stake > 0 {
                HStack {
                    Button("Sell 5%") { store.perform { try $0.sellShares(rivalID: rival.id, percent: min(0.05, stake)) } }
                        .buttonStyle(SoftButtonStyle(tint: Theme.amber))
                    Button("Sell all") { store.perform { try $0.sellShares(rivalID: rival.id, percent: stake) } }
                        .buttonStyle(SoftButtonStyle(tint: Theme.danger))
                }
            }
            Divider().overlay(Color.white.opacity(0.12))
            if bidHere, let bid = state.takeover {
                Label("Hostile bid in progress: shareholders vote in \(bid.weeksLeft) week\(bid.weeksLeft == 1 ? "" : "s")",
                      systemImage: "flag.fill").foregroundStyle(Theme.amber)
                LabeledValue(label: "Offer premium", value: Format.percent(bid.premium))
                LabeledValue(label: "Money committed", value: Format.money(bid.escrow))
                LabeledValue(label: "Chance of success", value: Format.percent(state.takeoverChance(rival, premium: bid.premium)))
            } else {
                takeoverControls(state, rival, stake: stake)
            }
        }
        .artCard(tint: Theme.danger)
    }

    @ViewBuilder
    private func takeoverControls(_ state: GameState, _ rival: Rival, stake: Double) -> some View {
        let cost = state.takeoverCost(rival, premium: premium)
        let chance = state.takeoverChance(rival, premium: premium)
        Text("Hostile takeover").font(.subheadline.weight(.bold)).foregroundStyle(.white)
        if stake < Formulas.disclosureStake {
            Text("Build a stake of at least \(Format.percent(Formulas.disclosureStake)) first.").font(.caption).foregroundStyle(Theme.amber)
        }
        Text("Offer \(Format.percent(premium)) above the market price for the rest of the company").font(.caption).foregroundStyle(Theme.text2)
        Slider(value: $premium, in: 0.1...1.0, step: 0.05).tint(Theme.danger)
        LabeledValue(label: "Total offer", value: Format.money(cost))
        StatBar(label: "Chance shareholders accept", value: chance, text: Format.percent(chance),
                tint: chance > 0.6 ? Theme.good : (chance > 0.35 ? Theme.amber : Theme.danger), compact: true)
        if state.antitrustRisk(rival) {
            Label("Regulators may balk: you'd control over 30% of all subscribers", systemImage: "scalemass.fill")
                .font(.caption).foregroundStyle(Theme.amber)
        }
        Text("If it works you absorb their subscribers (about 80% stay), cash and library, and countries where you weren't launched go live. If it fails you lose a 2% fee and the rival turns hostile.")
            .font(.caption2).foregroundStyle(Theme.text2)
        Button("Launch hostile bid") {
            store.perform { try $0.launchTakeover(rivalID: rival.id, premium: premium) }
        }
        .buttonStyle(GlowButtonStyle(tint: Theme.danger))
        .disabled(stake < Formulas.disclosureStake || state.finances.cash < cost || state.takeover != nil)
    }

    private func pricingText(_ rival: Rival) -> String {
        rival.priceLevel < 0.95 ? "Cutting prices" : rival.priceLevel > 1.05 ? "Raised prices" : "Normal"
    }

    private func regions(_ rival: Rival) -> some View {
        let total = max(1, rival.totalSubs)
        var byRegion: [Region: Double] = [:]
        for code in rival.subs.keys.sorted() {
            if let region = CountryData.country(code)?.region { byRegion[region, default: 0] += rival.subs[code] ?? 0 }
        }
        return VStack(alignment: .leading, spacing: 8) {
            SectionTitle(text: "Where they are strong", icon: "globe", tint: Theme.teal)
            ForEach(Region.allCases) { region in
                if let value = byRegion[region], value > 0 {
                    StatBar(label: region.displayName, value: value / total, text: Format.count(value), tint: Theme.teal, height: 5, compact: true)
                }
            }
        }
        .artCard(tint: Theme.teal)
    }

    private func topCountries(_ rival: Rival) -> some View {
        let codes = rival.subs.keys.sorted { (rival.subs[$0] ?? 0) > (rival.subs[$1] ?? 0) }.prefix(8)
        return VStack(alignment: .leading, spacing: 8) {
            SectionTitle(text: "Biggest markets", icon: "flag.fill", tint: Theme.violet)
            ForEach(Array(codes), id: \.self) { code in
                LabeledValue(label: "\(CountryData.country(code)?.flag ?? "") \(CountryData.country(code)?.name ?? code)",
                             value: Format.count(rival.subs[code] ?? 0))
            }
        }
        .artCard(tint: Theme.violet)
    }
}
