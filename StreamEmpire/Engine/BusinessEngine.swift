import Foundation

// MARK: Effects used by the weekly simulation

struct FeatureEffects { var adds = 1.0, churn = 1.0, appeal = 1.0, streaming = 1.0 }
struct SportsEffects { var appealBonus = 0.0, churn = 1.0, adds = 1.0 }
struct PartnerEffects { var adds = 1.0, arpu = 1.0 }

extension GameState {
    // MARK: Currencies

    func fxIndex(_ region: Region) -> Double { region == .northAmerica ? 1.0 : (fx[region.rawValue] ?? 1.0) }

    /// Exchange rates wander, but are pulled back toward parity.
    mutating func driftCurrencies() {
        for region in Region.allCases where region != .northAmerica {
            let current = fx[region.rawValue] ?? 1.0
            let next = current + 0.12 * (1 - current) + rng.nextDouble(in: -0.015...0.015)
            fx[region.rawValue] = Formulas.clamp(next, 0.8, 1.2)
        }
    }

    // MARK: Product features

    func featureLevel(_ feature: ProductFeature) -> Int { features[feature.rawValue] ?? 0 }

    func featurePrice(_ feature: ProductFeature) -> Double {
        scaled(feature.baseCost * Double(featureLevel(feature) + 1))
    }

    var featureUpkeep: Double {
        ProductFeature.allCases.reduce(0) { $0 + scaled($1.baseUpkeep * Double(featureLevel($1))) }
    }

    mutating func buyFeature(_ feature: ProductFeature) throws {
        guard outcome == .playing else { throw ActionError.gameOver }
        guard featureLevel(feature) < feature.maxLevel else { throw ActionError.invalidProject("\(feature.displayName) is fully built.") }
        let price = featurePrice(feature)
        guard finances.cash >= price else { throw ActionError.insufficientFunds(needed: price) }
        finances.cash -= price
        finances.ledger.other += price
        features[feature.rawValue] = featureLevel(feature) + 1
        addNews(.you, "\(companyName) launches \(feature.displayName.lowercased())", "A new product feature for customers.")
    }

    func featureEffects(for country: Country) -> FeatureEffects {
        var e = FeatureEffects()
        if featureLevel(.kidsProfiles) > 0 { e.churn *= 0.97 }
        if featureLevel(.downloads) > 0 {
            if country.priceTolerance < 6 { e.churn *= 0.97; e.adds *= 1.04 } else { e.churn *= 0.99 }
        }
        if featureLevel(.fourK) > 0 {
            e.streaming *= 1.12
            e.churn *= 0.98 / Trends.effects(week: week).churn
        }
        e.appeal = 1 + 0.03 * Double(featureLevel(.recommendations))
        return e
    }

    // MARK: Ad load

    mutating func setAdLoad(_ value: Double) throws {
        guard (0.5...1.5).contains(value) else { throw ActionError.invalidAmount }
        adLoad = value
    }

    // MARK: Sports rights

    static let sportsNames = ["Premier Footy League", "Gridiron Pro Football", "Hoops Association", "Grand Slam Tennis Tour",
                              "Formula Zero Racing", "Diamond League Baseball"]

    func sportsEffects(region: Region) -> SportsEffects {
        var e = SportsEffects()
        for right in sportsHeld where right.region == region {
            e.appealBonus += 0.10; e.churn *= 0.9; e.adds *= 1.1
        }
        return e
    }

    mutating func refreshSportsOffers() {
        sportsOffers.removeAll { $0.weeksLeft <= 0 }
        for i in sportsOffers.indices { sportsOffers[i].weeksLeft -= 1 }
        for i in sportsHeld.indices { sportsHeld[i].weeksLeft -= 1 }
        for right in sportsHeld where right.weeksLeft <= 0 {
            addNews(.you, "\(right.name) rights end", "Your \(right.region.displayName) sports package has expired.")
        }
        sportsHeld.removeAll { $0.weeksLeft <= 0 }
        if week % 52 == 20 {
            for _ in 0..<2 {
                let name = rng.pick(Self.sportsNames)
                let region = rng.pick(Region.allCases)
                guard !sportsOffers.contains(where: { $0.name == name }), !sportsHeld.contains(where: { $0.name == name }) else { continue }
                let ask = scaled(3_000_000) * min(8, Formulas.licenseAudienceScale(totalSubscribers: totalSubscribers))
                sportsOffers.append(SportsOffer(id: takeID(), name: name, region: region, askPrice: ask, weeksLeft: 6))
            }
        }
    }

    /// Bid `premium` times the asking price (1.0 to 1.6). A higher bid wins more often; you only pay if you win.
    mutating func bidForSports(offerID: Int, premium: Double) throws {
        guard outcome == .playing else { throw ActionError.gameOver }
        guard let index = sportsOffers.firstIndex(where: { $0.id == offerID }) else { throw ActionError.titleNotFound }
        guard (1.0...1.6).contains(premium) else { throw ActionError.invalidAmount }
        let offer = sportsOffers[index]
        let price = offer.askPrice * premium
        guard finances.cash >= price else { throw ActionError.insufficientFunds(needed: price) }
        sportsOffers.remove(at: index)
        let chance = Formulas.clamp(0.40 + 0.9 * (premium - 1), 0.1, 0.95)
        if rng.chance(chance) {
            finances.cash -= price
            finances.ledger.licensing += price
            sportsHeld.append(SportsRight(id: offer.id, name: offer.name, region: offer.region, weeksLeft: 52))
            addNews(.you, "\(companyName) wins \(offer.name)", "A year of live sport in \(offer.region.displayName) for \(Format.money(price)).")
        } else {
            addNews(.you, "\(companyName) loses the \(offer.name) auction", "A rival bid higher. You paid nothing.")
            lastSportsResult = "Outbid on \(offer.name)."
        }
    }

    // MARK: Partnerships

    static let maxPartnerships = 3

    func partnershipPrice(_ country: Country) -> Double { scaled(100_000 + 25_000 * country.households) }

    func partnerEffects(for code: String) -> PartnerEffects {
        var e = PartnerEffects()
        for p in partnerships where p.country == code { e.adds *= p.kind.adds; e.arpu *= p.kind.arpu }
        return e
    }

    mutating func signPartnership(code: String, kind: PartnershipKind) throws {
        guard outcome == .playing else { throw ActionError.gameOver }
        guard let country = CountryData.country(code), markets[code]?.isLive == true else {
            throw ActionError.invalidProject("Launch there first.")
        }
        guard partnerships.count < Self.maxPartnerships else { throw ActionError.invalidProject("You can run 3 partnerships at once.") }
        guard !partnerships.contains(where: { $0.country == code }) else { throw ActionError.invalidProject("You already have a partner there.") }
        if kind == .rivalBundle, !rivals.contains(where: { ($0.subs[code] ?? 0) > 0 }) {
            throw ActionError.invalidProject("No rival operates there.")
        }
        let price = partnershipPrice(country)
        guard finances.cash >= price else { throw ActionError.insufficientFunds(needed: price) }
        finances.cash -= price
        finances.ledger.other += price
        partnerships.append(Partnership(id: takeID(), country: code, kind: kind, weeksLeft: 52))
        addNews(.you, "\(companyName) teams up in \(country.name)", "\(country.flag) \(kind.displayName) for a year.")
    }

    mutating func progressPartnerships() {
        for i in partnerships.indices { partnerships[i].weeksLeft -= 1 }
        for p in partnerships where p.weeksLeft <= 0 {
            addNews(.you, "Partnership in \(CountryData.country(p.country)?.name ?? p.country) ends", "The \(p.kind.displayName.lowercased()) has run its course.")
        }
        partnerships.removeAll { $0.weeksLeft <= 0 }
        endOrphanedBundles()
    }

    /// A rival-bundle deal needs a rival to bundle with: it ends when the last one in that country is gone.
    mutating func endOrphanedBundles() {
        partnerships.removeAll { p in
            p.kind == .rivalBundle && !rivals.contains { ($0.subs[p.country] ?? 0) > 0 }
        }
    }

    // MARK: Acquisitions

    mutating func refreshAcquisitionOffers() {
        for i in acquisitionOffers.indices { acquisitionOffers[i].weeksLeft -= 1 }
        acquisitionOffers.removeAll { $0.weeksLeft <= 0 }
        guard week % 26 == 10, acquisitionOffers.count < 2 else { return }
        let scale = min(5, Formulas.licenseAudienceScale(totalSubscribers: totalSubscribers))
        if rng.chance(0.6) {
            let count = rng.nextInt(in: 6...10)
            acquisitionOffers.append(AcquisitionOffer(id: takeID(), kind: .library, name: "Independent film library",
                                                      price: scaled(800_000 * Double(count)) * scale, titleCount: count, weeksLeft: 8))
        } else {
            let name = StudioNames.make(rng: &rng)
            acquisitionOffers.append(AcquisitionOffer(id: takeID(), kind: .studio, name: name,
                                                      price: scaled(2_500_000) * min(3, scale), titleCount: 0, weeksLeft: 8))
        }
    }

    mutating func acceptAcquisition(id: Int) throws {
        guard outcome == .playing else { throw ActionError.gameOver }
        guard let index = acquisitionOffers.firstIndex(where: { $0.id == id }) else { throw ActionError.titleNotFound }
        let offer = acquisitionOffers[index]
        if offer.kind == .studio, studios.count >= Formulas.maxStudios {
            throw ActionError.invalidProject("You already run the maximum number of studios.")
        }
        guard finances.cash >= offer.price else { throw ActionError.insufficientFunds(needed: offer.price) }
        finances.cash -= offer.price
        finances.ledger.other += offer.price
        acquisitionOffers.remove(at: index)
        switch offer.kind {
        case .studio:
            let genre = rng.pick(Genre.allCases.filter { $0 != .local })
            studios.append(Studio(id: takeID(), name: offer.name, specialty: genre, level: 2, experience: 20, foundedWeek: week))
            addNews(.you, "\(companyName) buys \(offer.name)", "A level 2 \(genre.displayName.lowercased()) studio joins you.")
        case .library:
            var taken = Set(catalog.map(\.name) + licenseMarket.map(\.name) + projects.map(\.name) + loanedOut.map(\.title.name))
            for _ in 0..<offer.titleCount {
                var title = TitleGenerator.generate(id: takeID(), rng: &rng, avoiding: taken)
                taken.insert(title.name)
                title.license = nil
                title.weeksRemaining = nil
                title.listingWeeksLeft = 0
                title.embargoWeeks = 0
                title.sought = false
                title.quality = Int(Formulas.clamp(Double(title.quality), 50, 78))
                title.invested = offer.price / Double(offer.titleCount)
                catalog.append(title)
            }
            addNews(.you, "\(companyName) buys a film library", "\(offer.titleCount) titles, yours forever, for \(Format.money(offer.price)).")
        }
    }
}

// MARK: Earnings

enum Earnings {
    /// Cash profit with content spend spread over two years, over the last quarter.
    static func report(_ s: inout GameState) {
        guard s.week >= 13, s.week % 13 == 0 else { return }
        let quarter = s.finances.history.suffix(13)
        guard quarter.count == 13 else { return }
        let revenue = quarter.reduce(0) { $0 + $1.revenue }
        let profit = quarter.reduce(0) { $0 + $1.profit }
        let contentSpend = quarter.reduce(0) { $0 + $1.licensing + $1.originals }
        let lifetime = s.finances.lifetime
        let base = Double(s.week) <= 104 ? lifetime.licensing + lifetime.originals
                                         : (lifetime.licensing + lifetime.originals) * 104 / Double(s.week)
        let amortized = 13 * base / 104
        let accounting = profit + contentSpend - amortized

        var expected = accounting
        var verdict = "met"
        if let last = s.quarterReports.last {
            expected = last.accountingProfit > 0 ? last.accountingProfit * 1.08 : last.accountingProfit * 0.85
            let surprise = (accounting - expected) / max(500_000, abs(expected))
            verdict = surprise > 0.05 ? "beat" : surprise < -0.05 ? "missed" : "met"
        }
        switch verdict {
        case "beat": s.earningsSentiment = min(1.35, s.earningsSentiment + 0.05)
        case "missed": s.earningsSentiment = max(0.7, s.earningsSentiment - 0.07)
        default: s.earningsSentiment += (1 - s.earningsSentiment) * 0.05
        }
        let report = QuarterReport(id: s.week / 13, week: s.week, revenue: revenue, profit: profit, accountingProfit: accounting,
                                   expectedProfit: expected, subscribers: s.totalSubscribers, verdict: verdict)
        s.quarterReports.append(report)
        if s.quarterReports.count > 12 { s.quarterReports.removeFirst() }
        let headline = "\(s.companyName) \(verdict == "beat" ? "beats" : verdict == "missed" ? "misses" : "meets") expectations"
        s.addNews(.profit, headline, "Quarter \(report.id): \(Format.money(revenue)) revenue, \(Format.money(accounting)) profit on the books (analysts expected \(Format.money(expected))).")
    }
}

// MARK: Rivals pulling their shows back

enum RivalRecalls {
    static func run(_ s: inout GameState, events: inout [GameEvent]) {
        for index in s.rivals.indices {
            let rival = s.rivals[index]
            let threat = s.threat(from: rival)
            let chance = 0.0015 * (rival.personality == .originalsHeavy ? 4 : 1) * (1 + threat)
            guard s.rng.chance(chance) else { continue }
            let candidates = s.catalog.indices.filter {
                let t = s.catalog[$0]
                return t.license?.exclusive == false && (t.weeksRemaining ?? 0) > 8 && t.quality >= 60
            }
            guard !candidates.isEmpty else { continue }
            let pick = candidates[s.rng.nextInt(in: 0...(candidates.count - 1))]
            let title = s.catalog.remove(at: pick)
            let share = Double(title.weeksRemaining ?? 0) / Double(max(1, title.license?.weeks ?? 1))
            let refund = title.paidPrice * min(1, share) * 0.4
            s.finances.cash += refund
            s.finances.ledger.licensing -= refund
            s.titleStats[title.id] = nil
            s.addNews(.licensing, "\(rival.name) pulls \"\(title.name)\" back", "It's moving to \(rival.name)'s own service. You get \(Format.money(refund)) back.")
            events.append(s.makeEvent(.licenseLost, "\"\(title.name)\" pulled by \(rival.name)", "The rights holder took it home. Refund: \(Format.money(refund))."))
            return   // at most one per week
        }
    }
}
