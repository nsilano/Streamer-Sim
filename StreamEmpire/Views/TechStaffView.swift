import SwiftUI

/// Platforms, CDN infrastructure and staff departments.
struct TechStaffView: View {
    @EnvironmentObject var store: GameStore

    var body: some View {
        List {
            if let state = store.state {
                platformSection(state)
                cdnSection(state)
                staffSection(state)
                studioPaySection
            }
        }
        .navigationTitle("Tech & staff")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func platformSection(_ state: GameState) -> some View {
        Section {
            LabeledValue(label: "Reach", value: Format.percent(state.platformReach))
            ForEach(Platform.allCases) { platform in
                HStack {
                    VStack(alignment: .leading) {
                        Text(platform.displayName)
                        Text(platformDetail(platform, state)).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if state.platforms.contains(platform) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    } else if let build = state.builds.first(where: { $0.platform == platform }) {
                        Text("\(build.weeksLeft) wks").foregroundStyle(.secondary)
                    } else {
                        Button(Format.money(platform.unlockCost)) {
                            store.perform { try $0.startPlatform(platform) }
                        }
                        .buttonStyle(.bordered)
                        .disabled(state.finances.cash < platform.unlockCost)
                    }
                }
            }
        } header: {
            Text("Platforms")
        } footer: {
            Text("Each platform you ship on raises reach, which boosts sign-ups everywhere.")
        }
    }

    private func platformDetail(_ platform: Platform, _ state: GameState) -> String {
        if platform == .web { return "Included" }
        let weeks = Formulas.buildWeeks(base: platform.buildWeeks, engineeringLevel: state.staff.effectiveLevel(.engineering))
        return "+\(Int(platform.reachBonus * 100)) pts reach · \(weeks) wk build · \(Format.money(platform.weeklyUpkeep))/wk"
    }

    private func cdnSection(_ state: GameState) -> some View {
        Section {
            ForEach(Region.allCases) { region in
                let subs = state.subscribers(in: region)
                if subs > 0 || (state.cdnSteps[region.rawValue] ?? 0) > 0 {
                    let load = state.cdnLoad(region)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(region.displayName)
                            Spacer()
                            Text("\(Format.count(subs)) / \(Format.count(state.cdnCapacity(region)))")
                                .monospacedDigit().foregroundStyle(load > 1 ? .red : .secondary)
                        }
                        ProgressView(value: min(load, 1.5), total: 1.5)
                            .tint(load > 1 ? .red : load > 0.8 ? .orange : .green)
                        HStack {
                            Text(load > 1 ? "Buffering! Service quality \(Format.percent(Formulas.serviceQuality(load: load)))"
                                          : "Load \(Format.percent(load))")
                                .font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Button("+\(Format.count(Formulas.cdnStepCapacity)) for \(Format.money(state.cdnStepPrice))") {
                                store.perform { try $0.expandCDN(region: region) }
                            }
                            .font(.caption)
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
            LabeledValue(label: "Weekly platform + CDN cost", value: Format.money(state.weeklyTechCost))
        } header: {
            Text("Infrastructure (CDN capacity)")
        } footer: {
            Text("Going over capacity causes buffering and outages: slower sign-ups and more churn. Regions appear once you have subscribers there.")
        }
    }

    private func staffSection(_ state: GameState) -> some View {
        Section {
            ForEach(Department.allCases) { department in
                let level = state.staff[department]
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(department.displayName).font(.headline)
                        Spacer()
                        Text("Level \(level)/\(Formulas.maxDepartmentLevel)").foregroundStyle(.secondary)
                    }
                    Text(department.effectText).font(.caption).foregroundStyle(.secondary)
                    payRow(label: "Pay", value: state.staff.payScale(department)) { newValue in
                        store.perform { try $0.setPay(department, scale: newValue) }
                    }
                    HStack {
                        Button("Hire (\(Format.money(Formulas.hireCost(currentLevel: level))))") {
                            store.perform { try $0.hire(department) }
                        }
                        .buttonStyle(.bordered)
                        .disabled(level >= Formulas.maxDepartmentLevel
                                  || state.finances.cash < Formulas.hireCost(currentLevel: level))
                        Spacer()
                        Button("Cut", role: .destructive) {
                            store.perform { try $0.reduceStaff(department) }
                        }
                        .buttonStyle(.bordered)
                        .disabled(level == 0)
                    }
                }
            }
            LabeledValue(label: "Weekly salaries", value: Format.money(state.weeklySalaries))
        } header: {
            Text("Staff")
        } footer: {
            Text("Each level costs \(Format.money(Formulas.salaryPerLevelPerWeek)) a week at market pay, plus a one-time hiring fee. Pay above market makes a team more effective; below 90% staff start quitting.")
        }
    }

    private var studioPaySection: some View {
        Section {
            if let state = store.state {
                payRow(label: "Studio crew pay", value: state.staff.studioPay) { newValue in
                    store.perform { try $0.setStudioPay(scale: newValue) }
                }
                LabeledValue(label: "Studio upkeep", value: Format.money(state.weeklyStudioCost) + "/wk")
            }
        } header: {
            Text("Studio crews")
        } footer: {
            Text("Better-paid crews raise in-house quality. Underpaid crews lose experience every week.")
        }
    }

    private func payRow(label: String, value: Double, set: @escaping (Double) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Stepper(value: Binding(get: { value }, set: { set($0) }), in: Formulas.payRange, step: 0.1) {
                LabeledValue(label: label, value: Format.percent(value) + " of market")
            }
            let effect = Formulas.payEffectiveness(value)
            Text("Effectiveness \(Format.percent(effect))" + (value < 0.9 ? " · staff may quit" : ""))
                .font(.caption2).foregroundStyle(value < 0.9 ? .orange : .secondary)
        }
    }
}
