import SwiftUI

/// The in-game news platform: what rivals (and the industry) are doing.
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
            case .you: return item.kind == .you || (item.rivalID == nil && item.kind != .industry)
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

    private func card(_ item: NewsItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            if let id = item.rivalID, let rival = state.rivals.first(where: { $0.id == id }) {
                RivalBadge(name: rival.name, id: rival.id, size: 40)
            } else {
                ZStack {
                    Circle().fill(tint(item.kind).opacity(0.25))
                    Image(systemName: item.kind.icon).foregroundStyle(tint(item.kind))
                }
                .frame(width: 40, height: 40)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(item.headline).font(.subheadline.weight(.bold)).foregroundStyle(.white)
                Text(item.body).font(.caption).foregroundStyle(Theme.text2)
                HStack(spacing: 6) {
                    Pill(text: item.kind.displayName, tint: tint(item.kind))
                    Text("Week \(item.week)").font(.caption2).foregroundStyle(Theme.text2)
                    if item.id > state.newsSeenThrough { Pill(text: "NEW", tint: Theme.magenta) }
                }
            }
            Spacer(minLength: 0)
        }
        .artCard(tint: tint(item.kind))
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
