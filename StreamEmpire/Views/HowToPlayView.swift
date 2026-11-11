import SwiftUI

struct HowToPlayView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    tip("film.stack", "License content first",
                        "With an empty catalog nobody subscribes. Buy well-rated titles in the Content tab. Check the Quality, Popularity and Fit bars, or hire a licensing manager to shop for you.")
                    tip("tag", "Price near the fair price",
                        "Every country has a fair monthly price. Far above it means slow sign-ups and high churn; far below it means thin margins.")
                    tip("rectangle.stack", "Add subscription plans",
                        "You start with a Standard plan. Launch Ad-supported (cheap, ad revenue) and Premium (pricey, superfans) per country from its page on the map.")
                    tip("megaphone.fill", "Run promotions",
                        "Need subscribers fast? Launch a limited-time discount, free trial or marketing blitz from the Dashboard. They cost money, and people who join on a deal leave faster later.")
                    tip("megaphone", "Marketing builds awareness",
                        "Awareness fades without spending. Pair it with a good catalog, because ads can't fix a weak lineup.")
                    tip("globe.europe.africa.fill", "Expand across the map",
                        "Tap any country on the world map. Launching costs money and takes about 4 months. USA, India and Japan unlock with enough subscribers or titles.")
                    tip("trophy.fill", "Rivals fight back",
                        "Twelve rivals bid for licenses, cut prices and expand. If you start dominating a country, they'll launch price wars and pull your subscribers away.")
                    tip("clapperboard", "Make your own shows",
                        "Originals are a gamble: bigger budgets raise quality, never guarantee a hit. Build studios to produce in-house for less.")
                    tip("server.rack", "Watch your servers",
                        "Too many viewers too fast makes servers lag, buffer and even crash, and you lose subscribers. Build datacenters ahead of growth; rent cloud in a pinch.")
                    tip("banknote", "Don't go bankrupt",
                        "Debt has a limit. Fall past your overdraft limit, or stay in the red for 8 weeks with no funding left, and it's game over. Loans, investors and an IPO can bail you out.")
                    tip("crown.fill", "Win by being #1",
                        "Overtake every rival in global subscribers (from week 52). Bonus goals: IPO, $10B annual revenue, all \(CountryData.all.count) markets.")
                }
                .padding(16)
            }
            .artScreen()
            .navigationTitle("How to play")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Done") { dismiss() } }
        }
    }

    private func tip(_ icon: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).font(.title3).frame(width: 30).foregroundStyle(Theme.magenta)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline).foregroundStyle(.white)
                Text(text).font(.footnote).foregroundStyle(Theme.text2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .artCard()
    }
}
