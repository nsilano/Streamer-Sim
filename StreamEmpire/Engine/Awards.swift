import Foundation

/// Yearly awards for originals, plus the cut paid to stars.
enum Awards {
    static let week = 44          // the season is held on this week of every year

    static func season(_ s: inout GameState, events: inout [GameEvent]) {
        let contenders = s.catalog.filter { $0.isOriginal && $0.ageWeeks <= 104 }
            .sorted { score($0) != score($1) ? score($0) > score($1) : $0.id < $1.id }
            .prefix(3)
        for contender in contenders {
            guard let index = s.catalog.firstIndex(where: { $0.id == contender.id }) else { continue }
            let chance = min(0.8, Double(contender.quality) / 100 * 0.7
                             + ([.drama, .docs].contains(contender.genre) ? 0.1 : 0))
            guard s.rng.chance(chance) else { continue }
            s.catalog[index].awards += 1
            s.catalog[index].popularity = min(100, s.catalog[index].popularity + 8)
            s.brandTrust = min(100, s.brandTrust + 4)
            let name = s.catalog[index].name
            s.addNews(.you, "\"\(name)\" wins big at awards season", "Critics' darling. Popularity and brand trust both rise.")
            events.append(s.makeEvent(.news, "Award for \"\(name)\"", "It took home a top prize. Popularity +8, brand trust +4."))
        }
    }

    static func score(_ t: Title) -> Int { t.quality * 2 + t.popularity }
}

extension GameState {
    /// Weekly cut owed to stars on titles that are currently earning.
    func talentShares() -> Double {
        var total = 0.0
        for title in catalog where title.star.profitShare > 0 {
            total += (titleStats[title.id]?.weeklyRevenue ?? 0) * title.star.profitShare
        }
        return total
    }
}
