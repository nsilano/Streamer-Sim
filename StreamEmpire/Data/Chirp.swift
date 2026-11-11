import Foundation

/// The in-game social feed ("Chirp", a parody microblog). Every news story becomes a post, with an author,
/// hashtags, engagement numbers and, for stories about you, a reply from a fan or a critic that follows your
/// reputation. Everything is derived from the story and the game state, so the feed is stable between renders.
struct Chirp: Identifiable, Equatable {
    struct Reply: Equatable {
        var name: String
        var handle: String
        var text: String
        var positive: Bool
    }

    var id: Int
    var name: String
    var handle: String
    var verified: Bool
    var text: String
    var detail: String
    var hashtags: String
    var likes: Int
    var reposts: Int
    var replies: Int
    var week: Int
    var mine: Bool
    var kind: NewsKind
    var rivalID: String?
    var authorRivalID: String?      // set only when the rival itself is the one posting
    var reply: Reply?

    // MARK: Building posts

    private static func mix(_ a: Int, _ salt: Int) -> Int {
        var x = UInt64(truncatingIfNeeded: a) &* 0x9E3779B97F4A7C15 &+ UInt64(truncatingIfNeeded: salt) &* 0xBF58476D1CE4E5B9
        x ^= x >> 31
        x = x &* 0x94D049BB133111EB
        x ^= x >> 29
        return Int(truncatingIfNeeded: x >> 2) & 0x3fffffff
    }

    private static func handle(_ name: String) -> String {
        "@" + name.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    private static let fans: [(String, String)] = [
        ("Maya", "@maya_watches"), ("Dev", "@devbingeslate"), ("Priya", "@priyaplays"), ("Tom", "@tomonthecouch"),
        ("Lena", "@lena_streams"), ("Carlos", "@carlosrewinds"), ("Aiko", "@aiko_tv"), ("Sam", "@sam_snacks"),
    ].map { ($0.0, $0.1.replacingOccurrences(of: " ", with: "")) }

    private static let happy = [
        "Honestly love this. Best service on my phone right now.", "Finally. Take my money.", "This is why I'm staying subscribed.",
        "Okay that's actually a great move.", "My whole family is watching this tonight.", "Doing it right. More of this please.",
    ]
    private static let angry = [
        "Cancelling. Unbelievable.", "Every month it's something new to be annoyed about.", "Prices up, trust down. Great job.",
        "This is how you lose customers.", "Switching to a rival this week, bye.", "Nobody asked for this.",
    ]

    static func make(_ item: NewsItem, state: GameState) -> Chirp {
        let you = item.kind == .you || item.headline.contains(state.companyName) || item.body.contains(state.companyName)
        var name: String
        var verified = true
        var scale: Double
        // A rival only posts about its own news (launches, milestones, prices, deals). Stories where it is losing
        // customers or being criticised come from third parties.
        let h = item.headline
        let thirdParty = h.contains("switch from") || h.contains(" leave ") || h.hasPrefix("Shareholders reject")
        var authorRival: String?
        if let id = item.rivalID, !thirdParty, let rival = state.rivals.first(where: { $0.id == id }) {
            name = rival.name
            scale = max(1, rival.totalSubs / 4_000)
            authorRival = id
        } else if thirdParty {
            name = h.hasPrefix("Shareholders") ? "Wall Street Stream" : "Viewer Watch"
            scale = max(1, 20_000 + state.totalSubscribers / 400)
        } else if item.kind == .you {
            name = state.companyName
            scale = max(1, state.totalSubscribers / 150)
        } else {
            switch item.kind {
            case .pricing: name = "Deal Watch"
            case .licensing: name = "Rights Report"
            case .ranking: name = "StreamRank"
            case .profit, .subscribers: name = "Wall Street Stream"
            case .expansion: name = "Global Streaming"
            default: name = "Streaming Insider"
            }
            scale = max(1, 20_000 + state.totalSubscribers / 400)
        }
        if item.kind == .industry { verified = true }
        let r = Double(mix(item.id, 1) % 1000) / 1000
        let likes = Int(scale * (0.25 + 1.6 * r)) + 3
        let reposts = Int(Double(likes) * (0.12 + 0.2 * Double(mix(item.id, 2) % 100) / 100))
        let replies = Int(Double(likes) * (0.04 + 0.08 * Double(mix(item.id, 3) % 100) / 100))

        let tags: String
        switch item.kind {
        case .expansion: tags = "#Expansion #GoGlobal"
        case .subscribers: tags = "#Subscribers #Milestone"
        case .profit: tags = "#Earnings #Streaming"
        case .pricing: tags = "#Pricing #StreamingWars"
        case .licensing: tags = "#Licensing #Catalog"
        case .ranking: tags = "#Rankings #NumberOne"
        case .industry: tags = "#StreamingNews"
        case .you: tags = "#\(state.companyName.filter { $0.isLetter || $0.isNumber })"
        }

        var reply: Reply?
        if you, mix(item.id, 4) % 100 < 70 {
            let fan = fans[mix(item.id, 5) % fans.count]
            // Reputation decides who shows up: a trusted company draws fans, a distrusted one draws critics.
            let positiveChance = max(0.1, min(0.9, state.brandTrust / 100))
            let positive = Double(mix(item.id, 6) % 1000) / 1000 < positiveChance
            let pool = positive ? happy : angry
            reply = Reply(name: fan.0, handle: fan.1, text: pool[mix(item.id, 7) % pool.count], positive: positive)
        }

        return Chirp(id: item.id, name: name, handle: handle(name), verified: verified, text: item.headline, detail: item.body,
                     hashtags: tags, likes: likes, reposts: reposts, replies: replies, week: item.week, mine: you,
                     kind: item.kind, rivalID: item.rivalID, authorRivalID: authorRival, reply: reply)
    }
}
