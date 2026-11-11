import SwiftUI

/// The in-game social feed ("Chirp"): news stories laid out as posts.
struct NewsFeedView: View {
    enum Filter: String, CaseIterable, Identifiable {
        case all = "All", rivals = "Rivals", you = "You", prices = "Prices", industry = "Industry"
        var id: String { rawValue }
    }

    @EnvironmentObject var store: GameStore
    let state: GameState
    @State private var filter: Filter = .all

    private var items: [NewsItem] {
        state.news.filter { item in
            switch filter {
            case .all: return true
            case .rivals: return item.rivalID != nil
            case .you: return isAboutYou(item) || (item.rivalID == nil && item.kind != .industry)
            case .prices: return item.kind == .pricing
            case .industry: return item.kind == .industry
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Filter", selection: $filter) {
                ForEach(Filter.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            if items.isEmpty {
                Text("Nothing here yet. Play a few weeks and the stories will roll in.")
                    .font(.footnote).foregroundStyle(Theme.text2).frame(maxWidth: .infinity).artCard()
            }
            ForEach(items) { item in card(item) }
        }
        .onAppear { store.perform { $0.markNewsRead() } }
        .onChange(of: state.news.first?.id) { _, _ in store.perform { $0.markNewsRead() } }
    }

    /// Stories about your company: your own moves, or anything that names you.
    private func isAboutYou(_ item: NewsItem) -> Bool {
        item.kind == .you || item.headline.contains(state.companyName) || item.body.contains(state.companyName)
    }

    private func card(_ item: NewsItem) -> some View {
        let post = Chirp.make(item, state: state)
        let mine = post.mine
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                avatar(item, post)
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 4) {
                        Text(post.name).font(.subheadline.weight(.bold)).foregroundStyle(.white).lineLimit(1)
                        if post.verified { Image(systemName: "checkmark.seal.fill").font(.caption).foregroundStyle(Theme.teal) }
                        Text("\(post.handle) · \(Format.stamp(week: post.week))").font(.caption).foregroundStyle(Theme.text2).lineLimit(1)
                        Spacer(minLength: 0)
                        if item.id > state.newsSeenThrough { Circle().fill(Theme.magenta).frame(width: 8, height: 8) }
                    }
                    Text(post.text).font(.subheadline).foregroundStyle(.white)
                    Text(post.detail).font(.caption).foregroundStyle(Theme.text2)
                    Text(post.hashtags).font(.caption).foregroundStyle(Theme.teal)
                    HStack(spacing: 18) {
                        stat("bubble.left", post.replies)
                        stat("arrow.2.squarepath", post.reposts)
                        stat("heart", post.likes)
                        if mine { Pill(text: "YOU", tint: Theme.magenta) }
                    }
                    .padding(.top, 2)
                }
            }
            if let reply = post.reply {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: reply.positive ? "face.smiling" : "face.dashed")
                        .foregroundStyle(reply.positive ? Theme.good : Theme.danger).frame(width: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(reply.name) \(reply.handle)").font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.85))
                        Text(reply.text).font(.caption).foregroundStyle(Theme.text2)
                    }
                }
            }
        }
        .artCard(tint: mine ? Theme.magenta : tint(item.kind))
        .background(RoundedRectangle(cornerRadius: 18).fill(mine ? Theme.magenta.opacity(0.18) : Color.clear))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(mine ? Theme.magenta : Color.clear, lineWidth: 1.5))
    }

    @ViewBuilder
    private func avatar(_ item: NewsItem, _ post: Chirp) -> some View {
        if let id = item.rivalID, let rival = state.rivals.first(where: { $0.id == id }) {
            RivalBadge(name: rival.name, id: rival.id, size: 40)
        } else {
            ZStack {
                Circle().fill(tint(item.kind).opacity(0.25))
                Image(systemName: item.kind.icon).foregroundStyle(tint(item.kind))
            }
            .frame(width: 40, height: 40)
        }
    }

    private func stat(_ icon: String, _ value: Int) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.caption2)
            Text(Format.count(Double(value))).font(.caption2)
        }
        .foregroundStyle(Theme.text2)
    }

    private func tint(_ kind: NewsKind) -> Color {
        switch kind {
        case .expansion: return Theme.teal
        case .subscribers: return Theme.violet
        case .profit: return Theme.good
        case .pricing: return Theme.amber
        case .licensing: return Theme.magenta
        case .ranking: return Theme.amber
        case .industry: return Theme.text2
        case .you: return Theme.magenta
        }
    }
}
