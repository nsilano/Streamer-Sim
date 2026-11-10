import SwiftUI

struct TitleRef: Identifiable, Equatable {
    let id: Int
}

struct ContentTabView: View {
    enum Section: String, CaseIterable, Identifiable {
        case licensing = "Licensing", catalog = "Catalog", originals = "Originals"
        var id: String { rawValue }
    }

    enum Sort: String, CaseIterable, Identifiable {
        case fit = "Best fit", quality = "Quality", popularity = "Popularity", cheapest = "Cheapest", ending = "Ending soon"
        var id: String { rawValue }
    }

    @EnvironmentObject var store: GameStore
    @State private var section: Section = .licensing
    @State private var sort: Sort = .fit
    @State private var detail: TitleRef?
    @State private var showCurator = false

    private let columns = [GridItem(.adaptive(minimum: 140), spacing: 12, alignment: .top)]

    var body: some View {
        NavigationStack {
            ScrollView {
                if let state = store.state {
                    VStack(alignment: .leading, spacing: 14) {
                        ScreenHeader(title: "Content", subtitle: "\(GameCalendar.dateText(week: state.week)) · Week \(state.week) · \(state.catalog.count) titles · \(state.projects.count) in production")
                        Picker("Section", selection: $section) {
                            ForEach(Section.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)

                        switch section {
                        case .licensing: licensing(state)
                        case .catalog: catalog(state)
                        case .originals: OriginalsView(state: state, onOpen: { detail = TitleRef(id: $0) })
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
            .artScreen()
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $detail) { ref in TitleDetailSheet(titleID: ref.id) }
            .sheet(isPresented: $showCurator) { CuratorSheet() }
        }
    }

    // MARK: Licensing

    private func licensing(_ state: GameState) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            curatorCard(state)
            HStack {
                SectionTitle(text: "On the market", icon: "tag.fill", tint: Theme.amber)
                Menu {
                    Picker("Sort", selection: $sort) { ForEach(Sort.allCases) { Text($0.rawValue).tag($0) } }
                } label: {
                    Label(sort.rawValue, systemImage: "arrow.up.arrow.down").font(.caption.weight(.semibold))
                }
            }
            HStack(spacing: 10) {
                marketButton(title: "Refresh listings", price: state.refreshListingsPrice(), icon: "arrow.clockwise",
                             tint: Theme.amber, disabled: state.finances.cash < state.refreshListingsPrice()) {
                    store.perform { try $0.refreshListings() }
                }
                if state.listingReach < GameState.maxListingReach {
                    marketButton(title: "More listings +\(GameState.listingsPerReachLevel)", price: state.expandListingsPrice(),
                                 icon: "plus.rectangle.on.rectangle", tint: Theme.teal,
                                 disabled: state.finances.cash < state.expandListingsPrice()) {
                        store.perform { try $0.expandListings() }
                    }
                }
            }
            Text("\(state.licenseMarket.count) of \(state.listingTarget) offers · scouting level \(state.listingReach)/\(GameState.maxListingReach)")
                .font(.caption2).foregroundStyle(Theme.text2)
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(sorted(state.licenseMarket, state)) { title in
                    Button { detail = TitleRef(id: title.id) } label: {
                        TitleCell(title: title, state: state, priceText: Format.money(state.licensePrice(title)),
                                  footnote: "Offer ends in \(title.listingWeeksLeft) wk")
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    /// Equal-size action tile: label on top, price underneath.
    private func marketButton(title: String, price: Double, icon: String, tint: Color, disabled: Bool,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Label(title, systemImage: icon).font(.subheadline.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.8)
                Text(Format.money(price)).font(.caption.weight(.bold)).opacity(0.85)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .foregroundStyle(tint)
            .background(RoundedRectangle(cornerRadius: 14).fill(tint.opacity(0.15)))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(tint.opacity(0.5), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.5 : 1)
    }

    private func sorted(_ titles: [Title], _ state: GameState) -> [Title] {
        switch sort {
        case .fit: return titles.sorted { state.marketFit(of: $0) > state.marketFit(of: $1) }
        case .quality: return titles.sorted { $0.quality > $1.quality }
        case .popularity: return titles.sorted { $0.popularity > $1.popularity }
        case .cheapest: return titles.sorted { state.licensePrice($0) < state.licensePrice($1) }
        case .ending: return titles.sorted { $0.listingWeeksLeft < $1.listingWeeksLeft }
        }
    }

    private func curatorCard(_ state: GameState) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "Licensing manager", icon: "person.crop.rectangle.stack.fill", tint: Theme.teal)
            if let curator = state.curator {
                HStack {
                    Pill(text: curator.enabled ? "Active" : "Paused", tint: curator.enabled ? Theme.good : Theme.amber)
                    Text("\(Format.money(state.curatorSalary))/wk salary").font(.caption).foregroundStyle(Theme.text2)
                }
                let rules = state.effectiveCurator() ?? curator
                Pill(text: "Style: \(curator.mode.title)", tint: Theme.teal)
                Text("This week: up to \(Format.money(rules.weeklyBudget)) for titles with quality \(rules.minQuality)+, until your catalog reaches \(rules.targetCatalogSize), always keeping \(Format.money(rules.cashReserve)) in the bank.")
                    .font(.footnote).foregroundStyle(Theme.text2)
                LabeledValue(label: "Allowance available now", value: Format.money(rules.weeklyBudget + curator.carryBudget))
                if let block = state.curatorRunwayBlock {
                    Text(block).font(.caption).foregroundStyle(Theme.amber)
                }
                if let status = state.curatorStatus {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "text.bubble.fill").font(.caption).foregroundStyle(Theme.teal)
                        Text(status).font(.caption).foregroundStyle(.white.opacity(0.85))
                    }
                }
                HStack {
                    Button("Shop now") { store.perform { try $0.shopNow() } }.buttonStyle(SoftButtonStyle(tint: Theme.good))
                    Button("Edit rules") { showCurator = true }.buttonStyle(SoftButtonStyle(tint: Theme.teal))
                    Button(curator.enabled ? "Pause" : "Resume") {
                        var updated = curator
                        updated.enabled.toggle()
                        store.perform { try $0.updateCurator(updated) }
                    }
                    .buttonStyle(SoftButtonStyle(tint: Theme.amber))
                    Button("Dismiss") { store.perform { $0.fireCurator() } }
                        .buttonStyle(SoftButtonStyle(tint: Theme.danger))
                }
            } else {
                Text("A manager shops the market for you every week. Pick a style (Passive, Moderate or Aggressive) that spends in line with what you earn, or set every rule yourself.")
                    .font(.footnote).foregroundStyle(Theme.text2)
                Button("Hire · \(Format.money(state.curatorHirePrice)) + \(Format.money(state.curatorSalary))/wk") {
                    store.perform { try $0.hireCurator(mode: .passive) }
                    showCurator = true
                }
                .buttonStyle(GlowButtonStyle(tint: Theme.teal))
                .disabled(state.finances.cash < state.curatorHirePrice)
            }
        }
        .artCard(tint: Theme.teal)
    }

    // MARK: Catalog

    private func footnote(_ title: Title, _ state: GameState) -> String {
        let rights = title.weeksRemaining.map { "\($0) wks left" } ?? "Yours forever"
        let viewers = state.stats(for: title).weeklyViewers
        return viewers > 0 ? "\(rights) · \(Format.count(viewers)) watching" : rights
    }

    private func performanceSummary(_ state: GameState) -> some View {
        let ranked = state.catalog.sorted { state.stats(for: $0).weeklyRevenue > state.stats(for: $1).weeklyRevenue }
        let views = state.catalog.reduce(0) { $0 + state.stats(for: $1).weeklyViewers }
        return VStack(alignment: .leading, spacing: 8) {
            SectionTitle(text: "Catalog performance", icon: "chart.bar.fill", tint: Theme.teal)
            LabeledValue(label: "Viewers this week (all titles)", value: Format.count(views))
            ForEach(Array(ranked.prefix(3).enumerated()), id: \.element.id) { index, title in
                let s = state.stats(for: title)
                LabeledValue(label: "#\(index + 1) \(title.name)",
                             value: "\(Format.count(s.weeklyViewers)) · \(Format.money(s.weeklyRevenue))/wk")
            }
            if let worst = ranked.last, ranked.count > 3, state.stats(for: worst).weeksLive > 8 {
                LabeledValue(label: "Weakest: \(worst.name)", value: "\(Format.money(state.stats(for: worst).weeklyRevenue))/wk",
                             tint: Theme.danger)
            }
        }
        .artCard(tint: Theme.teal)
    }

    @ViewBuilder
    private func catalog(_ state: GameState) -> some View {
        RenewalModePicker(state: state)
        if !state.expiringTitles.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle(text: "Expiring soon", icon: "clock.badge.exclamationmark.fill", tint: Theme.danger)
                Button("Renew all (2 yr) · \(Format.money(state.renewAllPrice(years: 2)))") {
                    store.perform { _ = try $0.renewAll(years: 2) }
                }
                .buttonStyle(SoftButtonStyle(tint: Theme.danger))
                ForEach(state.expiringTitles) { title in
                    RenewCard(title: title, state: state, onDone: nil)
                }
            }
        }
        if !state.catalog.isEmpty { performanceSummary(state) }
        if !state.loanedOut.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                SectionTitle(text: "Licensed out", icon: "arrow.up.right.square.fill", tint: Theme.amber)
                ForEach(state.loanedOut, id: \.title.id) { loan in
                    HStack {
                        Text(loan.title.name).font(.subheadline.weight(.bold)).foregroundStyle(.white).lineLimit(1)
                        Spacer()
                        Text("\(loan.to) · \(loan.weeksLeft) wks · \(Format.money(loan.fee))")
                            .font(.caption).foregroundStyle(Theme.text2)
                    }
                }
            }
            .artCard(tint: Theme.amber)
        }
        if state.catalog.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "film").font(.largeTitle).foregroundStyle(Theme.text2)
                Text("Your catalog is empty").font(.headline).foregroundStyle(.white)
                Text("License titles from the Licensing tab, or produce your own originals.")
                    .font(.footnote).foregroundStyle(Theme.text2).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .artCard()
        } else {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(state.catalog.sorted { $0.quality > $1.quality }) { title in
                    Button { detail = TitleRef(id: title.id) } label: {
                        TitleCell(title: title, state: state, priceText: nil,
                                  footnote: footnote(title, state))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

/// Poster with bars underneath.
struct TitleCell: View {
    let title: Title
    let state: GameState
    var priceText: String?
    var footnote: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            PosterView(title: title)
            Text(title.name).font(.caption.weight(.bold)).foregroundStyle(.white).lineLimit(1)
            StatBar(label: "Quality", value: Double(title.quality) / 100, tint: Theme.amber, height: 4, compact: true)
            StatBar(label: "Popularity", value: Double(title.popularity) / 100, tint: Theme.magenta, height: 4, compact: true)
            StatBar(label: "Fits your markets", value: state.marketFit(of: title), tint: Theme.violet, height: 4, compact: true)
            HStack {
                if let priceText { Pill(text: priceText, tint: Theme.amber) }
                if let footnote { Text(footnote).font(.system(size: 10)).foregroundStyle(Theme.text2) }
            }
        }
    }
}

/// Full details for one title, with buy / localize actions.
struct TitleDetailSheet: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.dismiss) private var dismiss
    let titleID: Int
    @State private var showLocalize = false
    @State private var showContinue = false
    @State private var showNegotiate = false

    var body: some View {
        NavigationStack {
            ScrollView {
                if let state = store.state, let title = find(state) {
                    let owned = state.catalog.contains { $0.id == titleID }
                    VStack(spacing: 16) {
                        if owned, (title.weeksRemaining ?? .max) <= Formulas.renewalWindowWeeks, title.license != nil {
                            renewCard(title, state)
                        }
                        PosterView(title: title, cornerRadius: 16)
                            .frame(width: 210)
                            .padding(.top, 6)
                        VStack(spacing: 6) {
                            Text(title.name).font(Theme.display(24)).foregroundStyle(.white).multilineTextAlignment(.center)
                            HStack(spacing: 6) {
                                Pill(text: title.kind.displayName, tint: Theme.violet)
                                Pill(text: title.genre.displayName, tint: Theme.magenta)
                                Pill(text: title.language.displayName, tint: Theme.teal)
                                Pill(text: ageText(title), tint: Theme.amber)
                            }
                        }
                        bars(title, state)
                        topMarkets(title, state)
                        if owned { statsCard(title, state) }
                        if owned { ownedCard(title) } else { licenseCard(title, state) }
                        if owned { rightsCard(title, state) }
                    }
                    .padding(16)
                }
            }
            .artScreen()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Done") { dismiss() } }
            .sheet(isPresented: $showLocalize) { LocalizeView(titleID: titleID) }
            .sheet(isPresented: $showContinue) { ContinueView(titleID: titleID) }
            .sheet(isPresented: $showNegotiate) { NegotiateView(titleID: titleID) }
        }
    }

    private func find(_ state: GameState) -> Title? {
        state.catalog.first { $0.id == titleID } ?? state.licenseMarket.first { $0.id == titleID }
    }

    private func ageText(_ title: Title) -> String {
        title.ageWeeks < 4 ? "New release" : title.ageWeeks < 52 ? "\(title.ageWeeks) wks old" : "\(title.ageWeeks / 52) yr old"
    }

    private func bars(_ title: Title, _ state: GameState) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(text: "How good is it?", icon: "star.fill", tint: Theme.amber)
            StatBar(label: "Quality", value: Double(title.quality) / 100, tint: Theme.amber)
            Text("Critic and audience scores. Better titles pull in more subscribers.").font(.caption2).foregroundStyle(Theme.text2)
            StatBar(label: "Popularity", value: Double(title.popularity) / 100, tint: Theme.magenta)
            Text("How many people want to watch it. Pairs with quality for appeal.").font(.caption2).foregroundStyle(Theme.text2)
            StatBar(label: "Freshness", value: state.freshness(of: title), tint: Theme.teal)
            Text("New releases get a boost; older titles slowly lose pull.").font(.caption2).foregroundStyle(Theme.text2)
            StatBar(label: "Fit for your markets", value: state.marketFit(of: title), tint: Theme.violet)
            Text("How well its genre and language suit the countries you serve.").font(.caption2).foregroundStyle(Theme.text2)
        }
        .artCard(tint: Theme.amber)
    }

    private func topMarkets(_ title: Title, _ state: GameState) -> some View {
        let rows = state.liveMarketCodes.compactMap { code -> (Country, Double)? in
            guard let country = CountryData.country(code) else { return nil }
            return (country, min(1, Formulas.titleAppeal(title, in: country) / 0.8))
        }.sorted { $0.1 > $1.1 }.prefix(4)
        return VStack(alignment: .leading, spacing: 8) {
            SectionTitle(text: "Best in your markets", icon: "globe", tint: Theme.violet)
            ForEach(Array(rows), id: \.0.code) { row in
                StatBar(label: "\(row.0.flag) \(row.0.name)", value: row.1, tint: Theme.violet, height: 5, compact: true)
            }
        }
        .artCard(tint: Theme.violet)
    }

    private func licenseCard(_ title: Title, _ state: GameState) -> some View {
        let price = state.licensePrice(title)
        return VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "License terms", icon: "signature", tint: Theme.teal)
            if let license = title.license {
                LabeledValue(label: "Price", value: Format.money(price))
                LabeledValue(label: "Length", value: "\(license.years) year\(license.years == 1 ? "" : "s")")
                LabeledValue(label: "Exclusive", value: license.exclusive ? "Yes (+15% appeal)" : "No")
                LabeledValue(label: "Offer ends in", value: "\(title.listingWeeksLeft) weeks")
                if title.embargoWeeks > 0 {
                    Text("Rights go on sale in \(title.embargoWeeks) weeks.").font(.caption).foregroundStyle(Theme.amber)
                }
                if !license.regions.isEmpty {
                    Text("Territory: only \(license.regions.count) of \(CountryData.all.count) countries. Cheaper, but it won't play elsewhere.")
                        .font(.caption).foregroundStyle(Theme.amber)
                }
                if title.mature { Text("Mature: strict countries need a local edit.").font(.caption).foregroundStyle(Theme.text2) }
            }
            Button("Buy for \(Format.money(price))") {
                store.perform { try $0.buyLicense(titleID: titleID) }
                dismiss()
            }
            .buttonStyle(GlowButtonStyle(tint: Theme.teal))
            .disabled(state.finances.cash < price || title.embargoWeeks > 0)
            Button("Negotiate terms") { showNegotiate = true }
                .buttonStyle(SoftButtonStyle(tint: Theme.amber)).disabled(title.embargoWeeks > 0)
        }
        .artCard(tint: Theme.teal)
    }

    private func statsCard(_ title: Title, _ state: GameState) -> some View {
        let s = state.stats(for: title)
        let net = state.netReturn(title)
        return VStack(alignment: .leading, spacing: 8) {
            SectionTitle(text: "Performance", icon: "chart.bar.fill", tint: Theme.teal)
            if s.weeksLive == 0 {
                Text("Stats start after its first week on your service.").font(.footnote).foregroundStyle(Theme.text2)
            } else {
                LabeledValue(label: "Watching this week", value: Format.count(s.weeklyViewers))
                LabeledValue(label: "Peak weekly viewers", value: Format.count(s.peakViewers))
                LabeledValue(label: "Total views", value: Format.count(s.totalViews))
                LabeledValue(label: "Revenue this week", value: Format.money(s.weeklyRevenue))
                LabeledValue(label: "Lifetime revenue", value: Format.money(s.lifetimeRevenue))
                if s.licenseIncome > 0 { LabeledValue(label: "Licensing fees earned", value: Format.money(s.licenseIncome)) }
                LabeledValue(label: "Spent on it", value: Format.money(title.invested))
                LabeledValue(label: "Net return", value: Format.money(net), tint: net >= 0 ? Theme.good : Theme.danger)
                LabeledValue(label: "Weeks on your service", value: "\(s.weeksLive)")
                if let top = CountryData.country(s.topMarket) {
                    LabeledValue(label: "Most watched in", value: "\(top.flag) \(top.name)")
                }
            }
        }
        .artCard(tint: Theme.teal)
    }

    @ViewBuilder
    private func restrictions(_ title: Title, _ state: GameState) -> some View {
        let live = state.liveMarketCodes
        let blocked = live.compactMap { code -> (Country, String)? in
            guard let country = CountryData.country(code) else { return nil }
            if !title.inTerritory(code) { return (country, "Outside your license territory") }
            if let reason = title.blockReason(in: code) { return (country, reason) }
            return nil
        }
        if !blocked.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("Not playing in").font(.caption.weight(.bold)).foregroundStyle(Theme.amber)
                ForEach(blocked, id: \.0.code) { item in
                    HStack {
                        Text("\(item.0.flag) \(item.0.name): \(item.1)").font(.caption).foregroundStyle(Theme.text2)
                        Spacer()
                        if item.1 == "Needs a local edit" {
                            Button("Edit \(Format.money(state.editCost(title)))") {
                                store.perform { try $0.editForMarket(titleID: title.id, code: item.0.code) }
                            }
                            .font(.caption.weight(.bold)).buttonStyle(.bordered).tint(Theme.amber)
                        }
                    }
                }
                if let license = title.license, !license.regions.isEmpty {
                    let price = state.territoryExtensionPrice(title)
                    Button("Add worldwide rights · \(Format.money(price))") {
                        store.perform { try $0.extendTerritory(titleID: title.id) }
                    }
                    .buttonStyle(SoftButtonStyle(tint: Theme.teal)).disabled(state.finances.cash < price)
                }
            }
        }
    }

    private func rightsCard(_ title: Title, _ state: GameState) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "Rights", icon: "signature", tint: Theme.amber)
            restrictions(title, state)
            if title.license != nil, title.weeksRemaining != nil {
                let price = state.buyoutPrice(title)
                Text("Own it forever: no expiry, no renewals.").font(.caption).foregroundStyle(Theme.text2)
                Button("Buy rights forever · \(Format.money(price))") {
                    store.perform { try $0.buyOutRights(titleID: title.id) }
                }
                .buttonStyle(GlowButtonStyle(tint: Theme.good))
                .disabled(state.finances.cash < price)
            }
            Text("Or take it off your service and license it to another streamer for a fee.")
                .font(.caption).foregroundStyle(Theme.text2)
            ForEach(Formulas.sublicenseTerms, id: \.self) { weeks in
                let allowed = (title.weeksRemaining ?? .max) > weeks
                Button("License out \(weeks) weeks · +\(Format.money(state.sublicenseFee(title, weeks: weeks)))") {
                    store.perform { try $0.licenseOut(titleID: title.id, weeks: weeks) }
                    dismiss()
                }
                .buttonStyle(SoftButtonStyle(tint: Theme.amber))
                .disabled(!allowed)
            }
        }
        .artCard(tint: Theme.amber)
    }

    private func renewCard(_ title: Title, _ state: GameState) -> some View {
        RenewCard(title: title, state: state, onDone: nil)
    }

    private func ownedCard(_ title: Title) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "In your catalog", icon: "checkmark.seal.fill", tint: Theme.good)
            LabeledValue(label: "Rights", value: title.weeksRemaining.map { "\($0) weeks left" } ?? "Owned forever, worldwide")
            if !title.dubs.isEmpty { LabeledValue(label: "Dubbed", value: title.dubs.map(\.displayName).joined(separator: ", ")) }
            if !title.subtitles.isEmpty { LabeledValue(label: "Subtitled", value: title.subtitles.map(\.displayName).joined(separator: ", ")) }
            if title.isOriginal {
                LabeledValue(label: title.kind == .series ? "Seasons" : "Installments", value: "\(title.seasons)")
                if title.awards > 0 { LabeledValue(label: "Awards won", value: "\(title.awards)", tint: Theme.amber) }
                if title.star != .none { LabeledValue(label: "Star", value: title.star.displayName) }
                LabeledValue(label: "Release", value: title.weeklyRelease ? "Weekly episodes" : "Binge drop")
                Button(title.kind == .series ? "Order next season" : "Order a sequel") { showContinue = true }
                    .buttonStyle(SoftButtonStyle(tint: Theme.magenta))
            }
            Button("Add dubbing or subtitles") { showLocalize = true }.buttonStyle(SoftButtonStyle(tint: Theme.violet))
            Button(title.isOriginal ? "Write off (10% tax benefit, fans upset)" : "Pull from the service (no refund)") {
                store.perform { try $0.removeTitle(titleID: title.id) }
                dismiss()
            }
            .font(.caption).foregroundStyle(Theme.danger)
        }
        .artCard(tint: Theme.good)
    }
}

/// Rules for the licensing manager.
struct CuratorSheet: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft = Curator()
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Style", selection: $draft.mode) {
                        ForEach(CuratorMode.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Text(draft.mode.blurb).font(.footnote).foregroundStyle(Theme.text2)
                } header: {
                    Text("Shopping style")
                } footer: {
                    Text("Passive, Moderate and Aggressive size the budget to your revenue and cash every week, keep a reserve and stop buying when money runs short. Pick Custom to set everything yourself.")
                }
                Section("Right now") {
                    preview
                }
                Section {
                    Toggle("Manager is active", isOn: $draft.enabled).tint(Theme.magenta)
                } footer: {
                    Text("Each week your manager buys the best-value titles that pass every rule below, up to 3 purchases.")
                }
                if draft.mode == .custom {
                Section("Spending") {
                    NumberFieldRow(label: "Max per week", value: $draft.weeklyBudget, range: 0...1_000_000_000, isMoney: true)
                    NumberFieldRow(label: "Max price per title", value: $draft.maxPricePerTitle, range: 0...1_000_000_000, isMoney: true)
                    NumberFieldRow(label: "Always keep in the bank", value: $draft.cashReserve, range: 0...10_000_000_000, isMoney: true)
                }
                Section("What to buy") {
                    IntFieldRow(label: "Minimum quality (0-100)", value: $draft.minQuality, range: 0...100)
                    IntFieldRow(label: "Longest license (1-5)", value: $draft.maxYears, range: 1...5, suffix: "yr")
                    IntFieldRow(label: "Stop at catalog size", value: $draft.targetCatalogSize, range: 0...1_000, suffix: "titles")
                    Toggle("Movies", isOn: $draft.allowMovies)
                    Toggle("Series", isOn: $draft.allowSeries)
                    Toggle("Allow exclusives", isOn: $draft.allowExclusive)
                    Toggle("Only languages I serve (and English)", isOn: $draft.onlyMyLanguages)
                }
                Section {
                    Toggle("Renew expiring titles automatically", isOn: $draft.autoRenew).tint(Theme.magenta)
                    NumberFieldRow(label: "Max price per renewal", value: $draft.renewMaxPrice, range: 0...1_000_000_000, isMoney: true)
                    IntFieldRow(label: "Renewal length (1-5)", value: $draft.renewYears, range: 1...5, suffix: "yr")
                } header: {
                    Text("Renewals")
                } footer: {
                    Text("Renews titles within 8 weeks of expiring if they pass your quality bar and fit the price, budget and cash reserve. Otherwise you get a warning.")
                }
                Section {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 8)], spacing: 8) {
                        ForEach(Genre.allCases) { genre in
                            let on = draft.genres.contains(genre)
                            Button {
                                if on { draft.genres.removeAll { $0 == genre } } else { draft.genres.append(genre) }
                            } label: {
                                Text(genre.displayName).font(.caption.weight(.bold))
                                    .frame(maxWidth: .infinity).padding(.vertical, 8)
                                    .background(Capsule().fill(on ? Theme.magenta.opacity(0.4) : Color.white.opacity(0.08)))
                                    .overlay(Capsule().stroke(on ? Theme.magenta : Color.clear, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } header: {
                    Text("Genres")
                } footer: {
                    Text(draft.genres.isEmpty ? "None selected means any genre." : "Only these genres.")
                }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .artScreen()
            .navigationTitle("Manager rules")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.perform { try $0.updateCurator(draft) }
                        dismiss()
                    }
                }
            }
            .onAppear {
                if !loaded, let current = store.state?.curator { draft = current; loaded = true }
            }
        }
    }

    /// How many of today's listings pass the draft rules, and what they'd cost.
    @ViewBuilder
    private var preview: some View {
        if let state = store.state {
            let rules = state.effective(draft)
            let languages = servedLanguages(state)
            let passing = state.licenseMarket.filter { rules.allows($0, languages: languages) }
            let prices = passing.map { state.licensePrice($0) }
            let affordable = prices.filter { $0 <= rules.maxPricePerTitle && $0 <= rules.weeklyBudget * state.curatorCarryWeeks }
            LabeledValue(label: "Listings on the market", value: "\(state.licenseMarket.count)")
            LabeledValue(label: "Pass your quality, genre and language rules", value: "\(passing.count)")
            LabeledValue(label: "Also within budget and max price", value: "\(affordable.count)",
                         tint: affordable.isEmpty ? Theme.danger : Theme.good)
            if let cheapest = prices.min() {
                LabeledValue(label: "Cheapest that passes", value: Format.money(cheapest))
            }
            if affordable.isEmpty {
                Text("Nothing would be bought this week. Raise the budget or max price, lower the minimum quality, or allow more genres.")
                    .font(.caption).foregroundStyle(Theme.amber)
            }
        }
    }

    private func servedLanguages(_ state: GameState) -> Set<Language> {
        var set: Set<Language> = [.english]
        for code in state.markets.keys.sorted() where state.markets[code]?.status != .notLaunched {
            if let language = CountryData.country(code)?.language { set.insert(language) }
        }
        return set
    }
}

/// Add subtitles or dubbing to a catalog title.
struct LocalizeView: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.dismiss) private var dismiss
    let titleID: Int

    var body: some View {
        NavigationStack {
            ScrollView {
                if let state = store.state, let title = state.catalog.first(where: { $0.id == titleID }) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Dubbing counts almost like native-language content and helps local-content quotas. Subtitles help less but cost less.")
                            .font(.footnote).foregroundStyle(Theme.text2)
                        ForEach(targetLanguages(state: state, title: title), id: \.self) { language in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(language.displayName).font(.headline).foregroundStyle(.white)
                                HStack {
                                    action("Subtitles", state.localizationPrice(kind: title.kind, dub: false), done: title.subtitles.contains(language)) {
                                        store.perform { try $0.localizeTitle(titleID: titleID, language: language, dub: false) }
                                    }
                                    action("Dub", state.localizationPrice(kind: title.kind, dub: true), done: title.dubs.contains(language)) {
                                        store.perform { try $0.localizeTitle(titleID: titleID, language: language, dub: true) }
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .artCard(tint: Theme.violet)
                        }
                    }
                    .padding(16)
                }
            }
            .artScreen()
            .navigationTitle("Localize")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Done") { dismiss() } }
        }
    }

    private func action(_ label: String, _ cost: Double, done: Bool, run: @escaping () -> Void) -> some View {
        Button(done ? "\(label) ✓" : "\(label) · \(Format.money(cost))", action: run)
            .buttonStyle(SoftButtonStyle(tint: done ? Theme.good : Theme.violet))
            .disabled(done)
    }

    private func targetLanguages(state: GameState, title: Title) -> [Language] {
        var set = Set<Language>()
        for code in state.markets.keys.sorted() where state.markets[code]?.status != .notLaunched {
            if let language = CountryData.country(code)?.language { set.insert(language) }
        }
        return set.filter { $0 != title.language }.sorted { $0.rawValue < $1.rawValue }
    }
}

/// Renew an expiring license: pick 1-5 years. Cheaper than the original deal unless the title took off.
struct RenewCard: View {
    @EnvironmentObject var store: GameStore
    let title: Title
    let state: GameState
    var onDone: (() -> Void)?
    @State private var years = 2

    var body: some View {
        let price = state.renewalPrice(title, years: years)
        let jumped = state.hasPopularityJump(title)
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(title.name, systemImage: "clock.badge.exclamationmark.fill")
                    .font(.subheadline.weight(.bold)).foregroundStyle(Theme.danger).lineLimit(1)
                Spacer()
                Text("\(title.weeksRemaining ?? 0) wks left").font(.caption).foregroundStyle(Theme.danger)
            }
            if title.sought {
                Text("A famous show: the studio won't discount it.").font(.caption).foregroundStyle(Theme.amber)
            } else if jumped {
                Text("Popularity is up since you signed, so the price is higher.").font(.caption).foregroundStyle(Theme.amber)
            } else {
                Text("Renewing is cheaper than your original deal.").font(.caption).foregroundStyle(Theme.good)
            }
            Stepper(value: $years, in: 1...5) {
                LabeledValue(label: "Extend by", value: "\(years) year\(years == 1 ? "" : "s")")
            }
            Button("Renew for \(Format.money(price))") {
                store.perform { try $0.renewLicense(titleID: title.id, years: years) }
                onDone?()
            }
            .buttonStyle(GlowButtonStyle(tint: Theme.danger))
            .disabled(state.finances.cash < price)
        }
        .padding(12)
        .background(Theme.danger.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.danger.opacity(0.6), lineWidth: 1))
    }
}

/// Counter-offer on a listing: your price, your term, exclusive or not.
struct NegotiateView: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.dismiss) private var dismiss
    let titleID: Int
    @State private var offer = 0.85
    @State private var years = 2
    @State private var exclusive = false
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            Form {
                if let state = store.state, let title = state.licenseMarket.first(where: { $0.id == titleID }) {
                    let asking = state.askingPrice(title, years: years, exclusive: exclusive)
                    let chance = state.acceptChance(title, offer: offer)
                    Section("Terms") {
                        Stepper(value: $years, in: 1...5) { LabeledValue(label: "Length", value: "\(years) yr") }
                        Toggle("Exclusive (+15% appeal, costs more)", isOn: $exclusive)
                        LabeledValue(label: "Asking for these terms", value: Format.money(asking))
                    }
                    Section("Your offer") {
                        HStack {
                            Text("\(Format.percent(offer)) of asking")
                            Slider(value: $offer, in: 0.5...1.0, step: 0.01)
                        }
                        LabeledValue(label: "You pay", value: Format.money(asking * offer))
                        StatBar(label: "Chance they accept", value: chance, text: Format.percent(chance),
                                tint: chance > 0.6 ? Theme.good : chance > 0.3 ? Theme.amber : Theme.danger)
                        Text("If they say no, they won't talk for 4 weeks and the price goes up 5%.\(title.sought ? " Famous titles drive a hard bargain." : "")")
                            .font(.footnote).foregroundStyle(Theme.text2)
                    }
                    Section {
                        Button("Make the offer") {
                            store.perform { _ = try $0.negotiate(titleID: titleID, offer: offer, years: years, exclusive: exclusive) }
                        }
                        .disabled(state.finances.cash < asking * offer || title.talksBlockedUntil > state.week)
                        if title.talksBlockedUntil > state.week {
                            Text("They won't talk again until week \(title.talksBlockedUntil).").font(.footnote).foregroundStyle(Theme.amber)
                        }
                    }
                } else if let state = store.state {
                    Text(state.lastNegotiation.isEmpty ? "This listing is gone." : state.lastNegotiation)
                }
                if let note = store.state?.lastNegotiation, !note.isEmpty, store.state?.licenseMarket.contains(where: { $0.id == titleID }) == true {
                    Section { Text(note).font(.footnote) }
                }
            }
            .artScreen()
            .navigationTitle("Negotiate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Done") { dismiss() } }
            .onAppear {
                guard !loaded, let title = store.state?.licenseMarket.first(where: { $0.id == titleID }) else { return }
                years = title.license?.years ?? 2
                exclusive = title.license?.exclusive ?? false
                loaded = true
            }
        }
    }
}

/// Pick how freely expiring licenses renew on their own.
struct RenewalModePicker: View {
    @EnvironmentObject var store: GameStore
    let state: GameState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Auto-renew licenses").font(.subheadline.weight(.semibold)).foregroundStyle(.white)
            Picker("Auto-renew", selection: Binding(get: { state.renewalMode },
                                                    set: { mode in store.perform { $0.renewalMode = mode } })) {
                ForEach(RenewalMode.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            Text(state.renewalMode.blurb).font(.caption).foregroundStyle(Theme.text2)
        }
        .artCard(tint: Theme.good)
    }
}
