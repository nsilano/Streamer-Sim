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
    @EnvironmentObject var store: GameStore
    @State private var sheet: RivalRef?

    var body: some View {
        NavigationStack {
            ScrollView {
                if let state = store.state {
                    let board = state.leaderboard
                    let total = max(1, board.reduce(0) { $0 + $1.subs })
                    let leader = board.first?.subs ?? 0
                    VStack(alignment: .leading, spacing: 12) {
                        ScreenHeader(title: "Rivals", subtitle: "\(state.rivals.count) competitors · you are #\(state.rank)")
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
