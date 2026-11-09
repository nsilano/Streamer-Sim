import SwiftUI

struct HowToPlayView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                tip("film.stack", "License content first",
                    "With an empty catalog nobody subscribes. Buy a handful of well-rated titles in the Content tab, ideally in your market's language.")
                tip("tag", "Price near the fair price",
                    "Each country has a fair Standard price. Far above it means slow sign-ups and high churn; far below it means thin margins.")
                tip("megaphone", "Marketing builds awareness",
                    "Awareness decays without spending. Pair it with a good catalog, since ads can't fix a weak lineup.")
                tip("globe", "Expand carefully",
                    "Each launch costs money and runs 4 weeks of setup. USA, India and Japan unlock with enough subscribers or titles.")
                tip("clapperboard", "Originals are a gamble",
                    "Bigger budgets and longer schedules raise quality, but hits are never guaranteed. You own them forever, worldwide.")
                tip("server.rack", "Watch your servers",
                    "Going over CDN capacity causes buffering and churn. Add capacity before a region fills up.")
                tip("banknote", "Mind your runway",
                    "Cash below zero for 8 weeks ends the game unless funding is still available. Loans, investors and an IPO can bail you out.")
                tip("trophy", "Win by being #1",
                    "Overtake every rival in global subscribers (from week 52). Bonus goals: IPO, $10B annual revenue, all 30 markets.")
            }
            .navigationTitle("How to play")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Done") { dismiss() } }
        }
    }

    private func tip(_ icon: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).font(.title3).frame(width: 30).foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(text).font(.footnote).foregroundStyle(.secondary)
            }
        }
    }
}
