import Foundation

/// Originals, localization and funding decisions.
extension GameState {
    // MARK: Originals

    mutating func commissionOriginal(kind: TitleKind, genre: Genre, language: Language,
                                     budget: Double, weeks: Int) throws {
        guard outcome == .playing else { throw ActionError.gameOver }
        guard projects.count < Formulas.maxConcurrentProjects else {
            throw ActionError.invalidProject("You can run at most \(Formulas.maxConcurrentProjects) productions at once.")
        }
        guard Formulas.budgetRange(kind).contains(budget) else {
            throw ActionError.invalidProject("Budget for a \(kind.displayName.lowercased()) must be \(Format.money(Formulas.budgetRange(kind).lowerBound))-\(Format.money(Formulas.budgetRange(kind).upperBound)).")
        }
        guard Formulas.productionWeeksRange.contains(weeks) else {
            throw ActionError.invalidProject("Production takes 6 to 52 weeks.")
        }
        let weekly = budget / Double(weeks)
        guard finances.cash >= weekly * 4 else { throw ActionError.insufficientFunds(needed: weekly * 4) }
        let id = takeID()
        let name = TitleGenerator.makeName(genre: genre, rng: &rng)
        projects.append(OriginalProject(id: id, name: name, kind: kind, genre: genre, language: language,
                                        budget: budget, weeksTotal: weeks, weeksLeft: weeks, weeklyCost: weekly))
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
        let cost = dub ? Formulas.dubCost(title.kind) : Formulas.subtitleCost(title.kind)
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
            * Formulas.valuationBoost(financeLevel: staff.finance)
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
    }

    mutating func launchIPO() throws {
        guard outcome == .playing else { throw ActionError.gameOver }
        if let reason = ipoBlocker { throw ActionError.locked(reason) }
        let sold = 0.15
        finances.cash += valuation * 1.4 * sold
        equity.ownership *= (1 - sold)
        equity.ipoDone = true
    }
}
