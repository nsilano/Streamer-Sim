import Foundation

/// Originals, localization and funding decisions.
extension GameState {
    // MARK: Originals

    /// Commissions an original. `studioID == nil` outsources it; otherwise it is produced in-house.
    mutating func commissionOriginal(kind: TitleKind, genre: Genre, language: Language,
                                     budget: Double, weeks: Int, studioID: Int? = nil,
                                     release: ReleaseStyle = .binge, star: StarTier = .none,
                                     sequelOf: Int? = nil, name nameOverride: String? = nil) throws {
        guard outcome == .playing else { throw ActionError.gameOver }
        var costFactor = 1.0
        if let studioID {
            guard let studio = studios.first(where: { $0.id == studioID }) else {
                throw ActionError.invalidProject("That studio doesn't exist.")
            }
            guard freeSlots(at: studio) > 0 else {
                throw ActionError.invalidProject("\(studio.name) has no free production slots. Upgrade it or wait.")
            }
            costFactor = Formulas.inHouseCostFactor(level: studio.level)
        } else {
            guard projects.filter({ $0.studioID == nil }).count < Formulas.maxConcurrentProjects else {
                throw ActionError.invalidProject("You can outsource at most \(Formulas.maxConcurrentProjects) productions at once.")
            }
        }
        guard Formulas.budgetRange(kind).contains(budget) else {
            throw ActionError.invalidProject("Budget for a \(kind.displayName.lowercased()) must be \(Format.money(Formulas.budgetRange(kind).lowerBound))-\(Format.money(Formulas.budgetRange(kind).upperBound)).")
        }
        guard Formulas.productionWeeksRange.contains(weeks) else {
            throw ActionError.invalidProject("Production takes 6 to 52 weeks.")
        }
        var seasonFactor = 1.0
        if let sequelOf, let parent = catalog.first(where: { $0.id == sequelOf }) {
            seasonFactor = Formulas.seasonCostFactor(seasons: parent.seasons)
        }
        let weekly = budget * costFactor * star.costFactor * seasonFactor * costScale / Double(weeks)
        guard finances.cash >= weekly * 4 else { throw ActionError.insufficientFunds(needed: weekly * 4) }
        let id = takeID()
        let name = nameOverride ?? TitleGenerator.makeName(genre: genre, rng: &rng)
        addNews(.you, "\(companyName) greenlights \"\(name)\"",
                "A \(genre.displayName.lowercased()) \(kind.displayName.lowercased()) with a \(Format.money(budget)) budget, ready in \(weeks) weeks\(studioID == nil ? "" : " from your in-house studio").")
        projects.append(OriginalProject(id: id, name: name, kind: kind, genre: genre, language: language,
                                        budget: budget, weeksTotal: weeks, weeksLeft: weeks, weeklyCost: weekly,
                                        studioID: studioID, release: release, star: star, sequelOf: sequelOf))
    }

    // MARK: Seasons and sequels

    /// Can this title get another season (series) or a sequel (movie)?
    func canContinue(_ title: Title) -> String? {
        guard title.isOriginal else { return "Only your own originals can continue." }
        if projects.contains(where: { $0.sequelOf == title.id }) { return "A new season is already in production." }
        if title.seasons >= 8 { return "It has run its course." }
        return nil
    }

    mutating func orderSeason(titleID: Int, budget: Double, weeks: Int, studioID: Int? = nil,
                              release: ReleaseStyle = .binge, star: StarTier = .none) throws {
        guard let title = catalog.first(where: { $0.id == titleID }) else { throw ActionError.titleNotFound }
        if let reason = canContinue(title) { throw ActionError.invalidProject(reason) }
        let next = title.seasons + 1
        let name = title.kind == .series ? title.name : "\(title.name.replacingOccurrences(of: #" [IVX]+$"#, with: "", options: .regularExpression)) \(GameState.roman(next))"
        try commissionOriginal(kind: title.kind, genre: title.genre, language: title.language, budget: budget,
                               weeks: weeks, studioID: studioID, release: release, star: star,
                               sequelOf: titleID, name: name)
    }

    static func roman(_ n: Int) -> String {
        ["", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"][min(max(n, 0), 10)]
    }

    // MARK: Localization

    mutating func localizeTitle(titleID: Int, language: Language, dub: Bool) throws {
        guard outcome == .playing else { throw ActionError.gameOver }
        guard let index = catalog.firstIndex(where: { $0.id == titleID }) else { throw ActionError.titleNotFound }
        let title = catalog[index]
        guard title.language != language else {
            throw ActionError.invalidProject("\"\(title.name)\" is already in \(language.displayName).")
        }
        if dub ? title.dubs.contains(language) : title.subtitles.contains(language) {
            throw ActionError.invalidProject("Already done.")
        }
        let cost = localizationPrice(kind: title.kind, dub: dub)
        guard finances.cash >= cost else { throw ActionError.insufficientFunds(needed: cost) }
        finances.cash -= cost
        finances.ledger.localization += cost
        if dub { catalog[index].dubs.append(language) } else { catalog[index].subtitles.append(language) }
    }

    // MARK: Funding

    var outstandingDebt: Double { loans.reduce(0) { $0 + $1.balance } }

    var creditLimit: Double {
        Formulas.creditLimit(annualRevenue: finances.annualizedRevenue, cash: finances.cash)
    }
    var creditRoom: Double { max(0, creditLimit - outstandingDebt) }

    var valuation: Double {
        Formulas.valuation(annualRevenue: finances.annualizedRevenue, subscribers: totalSubscribers)
            * Formulas.valuationBoost(financeLevel: staff.effectiveLevel(.finance)) * earningsSentiment
    }

    /// nil if an investor round is available now, otherwise why not.
    var roundBlocker: String? {
        if equity.ipoDone { return "You are public: raise money through loans." }
        if equity.roundsRaised >= Formulas.maxRounds { return "You've used all \(Formulas.maxRounds) funding rounds." }
        if equity.ownership <= Formulas.minOwnership + 0.0001 { return "Investors won't take you below \(Format.percent(Formulas.minOwnership)) ownership." }
        if finances.annualizedRevenue < Formulas.roundMinAnnualRevenue {
            return "Investors want at least \(Format.money(Formulas.roundMinAnnualRevenue)) annual revenue first."
        }
        let wait = equity.lastRoundWeek + Formulas.roundCooldownWeeks - week
        if wait > 0 { return "Next round possible in \(wait) week\(wait == 1 ? "" : "s")." }
        return nil
    }

    /// nil if an IPO is possible, otherwise why not.
    var ipoBlocker: String? {
        if equity.ipoDone { return "Already public." }
        if totalSubscribers < Formulas.ipoMinSubscribers || finances.annualizedRevenue < Formulas.ipoMinAnnualRevenue {
            return "IPO needs \(Format.count(Formulas.ipoMinSubscribers)) subscribers and \(Format.money(Formulas.ipoMinAnnualRevenue)) annual revenue."
        }
        return nil
    }

    /// Whether any outside money could still be raised (affects the bankruptcy rule).
    var fundingAvailable: Bool { creditRoom >= 250_000 || roundBlocker == nil || ipoBlocker == nil }

    mutating func takeLoan(amount: Double, termWeeks: Int) throws {
        guard outcome == .playing else { throw ActionError.gameOver }
        guard amount >= 250_000, [52, 104, 208].contains(termWeeks) else { throw ActionError.invalidAmount }
        guard amount <= creditRoom else {
            throw ActionError.locked("Lenders will only extend \(Format.money(creditRoom)) more right now.")
        }
        let rate = loanRate
        loans.append(Loan(id: takeID(), principal: amount, balance: amount, annualRate: rate,
                          weeklyPrincipal: amount / Double(termWeeks)))
        finances.cash += amount
        addNews(.you, "\(companyName) borrows \(Format.money(amount))", "A \(termWeeks / 52)-year loan at \(Format.percent(rate)) interest.")
    }

    mutating func repayLoan(id: Int, amount: Double) throws {
        guard let index = loans.firstIndex(where: { $0.id == id }) else { throw ActionError.invalidAmount }
        let pay = min(amount, loans[index].balance)
        guard pay > 0 else { throw ActionError.invalidAmount }
        guard finances.cash >= pay else { throw ActionError.insufficientFunds(needed: pay) }
        finances.cash -= pay
        loans[index].balance -= pay
        if loans[index].balance <= 0.01 { loans.remove(at: index) }
    }

    /// Sell `percent` (5%...25%) of the company to investors at the current valuation.
    mutating func raiseRound(percent: Double) throws {
        guard outcome == .playing else { throw ActionError.gameOver }
        if let reason = roundBlocker { throw ActionError.locked(reason) }
        guard (0.05...0.25).contains(percent) else { throw ActionError.invalidAmount }
        guard equity.ownership * (1 - percent) >= Formulas.minOwnership else {
            throw ActionError.locked("That would take you below \(Format.percent(Formulas.minOwnership)) ownership.")
        }
        finances.cash += valuation * percent
        equity.ownership *= (1 - percent)
        equity.roundsRaised += 1
        equity.lastRoundWeek = week
        addNews(.you, "\(companyName) raises \(Format.money(valuation * percent)) from investors",
                "\(Format.percent(percent)) of the company sold at a \(Format.money(valuation)) valuation. Founders now own \(Format.percent(equity.ownership)).")
    }

    mutating func launchIPO() throws {
        guard outcome == .playing else { throw ActionError.gameOver }
        if let reason = ipoBlocker { throw ActionError.locked(reason) }
        let sold = 0.15
        finances.cash += valuation * 1.4 * sold
        equity.ownership *= (1 - sold)
        equity.ipoDone = true
        addNews(.you, "\(companyName) goes public", "A \(Format.money(valuation * 1.4)) IPO raises \(Format.money(valuation * 1.4 * sold)) for 15% of the company.")
    }
}
