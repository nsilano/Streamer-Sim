# Stream Empire (working title)

Native iOS 17+ SwiftUI management sim. No third-party dependencies. Streaming brands are fictional
parodies (Netflux, Disnay+, PrimeStream, Hulo, MaxStream...). Every licensable show/movie is a *parody title*
of a real one ("The First of Us", "Breaking Better"; see `Data/ParodyTitles.swift`): never use real titles or brands verbatim.

## Concept
Single player. Found a streaming service in one country and grow it into the #1 platform in the world by
expanding into countries, building a catalog (licensed + originals) and winning subscribers and revenue.

- **Start:** $25M seed cash, empty catalog, pick any of the 30 countries as your home market and a difficulty (Easy/Medium/Hard: costs x0.75 / x1.0 / x1.4, rivals slower/normal/faster).
- **Win:** #1 in global subscribers, ahead of every rival (checked from week 52). Bonus goals: IPO, $10B annual revenue, all 30 markets.
- **Lose:** cash below the overdraft limit ($5M + 25% of annual revenue), or below zero for 8 straight weeks with no funding available (hard cap 26 weeks).

## Release rule (important)
**Never push to `main`, merge to `main`, or trigger the TestFlight workflow without the user's explicit permission.** Work on the feature branch only. The TestFlight workflow is manual (`workflow_dispatch`) and must stay that way.

## Changelog rule
Every commit pushed to the feature branch must also update `CHANGELOG.md` (player-facing summary under "Unreleased", newest first, with the short commit hash and save version if it changed). Do this in the same push, not later.

## Core loop
1 turn = 1 week. Player decides -> "Next Week" -> `SimulationEngine.advanceWeek` -> weekly report
(new subs, churn, revenue, costs, events). Auto-advance toggle on the dashboard.

## Key mechanics
- **Countries (30 / 6 regions):** broadband households (subscription ceiling = households x subscriptions per household, ~1.8 to ~4.2 by income, shared by ALL services), price tolerance, ad strength, genre taste weights, language, local quota, rival shares, launch cost, regulatory risk. Launch = pay cost, 4 weeks setup, then live. Big markets (USA, India, Japan) unlock at a global-subs OR catalog-size threshold.
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
3. **Phase 3 (done):** originals (`GameState.projects`, weekly cost, quality rolled at release via `Formulas.rolledOriginalQuality`), dubbing/subtitles (`Title.dubs/subtitles`, affects `languageMatch` and local-content quota fines), random events (`Engine/RandomEvents.swift`; choice events set `pendingEvent` and block `advanceWeek` until `resolveEvent`), loans, investor rounds, IPO, bonus goals (`GameState.goals`). Funding rules live in `Engine/OriginalsAndFunding.swift`. The 8-week-debt loss only applies when `fundingAvailable` is false (hard cap 26 weeks). Save version is 3. Tests switch random events off with `eventsEnabled = false`.
4. **Phase 4 (done):** platforms (`Platform`, reach 0.70 web-only -> 1.0 with everything, build time, upkeep, 6% app-store fee per mobile app), CDN capacity per region (`GameState.cdnSteps`, `Formulas.serviceQuality(load:)` feeds sign-ups and churn per region), staff departments (`Staff`, levels 0-5, effects in `Formulas` "Department effects"), dashboard trend chart, how-to-play, app icon (`Assets.xcassets`), TestFlight workflow + `docs/TESTFLIGHT.md` (needs your Apple account; never run). Save version is 4.
   **Balance pass:** the economy scales with success (audience-priced licenses via `licenseAudienceScale`, 4% overhead, per-sub streaming cost, country operating cost). `BalanceTests` runs a simple autopilot (`Bot`) for 3 starters-years and asserts subscriber pacing bands; it also prints `BALANCE ...` lines to the CI log. **When you change economy constants, read those lines in the CI log and adjust the bands deliberately.** Observed with the bot (12 rivals, realistic world scale): ~120-400K subs at year 1, 0.6-2M at year 2, 1.5-4.8M at year 3, ~10M at year 5 (Canada); Netflux grows from ~325M to ~410M in 5 years, so winning (#1) needs a much stronger player than the bot.

5. **Phase 5 (done):** employee pay (`Staff.pay`, `studioPay`, range 0.6-1.6 of market; scales salaries, effectiveness via `Formulas.payEffectiveness`, attrition below 90%), in-house studios (`Studio`, `Engine/Studios.swift`: found/upgrade, slots, cheaper in-house production, quality/popularity bonuses, experience, upkeep), global price tool (`applyPriceLevel`). Department effects use `staff.effectiveLevel(_:)` (level x pay effectiveness), not raw levels. Save version is 5.

6. **Phase 6 (done): art + depth pass.** Dark cinematic theme (`Views/Theme.swift`), procedural poster covers (`Data/PosterSpec.swift` + `Views/PosterView.swift`), bars everywhere (`StatBar`), real world map (`Resources/world.json` from Natural Earth, public domain; `Views/WorldMapView.swift`) with a country sheet, all 30 countries selectable as the starting market, 12 rivals sized after real services (`Data/RivalData.swift`; world capacity = households x subscriptions per household, so Netflux starts near 325M), rivals retaliate against a dominant player (price wars + poaching, `Formulas.dominanceThreat`), datacenters + cloud + crashes + surges (`Engine/TechAndStaff.swift`, `Models/Datacenter.swift`), a hard bankruptcy overdraft limit (`Formulas.bankruptcyFloor`, `GameState.lossReason`), subscription tiers launched per market (`MarketState.liveTiers`), a hireable licensing manager (`Curator`) that auto-buys within rules, and Settings (restart / replay same seed / quit). Save version is 7.

7. **Phase 7 (done): depth pass 2.** News feed (`Models/News.swift`, `Engine/NewsEngine.swift`; rival launches, subscriber and profit milestones, price moves, license wins, overtakes; lives in the Rivals tab), exact dollar prices + rival dollar prices per country (`Formulas.rivalPrice`, `PriceField`, `matchRival`), Finances screen (`FinanceView`, `GameState.costBreakdown/diagnosis/losingMarkets`, per-country P&L in `MarketReport.costs`, `Finances.history/lifetime`), licensing manager fixed + transparent (`Engine/Curating.swift`: carry-over allowance, status text, Shop now), parody title library, gentler regulation (quota fines only after week 40 and 20K subs, capped at 5% of country revenue; regulation event needs week 30, $2M revenue, 1/yr), shares and hostile takeovers (`Engine/Investing.swift`: market caps, 5% disclosure, 20% poison pill, 49% open-market limit, 4-week bid, success absorbs the rival), policies (`Models/Policy.swift`, `Data/PolicyData.swift`, `Engine/Policies.swift`: ~21 policies with good/bad reactions, brand trust, regulatory heat, shocks, cooldown) and difficulty (`Engine/Difficulty.swift`: all prices come from `GameState.*Price` helpers so the UI and the charge always match). Save version is 11.
   **Rules:** any new cost must go through `scaled(...)` / a `*Price` helper in `Difficulty.swift`; defaults of every policy must be neutral (tested); keep news/policy logs capped.

8. **Phase 8 (done):** news covers the player's moves (`NewsEngine.publishPlayerPrices`: net price changes per week; launches, builds, studios, productions, funding, event outcomes), and temporary promotions (`Models/Promotion.swift`, `Engine/Promotions.swift`, `Views/PromotionsView.swift`: 5 campaign kinds, scope all/one country, up to 3 at once, fatigue, post-campaign churn hangover, result log; campaign budgets are their own cost line `CostCategory.promotions`). Save version is 13.

9. **Phase 9 (done):** random events are rare (from week 12, 12-week gap, negatives only from week 24 once you have cash and subs), mild, and never a modal pop-up: `pendingEvent` is a red `AlertCard` on the Dashboard (plus tab badge), never blocks `advanceWeek`, and settles itself with `defaultChoice` after 6 weeks (`RandomEvents.resolveExpired`). Regulation no longer rolls randomly. License renewals (`Engine/Renewals.swift`: `renewalPrice` = 80% of per-year paid, higher if popularity jumped or the title is `sought`, `renewLicense`, 26-week window, news at 12 and 4 weeks, Content tab "Expiring soon" cards and badge), sought-after iconic titles (`Title.sought`, `ParodyLibrary.iconicNames`, 2.2x price, appeal x1.25, rivals bid 2x), and licensing-manager auto-renew (`Curator.autoRenew/renewMaxPrice/renewYears`). Save version is 15.

10. **Phase 10 (done):** catalog depth. Buy rights forever (`buyOutRights`, 10x yearly price, `Engine/CatalogGrowth.swift`), license a title out to a rival for 13/26/52/104 weeks for an upfront fee (`licenseOut`, `GameState.loanedOut`, fee is `WeeklyFinancials.licenseOutRevenue`, already in cash so `SpendLedger.licenseIncome` is subtracted from the weekly cash update), per-title stats (`GameState.titleStats`: weekly/peak/total viewers, revenue credited by appeal share, fees, spend, net return; shown in the title sheet and a Content tab summary). Save version is 16.

## Ideas not yet built
- Win-condition tuning with human playtests (the bot never uses originals, funding, pricing changes or staff).
- Rival originals/events that visibly react to the player; difficulty levels.
- Sound, haptics, localization of the UI, iPad layout polish, accessibility pass.
