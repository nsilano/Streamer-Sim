# Changelog

Newest first. Every pushed update adds an entry here (see "Changelog rule" in CLAUDE.md).
Save version is noted when it changes (older saves are ignored).

## Unreleased (feature branch `claude/stream-empire-ios-setup-7nzt9v`)

### Localize a whole market in one tap
- "Choose titles to subtitle / dub" opens a list with every eligible title ticked; untick the ones you want to skip and the price updates.
- Each launched country's page has a "Localize for <country>" card: subtitle every title in the local language, dub your top 20 (best fit for that market first), or dub everything. Prices are shown up front; titles already in that language or already localized are skipped.

### Renewal styles: only absurd renewals interrupt you (save v26)
- "Always auto-renew" is now an Auto-renew style: Off, Careful, Standard (new games start here) or Generous.
- With a style on, every license 13 weeks from expiry renews for 2 years by itself, as long as the price is reasonable: no more per year than 1.0x / 1.3x / 2.0x what you paid, under 2% / 5% / 12% of your cash, and leaving 4 weeks of costs in the bank.
- The sim only stops (at 12, 4 and 1 week left) for licenses your style refused, and the renewal sheet and pause panel say why (e.g. "price jumped to 2.4x what you paid per year").

### Better Dashboard charts (save v25)
- The Dashboard chart now keeps your full history (up to 10 years) and shows the Past year or All time on a calendar axis (months), fitted to your data instead of a squashed week axis starting at 0.
- Metrics: Subscribers, Revenue, Profit (green/red weekly bars) and Cash, with a zero line where it matters, the latest value, and the change over the period shown.

### One ad-load control
- Removed the duplicate "Ad load" policy. Ad load is set only with the slider in Company > Business.

### Readable spending chart
- Finances > Spending over time now shows just the last 12 weeks as evenly spaced bars (one per week, labelled W96, W99...), the top 4 cost types plus "Everything else", and no more bars below zero from refunds.

### Licensing manager styles (save v24)
- Pick a style instead of fiddling with numbers: Passive, Moderate, Aggressive or Custom.
- The three presets size the weekly budget to your revenue and cash (5% / 15% / 30% of revenue plus a small slice of cash), always keep a reserve in the bank (12 / 8 / 4 weeks of costs), and stop buying entirely when your runway drops under 26 / 16 / 8 weeks. They can't drain an early-game company.
- Custom keeps every detailed rule (budget, max price, quality, genres, renewals) for when you want full control. A newly hired manager starts on Passive.

### Last-chance expiry stop
- The sim now also stops when a license has 1 week left (in addition to 12 and 4 weeks), so nothing lapses without a final warning.

### Dates and your-company news highlight
- An in-game calendar: week 1 is Monday, Jan 5, 2026, and each turn is a week. Every tab's header shows the date and week number (the Dashboard also shows your company's age in years).
- News items, weekly reports and policy reactions are stamped with the date and week.
- News about your company (your own moves, or any story that names you) is highlighted in pink with a "YOUR COMPANY" tag, and the "You" filter catches them all.

### Play/Pause instead of Next week; the sim stops for anything major
- The Dashboard's main control is now a big Play/Pause button with 1x/2x/4x/8x speed (a small "Step 1 week" stays for when you're paused).
- The sim pauses by itself and shows a red "Paused: needs your attention" panel that stays until you dismiss it or press Resume when: licenses hit 12 or 4 weeks left, a license expires, servers in a region pass 90% or 100% of capacity, servers crash, cash goes negative or runway drops under 8 weeks, a rival declares a price war or pulls one of your shows, or the game ends.

### Expiring licenses can't slip by anymore (save v23)
- When any license crosses 12 weeks left, and again at 4 weeks, auto-advance stops and an "Expiring licenses" sheet opens with every expiring title, a Renew button on each, and Renew all (choose 1-5 years; with limited cash it keeps the cheapest first).
- New "Always auto-renew" switch (in that sheet and at the top of Content > Catalog): every license is renewed for 2 years two weeks before it expires, if you have the cash. No licensing manager needed.
- "Renew all (2 yr)" button on the Expiring soon section in Content.

### Refresh or expand the licensing market (save v22)
- "Refresh listings": pay to swap every offer on the market for a fresh batch right away (price grows with your audience).
- "More listings": a permanent upgrade (3 levels) that shows 6 more offers at a time and refills faster.

### Customers switch both ways
- In every live country, customers now move between you and each rival based on catalog strength, standard-plan price and service quality. A better offer pulls their subscribers to you (up to 0.3% of each rival's customers there per week, more once people know your brand); a worse one sends yours to them (capped at 0.15% a week in total).
- Rival subscriber counts can now fall. The news and weekly report show the biggest swings, and the country sheet tags each rival "Switching to you" or "Losing to them".

### CEO toolkit (save v21)
- Negotiate licenses: counter-offer on any listing with your own price, length and exclusivity. Lowballs and famous titles are less likely to be accepted; a refusal stalls talks for 4 weeks and raises the price 5%.
- Studio output deals: pay a weekly fee and a studio delivers a new exclusive 3-year title in your chosen genre every 8 weeks for two years (up to 2 deals; ending early costs 8 weeks of fees).
- Exit a market: shut down in a country (subscribers there lose the service; wind-down cost). You can relaunch later.
- Cancel a production mid-way (money spent is gone).
- Pull a licensed title from the service, or write off an original for a 10% tax benefit (fans don't like it).
- (Test fix: a delivered title ages in the week it arrives.)
- Corporate: rename the company; after the IPO, buy back shares and pay quarterly dividends.

### Project notes
- CLAUDE.md now documents phases 11-15 (realism packs, business, challenges, 50 countries, named employees). No gameplay change.

### Named employees (save v20)
- Departments are staffed by named people. A job board offers six applicants (new ones every 4 weeks), each with a department, a skill of 1-3 stars and an asking salary.
- You set each person's salary. Better pay makes them work better; people paid under 90% of market may quit (shown by name in the weekly report).
- A department's level is its people's combined skill (max 5). Departments stay fixed: no teams to build or assign. Kept deliberately simple: no traits, morale or promotions.

### 20 more countries (50 in total)
- New markets: Portugal, Belgium, Switzerland, Austria, Denmark, Norway, Finland, Czechia, Greece, Romania, Vietnam, Philippines, Malaysia, Pakistan, Taiwan, Peru, Israel, Qatar, Morocco and Ghana. All are on the map and the list, can be your starting market, and have their own size, prices, language and rules (Qatar and Pakistan ban reality shows; Pakistan, Qatar, Malaysia and Vietnam are strict about mature titles).
- Eight new languages for dubbing and subtitles (Danish, Norwegian, Finnish, Czech, Greek, Romanian, Hebrew, Vietnamese).
- The "all markets" goal is now 50 markets. Rivals spread their existing subscribers over all 50 countries.
- Two older tests updated for 50 countries (rival footprint count, week-one milestone news).
- Fixed a test that expected a scandal from a title that had already expired.

### Test and balance fixes
- The opening license market is always fully on sale (no embargo on day one).
- Piracy now scales churn instead of adding to it; exchange rates move at the end of each week so the first week is neutral.
- Regional-territory listings are a bit rarer (25%). Year-3 pacing band for small starter markets lowered to 450K because the new rules are deliberate extra difficulty.

### Build fix
- Renamed a duplicate source filename that stopped the realism packs from compiling. No gameplay change.

### Challenges and advisor (save v19)
- Pick a challenge on the new-game screen: Sandbox, 10M subscribers in 3 years, profit in 2 years, or become #1 within 8 years. Deadlines, a score (audience, cash, time left), and your best score per challenge on this device.
- "What should I do next?" advisor on the Dashboard: urgent warnings first, then expiring titles, new markets worth opening, catalog gaps, blocked titles, piracy hot spots, auctions and offers.

### Realism pack 3: the business side (save v18)
- New Company > Business screen.
- Quarterly earnings every 13 weeks: profit on the books (content spending spread over two years) vs analysts' expectations. Beat or miss moves your investor mood and your valuation.
- Digital services taxes in some countries (new "Digital taxes" cost line) and exchange rates that drift and pull revenue up or down by region.
- Ad load slider: more ads earn more but wear viewers out.
- Product features: kids profiles, offline downloads (strongest in low-income markets), 4K (cancels the later 4K-expectation trend, costs more to stream) and a 3-level recommendation engine.
- Live sports rights: yearly auctions; bid above asking to win more often (you pay only if you win). A year of sport lifts appeal and sign-ups and cuts churn in its region.
- Bundles and partnerships: carrier or rival bundles for a year in one country (more sign-ups, lower revenue per customer).
- Acquisitions: yearly offers to buy a film library (titles yours forever) or a small level 2 studio.
- Rivals can pull good non-exclusive licensed shows back to their own service, with a partial refund.

### Realism pack 2: seasons, release style, stars, awards
- Order the next season of a series (refreshes the same show) or a sequel to a movie (a new title that inherits fans). Returning casts cost 12% more per season already made; quality blends the last release with new luck.
- Release style: binge drop (bigger launch, fades faster) or weekly episodes (smaller launch, stays fresh longer).
- Star talent on originals: rising star or A-list star. Costs more, lifts quality and popularity, and takes a weekly cut of the title's revenue.
- Awards season every year (week 44): your best recent originals can win, boosting popularity and brand trust.

### Realism pack 1: restrictions, territories, piracy, trends (save v17)
- Country content rules: Saudi Arabia, UAE, Egypt and Indonesia ban reality shows; strict countries (also India, Thailand) block mature titles until you pay for a local edit (the edit slightly lowers appeal). Blocked titles don't count toward that country's catalog.
- Regional license territories: about a third of listings only cover one or two regions (cheaper); add worldwide rights later for the price difference.
- Embargoed listings: some rights go on sale a few weeks after they appear (the licensing manager waits).
- Piracy per market: rises with high prices, thin catalogs and low-income markets; costs sign-ups and adds churn. Shown on the country sheet.
- Industry trends over the years (password sharing, ad boom, 4K expectations, streaming fatigue).
- New title traits: mature, controversial (more appeal, occasional scandal that dents brand trust), evergreen (classics that never fully go stale).

### Random pop-up events removed
- No more random events at all (outages, piracy, strikes, password crackdowns, recessions, viral/merger news). Nothing pops up or forces a choice. An old save's pending alert still settles itself. Server crashes from overloaded capacity are separate and still happen if you let load exceed capacity.

### Expiring titles are hard to miss
- A red "about to expire" card on the Dashboard (always shown, not one of the two advice slots) lists titles with 12 weeks or less left, each with a one-tap Renew.
- The weekly report now warns at 12 weeks as well as 4 weeks.
- Auto-advance pauses when a license reaches 4 weeks left (unless your manager already renewed it).

### Type your numbers
- Licensing manager rules (budget, max price, cash reserve, quality, years, catalog size, renewals) are typed number fields instead of +/- steppers. Values are clamped to sensible limits when you finish typing; dragging the list dismisses the keyboard.

### TestFlight signing cleanup
- The manual TestFlight workflow now revokes old "Created via API" signing certificates before archiving, so it doesn't hit Apple's certificate limit. Certificates you created yourself are never touched. (Runs in a Python virtualenv; the runner blocks system pip.)

### Test fixes
- Fixed two tests (title stats ranking, random-event firing) that CI caught; no gameplay change.

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
