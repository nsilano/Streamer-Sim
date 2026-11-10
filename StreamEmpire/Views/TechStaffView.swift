import SwiftUI

/// Apps, datacenters and staff, explained in plain language.
struct TechStaffView: View {
    @EnvironmentObject var store: GameStore

    var body: some View {
        ScrollView {
            if let state = store.state {
                VStack(alignment: .leading, spacing: 14) {
                    nextStep(state)
                    platforms(state)
                    servers(state)
                    team(state)
                    studioCrews(state)
                }
                .padding(16)
            }
        }
        .artScreen()
        .navigationTitle("Tech, servers & team")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Advice

    @ViewBuilder
    private func nextStep(_ state: GameState) -> some View {
        let items = state.advice().filter { $0.id.hasPrefix("servers") || $0.id.hasPrefix("pay") || $0.id.hasPrefix("platform") }
        if let first = items.first {
            VStack(alignment: .leading, spacing: 6) {
                SectionTitle(text: "Your next best move", icon: "lightbulb.fill", tint: Theme.amber)
                AdviceBanner(advice: first)
            }
        }
    }

    // MARK: Apps

    private func platforms(_ state: GameState) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "Apps: where people can watch", icon: "iphone.gen3", tint: Theme.teal)
            Text("Every app you ship on lets more people find and use your service, which boosts sign-ups everywhere.")
                .font(.footnote).foregroundStyle(Theme.text2)
            StatBar(label: "Reach", value: state.platformReach, text: Format.percent(state.platformReach), tint: Theme.teal)
            ForEach(Platform.allCases) { platform in
                HStack(spacing: 12) {
                    Image(systemName: icon(platform)).font(.title3).foregroundStyle(Theme.teal).frame(width: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(platform.displayName).font(.subheadline.weight(.bold)).foregroundStyle(.white)
                        Text(detail(platform, state)).font(.caption).foregroundStyle(Theme.text2)
                    }
                    Spacer()
                    if state.platforms.contains(platform) {
                        Pill(text: "Live", tint: Theme.good, icon: "checkmark")
                    } else if let build = state.builds.first(where: { $0.platform == platform }) {
                        Pill(text: "\(build.weeksLeft) wks", tint: Theme.amber, icon: "hourglass")
                    } else {
                        Button(Format.money(state.platformPrice(platform))) { store.perform { try $0.startPlatform(platform) } }
                            .buttonStyle(SoftButtonStyle(tint: Theme.teal))
                            .disabled(state.finances.cash < state.platformPrice(platform))
                    }
                }
            }
        }
        .artCard(tint: Theme.teal)
    }

    private func icon(_ platform: Platform) -> String {
        switch platform {
        case .web: return "safari.fill"
        case .ios: return "iphone.gen3"
        case .android: return "smartphone"
        case .smartTV: return "tv.fill"
        case .consoles: return "gamecontroller.fill"
        }
    }

    private func detail(_ platform: Platform, _ state: GameState) -> String {
        if platform == .web { return "Your starting platform. Always on." }
        let weeks = Formulas.buildWeeks(base: platform.buildWeeks, engineeringLevel: state.staff.effectiveLevel(.engineering))
        let fee = (platform == .ios || platform == .android) ? " · 6% store fee" : ""
        return "+\(Int(platform.reachBonus * 100)) pts reach · \(weeks) wk to build · \(Format.money(platform.weeklyUpkeep))/wk\(fee)"
    }

    // MARK: Servers

    private func servers(_ state: GameState) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(text: "Servers & datacenters", icon: "server.rack", tint: Theme.violet)
            Text("Servers decide how many people can stream at once. Above 90% full, viewers see lag. Past 100% they buffer and cancel. Far past it, the servers can crash and you lose subscribers. Fast growth or a viral hit can spike traffic, so keep some headroom.")
                .font(.footnote).foregroundStyle(Theme.text2)
            ForEach(Region.allCases) { region in
                let subs = state.subscribers(in: region)
                let dcs = state.datacenters(in: region)
                if subs > 0 || !dcs.isEmpty || (state.cloudUnits[region.rawValue] ?? 0) > 0 {
                    regionCard(region, state, subs: subs, dcs: dcs)
                }
            }
            if state.liveMarketCodes.isEmpty == false, Region.allCases.allSatisfy({ state.subscribers(in: $0) == 0 && state.datacenters(in: $0).isEmpty }) {
                Text("Regions appear here once you have subscribers.").font(.caption).foregroundStyle(Theme.text2)
            }
            LabeledValue(label: "Weekly servers + apps cost", value: Format.money(state.weeklyTechCost))
        }
        .artCard(tint: Theme.violet)
    }

    private func regionCard(_ region: Region, _ state: GameState, subs: Double, dcs: [Datacenter]) -> some View {
        let load = state.effectiveLoad(region)
        let capacity = state.serverCapacity(region)
        let cloud = state.cloudUnits[region.rawValue] ?? 0
        let tint: Color = load > 1 ? Theme.danger : (load > 0.9 ? Theme.amber : Theme.good)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(region.displayName).font(.headline).foregroundStyle(.white)
                Spacer()
                Pill(text: status(load), tint: tint)
            }
            StatBar(label: "\(Format.count(subs)) viewers of \(Format.count(capacity)) capacity",
                    value: min(1.3, load) / 1.3, text: Format.percent(load), tint: tint, compact: true)
            if (state.outages[region.rawValue] ?? 0) > 0 {
                Label("Recovering from a crash", systemImage: "wrench.and.screwdriver.fill").font(.caption).foregroundStyle(Theme.danger)
            }
            if (state.surges[region.rawValue] ?? 0) > 0 {
                Label("Traffic surge right now", systemImage: "bolt.fill").font(.caption).foregroundStyle(Theme.amber)
            }
            ForEach(dcs) { dc in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(dc.name).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                        if dc.isOnline {
                            Text("\(Format.count(dc.capacity)) viewers · \(Format.money(state.datacenterUpkeepPrice(level: dc.level)))/wk")
                                .font(.caption2).foregroundStyle(Theme.text2)
                        } else {
                            Text("Building: \(dc.weeksToBuild) weeks left").font(.caption2).foregroundStyle(Theme.amber)
                        }
                    }
                    Spacer()
                    PipRow(level: dc.level, max: Formulas.maxDatacenterLevel, tint: Theme.violet)
                    if let price = state.datacenterUpgradePrice(dc) {
                        Button("Upgrade \(Format.money(price))") { store.perform { try $0.upgradeDatacenter(id: dc.id) } }
                            .buttonStyle(SoftButtonStyle(tint: Theme.violet)).font(.caption)
                            .disabled(state.finances.cash < price)
                    }
                }
            }
            HStack {
                Button("Build datacenter · \(Format.money(state.datacenterBuildPrice))") {
                    store.perform { try $0.buildDatacenter(region: region) }
                }
                .buttonStyle(SoftButtonStyle(tint: Theme.violet))
                .disabled(dcs.count >= Formulas.maxDatacentersPerRegion || state.finances.cash < state.datacenterBuildPrice)
            }
            Text("Datacenters take \(Formulas.buildWeeks(base: Formulas.datacenterBuildWeeks, engineeringLevel: state.staff.effectiveLevel(.engineering))) weeks to build. Two or more in a region make crashes less likely.")
                .font(.caption2).foregroundStyle(Theme.text2)
            HStack {
                Text("Cloud rental: \(cloud) × \(Format.count(Formulas.cloudUnitCapacity))").font(.caption).foregroundStyle(.white)
                Spacer()
                Button("−") { store.perform { try $0.releaseCloud(region: region) } }
                    .buttonStyle(SoftButtonStyle(tint: Theme.text2)).disabled(cloud == 0)
                Button("+ \(Format.money(state.cloudUnitPrice))/wk") { store.perform { try $0.rentCloud(region: region) } }
                    .buttonStyle(SoftButtonStyle(tint: Theme.amber)).disabled(cloud >= Formulas.maxCloudUnits)
            }
            Text("Cloud is instant but about 8× pricier per viewer. Use it to cover a rush, then release it.")
                .font(.caption2).foregroundStyle(Theme.text2)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.05)))
    }

    private func status(_ load: Double) -> String {
        if load > 1.05 { return "Overloaded" }
        if load > 1.0 { return "Buffering" }
        if load > 0.9 { return "Lagging" }
        if load > 0.7 { return "Busy" }
        return "Comfortable"
    }

    // MARK: Team

    private func team(_ state: GameState) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(text: "Your team", icon: "person.3.fill", tint: Theme.amber)
            Text("Hire people from the job board. Each person has a skill (1-3 stars), a trait and a salary you set. A department's level is its people's combined skill (max 5); pay and morale decide how well they work.")
                .font(.footnote).foregroundStyle(Theme.text2)
            hiringBoard(state)
            ForEach(Department.allCases) { department in
                departmentCard(department, state)
            }
            LabeledValue(label: "Total weekly salaries", value: Format.money(state.weeklySalaries))
        }
        .artCard(tint: Theme.amber)
    }

    private func departmentCard(_ department: Department, _ state: GameState) -> some View {
        let level = state.staff[department]
        let pay = state.staff.payScale(department)
        let effective = state.staff.effectiveLevel(department)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: department.icon).foregroundStyle(Theme.amber).frame(width: 26)
                Text(department.displayName).font(.headline).foregroundStyle(.white)
                Spacer()
                PipRow(level: level, max: Formulas.maxDepartmentLevel)
            }
            Text(department.summary).font(.caption).foregroundStyle(Theme.text2)
            if level > 0 {
                Label("Now: \(department.benefit(at: effective))", systemImage: "checkmark.circle.fill")
                    .font(.caption).foregroundStyle(Theme.good)
            }
            if level < Formulas.maxDepartmentLevel {
                let next = Double(level + 1) * Formulas.payEffectiveness(pay)
                Label("Next level: \(department.benefit(at: next))", systemImage: "arrow.up.circle")
                    .font(.caption).foregroundStyle(Theme.amber)
            }
            if state.staff.members(department).isEmpty {
                Text("Nobody here yet. Hire from the job board above.").font(.caption).foregroundStyle(Theme.text2)
            }
            ForEach(state.staff.members(department)) { person in
                employeeRow(person, state)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.05)))
    }

    private func stars(_ skill: Int) -> String {
        String(repeating: "★", count: skill) + String(repeating: "☆", count: Employee.maxSkill - skill)
    }

    private func hiringBoard(_ state: GameState) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("JOB BOARD").font(.caption2.weight(.heavy)).tracking(1.2).foregroundStyle(Theme.text2)
            Text("New applicants every 4 weeks.").font(.caption2).foregroundStyle(Theme.text2)
            ForEach(state.candidates) { person in
                let full = state.staff[person.department] >= Formulas.maxDepartmentLevel
                let fee = state.hirePrice(person)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(person.name).font(.subheadline.weight(.bold)).foregroundStyle(.white)
                        Text(stars(person.skill)).font(.caption).foregroundStyle(Theme.amber)
                        Spacer()
                        Pill(text: person.department.displayName, tint: Theme.teal)
                    }
                    Text("\(person.trait.displayName): \(person.trait.blurb)").font(.caption2).foregroundStyle(Theme.text2)
                    HStack {
                        Text("Asks \(Format.money(state.salaryPrice(person)))/wk").font(.caption).foregroundStyle(Theme.text2)
                        Spacer()
                        Button(full ? "Department full" : "Hire · \(Format.money(fee)) fee") {
                            store.perform { try $0.hire(candidateID: person.id) }
                        }
                        .font(.caption.weight(.bold)).buttonStyle(.bordered).tint(Theme.amber)
                        .disabled(full || state.finances.cash < fee)
                    }
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.05)))
            }
        }
    }

    private func employeeRow(_ person: Employee, _ state: GameState) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(person.name).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                Text(stars(person.skill)).font(.caption).foregroundStyle(Theme.amber)
                Spacer()
                Pill(text: person.trait.displayName, tint: Theme.violet)
            }
            StatBar(label: "Morale", value: person.morale / 100, text: "\(Int(person.morale))",
                    tint: person.morale < 30 ? Theme.danger : person.morale < 50 ? Theme.amber : Theme.good, height: 4, compact: true)
            HStack {
                Text("\(Format.money(state.salaryPrice(person)))/wk · \(Format.percent(person.pay)) of market").font(.caption2).foregroundStyle(Theme.text2)
                Spacer()
                Stepper("", value: Binding(get: { person.pay },
                                           set: { v in store.perform { try $0.setSalary(employeeID: person.id, pay: v) } }),
                        in: Formulas.payRange, step: 0.05).labelsHidden()
            }
            HStack {
                Text("\(person.weeksEmployed) wks with you").font(.caption2).foregroundStyle(Theme.text2)
                Spacer()
                Button("Let go · \(Format.money(state.severancePrice(person))) severance") {
                    store.perform { try $0.fire(employeeID: person.id) }
                }
                .font(.caption2).foregroundStyle(Theme.danger)
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.04)))
    }

    private func studioCrews(_ state: GameState) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(text: "Studio crews", icon: "film.fill", tint: Theme.violet)
            Text("Pay for the people who make your in-house shows. Better-paid crews make better shows; underpaid ones lose experience every week.")
                .font(.footnote).foregroundStyle(Theme.text2)
            payPicker(pay: state.staff.studioPay) { value in store.perform { try $0.setStudioPay(scale: value) } }
            LabeledValue(label: "Studio upkeep", value: Format.money(state.weeklyStudioCost) + "/wk")
        }
        .artCard(tint: Theme.violet)
    }

    /// Low / Fair / Generous instead of raw percentages.
    private func payPicker(pay: Double, set: @escaping (Double) -> Void) -> some View {
        let current = PayLevel.closest(to: pay)
        return VStack(alignment: .leading, spacing: 4) {
            Picker("Pay", selection: Binding(get: { current }, set: { set($0.scale) })) {
                ForEach(PayLevel.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            Text(payNote(current))
                .font(.caption2).foregroundStyle(current == .low ? Theme.amber : Theme.text2)
        }
    }

    private func payNote(_ level: PayLevel) -> String {
        switch level {
        case .low: return "Pay: Low (80% of market). Cheaper, but the team works at \(Int(Formulas.payEffectiveness(0.8) * 100))% and people may quit."
        case .fair: return "Pay: Fair (market rate). Steady and reliable."
        case .generous: return "Pay: Generous (130%). Costs more, team works at \(Int(Formulas.payEffectiveness(1.3) * 100))%."
        }
    }
}
