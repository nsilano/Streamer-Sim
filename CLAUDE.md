# Stream Empire (working title)

Native iOS 17+ SwiftUI management sim. No third-party dependencies. All brands and titles are
fictional parodies (Netflux, Disnay+, PrimeStream, Hulo, MaxStream) - never use real brands or shows.

## Concept
Single player. Found a streaming service in one country and grow it into the #1 platform in the world by
expanding into countries, building a catalog (licensed + originals) and winning subscribers and revenue.

- **Start:** $25M seed cash, empty catalog, pick 1 starting country (Ireland, New Zealand, Netherlands, Canada are the starter picks).
- **Win:** #1 in global subscribers, ahead of every rival (checked from week 52). Bonus goals: IPO, $10B annual revenue, all 30 markets.
- **Lose:** cash below zero for 8 straight weeks with no funding available.

## Core loop
1 turn = 1 week. Player decides -> "Next Week" -> `SimulationEngine.advanceWeek` -> weekly report
(new subs, churn, revenue, costs, events). Auto-advance toggle on the dashboard.

## Key mechanics
- **Countries (30 / 6 regions):** broadband households (subscriber ceiling = households x 55%), price tolerance, ad strength, genre taste weights, language, local quota, rival shares, launch cost, regulatory risk. Launch = pay cost, 4 weeks setup, then live. Big markets (USA, India, Japan) unlock at a global-subs OR catalog-size threshold.
- **Content:** licensing market (rotating, procedural fictional titles; rivals can snatch listings) and originals (6-52 weeks, budget raises quality but hits are never guaranteed, owned forever worldwide). Appeal per country = sum of title appeal x genre taste x language match x freshness x release boost, with diminishing returns. Subtitles/dubbing cost per title per language.
- **Subscribers** tracked per country and per tier (Ad / Standard / Premium, each with own price). Adds depend on catalog appeal, marketing, price vs tolerance, awareness, word of mouth, rivals, platform reach. Churn depends on content freshness, price, rival releases, service quality.
- **Finances:** revenue = subscriptions (price x 12 / 52 per week) + ads. Costs = licensing, originals, dubbing, streaming/CDN per sub, staff, marketing, country operating costs. Funding = loans (interest) and investor rounds (equity %). IPO at a revenue/subscriber threshold. Always show cash, weekly P/L and runway.
- **Tech/ops:** platforms (web, iOS, Android, smart TV, consoles) raise reach; CDN capacity per region (under-capacity -> buffering/outages/churn); departments Content, Marketing, Engineering, Legal, Finance.
- **Rivals:** 5 AI competitors with personalities (aggressive bidder, price cutter, originals-heavy...), subs per country, catalog strength, cash. They expand, change prices, bid on licenses. Global leaderboard.
- **Events:** viral show, outages, password-sharing crackdown, regulations, actor strikes, piracy, rival mergers, recessions. Some offer a choice.

## Screens (TabView)
Dashboard - Markets - Content - Rivals - Company.

## Architecture rules
- `Models/` Codable structs: GameState, Country, Title, Rival, Finances, GameEvent (+ WeeklyReport, enums).
- `Engine/` is **pure Swift, no UI imports**. `SimulationEngine.advanceWeek(_:) -> GameState` is the single entry point; `Formulas` holds all tunable math; `GameActions` holds player decisions as `GameState` mutating funcs that throw `ActionError`.
- `Data/` country table, rival table, title name generator, display `Format`. Keep each in its own file.
- **All randomness** goes through `SeededRNG` (SplitMix64) stored inside `GameState`, so runs and saves are reproducible. Never use `Int.random`/`Date()` in the engine.
- **Never sum or iterate `Dictionary.values` / unsorted keys in the engine for floating-point results**: dictionary order differs between instances (even after a save/load), which breaks determinism. Iterate `keys.sorted()` (see `GameState.totalSubscribers`, `Rival.totalSubs`).
- `Persistence/SaveManager` autosaves `GameState` as JSON after every change (`GameStore.persist`).
- `Views/` + `App/` are the only places that import SwiftUI.
- Money flow rule: licensing and launch costs are deducted from cash when paid and recorded in `finances.ledger`; the next weekly report includes them in costs but does not deduct them again.
- Unit tests live in `StreamEmpireTests/` and must cover any change to simulation math.

## Build & test
- Project file is generated, not committed: `brew install xcodegen && xcodegen generate` (from `project.yml`).
- App: `xcodebuild test -project StreamEmpire.xcodeproj -scheme StreamEmpire -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO`
- Engine only, any OS: `swift test` (`Package.swift` compiles Models/Engine/Data/Persistence as `StreamEmpireCore`).
- CI (`.github/workflows/ci.yml`) runs both on macOS. The tests import `StreamEmpireCore` under SwiftPM and `StreamEmpire` under Xcode.
- Cloud Linux sessions have no Swift toolchain: rely on CI results for compile/test status and say so honestly.

## Build phases
1. **Phase 1 (done, CI green):** models, engine, 1 country playable, licensing, subscribers, finances, dashboard, save/load, tests.
2. **Phase 2 (done):** all 30 countries, unlock rules (`GameState.launchBlocker`), per-country pricing UI hints, rival AI (expansion, price cuts/raises, personality-based license bidding, cash), rival pressure feeding sign-ups and churn (`Formulas.rivalPressure`), richer leaderboard. Save version is 2 (older saves are ignored).
3. **Phase 3:** originals, dubbing/subtitles, events (incl. choices), loans, investor rounds, IPO.
4. **Phase 4:** tech platforms, CDN infrastructure, staff departments, balancing pass, polish, app icon, TestFlight setup.

Placeholders to replace later: `GameState.platformReach`, `GameState.serviceQuality` (Phase 4), `Country.localQuota` and `regulatoryRisk` (unused until Phase 3), Originals tab, funding/staff/tech sections of the Company tab.
