import SwiftUI

struct ContentTabView: View {
    enum Section: String, CaseIterable, Identifiable {
        case catalog = "Catalog", licensing = "Licensing", originals = "Originals"
        var id: String { rawValue }
    }

    @EnvironmentObject var store: GameStore
    @State private var section: Section = .licensing
    @State private var localizing: Int?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Section", selection: $section) {
                    ForEach(Section.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding()

                if let state = store.state {
                    switch section {
                    case .catalog: catalogList(state)
                    case .licensing: licensingList(state)
                    case .originals: OriginalsView(state: state)
                    }
                }
            }
            .navigationTitle("Content")
        }
    }

    @ViewBuilder
    private func catalogList(_ state: GameState) -> some View {
        if state.catalog.isEmpty {
            ContentUnavailableView("Empty catalog", systemImage: "film",
                                   description: Text("License titles from the Licensing tab."))
        } else {
            List(state.catalog.sorted { $0.quality > $1.quality }) { title in
                Button {
                    localizing = title.id
                } label: {
                    TitleRow(title: title, trailing: title.weeksRemaining.map { "\($0) wks left" } ?? "Owned")
                }
                .buttonStyle(.plain)
            }
            .sheet(item: Binding(get: { localizing.map(LocalizeTarget.init) }, set: { localizing = $0?.id })) {
                LocalizeView(titleID: $0.id)
            }
        }
    }

    private func licensingList(_ state: GameState) -> some View {
        List(state.licenseMarket) { title in
            VStack(alignment: .leading, spacing: 6) {
                TitleRow(title: title, trailing: "Offer: \(title.listingWeeksLeft) wks")
                if let license = title.license {
                    HStack {
                        Text("\(license.years) yr\(license.years == 1 ? "" : "s")\(license.exclusive ? " · Exclusive" : "")")
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button(Format.money(license.cost)) {
                            store.perform { try $0.buyLicense(titleID: title.id) }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(state.finances.cash < license.cost)
                    }
                }
            }
        }
    }
}

struct TitleRow: View {
    let title: Title
    let trailing: String

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title.name).font(.headline)
                Text("\(title.kind.displayName) · \(title.genre.displayName) · \(title.language.displayName)")
                    .font(.caption).foregroundStyle(.secondary)
                Text("Quality \(title.quality) · Popularity \(title.popularity) · \(ageText)")
                    .font(.caption2).foregroundStyle(.secondary)
                if !title.subtitles.isEmpty || !title.dubs.isEmpty {
                    Text(localizationText).font(.caption2).foregroundStyle(.tint)
                }
            }
            Spacer()
            Text(trailing).font(.caption).foregroundStyle(.secondary)
        }
    }

    private var localizationText: String {
        var parts: [String] = []
        if !title.dubs.isEmpty { parts.append("Dub: " + title.dubs.map(\.displayName).joined(separator: ", ")) }
        if !title.subtitles.isEmpty { parts.append("Subs: " + title.subtitles.map(\.displayName).joined(separator: ", ")) }
        return parts.joined(separator: " · ")
    }

    private var ageText: String {
        title.ageWeeks < 4 ? "New release" : title.ageWeeks < 52 ? "\(title.ageWeeks) wks old" : "\(title.ageWeeks / 52) yr old"
    }
}

struct LocalizeTarget: Identifiable { let id: Int }
