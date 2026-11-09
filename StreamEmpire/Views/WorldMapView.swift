import SwiftUI

/// One country outline ready to draw.
struct MapShape {
    let code: String           // "" for scenery countries you can't play
    let name: String
    let path: Path
    let center: CGPoint
}

/// Loads the bundled world map (Natural Earth outlines, public domain) once.
final class WorldMapStore {
    static let shared = WorldMapStore()

    let width: Double
    let height: Double
    let shapes: [MapShape]

    private init() {
        var loaded: [MapShape] = []
        var w = 2000.0, h = 988.0
        if let url = Bundle.main.url(forResource: "world", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let map = try? WorldMap.decode(data) {
            w = Double(map.w)
            h = Double(map.h)
            for country in map.countries {
                var path = Path()
                for ring in country.rings where ring.count >= 6 {
                    path.move(to: CGPoint(x: ring[0], y: ring[1]))
                    var i = 2
                    while i + 1 < ring.count {
                        path.addLine(to: CGPoint(x: ring[i], y: ring[i + 1]))
                        i += 2
                    }
                    path.closeSubpath()
                }
                loaded.append(MapShape(code: country.code, name: country.name, path: path,
                                       center: CGPoint(x: country.cx, y: country.cy)))
            }
        }
        width = w
        height = h
        shapes = loaded
    }
}

enum MapPalette {
    static func fill(_ status: MapStatus?) -> Color {
        switch status {
        case .live: return Theme.teal.opacity(0.85)
        case .launching: return Theme.amber.opacity(0.85)
        case .available: return Theme.violet.opacity(0.60)
        case .locked: return Color(red: 0.55, green: 0.22, blue: 0.34).opacity(0.65)
        case nil: return Color.white.opacity(0.09)
        }
    }

    static func name(_ status: MapStatus) -> String {
        switch status {
        case .live: return "Live"
        case .launching: return "Launching"
        case .available: return "Available"
        case .locked: return "Locked"
        }
    }

    static func color(_ status: MapStatus) -> Color {
        switch status {
        case .live: return Theme.teal
        case .launching: return Theme.amber
        case .available: return Theme.violet
        case .locked: return Color(red: 0.75, green: 0.30, blue: 0.45)
        }
    }
}

/// Pannable, zoomable world map. Countries are colour-coded by launch status; tap one to select it.
struct WorldMapView: View {
    let state: GameState
    @Binding var selected: String?

    @State private var zoom: CGFloat = 1
    @State private var pan: CGSize = .zero
    @GestureState private var liveZoom: CGFloat = 1
    @GestureState private var livePan: CGSize = .zero

    private let map = WorldMapStore.shared

    private func clampedZoom(_ value: CGFloat) -> CGFloat { min(8, max(1, value)) }

    private func transform(size: CGSize, zoom: CGFloat, pan: CGSize) -> CGAffineTransform {
        let total = (size.width / map.width) * zoom
        let tx = (size.width - map.width * total) / 2 + pan.width
        let ty = (size.height - map.height * total) / 2 + pan.height
        return CGAffineTransform(a: total, b: 0, c: 0, d: total, tx: tx, ty: ty)
    }

    private func hit(_ point: CGPoint, transform t: CGAffineTransform) -> String? {
        var best: (String, CGFloat)?
        for shape in map.shapes where !shape.code.isEmpty {
            let p = shape.center.applying(t)
            let distance = hypot(p.x - point.x, p.y - point.y)
            if distance < 20, distance < (best?.1 ?? .infinity) { best = (shape.code, distance) }
        }
        if let best { return best.0 }
        let mapPoint = point.applying(t.inverted())
        for shape in map.shapes where !shape.code.isEmpty && shape.path.contains(mapPoint) { return shape.code }
        return nil
    }

    var body: some View {
        let statuses = Dictionary(uniqueKeysWithValues: CountryData.all.map { ($0.code, state.mapStatus($0.code)) })
        GeometryReader { proxy in
            let size = proxy.size
            let z = clampedZoom(zoom * liveZoom)
            let p = CGSize(width: pan.width + livePan.width, height: pan.height + livePan.height)
            let t = transform(size: size, zoom: z, pan: p)

            ZStack(alignment: .bottomTrailing) {
                Canvas { context, canvasSize in
                    drawMap(&context, transform: t, zoom: z, statuses: statuses)
                    _ = canvasSize
                }
                .contentShape(Rectangle())
                .gesture(
                    SpatialTapGesture().onEnded { value in
                        if let code = hit(value.location, transform: t) { selected = code }
                    }
                )
                .gesture(
                    DragGesture(minimumDistance: 6)
                        .updating($livePan) { value, gestureState, _ in gestureState = value.translation }
                        .onEnded { value in
                            pan = CGSize(width: pan.width + value.translation.width,
                                         height: pan.height + value.translation.height)
                        }
                )
                .gesture(
                    MagnifyGesture()
                        .updating($liveZoom) { value, gestureState, _ in gestureState = value.magnification }
                        .onEnded { value in zoom = clampedZoom(zoom * value.magnification) }
                )

                VStack(spacing: 8) {
                    mapButton("plus") { withAnimation { zoom = clampedZoom(zoom * 1.6) } }
                    mapButton("minus") { withAnimation { zoom = clampedZoom(zoom / 1.6) } }
                    mapButton("scope") { withAnimation { zoom = 1; pan = .zero } }
                }
                .padding(10)
            }
        }
    }

    private func mapButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.subheadline.weight(.bold)).foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Color.black.opacity(0.45)))
                .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 0.5))
        }
    }

    private func drawMap(_ context: inout GraphicsContext, transform t: CGAffineTransform, zoom: CGFloat,
                         statuses: [String: MapStatus]) {
        for shape in map.shapes {
            let path = shape.path.applying(t)
            let status = shape.code.isEmpty ? nil : statuses[shape.code]
            context.fill(path, with: .color(MapPalette.fill(status)))
            let isSelected = !shape.code.isEmpty && shape.code == selected
            context.stroke(path, with: .color(isSelected ? Color.white : Color.white.opacity(0.18)),
                           lineWidth: isSelected ? 1.6 : 0.5)
        }
        for shape in map.shapes where !shape.code.isEmpty {
            guard let status = statuses[shape.code] else { continue }
            let center = shape.center.applying(t)
            let radius: CGFloat = 3.2 + min(zoom, 3) * 0.9
            let dot = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
            context.fill(Path(ellipseIn: dot), with: .color(MapPalette.color(status)))
            context.stroke(Path(ellipseIn: dot), with: .color(Color.white.opacity(0.85)), lineWidth: 1)
            if shape.code == selected {
                let ring = dot.insetBy(dx: -4, dy: -4)
                context.stroke(Path(ellipseIn: ring), with: .color(Color.white), lineWidth: 1.5)
            }
            if zoom >= 2.4 || shape.code == selected {
                let label = Text(CountryData.country(shape.code)?.name ?? shape.name)
                    .font(.system(size: 9, weight: .bold)).foregroundStyle(Color.white)
                context.draw(label, at: CGPoint(x: center.x, y: center.y - radius - 8))
            }
        }
    }
}
