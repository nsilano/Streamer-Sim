import SwiftUI

/// Run temporary campaigns to win subscribers fast.
struct PromotionsView: View {
    @EnvironmentObject var store: GameStore
    @State private var kind: PromotionKind = .discount
    @State private var scope = ""
    @State private var weeks = 4
    @State private var intensity = 0.3

    var body: some View {
        ScrollView {
            if let state = store.state {
                VStack(alignment: .leading, spacing: 14) {
                    intro
                    activeSection(state)
                    builder(state)
                    history(state)
                }
                .padding(16)
            }
        }
        .artScreen()
        .navigationTitle("Promotions")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Intro & active

    private var intro: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionTitle(text: "Limited-time campaigns", icon: "megaphone.fill", tint: Theme.magenta)
            Text("Run a campaign to win a rush of new subscribers. Each costs money up front, and the people it brings in tend to leave faster once it ends. Repeating the same campaign soon is less effective.")
                .font(.footnote).foregroundStyle(Theme.text2)
        }
        .artCard(tint: Theme.magenta)
    }

    @ViewBuilder
    private func activeSection(_ state: GameState) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "Running now (\(state.promotions.count)/\(PromoMath.maxActive))", icon: "play.circle.fill", tint: Theme.good)
            if state.promotions.isEmpty {
                Text("No campaigns running.").font(.footnote).foregroundStyle(Theme.text2)
            }
            ForEach(state.promotions) { promo in
                let place = promo.scope.isEmpty ? "All markets" : (CountryData.country(promo.scope).map { "\($0.flag) \($0.name)" } ?? promo.scope)
                let now = promo.scope.isEmpty ? state.totalSubscribers : (state.markets[promo.scope]?.subs.total ?? 0)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: promo.kind.icon).foregroundStyle(Theme.good)
                        Text(promo.kind.usesIntensity ? "\(Int(promo.intensity * 100))% off" : promo.kind.title)
                            .font(.headline).foregroundStyle(.white)
                        Spacer()
                        Pill(text: place, tint: Theme.teal)
                    }
                    StatBar(label: "\(promo.weeksLeft) of \(promo.weeksTotal) weeks left",
                            value: Double(promo.weeksTotal - promo.weeksLeft) / Double(promo.weeksTotal),
                            text: "\(Format.count(now - promo.startSubs)) net subs so far", tint: Theme.good, height: 5, compact: true)
                    Button("End early") { store.perform { try $0.cancelPromotion(id: promo.id) } }
                        .buttonStyle(SoftButtonStyle(tint: Theme.danger))
                }
                .artCard(tint: Theme.good)
            }
            if !state.promoHangovers.isEmpty {
                Label("Afterglow churn from a recent campaign is still fading", systemImage: "arrow.down.right")
                    .font(.caption).foregroundStyle(Theme.amber)
            }
        }
    }

    // MARK: Builder

    private func builder(_ state: GameState) -> some View {
        let used = kind.usesIntensity ? intensity : 0
        let quote = state.promotionQuote(kind: kind, scope: scope, weeks: weeks, intensity: used)
        let liveCountries = state.liveMarketCodes.compactMap { CountryData.country($0) }
        return VStack(alignment: .leading, spacing: 12) {
            SectionTitle(text: "New campaign", icon: "plus.circle.fill", tint: Theme.amber)
            ForEach(PromotionKind.allCases) { option in
                Button { kind = option } label: {
                    HStack(spacing: 10) {
                        Image(systemName: option.icon).frame(width: 28).foregroundStyle(kind == option ? Theme.magenta : Theme.text2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(option.title).font(.subheadline.weight(.bold)).foregroundStyle(.white)
                            Text(option.blurb).font(.caption2).foregroundStyle(Theme.text2).multilineTextAlignment(.leading)
                        }
                        Spacer(minLength: 0)
                        if kind == option { Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.magenta) }
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 12).fill(kind == option ? Theme.magenta.opacity(0.18) : Color.white.opacity(0.05)))
                }
                .buttonStyle(.plain)
            }

            Picker("Where", selection: $scope) {
                Text("All my markets").tag("")
                ForEach(liveCountries) { Text("\($0.flag) \($0.name)").tag($0.code) }
            }

            Stepper(value: $weeks, in: 1...PromoMath.maxWeeks) {
                LabeledValue(label: "Length", value: "\(weeks) week\(weeks == 1 ? "" : "s")")
            }
            if kind.usesIntensity {
                VStack(alignment: .leading, spacing: 4) {
                    LabeledValue(label: "Discount", value: "\(Int(intensity * 100))% off")
                    Slider(value: $intensity, in: PromoMath.discountRange, step: 0.05).tint(Theme.amber)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("What to expect").font(.caption.weight(.bold)).foregroundStyle(.white)
                LabeledValue(label: "Campaign cost", value: Format.money(quote.cost), tint: Theme.amber)
                effectRow("New subscribers", quote.effects.adds - 1)
                if abs(quote.effects.arpu - 1) > 0.001 { effectRow("Revenue per subscriber", quote.effects.arpu - 1) }
                if abs(quote.effects.churn - 1) > 0.001 { effectRow("Churn while running", quote.effects.churn - 1, goodWhenNegative: true) }
                if abs(quote.effects.streaming - 1) > 0.001 { effectRow("Hosting cost", quote.effects.streaming - 1, goodWhenNegative: true) }
                if quote.effects.awareness > 0 { Text("Builds awareness every week.").font(.caption).foregroundStyle(Theme.good) }
                if quote.hangoverWeeks > 0 {
                    Text("Afterwards: about +\(Int((quote.hangoverChurn - 1) * 100))% churn for \(quote.hangoverWeeks) weeks.")
                        .font(.caption).foregroundStyle(Theme.amber)
                }
                if quote.fatigued {
                    Label("You ran this recently, so it's less effective", systemImage: "battery.25").font(.caption).foregroundStyle(Theme.amber)
                } else if quote.strength > 1.01 {
                    Label("Your \"never discount\" policy makes promotions land harder", systemImage: "sparkles").font(.caption).foregroundStyle(Theme.good)
                } else if quote.strength < 0.99 {
                    Label("Always-on deals mean customers wait for offers", systemImage: "tag.slash.fill").font(.caption).foregroundStyle(Theme.amber)
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.05)))

            Button("Launch campaign · \(Format.money(quote.cost))") {
                store.perform { try $0.launchPromotion(kind: kind, scope: scope, weeks: weeks, intensity: used) }
            }
            .buttonStyle(GlowButtonStyle(tint: Theme.magenta))
            .disabled(state.finances.cash < quote.cost || state.promotions.count >= PromoMath.maxActive || state.liveMarketCodes.isEmpty)
        }
        .artCard(tint: Theme.amber)
    }

    private func effectRow(_ label: String, _ change: Double, goodWhenNegative: Bool = false) -> some View {
        let good = goodWhenNegative ? change <= 0 : change >= 0
        return LabeledValue(label: label, value: "\(change >= 0 ? "+" : "")\(String(format: "%.0f", change * 100))%",
                            tint: good ? Theme.good : Theme.danger)
    }

    // MARK: History

    @ViewBuilder
    private func history(_ state: GameState) -> some View {
        if !state.promoHistory.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle(text: "Past campaigns", icon: "clock.arrow.circlepath", tint: Theme.teal)
                ForEach(state.promoHistory) { result in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: result.kind.icon).foregroundStyle(result.subscribersGained >= 0 ? Theme.good : Theme.danger).frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(result.kind.title).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                            Text(result.note).font(.caption).foregroundStyle(Theme.text2)
                            Text("Week \(result.week) · ran \(result.weeks) week\(result.weeks == 1 ? "" : "s")")
                                .font(.caption2).foregroundStyle(Theme.text2)
                        }
                    }
                }
            }
            .artCard(tint: Theme.teal)
        }
    }
}
