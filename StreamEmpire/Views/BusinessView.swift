import SwiftUI

/// Earnings, product features, sports rights, partnerships, acquisitions and advertising.
struct BusinessView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case earnings = "Earnings", deals = "Deals", product = "Product"
        var id: String { rawValue }
    }

    @EnvironmentObject var store: GameStore
    @State private var tab: Tab

    init(tab: Tab = .earnings) { _tab = State(initialValue: tab) }
    @State private var partnerCountry = ""
    @State private var premium = 1.2
    @State private var dealGenre: Genre = .drama
    @State private var newName = ""
    @State private var buyback = 0.05

    var body: some View {
        ScrollView {
            if let state = store.state {
                VStack(alignment: .leading, spacing: 14) {
                    Picker("Section", selection: $tab) { ForEach(Tab.allCases) { Text($0.rawValue).tag($0) } }
                        .pickerStyle(.segmented)
                    switch tab {
                    case .earnings:
                        earnings(state)
                        corporate(state)
                        currencies(state)
                    case .deals:
                        outputDeals(state)
                        sports(state)
                        partnerships(state)
                        acquisitions(state)
                    case .product:
                        features(state)
                        advertising(state)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .artScreen()
        .navigationTitle(tab == .earnings ? "Earnings & corporate" : tab == .deals ? "Deals" : "Product")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Earnings

    private func earnings(_ state: GameState) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(text: "Quarterly earnings", icon: "chart.bar.doc.horizontal.fill", tint: Theme.amber)
            LabeledValue(label: "Investor mood", value: "\(state.earningsSentiment >= 1 ? "+" : "")\(Format.percent(state.earningsSentiment - 1)) on your valuation",
                         tint: state.earningsSentiment >= 1 ? Theme.good : Theme.danger)
            if state.quarterReports.isEmpty {
                Text("Your first report lands in week 13. Beat analysts' expectations to lift your valuation; miss and it drops.")
                    .font(.footnote).foregroundStyle(Theme.text2)
            }
            ForEach(state.quarterReports.reversed().prefix(4)) { q in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("Q\(q.id)").font(.subheadline.weight(.bold)).foregroundStyle(.white)
                        Pill(text: q.verdict.uppercased(), tint: q.verdict == "beat" ? Theme.good : q.verdict == "missed" ? Theme.danger : Theme.amber)
                        Spacer()
                        Text(Format.money(q.accountingProfit)).foregroundStyle(q.accountingProfit >= 0 ? Theme.good : Theme.danger)
                    }
                    Text("Revenue \(Format.money(q.revenue)) · expected \(Format.money(q.expectedProfit)) · cash profit \(Format.money(q.profit))")
                        .font(.caption2).foregroundStyle(Theme.text2)
                }
            }
            Text("Profit on the books spreads licensing and production spending over two years, like real accounting.")
                .font(.caption2).foregroundStyle(Theme.text2)
        }
        .artCard(tint: Theme.amber)
    }

    // MARK: Corporate

    private func corporate(_ state: GameState) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(text: "Corporate", icon: "building.columns.fill", tint: Theme.violet)
            HStack {
                TextField("New company name", text: $newName).textFieldStyle(.roundedBorder)
                Button("Rename") { store.perform { try $0.renameCompany(newName) }; newName = "" }
                    .disabled(newName.trimmingCharacters(in: .whitespaces).count < 2)
            }
            if state.equity.ipoDone {
                LabeledValue(label: "You own", value: Format.percent(state.equity.ownership))
                HStack {
                    Text("Buy back \(Format.percent(buyback))").font(.caption)
                    Slider(value: $buyback, in: 0.01...0.10, step: 0.01)
                }
                Button("Buy back shares · \(Format.money(state.buybackPrice(percent: buyback)))") {
                    store.perform { try $0.buyBackShares(percent: buyback) }
                }
                .buttonStyle(SoftButtonStyle(tint: Theme.violet)).disabled(state.finances.cash < state.buybackPrice(percent: buyback))
                Button("Pay a dividend · \(Format.money(state.dividendPrice()))") { store.perform { try $0.payDividend() } }
                    .buttonStyle(SoftButtonStyle(tint: Theme.good))
                    .disabled(state.finances.cash < state.dividendPrice() || state.week - state.lastDividendWeek < 13)
                Text("Buybacks raise your ownership; dividends lift investor mood (once a quarter).").font(.caption2).foregroundStyle(Theme.text2)
            } else {
                Text("Share buybacks and dividends unlock after your IPO.").font(.caption).foregroundStyle(Theme.text2)
            }
        }
        .artCard(tint: Theme.violet)
    }

    // MARK: Output deals

    private func outputDeals(_ state: GameState) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(text: "Studio output deals (\(state.outputDeals.count)/\(GameState.maxOutputDeals))", icon: "shippingbox.fill", tint: Theme.teal)
            Text("A studio delivers a new exclusive 3-year title in your chosen genre every \(GameState.outputDeliveryEvery) weeks, for two years, for a weekly fee. Ending early costs 8 weeks of fees.")
                .font(.footnote).foregroundStyle(Theme.text2)
            ForEach(state.outputDeals) { deal in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(deal.studio) · \(deal.genre.displayName)").font(.subheadline.weight(.bold)).foregroundStyle(.white)
                        Text("\(Format.money(deal.weeklyFee))/wk · next title in \(deal.nextDelivery) wks · \(deal.delivered) delivered · \(deal.weeksLeft) wks left")
                            .font(.caption2).foregroundStyle(Theme.text2)
                    }
                    Spacer()
                    Button("End") { store.perform { try $0.cancelOutputDeal(id: deal.id) } }.font(.caption).foregroundStyle(Theme.danger)
                }
            }
            if state.outputDeals.count < GameState.maxOutputDeals {
                Picker("Genre", selection: $dealGenre) { ForEach(Genre.allCases) { Text($0.displayName).tag($0) } }
                Button("Sign a deal · \(Format.money(state.outputDealFee()))/wk") {
                    store.perform { try $0.signOutputDeal(genre: dealGenre) }
                }
                .buttonStyle(SoftButtonStyle(tint: Theme.teal)).disabled(state.finances.cash < state.outputDealFee() * 4)
            }
        }
        .artCard(tint: Theme.teal)
    }

    // MARK: Features

    private func features(_ state: GameState) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "Product features", icon: "iphone.gen3", tint: Theme.teal)
            ForEach(ProductFeature.allCases) { feature in
                let level = state.featureLevel(feature)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(feature.displayName).font(.subheadline.weight(.bold)).foregroundStyle(.white)
                        Spacer()
                        if feature.maxLevel > 1 { Pill(text: "Level \(level)/\(feature.maxLevel)", tint: Theme.teal) }
                        else if level > 0 { Pill(text: "Live", tint: Theme.good) }
                    }
                    Text(feature.blurb).font(.caption).foregroundStyle(Theme.text2)
                    if level < feature.maxLevel {
                        let price = state.featurePrice(feature)
                        Button("\(level == 0 ? "Build" : "Upgrade") · \(Format.money(price))") {
                            store.perform { try $0.buyFeature(feature) }
                        }
                        .buttonStyle(SoftButtonStyle(tint: Theme.teal)).disabled(state.finances.cash < price)
                    }
                }
            }
            if state.featureUpkeep > 0 { LabeledValue(label: "Upkeep", value: "\(Format.money(state.featureUpkeep))/wk") }
        }
        .artCard(tint: Theme.teal)
    }

    // MARK: Sports

    private func sports(_ state: GameState) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(text: "Live sports rights", icon: "sportscourt.fill", tint: Theme.good)
            Text("Sport is expensive but loyal: in its region, +10% appeal, +10% sign-ups and 10% less churn for a year. Auctions open once a year.")
                .font(.footnote).foregroundStyle(Theme.text2)
            ForEach(state.sportsHeld) { right in
                LabeledValue(label: "\(right.name) · \(right.region.displayName)", value: "\(right.weeksLeft) wks left", tint: Theme.good)
            }
            ForEach(state.sportsOffers) { offer in
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(offer.name) · \(offer.region.displayName)").font(.subheadline.weight(.bold)).foregroundStyle(.white)
                    Text("Asking \(Format.money(offer.askPrice)) · auction closes in \(offer.weeksLeft) wks")
                        .font(.caption).foregroundStyle(Theme.text2)
                    HStack {
                        Text("Bid \(Format.percent(premium)) of asking").font(.caption)
                        Slider(value: $premium, in: 1.0...1.6, step: 0.05)
                    }
                    Button("Bid \(Format.money(offer.askPrice * premium)) (pay only if you win)") {
                        store.perform { try $0.bidForSports(offerID: offer.id, premium: premium) }
                    }
                    .buttonStyle(SoftButtonStyle(tint: Theme.good)).disabled(state.finances.cash < offer.askPrice * premium)
                }
            }
            if state.sportsOffers.isEmpty && state.sportsHeld.isEmpty {
                Text("No auction right now. Next one opens around week \(((state.week / 52) + (state.week % 52 > 20 ? 1 : 0)) * 52 + 20).")
                    .font(.caption).foregroundStyle(Theme.text2)
            }
            if !state.lastSportsResult.isEmpty { Text(state.lastSportsResult).font(.caption).foregroundStyle(Theme.amber) }
        }
        .artCard(tint: Theme.good)
    }

    // MARK: Partnerships

    private func partnerships(_ state: GameState) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(text: "Bundles & partnerships (\(state.partnerships.count)/\(GameState.maxPartnerships))", icon: "link", tint: Theme.violet)
            ForEach(state.partnerships) { p in
                LabeledValue(label: "\(CountryData.country(p.country)?.flag ?? "") \(p.kind.displayName)", value: "\(p.weeksLeft) wks left")
            }
            let live = state.liveMarketCodes
            if live.isEmpty {
                Text("Launch a market first.").font(.caption).foregroundStyle(Theme.text2)
            } else {
                Picker("Country", selection: $partnerCountry) {
                    ForEach(live, id: \.self) { code in
                        Text("\(CountryData.country(code)?.flag ?? "") \(CountryData.country(code)?.name ?? code)").tag(code)
                    }
                }
                ForEach(PartnershipKind.allCases) { kind in
                    let code = live.contains(partnerCountry) ? partnerCountry : live[0]
                    let price = CountryData.country(code).map { state.partnershipPrice($0) } ?? 0
                    VStack(alignment: .leading, spacing: 2) {
                        Text(kind.blurb).font(.caption).foregroundStyle(Theme.text2)
                        Button("\(kind.displayName) · \(Format.money(price)) for a year") {
                            store.perform { try $0.signPartnership(code: code, kind: kind) }
                        }
                        .buttonStyle(SoftButtonStyle(tint: Theme.violet)).disabled(state.finances.cash < price)
                    }
                }
            }
        }
        .artCard(tint: Theme.violet)
    }

    // MARK: Acquisitions

    private func acquisitions(_ state: GameState) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(text: "Acquisitions", icon: "building.2.crop.circle.fill", tint: Theme.magenta)
            if state.acquisitionOffers.isEmpty {
                Text("Small studios and film libraries come up for sale a couple of times a year.").font(.footnote).foregroundStyle(Theme.text2)
            }
            ForEach(state.acquisitionOffers) { offer in
                VStack(alignment: .leading, spacing: 4) {
                    Text(offer.name).font(.subheadline.weight(.bold)).foregroundStyle(.white)
                    Text(offer.kind == .library ? "\(offer.titleCount) titles you'd own forever. Offer ends in \(offer.weeksLeft) wks."
                                                : "A ready-made level 2 studio. Offer ends in \(offer.weeksLeft) wks.")
                        .font(.caption).foregroundStyle(Theme.text2)
                    Button("Buy for \(Format.money(offer.price))") { store.perform { try $0.acceptAcquisition(id: offer.id) } }
                        .buttonStyle(SoftButtonStyle(tint: Theme.magenta)).disabled(state.finances.cash < offer.price)
                }
            }
        }
        .artCard(tint: Theme.magenta)
    }

    // MARK: Advertising and currencies

    private func advertising(_ state: GameState) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionTitle(text: "Ad load", icon: "rectangle.stack.badge.play.fill", tint: Theme.amber)
            LabeledValue(label: "Ads per hour", value: Format.percent(state.adLoad) + " of normal")
            Slider(value: Binding(get: { state.adLoad }, set: { v in store.perform { try $0.setAdLoad((v * 20).rounded() / 20) } }), in: 0.5...1.5)
            Text("More ads earn more from the ad tier but wear viewers out: about 12% more churn at +100%.")
                .font(.caption).foregroundStyle(Theme.text2)
        }
        .artCard(tint: Theme.amber)
    }

    private func currencies(_ state: GameState) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionTitle(text: "Currencies", icon: "dollarsign.arrow.circlepath", tint: Theme.teal)
            Text("Revenue is earned in local money. A stronger local currency means more dollars.").font(.caption).foregroundStyle(Theme.text2)
            ForEach(Region.allCases) { region in
                let index = state.fxIndex(region)
                LabeledValue(label: region.displayName, value: "\(index >= 1 ? "+" : "")\(Format.percent(index - 1))",
                             tint: index >= 1 ? Theme.good : Theme.danger)
            }
        }
        .artCard(tint: Theme.teal)
    }
}
