import SwiftUI
import Foundation

/// Procedurally generated movie-poster cover art for a title. Every title gets its own artwork,
/// styled by genre (see `PosterSpec`).
struct PosterView: View {
    let title: Title
    var showsText = true
    var cornerRadius: CGFloat = 12

    var body: some View {
        let spec = PosterSpec.make(for: title)
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack {
                LinearGradient(colors: [color(spec.palette[0]), color(spec.palette[1])], startPoint: .top, endPoint: .bottom)
                Canvas { context, size in
                    PosterArt.draw(spec, in: &context, size: size)
                }
                LinearGradient(colors: [Color.clear, Color.black.opacity(0.75)], startPoint: .center, endPoint: .bottom)
                if showsText {
                    VStack(alignment: .leading, spacing: 0) {
                        if let badge = spec.badge {
                            Text(badge)
                                .font(.system(size: max(7, width * 0.06), weight: .heavy))
                                .tracking(1)
                                .padding(.horizontal, width * 0.04)
                                .padding(.vertical, width * 0.015)
                                .background(Capsule().fill(color(spec.palette[2])))
                                .foregroundStyle(Color.black.opacity(0.85))
                        }
                        Spacer(minLength: 0)
                        ForEach(Array(spec.titleLines.enumerated()), id: \.offset) { _, line in
                            Text(line.uppercased())
                                .font(.system(size: width * 0.125, weight: .black, design: .serif))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                .shadow(color: .black.opacity(0.6), radius: 2, y: 1)
                        }
                        Text(spec.tagline)
                            .font(.system(size: width * 0.052, weight: .medium, design: .serif).italic())
                            .foregroundStyle(.white.opacity(0.8))
                            .lineLimit(2)
                            .padding(.top, width * 0.02)
                        Text("\(title.genre.displayName) · \(title.kind.displayName)".uppercased())
                            .font(.system(size: width * 0.045, weight: .bold))
                            .tracking(1.2)
                            .foregroundStyle(color(spec.palette[2]))
                            .padding(.top, width * 0.02)
                    }
                    .padding(width * 0.07)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1))
            .shadow(color: color(spec.palette[1]).opacity(0.5), radius: 8, y: 4)
        }
        .aspectRatio(2.0 / 3.0, contentMode: .fit)
    }

    private func color(_ c: PosterColor) -> Color { Color(red: c.r, green: c.g, blue: c.b) }
}

/// The shapes behind each genre's motif.
enum PosterArt {
    private static func color(_ c: PosterColor, _ opacity: Double = 1) -> Color {
        Color(red: c.r, green: c.g, blue: c.b).opacity(opacity)
    }

    /// Deterministic pseudo-random number in 0..<1 from a seed and an index.
    private static func noise(_ seed: Double, _ index: Int) -> Double {
        let v = sin(Double(index) * 12.9898 + seed * 78.233) * 43_758.5453
        return v - v.rounded(.down)
    }

    static func draw(_ spec: PosterSpec, in context: inout GraphicsContext, size: CGSize) {
        switch spec.motif {
        case .figure: figure(spec, &context, size)
        case .confetti: confetti(spec, &context, size)
        case .slashes: slashes(spec, &context, size)
        case .blobs: blobs(spec, &context, size)
        case .burst: burst(spec, &context, size)
        case .frames: frames(spec, &context, size)
        case .landscape: landscape(spec, &context, size)
        case .pattern: pattern(spec, &context, size)
        }
    }

    private static func figure(_ spec: PosterSpec, _ ctx: inout GraphicsContext, _ size: CGSize) {
        let s = spec.seeds
        let w = size.width, h = size.height
        let r = w * (0.14 + 0.10 * s[0])
        let center = CGPoint(x: w * (0.3 + 0.4 * s[1]), y: h * (0.20 + 0.10 * s[2]))
        ctx.fill(Path(ellipseIn: CGRect(x: center.x - r * 1.9, y: center.y - r * 1.9, width: r * 3.8, height: r * 3.8)),
                 with: .color(color(spec.palette[2], 0.16)))
        ctx.fill(Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)),
                 with: .color(color(spec.palette[2], 0.92)))
        for layer in 0..<3 {
            var path = Path()
            path.move(to: CGPoint(x: 0, y: h))
            let base = 0.50 + 0.10 * Double(layer)
            for step in 0...6 {
                let x = w * Double(step) / 6
                let y = h * (base + 0.13 * noise(s[3] + Double(layer), step))
                path.addLine(to: CGPoint(x: x, y: y))
            }
            path.addLine(to: CGPoint(x: w, y: h))
            path.closeSubpath()
            ctx.fill(path, with: .color(Color.black.opacity(0.25 + 0.2 * Double(layer))))
        }
        // A lone figure.
        let fx = w * (0.3 + 0.4 * s[4])
        let fy = h * 0.70
        ctx.fill(Path(ellipseIn: CGRect(x: fx - w * 0.03, y: fy - w * 0.10, width: w * 0.06, height: w * 0.06)),
                 with: .color(Color.black.opacity(0.88)))
        ctx.fill(Path(roundedRect: CGRect(x: fx - w * 0.04, y: fy - w * 0.04, width: w * 0.08, height: w * 0.2),
                      cornerRadius: w * 0.03), with: .color(Color.black.opacity(0.88)))
    }

    private static func confetti(_ spec: PosterSpec, _ ctx: inout GraphicsContext, _ size: CGSize) {
        let w = size.width, h = size.height
        for i in 0..<24 {
            let x = w * noise(spec.seeds[0], i * 3 + 1)
            let y = h * 0.8 * noise(spec.seeds[1], i * 3 + 2)
            let d = w * (0.05 + 0.13 * noise(spec.seeds[2], i * 3 + 3))
            let tint = color(spec.palette[i % 3], 0.85)
            switch i % 3 {
            case 0:
                ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: d, height: d)), with: .color(tint))
            case 1:
                ctx.fill(Path(roundedRect: CGRect(x: x, y: y, width: d, height: d * 0.6), cornerRadius: d * 0.2),
                         with: .color(tint))
            default:
                var tri = Path()
                tri.move(to: CGPoint(x: x, y: y + d))
                tri.addLine(to: CGPoint(x: x + d / 2, y: y))
                tri.addLine(to: CGPoint(x: x + d, y: y + d))
                tri.closeSubpath()
                ctx.fill(tri, with: .color(tint))
            }
        }
    }

    private static func slashes(_ spec: PosterSpec, _ ctx: inout GraphicsContext, _ size: CGSize) {
        let w = size.width, h = size.height
        for i in 0..<6 {
            let offset = w * (Double(i) * 0.32 - 0.4 + 0.1 * spec.seeds[i % 8])
            var path = Path()
            path.move(to: CGPoint(x: offset, y: h))
            path.addLine(to: CGPoint(x: offset + w * 0.22, y: h))
            path.addLine(to: CGPoint(x: offset + w * 0.22 + w * 0.7, y: 0))
            path.addLine(to: CGPoint(x: offset + w * 0.7, y: 0))
            path.closeSubpath()
            ctx.fill(path, with: .color(color(spec.palette[i % 2 == 0 ? 2 : 1], i % 2 == 0 ? 0.85 : 0.5)))
        }
        let center = CGPoint(x: w * (0.35 + 0.3 * spec.seeds[6]), y: h * 0.32)
        ctx.fill(Path(ellipseIn: CGRect(x: center.x - w * 0.14, y: center.y - w * 0.14, width: w * 0.28, height: w * 0.28)),
                 with: .color(Color.white.opacity(0.85)))
    }

    private static func blobs(_ spec: PosterSpec, _ ctx: inout GraphicsContext, _ size: CGSize) {
        let w = size.width, h = size.height
        for i in 0..<5 {
            let d = w * (0.35 + 0.35 * noise(spec.seeds[0], i))
            let x = (w - d) * noise(spec.seeds[1], i + 10)
            let y = h * 0.6 * noise(spec.seeds[2], i + 20)
            ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: d, height: d * (0.8 + 0.3 * noise(spec.seeds[3], i)))),
                     with: .color(color(spec.palette[i % 3], 0.55)))
        }
        for i in 0..<14 {
            let d = w * (0.015 + 0.03 * noise(spec.seeds[4], i))
            ctx.fill(Path(ellipseIn: CGRect(x: w * noise(spec.seeds[5], i + 30), y: h * 0.7 * noise(spec.seeds[6], i + 40), width: d, height: d)),
                     with: .color(Color.white.opacity(0.9)))
        }
    }

    private static func burst(_ spec: PosterSpec, _ ctx: inout GraphicsContext, _ size: CGSize) {
        let w = size.width, h = size.height
        let center = CGPoint(x: w * (0.35 + 0.3 * spec.seeds[0]), y: h * 0.33)
        let reach = max(w, h) * 1.3
        for i in 0..<26 {
            let a0 = Double(i) / 26 * 2 * Double.pi
            let a1 = a0 + Double.pi / 26
            var path = Path()
            path.move(to: center)
            let cos0 = CGFloat(Foundation.cos(a0)), sin0 = CGFloat(Foundation.sin(a0))
            let cos1 = CGFloat(Foundation.cos(a1)), sin1 = CGFloat(Foundation.sin(a1))
            path.addLine(to: CGPoint(x: center.x + cos0 * reach, y: center.y + sin0 * reach))
            path.addLine(to: CGPoint(x: center.x + cos1 * reach, y: center.y + sin1 * reach))
            path.closeSubpath()
            ctx.fill(path, with: .color(color(spec.palette[2], i % 2 == 0 ? 0.20 : 0.05)))
        }
        let r = w * 0.17
        ctx.fill(Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)),
                 with: .color(color(spec.palette[2], 0.95)))
    }

    private static func frames(_ spec: PosterSpec, _ ctx: inout GraphicsContext, _ size: CGSize) {
        let w = size.width, h = size.height
        for i in 0..<5 {
            let inset = w * (0.06 + 0.09 * Double(i))
            let rect = CGRect(x: inset, y: inset * 1.2, width: w - 2 * inset, height: h * 0.7 - inset * 1.4)
            ctx.stroke(Path(roundedRect: rect, cornerRadius: w * 0.08),
                       with: .color(color(spec.palette[i % 3], 0.35 + 0.1 * Double(i))), lineWidth: 2.5)
        }
        for i in 0..<18 {
            let y = h * Double(i) / 18
            ctx.fill(Path(CGRect(x: 0, y: y, width: w, height: 1)), with: .color(Color.white.opacity(0.06)))
        }
    }

    private static func landscape(_ spec: PosterSpec, _ ctx: inout GraphicsContext, _ size: CGSize) {
        let w = size.width, h = size.height
        let r = w * 0.15
        let sun = CGPoint(x: w * (0.3 + 0.4 * spec.seeds[0]), y: h * 0.28)
        ctx.fill(Path(ellipseIn: CGRect(x: sun.x - r, y: sun.y - r, width: r * 2, height: r * 2)),
                 with: .color(color(spec.palette[2], 0.95)))
        for layer in 0..<3 {
            var path = Path()
            path.move(to: CGPoint(x: 0, y: h))
            let base = 0.52 + 0.10 * Double(layer)
            for step in 0...24 {
                let x = w * Double(step) / 24
                let wave = sin(Double(step) * 0.5 + spec.seeds[layer + 1] * 6) * 0.04
                path.addLine(to: CGPoint(x: x, y: h * (base + wave)))
            }
            path.addLine(to: CGPoint(x: w, y: h))
            path.closeSubpath()
            ctx.fill(path, with: .color(Color.black.opacity(0.18 + 0.18 * Double(layer))))
        }
    }

    private static func pattern(_ spec: PosterSpec, _ ctx: inout GraphicsContext, _ size: CGSize) {
        let w = size.width, h = size.height
        let cell = w / 4
        for row in 0..<7 {
            for col in 0..<5 {
                let cx = Double(col) * cell + (row % 2 == 0 ? 0 : cell / 2)
                let cy = Double(row) * cell * 0.6
                var diamond = Path()
                diamond.move(to: CGPoint(x: cx, y: cy - cell * 0.3))
                diamond.addLine(to: CGPoint(x: cx + cell * 0.3, y: cy))
                diamond.addLine(to: CGPoint(x: cx, y: cy + cell * 0.3))
                diamond.addLine(to: CGPoint(x: cx - cell * 0.3, y: cy))
                diamond.closeSubpath()
                ctx.fill(diamond, with: .color(color(spec.palette[(row + col) % 3], (row + col) % 2 == 0 ? 0.55 : 0.25)))
            }
        }
        _ = h
    }
}
