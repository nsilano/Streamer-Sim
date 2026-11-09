import SwiftUI

struct NewGameView: View {
    @EnvironmentObject var store: GameStore
    @State private var companyName = ""
    @State private var selected = "IE"

    var body: some View {
        NavigationStack {
            Form {
                Section("Your company") {
                    TextField("Company name", text: $companyName)
                }
                Section("Starting country") {
                    ForEach(CountryData.starters) { country in
                        Button {
                            selected = country.code
                        } label: {
                            HStack {
                                Text(country.flag).font(.largeTitle)
                                VStack(alignment: .leading) {
                                    Text(country.name).foregroundStyle(.primary)
                                    Text("\(country.region.displayName) · \(country.households, specifier: "%.1f")M broadband households · \(country.language.displayName)")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if selected == country.code {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.tint)
                                }
                            }
                        }
                    }
                }
                Section {
                    Text("You start with \(Format.money(GameState.startingCash)) and an empty catalog. License shows, win subscribers, and take on the world.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Button("Found Company") {
                        store.newGame(companyName: companyName, country: selected)
                    }
                    .bold()
                }
            }
            .navigationTitle("Stream Empire")
        }
    }
}
