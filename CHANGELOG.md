# Changelog

Newest first. Every pushed update adds an entry here (see "Changelog rule" in CLAUDE.md).
Save version is noted when it changes (older saves are ignored).

## Unreleased (feature branch `claude/stream-empire-ios-setup-7nzt9v`)

### Catalog depth and title stats (save v16) - 06086cd
- Buy the rights to a licensed title forever (about 10 years of its yearly price); no more expiry or renewals.
- License a title out to another service for 13/26/52/104 weeks for an upfront fee; it returns when the term ends. New "Licensing fees" revenue line.
- Per-title stats: viewers this week, peak, total views, revenue this week and lifetime, fees earned, spend, net return, weeks live, top market. Catalog performance summary and viewers on posters.

### Renewals and sought-after titles (save v15) - 5850d00
- Renew expiring licenses (1-5 years) at a discount unless the title gained popularity. Expiry news at 12 and 4 weeks, advice card, Content tab badge and "Expiring soon" cards.
- Famous "real-life hit" titles: about 2.2x price, bigger audiences, rivals bid harder, ICONIC badge, no renewal discount.
- Licensing manager can auto-renew within a price cap, budget and cash reserve.
- Licensed titles can randomly gain popularity.

### Calmer random events (save v14) - 1189eca
- Events are rarer and milder, never a full-screen pop-up: a red alert card on the Dashboard plus a tab badge. The sim never stops; ignored alerts settle themselves with a mild default after 6 weeks.
- Regulation no longer appears as a random event.

### Release safety - 06ae231
- TestFlight workflow is manual-only (`workflow_dispatch`). Release rule added to CLAUDE.md: no push to `main` or TestFlight upload without explicit permission.

## Earlier work (all on the feature branch)
- Promotions: five temporary campaign types with fatigue and churn hangover (a0dadd4; save v13).
- News covers player moves and net price changes (c10918e).
- Difficulty Easy/Medium/Hard (dcf1015), policies with good/bad reactions and brand trust (6d32ea3, 5cba43e), shares and hostile takeovers, parody title library, gentler regulation (8590a1c).
- News feed, rival dollar prices, Finances screen, licensing manager fixes (cdb4084, 8aa7b11).
- Art overhaul: dark theme, procedural posters, world map, country sheet, bars everywhere (cf7d2c6).
- Tier launches, licensing manager, restart/replay settings (b314ed5, cc75771).
- Bankruptcy limit, 12 realistic rivals (f8bff27); datacenters, cloud, crashes (2d102bc); rival price wars, more start countries (bfdf41a).
- TestFlight setup and fixes, bundle ID `com.nsilano.streamempire` (c7f4ab9 to 4135177); phone install guide (7f2c108).
- Phase 5: employee pay, in-house studios, global price tool (40775c3).
- Phase 4: platforms, CDN, staff departments, charts, app icon, balance passes (30e0ed6 to 317798d).
- Phase 3: originals, dubbing, random events, loans, investors, IPO, goals (7fd80bd).
- Phase 2: 30 countries, unlock rules, rival AI (289f86e, b5fc032).
- Phase 1: models, engine, single-market loop, tests (622e71b).
