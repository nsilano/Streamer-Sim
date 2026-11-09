import Foundation

extension GameState {
    /// Owned licenses that can be renewed now, soonest first.
    var expiringTitles: [Title] {
        catalog.filter { $0.license != nil && ($0.weeksRemaining ?? .max) <= Formulas.renewalWindowWeeks }
            .sorted { ($0.weeksRemaining ?? 0) != ($1.weeksRemaining ?? 0) ? ($0.weeksRemaining ?? 0) < ($1.weeksRemaining ?? 0) : $0.id < $1.id }
    }

    /// What it costs to extend this license by `years` (1...5).
    func renewalPrice(_ title: Title, years: Int) -> Double {
        guard let license = title.license else { return 0 }
        let paid = title.paidPrice > 0 ? title.paidPrice : licensePrice(title)
        let perYear = paid / Double(max(1, license.years))
        return Formulas.renewalPrice(perYearPaid: perYear, years: years,
                                     popularityGain: title.popularity - title.popularityAtPurchase, sought: title.sought)
    }

    /// True if the title is now more popular than when you signed it.
    func hasPopularityJump(_ title: Title) -> Bool { title.popularity - title.popularityAtPurchase >= 10 }

    mutating func renewLicense(titleID: Int, years: Int) throws {
        guard outcome == .playing else { throw ActionError.gameOver }
        guard let index = catalog.firstIndex(where: { $0.id == titleID }), catalog[index].license != nil else {
            throw ActionError.titleNotFound
        }
        guard (1...5).contains(years) else { throw ActionError.invalidProject("Pick a term of 1 to 5 years.") }
        let left = catalog[index].weeksRemaining ?? .max
        guard left <= Formulas.renewalWindowWeeks else {
            throw ActionError.invalidProject("You can renew within \(Formulas.renewalWindowWeeks) weeks of the end of the license.")
        }
        let price = renewalPrice(catalog[index], years: years)
        guard finances.cash >= price else { throw ActionError.insufficientFunds(needed: price) }
        finances.cash -= price
        finances.ledger.licensing += price
        catalog[index].weeksRemaining = left + years * 52
        catalog[index].license?.years = years
        catalog[index].paidPrice = price
        catalog[index].invested += price
        catalog[index].popularityAtPurchase = catalog[index].popularity
        addNews(.you, "\(companyName) renews \"\(catalog[index].name)\"",
                "Kept for \(years) more year\(years == 1 ? "" : "s") at \(Format.money(price)).")
    }

    /// The licensing manager renews expiring titles that still pass the quality bar and fit the price and budget.
    /// Returns the names renewed, the money spent and how many were skipped.
    mutating func curatorRenew(_ c: Curator, allowance: Double) -> (names: [String], spent: Double, skipped: Int) {
        var names: [String] = []
        var spent = 0.0
        var skipped = 0
        for title in expiringTitles where (title.weeksRemaining ?? 99) <= 8 {
            guard title.quality >= c.minQuality else { continue }
            let price = renewalPrice(title, years: c.renewYears)
            if price > c.renewMaxPrice || spent + price > allowance || finances.cash - price < c.cashReserve { skipped += 1; continue }
            if (try? renewLicense(titleID: title.id, years: c.renewYears)) != nil {
                spent += price
                names.append(title.name)
            }
        }
        return (names, spent, skipped)
    }
}
