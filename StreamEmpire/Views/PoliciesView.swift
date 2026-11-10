import SwiftUI

struct PolicyRef: Identifiable, Equatable {
    let id: String
}

/// Every rule of your service: sharing, trials, ads, privacy and more, with reactions good and bad.
struct PoliciesView: View {
    @EnvironmentObject var store: GameStore
    @State private var sheet: PolicyRef?

    var body: some View {
        ScrollView {
            if let state = store.state {
                VStack(alignment: .leading, spacing: 14) {
                    meters(state)
                    summary(state)
                    ForEach(PolicyCategory.allCases) { category in
                        VStack(alignment: .leading, spacing: 8) {
                            SectionTitle(text: category.displayName, icon: category.icon, tint: Theme.violet)
                            ForEach(PolicyData.all.filter { $0.category == category }) { definition in
                                Button { sheet = PolicyRef(id: definition.id) } label: { card(definition, state) }
                                    .buttonStyle(.plain)
                            }
                        }
                    }
                    log(state)
                }
                .padding(16)
            }
        }
        .artScreen()
        .navigationTitle("Policies")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $sheet) { ref in PolicySheet(policyID: ref.id) }
    }

    // MARK: Pieces

    private func meters(_ state: GameState) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(text: "Your reputation", icon: "heart.text.square.fill", tint: Theme.magenta)
            StatBar(label: "Brand trust", value: state.brandTrust / 100, text: "\(Int(state.brandTrust))/100",
                    tint: state.brandTrust >= 60 ? Theme.good : (state.brandTrust >= 35 ? Theme.amber : Theme.danger))
            Text("Trusted brands win more sign-ups, lose fewer subscribers and get the benefit of the doubt when a policy is unpopular.")
                .font(.caption2).foregroundStyle(Theme.text2)
            StatBar(label: "Regulatory heat", value: state.regulatoryHeat / 100, text: "\(Int(state.regulatoryHeat))/100",
                    tint: state.regulatoryHeat < 25 ? Theme.good : (state.regulatoryHeat < 55 ? Theme.amber : Theme.danger))
            Text("Dark patterns, data selling and edgy content attract regulators: bigger fines and more investigations.")
                .font(.caption2).foregroundStyle(Theme.text2)
        }
        .artCard(tint: Theme.magenta)
    }

    @ViewBuilder
    private func summary(_ state: GameState) -> some View {
        let lines = state.policySummary()
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(text: "What your policies do overall", icon: "chart.bar.doc.horizontal.fill", tint: Theme.teal)
            if lines.isEmpty {
                Text("Everything is on default settings. Change a policy below to reshape how your service works.")
                    .font(.footnote).foregroundStyle(Theme.text2)
            }
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                let good = isGood(line.label, line.percent)
                LabeledValue(label: line.label, value: "\(line.percent >= 0 ? "+" : "")\(String(format: "%.0f", line.percent * 100))%",
                             tint: good ? Theme.good : Theme.danger)
            }
        }
        .artCard(tint: Theme.teal)
    }

    /// Whether an increase in this measure is good news.
    private func isGood(_ label: String, _ percent: Double) -> Bool {
        let higherIsBetter = ["New subscribers", "Revenue per subscriber", "Ad revenue"].contains(label)
        return higherIsBetter ? percent >= 0 : percent <= 0
    }

    private func card(_ definition: PolicyDefinition, _ state: GameState) -> some View {
        let option = state.activeOption(definition)
        let wait = state.weeksUntilPolicyCanChange(definition.id)
        return HStack(spacing: 12) {
            Image(systemName: definition.icon).font(.title3).foregroundStyle(Theme.violet).frame(width: 32)
            VStack(alignment: .leading, spacing: 3) {
                Text(definition.title).font(.subheadline.weight(.bold)).foregroundStyle(.white)
                Text(definition.summary).font(.caption).foregroundStyle(Theme.text2).lineLimit(2)
                HStack(spacing: 6) {
                    Pill(text: option.title, tint: option.id == definition.defaultOption ? Theme.text2 : Theme.magenta)
                    if wait > 0 { Pill(text: "Locked \(wait) wk", tint: Theme.amber, icon: "lock.fill") }
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").foregroundStyle(Theme.text2)
        }
        .artCard(tint: option.id == definition.defaultOption ? Theme.violet.opacity(0.5) : Theme.magenta)
    }

    @ViewBuilder
    private func log(_ state: GameState) -> some View {
        if !state.policyLog.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle(text: "How the world reacted", icon: "bubble.left.and.bubble.right.fill", tint: Theme.amber)
                ForEach(state.policyLog.prefix(10)) { reaction in
                    ReactionRow(reaction: reaction)
                }
            }
            .artCard(tint: Theme.amber)
        }
    }
}

struct ReactionRow: View {
    let reaction: PolicyReaction

    private var tint: Color {
        switch reaction.tone {
        case .good: return Theme.good
        case .mixed: return Theme.amber
        case .bad: return Theme.danger
        }
    }

    private var icon: String {
        switch reaction.tone {
        case .good: return "hand.thumbsup.fill"
        case .mixed: return "equal.circle.fill"
        case .bad: return "hand.thumbsdown.fill"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).foregroundStyle(tint).frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(reaction.headline).font(.subheadline.weight(.bold)).foregroundStyle(.white)
                Text(reaction.detail).font(.caption).foregroundStyle(Theme.text2)
                HStack(spacing: 6) {
                    Text("\(Format.stamp(week: reaction.week)) · \(reaction.policyTitle): \(reaction.optionTitle)")
                        .font(.caption2).foregroundStyle(Theme.text2)
                    if abs(reaction.subscribersChange) >= 1 {
                        Pill(text: "\(reaction.subscribersChange >= 0 ? "+" : "-")\(Format.count(abs(reaction.subscribersChange))) subs", tint: tint)
                    }
                }
            }
        }
    }
}

/// Pick an option for one policy, with pros, cons and the risk of a bad reaction.
struct PolicySheet: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.dismiss) private var dismiss
    let policyID: String
    @State private var reaction: PolicyReaction?

    var body: some View {
        NavigationStack {
            ScrollView {
                if let state = store.state, let definition = PolicyData.definition(policyID) {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 12) {
                            Image(systemName: definition.icon).font(.largeTitle).foregroundStyle(Theme.magenta)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(definition.title).font(Theme.display(26)).foregroundStyle(.white)
                                Text(definition.summary).font(.footnote).foregroundStyle(Theme.text2)
                            }
                        }
                        if let reaction {
                            VStack(alignment: .leading, spacing: 6) {
                                SectionTitle(text: "Reaction", icon: "sparkles", tint: Theme.amber)
                                ReactionRow(reaction: reaction)
                            }
                            .artCard(tint: Theme.amber)
                        }
                        ForEach(definition.options) { option in
                            optionCard(definition, option, state)
                        }
                    }
                    .padding(16)
                }
            }
            .artScreen()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Done") { dismiss() } }
        }
    }

    private func risk(_ option: PolicyOption, _ state: GameState) -> (String, Color)? {
        guard option.bad != nil else { return nil }
        let chance = Formulas.clamp(option.badChance * (1.3 - state.brandTrust * 0.006), 0, 0.95)
        if chance >= 0.4 { return ("Backlash risk: high", Theme.danger) }
        if chance >= 0.2 { return ("Backlash risk: medium", Theme.amber) }
        if chance > 0 { return ("Backlash risk: low", Theme.good) }
        return nil
    }

    private func optionCard(_ definition: PolicyDefinition, _ option: PolicyOption, _ state: GameState) -> some View {
        let isCurrent = state.policyOptionID(definition.id) == option.id
        let blocker = state.policyBlocker(definition, option)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(option.title).font(.headline).foregroundStyle(.white)
                Spacer()
                if isCurrent { Pill(text: "Current", tint: Theme.good, icon: "checkmark") }
            }
            Text(option.detail).font(.caption).foregroundStyle(Theme.text2)
            ForEach(option.pros, id: \.self) { pro in
                Label(pro, systemImage: "plus.circle.fill").font(.caption).foregroundStyle(Theme.good)
            }
            ForEach(option.cons, id: \.self) { con in
                Label(con, systemImage: "minus.circle.fill").font(.caption).foregroundStyle(Theme.danger)
            }
            HStack(spacing: 6) {
                if let (text, color) = risk(option, state) { Pill(text: text, tint: color, icon: "exclamationmark.triangle.fill") }
                if option.cost > 0 { Pill(text: "Setup \(Format.money(state.policyPrice(option)))", tint: Theme.amber) }
                if option.minSubscribers > 0 { Pill(text: "Needs \(Format.count(option.minSubscribers)) subs", tint: Theme.violet) }
            }
            if !isCurrent {
                Button("Enact this policy") {
                    store.perform { _ = try $0.setPolicy(definition.id, option: option.id) }
                    reaction = store.state?.policyLog.first
                }
                .buttonStyle(GlowButtonStyle(tint: Theme.magenta))
                .disabled(blocker != nil)
                if let blocker { Text(blocker).font(.caption2).foregroundStyle(Theme.amber) }
            }
        }
        .artCard(tint: isCurrent ? Theme.good : Theme.violet)
    }
}
