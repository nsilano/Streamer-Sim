import Foundation

/// Every policy the player can set. The default option of each policy is neutral (all multipliers 1.0).
enum PolicyData {
    static let all: [PolicyDefinition] = accounts + pricing + content + ads + product + retention + partnerships + extras

    static func definition(_ id: String) -> PolicyDefinition? { all.first { $0.id == id } }

    // MARK: Accounts & sharing

    private static let accounts: [PolicyDefinition] = [
        PolicyDefinition(
            id: "sharing", category: .accounts, title: "Password sharing", icon: "key.fill",
            summary: "Do you let subscribers share logins with friends and family?",
            defaultOption: "allow",
            options: [
                PolicyOption(id: "allow", title: "Allow sharing", detail: "Anyone can share a login. Free word of mouth, but plenty of non-payers.",
                             effects: .neutral, pros: ["Free word of mouth", "No backlash"], cons: ["Lots of people watch without paying"]),
                PolicyOption(id: "extra", title: "Paid extra members", detail: "Sharing outside the home costs a small monthly fee.",
                             effects: PolicyEffects(adds: 1.0, arpu: 1.04, trust: -0.02), pros: ["Turns some sharers into revenue", "Mild reaction"],
                             cons: ["Some annoyed customers"], badChance: 0.2,
                             good: PolicyOutcome(headline: "Extra-member fee goes down well", detail: "Many sharers happily pay a little extra.", subsPct: 0.015, trust: 1),
                             bad: PolicyOutcome(headline: "Extra-member fee draws complaints", detail: "Social media calls it a cash grab.", subsPct: -0.01, trust: -4, shockWeeks: 3, shockChurn: 1.25)),
                PolicyOption(id: "household", title: "Household only", detail: "One household per account. Sharers must sign up or leave.",
                             effects: PolicyEffects(adds: 0.97, churn: 1.03, arpu: 1.10, trust: -0.12, heat: 0.05),
                             pros: ["Big jump in paying accounts", "Higher revenue per subscriber"],
                             cons: ["Angers loyal customers", "Slower sign-ups", "Rivals will mock you"], badChance: 0.45,
                             good: PolicyOutcome(headline: "Crackdown converts sharers", detail: "Millions of freeloaders sign up for their own plans.", subsPct: 0.05, trust: -3, shockWeeks: 4, shockAdds: 1.15),
                             bad: PolicyOutcome(headline: "Password crackdown backfires", detail: "Customers revolt and cancel in droves; rivals run free-sharing promos.", subsPct: -0.04, trust: -10, shockWeeks: 6, shockChurn: 1.6, rivalPounces: true)),
                PolicyOption(id: "strict", title: "Strict device verification", detail: "Devices are verified every few weeks. Sharing is effectively impossible.",
                             effects: PolicyEffects(adds: 0.92, churn: 1.08, arpu: 1.15, trust: -0.3, heat: 0.15),
                             pros: ["Highest revenue per subscriber"], cons: ["Heavy backlash risk", "Sign-ups slow", "Trust erodes every week"],
                             badChance: 0.6,
                             good: PolicyOutcome(headline: "Hard line pays off", detail: "Sharers grudgingly subscribe.", subsPct: 0.06, trust: -6, shockWeeks: 4, shockAdds: 1.1),
                             bad: PolicyOutcome(headline: "Verification revolt", detail: "A viral boycott hits just as rivals offer easy sharing.", subsPct: -0.07, trust: -16, heat: 5, shockWeeks: 8, shockChurn: 1.9, rivalPounces: true)),
            ]),
        PolicyDefinition(
            id: "screens", category: .accounts, title: "Screens per plan", icon: "rectangle.on.rectangle",
            summary: "How many people can watch at once?",
            defaultOption: "standard",
            options: [
                PolicyOption(id: "standard", title: "1 / 2 / 4 screens", detail: "One screen on Ads, two on Standard, four on Premium.",
                             effects: .neutral, pros: ["Balanced"], cons: []),
                PolicyOption(id: "generous", title: "2 / 4 / 6 screens", detail: "Households love it, but more streams cost more to serve.",
                             effects: PolicyEffects(adds: 1.04, churn: 0.96, arpu: 0.98, streamingCost: 1.05), pros: ["Fewer cancellations", "More sign-ups"],
                             cons: ["Higher hosting bill", "Slightly lower revenue per subscriber"]),
                PolicyOption(id: "tight", title: "1 / 1 / 2 screens", detail: "Nudges households toward higher tiers.",
                             effects: PolicyEffects(adds: 0.96, churn: 1.04, arpu: 1.05, streamingCost: 0.95), pros: ["Upsell pressure", "Cheaper to serve"],
                             cons: ["Annoys families"], badChance: 0.15,
                             bad: PolicyOutcome(headline: "Families grumble about screen limits", detail: "Reviews complain about sharing the TV with the kids.", subsPct: -0.01, trust: -3, shockWeeks: 3, shockChurn: 1.15)),
            ]),
    ]

    // MARK: Pricing & offers

    private static let pricing: [PolicyDefinition] = [
        PolicyDefinition(
            id: "trial", category: .pricing, title: "Free trial", icon: "gift.fill",
            summary: "Let new people try the service before paying?",
            defaultOption: "none",
            options: [
                PolicyOption(id: "none", title: "No free trial", detail: "People pay from day one.", effects: .neutral, pros: ["No freeloaders"], cons: ["Harder to win skeptics"]),
                PolicyOption(id: "seven", title: "7-day trial", detail: "A short taste of the library.",
                             effects: PolicyEffects(adds: 1.12, churn: 1.04, streamingCost: 1.02), pros: ["More sign-ups"], cons: ["Some people only come for the trial"]),
                PolicyOption(id: "thirty", title: "30-day trial", detail: "A full month free. Huge reach, lots of trial hoppers.",
                             effects: PolicyEffects(adds: 1.25, churn: 1.12, streamingCost: 1.06, trust: 0.02), pros: ["Big surge in sign-ups"],
                             cons: ["Many leave when billing starts", "Costs money to serve non-payers"]),
            ]),
        PolicyDefinition(
            id: "annual", category: .pricing, title: "Billing plans", icon: "calendar",
            summary: "Monthly, annual, or both?",
            defaultOption: "monthly",
            options: [
                PolicyOption(id: "monthly", title: "Monthly only", detail: "Maximum flexibility, maximum churn.", effects: .neutral, pros: ["Easy to join"], cons: ["People cancel freely"]),
                PolicyOption(id: "both", title: "Monthly + annual (15% off)", detail: "Annual subscribers stay longer for a discount.",
                             effects: PolicyEffects(churn: 0.88, arpu: 0.96), pros: ["Noticeably lower churn"], cons: ["Lower revenue per subscriber"]),
                PolicyOption(id: "annualonly", title: "Annual only", detail: "Pay for a year up front. Very sticky, but a big barrier to join.",
                             effects: PolicyEffects(adds: 0.88, churn: 0.8, arpu: 0.94, trust: -0.03), pros: ["Lowest churn"], cons: ["Far fewer new sign-ups", "Some backlash"],
                             badChance: 0.25,
                             bad: PolicyOutcome(headline: "Annual-only plans draw fire", detail: "Reviewers say you've locked people in.", subsPct: -0.02, trust: -4)),
            ]),
        PolicyDefinition(
            id: "pricechanges", category: .pricing, title: "Price changes", icon: "arrow.up.right.circle.fill",
            summary: "How do you treat existing customers when prices change?",
            defaultOption: "everyone",
            options: [
                PolicyOption(id: "everyone", title: "Same prices for everyone", detail: "New prices apply to all subscribers at once.", effects: .neutral, pros: ["Simple"], cons: []),
                PolicyOption(id: "loyalty", title: "Lock in loyal customers", detail: "Existing subscribers keep their old price for a while.",
                             effects: PolicyEffects(churn: 0.95, arpu: 0.97, trust: 0.12), pros: ["Builds trust", "Less churn after price rises"], cons: ["Slower revenue growth"]),
                PolicyOption(id: "dynamic", title: "Dynamic demand pricing", detail: "Prices flex with demand and show popularity.",
                             effects: PolicyEffects(adds: 0.98, arpu: 1.05, trust: -0.08, heat: 0.05), pros: ["More revenue at peak times"], cons: ["Feels unfair", "Regulators watch this"],
                             badChance: 0.3,
                             bad: PolicyOutcome(headline: "Surge pricing sparks outrage", detail: "A blockbuster premiere costs more than usual and fans notice.", subsPct: -0.02, trust: -7, heat: 4, shockWeeks: 3, shockChurn: 1.3)),
            ]),
        PolicyDefinition(
            id: "discounts", category: .pricing, title: "Student & family plans", icon: "graduationcap.fill",
            summary: "Special plans for specific groups.",
            defaultOption: "none",
            options: [
                PolicyOption(id: "none", title: "None", detail: "One price for everyone.", effects: .neutral, pros: [], cons: []),
                PolicyOption(id: "student", title: "Student discount", detail: "Cheaper plans for students.",
                             effects: PolicyEffects(adds: 1.06, arpu: 0.985, trust: 0.03), pros: ["More young subscribers"], cons: ["Slightly lower revenue per subscriber"]),
                PolicyOption(id: "family", title: "Family plan", detail: "Multiple profiles at a bundle price.",
                             effects: PolicyEffects(adds: 1.05, churn: 0.95, arpu: 0.98), pros: ["Households stay longer"], cons: ["Lower revenue per subscriber"]),
                PolicyOption(id: "both", title: "Student + family", detail: "Both plans.",
                             effects: PolicyEffects(adds: 1.10, churn: 0.94, arpu: 0.965, trust: 0.03), cost: 150_000, pros: ["Broad appeal"], cons: ["One-time setup cost", "Lower revenue per subscriber"]),
            ]),
        PolicyDefinition(
            id: "promos", category: .pricing, title: "Promotions", icon: "percent",
            summary: "How often do you discount?",
            defaultOption: "never",
            options: [
                PolicyOption(id: "never", title: "Never discount", detail: "Premium brand feel.", effects: .neutral, pros: ["Keeps prices firm"], cons: []),
                PolicyOption(id: "seasonal", title: "Seasonal promotions", detail: "Holiday and premiere deals.", effects: PolicyEffects(adds: 1.06, arpu: 0.99), pros: ["Sign-up bursts"], cons: ["Small revenue dilution"]),
                PolicyOption(id: "always", title: "Always-on deals", detail: "A discount code is always available.",
                             effects: PolicyEffects(adds: 1.15, arpu: 0.93, trust: -0.05), pros: ["Strong growth"], cons: ["Customers wait for deals", "Brand looks cheap"]),
            ]),
    ]

    // MARK: Content & ratings

    private static let content: [PolicyDefinition] = [
        PolicyDefinition(
            id: "schedule", category: .content, title: "Release schedule", icon: "calendar.badge.clock",
            summary: "Drop whole seasons at once, or weekly?",
            defaultOption: "weekly",
            options: [
                PolicyOption(id: "weekly", title: "Weekly episodes", detail: "Keeps people subscribed week after week.", effects: .neutral, pros: ["Steady viewing"], cons: []),
                PolicyOption(id: "binge", title: "Binge drops", detail: "Whole seasons at once. Big launches, then people cancel.",
                             effects: PolicyEffects(adds: 1.05, churn: 1.08), pros: ["Launch buzz"], cons: ["People binge and cancel"]),
                PolicyOption(id: "hybrid", title: "Split drops", detail: "Half the season, then the rest a few weeks later.", effects: PolicyEffects(adds: 1.02, churn: 0.97), pros: ["Best of both"], cons: []),
            ]),
        PolicyDefinition(
            id: "ratings", category: .content, title: "Content standards", icon: "checkmark.shield.fill",
            summary: "How edgy is your service?",
            defaultOption: "standard",
            options: [
                PolicyOption(id: "family", title: "Family-friendly", detail: "Safe for all ages. Advertisers and regulators love you.",
                             effects: PolicyEffects(adds: 0.97, adRevenue: 1.08, fines: 0.7, trust: 0.05, heat: -0.1), pros: ["Fewer fines", "Advertisers pay more"], cons: ["Less buzz"]),
                PolicyOption(id: "standard", title: "Standard", detail: "A mix of general and mature content.", effects: .neutral, pros: [], cons: []),
                PolicyOption(id: "mature", title: "Edgy & mature", detail: "Provocative shows get people talking.",
                             effects: PolicyEffects(adds: 1.08, adRevenue: 0.9, fines: 1.25, trust: -0.05, heat: 0.25), pros: ["More buzz and sign-ups"], cons: ["More fines", "Advertisers avoid you"],
                             badChance: 0.2,
                             bad: PolicyOutcome(headline: "Controversy over a mature series", detail: "Campaigners and some advertisers turn on you.", subsPct: -0.01, trust: -5, heat: 6, shockWeeks: 3, shockChurn: 1.15)),
            ]),
        PolicyDefinition(
            id: "moderation", category: .content, title: "Moderation", icon: "hand.raised.fill",
            summary: "How do you handle controversial content?",
            defaultOption: "balanced",
            options: [
                PolicyOption(id: "strict", title: "Strict review", detail: "Anything risky is cut or edited.", effects: PolicyEffects(adds: 0.98, trust: 0.06, heat: -0.15, flatCost: 8_000), pros: ["Few scandals"], cons: ["Costs money", "Creators grumble"]),
                PolicyOption(id: "balanced", title: "Balanced", detail: "Case-by-case decisions.", effects: .neutral, pros: [], cons: []),
                PolicyOption(id: "open", title: "Open platform", detail: "Free speech first.", effects: PolicyEffects(adds: 1.04, trust: -0.08, heat: 0.2), pros: ["Creators love it"], cons: ["Scandal risk", "Regulators take notice"],
                             badChance: 0.2,
                             bad: PolicyOutcome(headline: "Scandal over a controversial title", detail: "Critics say you went too far.", subsPct: -0.015, trust: -6, heat: 5, shockWeeks: 3, shockChurn: 1.2)),
            ]),
        PolicyDefinition(
            id: "local", category: .content, title: "Local content commitment", icon: "mappin.and.ellipse",
            summary: "How hard do you push local-language programming?",
            defaultOption: "balanced",
            options: [
                PolicyOption(id: "minimal", title: "Minimal", detail: "Mostly global hits, little local content.", effects: PolicyEffects(adds: 0.99, fines: 1.4, heat: 0.1), pros: ["Cheaper"], cons: ["Bigger fines", "Regulators notice"]),
                PolicyOption(id: "balanced", title: "Balanced", detail: "A sensible local slate.", effects: .neutral, pros: [], cons: []),
                PolicyOption(id: "champion", title: "Local champion", detail: "Invest heavily in local stories everywhere.", effects: PolicyEffects(adds: 1.03, fines: 0.5, trust: 0.08, heat: -0.15, flatCost: 20_000),
                             pros: ["Far fewer fines", "Local goodwill"], cons: ["Weekly cost"]),
            ]),
    ]

    // MARK: Ads & data

    private static let ads: [PolicyDefinition] = [
        PolicyDefinition(
            id: "adload", category: .ads, title: "Ad load", icon: "rectangle.3.group.fill",
            summary: "How many ads on the Ad-supported tier?",
            defaultOption: "standard",
            options: [
                PolicyOption(id: "light", title: "Light", detail: "Few ads, happy viewers.", effects: PolicyEffects(churn: 0.95, adRevenue: 0.7, trust: 0.03), pros: ["Happier viewers"], cons: ["Much less ad revenue"]),
                PolicyOption(id: "standard", title: "Standard", detail: "Industry-typical.", effects: .neutral, pros: [], cons: []),
                PolicyOption(id: "heavy", title: "Heavy", detail: "Ads everywhere.", effects: PolicyEffects(churn: 1.10, adRevenue: 1.35, trust: -0.08), pros: ["Big ad revenue"], cons: ["More cancellations", "Trust slips"]),
            ]),
        PolicyDefinition(
            id: "privacy", category: .ads, title: "Data & privacy", icon: "lock.shield.fill",
            summary: "What do you do with viewer data?",
            defaultOption: "standard",
            options: [
                PolicyOption(id: "monetize", title: "Monetize data", detail: "Sell targeted insights to advertisers.",
                             effects: PolicyEffects(adRevenue: 1.2, fines: 1.2, trust: -0.2, heat: 0.3), pros: ["More ad revenue"], cons: ["Trust erodes", "Regulatory heat", "Scandal risk"],
                             badChance: 0.3,
                             bad: PolicyOutcome(headline: "Data-selling scandal", detail: "A leak reveals what you share with advertisers.", subsPct: -0.03, trust: -12, heat: 10, shockWeeks: 5, shockChurn: 1.4)),
                PolicyOption(id: "standard", title: "Standard practice", detail: "Typical privacy settings.", effects: .neutral, pros: [], cons: []),
                PolicyOption(id: "strict", title: "Privacy first", detail: "Minimal data, strong protections.", effects: PolicyEffects(adRevenue: 0.9, fines: 0.8, trust: 0.2, heat: -0.2, flatCost: 6_000), pros: ["Trust grows", "Fewer fines"], cons: ["Less ad revenue"]),
            ]),
        PolicyDefinition(
            id: "placement", category: .ads, title: "Product placement", icon: "bag.fill",
            summary: "Sponsors paying to appear in your shows.",
            defaultOption: "off",
            options: [
                PolicyOption(id: "off", title: "None", detail: "Clean viewing.", effects: .neutral, pros: [], cons: []),
                PolicyOption(id: "on", title: "In-show placements", detail: "Brands pay to appear on screen.", effects: PolicyEffects(adRevenue: 1.12, trust: -0.04), pros: ["Extra income"], cons: ["Viewers notice"]),
            ]),
    ]

    // MARK: Product & quality

    private static let product: [PolicyDefinition] = [
        PolicyDefinition(
            id: "quality", category: .product, title: "Video quality", icon: "4k.tv.fill",
            summary: "What resolution does each plan get?",
            defaultOption: "hd",
            options: [
                PolicyOption(id: "saver", title: "Data saver default", detail: "Lower bitrate by default. Cheap to serve.", effects: PolicyEffects(adds: 0.97, streamingCost: 0.85), pros: ["Much cheaper hosting"], cons: ["Fewer sign-ups"]),
                PolicyOption(id: "hd", title: "HD for everyone", detail: "The standard experience.", effects: .neutral, pros: [], cons: []),
                PolicyOption(id: "premium4k", title: "4K on Premium only", detail: "A reason to upgrade.", effects: PolicyEffects(arpu: 1.02, streamingCost: 1.08), pros: ["Upsell"], cons: ["Hosting costs"]),
                PolicyOption(id: "all4k", title: "4K for all", detail: "The best picture everywhere.", effects: PolicyEffects(adds: 1.04, churn: 0.96, streamingCost: 1.2), pros: ["Delighted viewers"], cons: ["Big hosting bill"]),
            ]),
        PolicyDefinition(
            id: "downloads", category: .product, title: "Offline downloads", icon: "arrow.down.circle.fill",
            summary: "Can people download shows to watch offline?",
            defaultOption: "off",
            options: [
                PolicyOption(id: "off", title: "No downloads", detail: "Streaming only.", effects: .neutral, pros: [], cons: []),
                PolicyOption(id: "premium", title: "Premium only", detail: "A premium perk.", effects: PolicyEffects(churn: 0.98, arpu: 1.01, streamingCost: 1.01), pros: ["Small perk"], cons: []),
                PolicyOption(id: "all", title: "Everyone", detail: "Great for commuters and travelers.", effects: PolicyEffects(churn: 0.95, streamingCost: 0.98), pros: ["Happier subscribers"], cons: ["Piracy worries"]),
            ]),
        PolicyDefinition(
            id: "support", category: .product, title: "Customer support", icon: "headphones",
            summary: "How much help do customers get?",
            defaultOption: "standard",
            options: [
                PolicyOption(id: "selfserve", title: "Self-serve only", detail: "FAQs and a chatbot.", effects: PolicyEffects(churn: 1.05, trust: -0.1), pros: ["Free"], cons: ["Customers feel ignored"]),
                PolicyOption(id: "standard", title: "Standard support", detail: "Email and chat.", effects: .neutral, pros: [], cons: []),
                PolicyOption(id: "premium", title: "24/7 premium support", detail: "Real people, any time.", effects: PolicyEffects(churn: 0.93, trust: 0.15, overhead: 0.025), cost: 200_000, pros: ["Fewer cancellations", "Trust grows"], cons: ["Costs 2.5% of revenue", "Setup cost"]),
            ]),
    ]

    // MARK: Keeping subscribers

    private static let retention: [PolicyDefinition] = [
        PolicyDefinition(
            id: "cancel", category: .retention, title: "Cancellation flow", icon: "xmark.circle.fill",
            summary: "How hard is it to cancel?",
            defaultOption: "standard",
            options: [
                PolicyOption(id: "easy", title: "One-click cancel", detail: "Leaving is easy, so people trust you.", effects: PolicyEffects(churn: 1.04, trust: 0.1, heat: -0.15), pros: ["Trust grows", "Regulators approve"], cons: ["A bit more churn"]),
                PolicyOption(id: "standard", title: "Standard", detail: "A few screens and an exit survey.", effects: .neutral, pros: [], cons: []),
                PolicyOption(id: "maze", title: "Retention maze", detail: "Offers, hoops and a phone call to leave.", effects: PolicyEffects(churn: 0.82, trust: -0.3, heat: 0.5), pros: ["Much lower churn"], cons: ["Trust falls fast", "Regulators hate dark patterns"],
                             badChance: 0.35,
                             bad: PolicyOutcome(headline: "Regulator investigates your cancellation flow", detail: "Consumer groups call it a dark pattern.", subsPct: -0.015, trust: -8, heat: 12, shockWeeks: 4, shockChurn: 1.2)),
            ]),
    ]

    // MARK: Refunds & creators (kept with their categories below)

    private static let extras: [PolicyDefinition] = [
        PolicyDefinition(
            id: "refunds", category: .retention, title: "Refund policy", icon: "arrow.uturn.backward.circle.fill",
            summary: "What happens when someone asks for their money back?",
            defaultOption: "standard",
            options: [
                PolicyOption(id: "strict", title: "No refunds", detail: "All sales are final.", effects: PolicyEffects(adds: 0.98, arpu: 1.01, trust: -0.05, heat: 0.05),
                             pros: ["Keeps every payment"], cons: ["Customers feel trapped", "Fewer sign-ups"]),
                PolicyOption(id: "standard", title: "Standard", detail: "Refunds on request within a few days.", effects: .neutral, pros: [], cons: []),
                PolicyOption(id: "generous", title: "No-questions refunds", detail: "Anyone can get their money back, no questions asked.",
                             effects: PolicyEffects(adds: 1.03, arpu: 0.99, trust: 0.12, heat: -0.05), pros: ["Trust grows", "More sign-ups"], cons: ["A little revenue lost"]),
            ]),
        PolicyDefinition(
            id: "creators", category: .content, title: "Creator support", icon: "person.crop.rectangle.stack.fill",
            summary: "How do you treat the people who make your shows?",
            defaultOption: "none",
            options: [
                PolicyOption(id: "none", title: "Standard contracts", detail: "Industry-standard deals.", effects: .neutral, pros: [], cons: []),
                PolicyOption(id: "fund", title: "Creator fund", detail: "A weekly fund to back emerging talent.",
                             effects: PolicyEffects(adds: 1.03, trust: 0.05, flatCost: 25_000), pros: ["Goodwill with creators", "Fresh buzz"], cons: ["Weekly cost"]),
                PolicyOption(id: "exclusive", title: "Exclusive talent deals", detail: "Lock star creators in to first-look deals.",
                             effects: PolicyEffects(adds: 1.05, awareness: 0.002, flatCost: 40_000), pros: ["Big names drive sign-ups"], cons: ["Expensive"]),
            ]),
    ]

    // MARK: Partnerships

    private static let partnerships: [PolicyDefinition] = [
        PolicyDefinition(
            id: "bundles", category: .partnerships, title: "Telecom bundles", icon: "antenna.radiowaves.left.and.right",
            summary: "Sell through phone and internet providers?",
            defaultOption: "none",
            options: [
                PolicyOption(id: "none", title: "No bundles", detail: "Direct sign-ups only.", effects: .neutral, pros: [], cons: []),
                PolicyOption(id: "telecom", title: "Telecom partnerships", detail: "Bundled with mobile plans. Lots of reach, lower margins.",
                             effects: PolicyEffects(adds: 1.2, churn: 0.9, arpu: 0.92, trust: 0.02), cost: 300_000, minSubscribers: 50_000,
                             pros: ["Big reach", "Sticky customers"], cons: ["Lower revenue per subscriber", "Setup cost"]),
                PolicyOption(id: "isp", title: "Broadband bundles", detail: "Included with home internet.",
                             effects: PolicyEffects(adds: 1.12, churn: 0.93, arpu: 0.96), cost: 200_000, minSubscribers: 25_000, pros: ["Steady sign-ups"], cons: ["Slightly lower revenue"]),
            ]),
    ]
}
