import SwiftUI

/// The game's look: a dark, cinematic palette with neon accents, serif display type and film-grain backgrounds.
enum Theme {
    static let ink = Color(red: 0.04, green: 0.03, blue: 0.10)
    static let ink2 = Color(red: 0.10, green: 0.06, blue: 0.22)
    static let magenta = Color(red: 0.96, green: 0.27, blue: 0.56)
    static let amber = Color(red: 1.0, green: 0.78, blue: 0.30)
    static let teal = Color(red: 0.22, green: 0.86, blue: 0.78)
    static let violet = Color(red: 0.58, green: 0.45, blue: 1.0)
    static let danger = Color(red: 1.0, green: 0.36, blue: 0.40)
    static let good = Color(red: 0.36, green: 0.90, blue: 0.56)
    static let text2 = Color.white.opacity(0.62)

    static var accentGradient: LinearGradient {
        LinearGradient(colors: [magenta, violet], startPoint: .leading, endPoint: .trailing)
    }

    static func display(_ size: CGFloat) -> Font { .system(size: size, weight: .bold, design: .serif) }
    static func number(_ size: CGFloat) -> Font { .system(size: size, weight: .bold, design: .rounded).monospacedDigit() }
}

/// Layered gradients, glow and film grain behind every screen.
struct ArtBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Theme.ink2, Theme.ink], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [Theme.magenta.opacity(0.22), Color.clear],
                           center: .topTrailing, startRadius: 0, endRadius: 380)
            RadialGradient(colors: [Theme.violet.opacity(0.20), Color.clear],
                           center: .bottomLeading, startRadius: 0, endRadius: 440)
            Canvas { context, size in
                var seed: UInt64 = 7
                for _ in 0..<240 {
                    seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
                    let fx = Double((seed >> 33) % 10_000) / 10_000
                    seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
                    let fy = Double((seed >> 33) % 10_000) / 10_000
                    let rect = CGRect(x: fx * size.width, y: fy * size.height, width: 1.3, height: 1.3)
                    context.fill(Path(ellipseIn: rect), with: .color(Color.white.opacity(0.10)))
                }
            }
        }
        .ignoresSafeArea()
    }
}

struct ArtCardStyle: ViewModifier {
    var tint: Color
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        content
            .padding(14)
            .background(
                shape.fill(LinearGradient(colors: [Color.white.opacity(0.10), Color.white.opacity(0.03)],
                                          startPoint: .topLeading, endPoint: .bottomTrailing))
            )
            .overlay(
                shape.stroke(LinearGradient(colors: [tint.opacity(0.55), Color.white.opacity(0.06)],
                                            startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
            )
    }
}

extension View {
    /// A glassy, gradient-bordered card.
    func artCard(tint: Color = Theme.violet) -> some View { modifier(ArtCardStyle(tint: tint)) }

    /// Standard screen chrome: dark art background, no system list background.
    func artScreen() -> some View {
        self
            .background(ArtBackground())
            .scrollContentBackground(.hidden)
            .preferredColorScheme(.dark)
    }
}

/// Big serif screen title with an optional trailing control.
struct ScreenHeader<Trailing: View>: View {
    let title: String
    var subtitle: String? = nil
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Theme.display(32)).foregroundStyle(.white)
                if let subtitle {
                    Text(subtitle).font(.footnote).foregroundStyle(Theme.text2)
                }
            }
            Spacer()
            trailing()
        }
        .padding(.top, 6)
    }
}

extension ScreenHeader where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = { EmptyView() }
    }
}

struct SectionTitle: View {
    let text: String
    var icon: String? = nil
    var tint: Color = Theme.magenta

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2).fill(tint).frame(width: 4, height: 16)
            if let icon { Image(systemName: icon).foregroundStyle(tint) }
            Text(text.uppercased()).font(.caption.weight(.heavy)).tracking(1.4).foregroundStyle(.white.opacity(0.85))
            Spacer()
        }
    }
}

struct Pill: View {
    let text: String
    var tint: Color = Theme.violet
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 4) {
            if let icon { Image(systemName: icon).font(.caption2) }
            Text(text).font(.caption2.weight(.bold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .foregroundStyle(tint)
        .background(Capsule().fill(tint.opacity(0.18)))
        .overlay(Capsule().stroke(tint.opacity(0.4), lineWidth: 0.5))
    }
}

/// Horizontal bar with a label and value, e.g. Quality 61.
struct StatBar: View {
    let label: String
    let value: Double               // 0...1
    var text: String? = nil
    var tint: Color = Theme.teal
    var height: CGFloat = 7
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(label).font(compact ? .caption2 : .caption).foregroundStyle(Theme.text2)
                Spacer()
                Text(text ?? "\(Int((min(max(value, 0), 1)) * 100))")
                    .font((compact ? Font.caption2 : Font.caption).bold().monospacedDigit())
                    .foregroundStyle(.white)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.10))
                    Capsule()
                        .fill(LinearGradient(colors: [tint.opacity(0.6), tint], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(height, proxy.size.width * CGFloat(min(max(value, 0), 1))))
                }
            }
            .frame(height: height)
        }
    }
}

/// Level pips like ●●●○○.
struct PipRow: View {
    let level: Int
    let max: Int
    var tint: Color = Theme.amber

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<max, id: \.self) { index in
                Circle()
                    .fill(index < level ? tint : Color.white.opacity(0.14))
                    .frame(width: 9, height: 9)
            }
        }
    }
}

/// Large number tile.
struct BigStat: View {
    let title: String
    let value: String
    var subtitle: String? = nil
    var tint: Color = .white
    var icon: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                if let icon { Image(systemName: icon).font(.caption2).foregroundStyle(Theme.magenta) }
                Text(title.uppercased()).font(.caption2.weight(.heavy)).tracking(1.0).foregroundStyle(Theme.text2)
            }
            Text(value).font(Theme.number(24)).foregroundStyle(tint).minimumScaleFactor(0.55).lineLimit(1)
            if let subtitle {
                Text(subtitle).font(.caption2).foregroundStyle(Theme.text2).lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .artCard()
    }
}

/// Kept for older call sites: same as BigStat.
struct StatCard: View {
    let title: String
    let value: String
    var subtitle: String? = nil
    var tint: Color = .primary

    var body: some View {
        BigStat(title: title, value: value, subtitle: subtitle, tint: tint == .primary ? .white : tint)
    }
}

struct LabeledValue: View {
    let label: String
    let value: String
    var tint: Color = .white

    var body: some View {
        HStack {
            Text(label).foregroundStyle(Theme.text2)
            Spacer()
            Text(value).foregroundStyle(tint).monospacedDigit()
        }
        .font(.subheadline)
    }
}

struct GlowButtonStyle: ButtonStyle {
    var tint: Color = Theme.magenta
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.vertical, 12)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity)
            .background(
                Capsule().fill(LinearGradient(colors: [tint, tint.opacity(0.65)], startPoint: .topLeading, endPoint: .bottomTrailing))
            )
            .shadow(color: tint.opacity(configuration.isPressed ? 0.2 : 0.55), radius: configuration.isPressed ? 4 : 12, y: 4)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(isEnabled ? 1 : 0.4)
    }
}

struct SoftButtonStyle: ButtonStyle {
    var tint: Color = Theme.violet
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.vertical, 7)
            .padding(.horizontal, 12)
            .background(Capsule().fill(tint.opacity(configuration.isPressed ? 0.30 : 0.16)))
            .overlay(Capsule().stroke(tint.opacity(0.45), lineWidth: 0.5))
            .opacity(isEnabled ? 1 : 0.4)
    }
}

/// An advice banner.
struct AdviceBanner: View {
    let advice: Advice

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: advice.icon).foregroundStyle(advice.urgent ? Theme.danger : Theme.amber)
            VStack(alignment: .leading, spacing: 2) {
                Text(advice.title).font(.subheadline.weight(.bold)).foregroundStyle(.white)
                Text(advice.detail).font(.caption).foregroundStyle(Theme.text2)
            }
            Spacer(minLength: 0)
        }
        .artCard(tint: advice.urgent ? Theme.danger : Theme.amber)
    }
}

extension Double {
    var profitColor: Color { self >= 0 ? Theme.good : Theme.danger }
}
