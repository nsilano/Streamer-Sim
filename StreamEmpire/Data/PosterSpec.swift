import Foundation

struct PosterColor: Equatable {
    var r: Double
    var g: Double
    var b: Double
    init(_ hex: UInt32) {
        r = Double((hex >> 16) & 0xFF) / 255
        g = Double((hex >> 8) & 0xFF) / 255
        b = Double(hex & 0xFF) / 255
    }
}

enum PosterMotif: String, CaseIterable {
    case figure, confetti, slashes, blobs, burst, frames, landscape, pattern
}

/// Everything needed to draw a title's cover art, derived deterministically from the title.
/// Pure data (no SwiftUI) so it can be unit-tested; `PosterView` turns it into pixels.
struct PosterSpec: Equatable {
    var motif: PosterMotif
    var palette: [PosterColor]      // [top, bottom, accent]
    var seeds: [Double]             // 8 numbers in 0..<1 that position shapes
    var tagline: String
    var titleLines: [String]
    var badge: String?

    static func motif(for genre: Genre) -> PosterMotif {
        switch genre {
        case .drama: return .figure
        case .comedy: return .confetti
        case .action: return .slashes
        case .kids: return .blobs
        case .anime: return .burst
        case .reality: return .frames
        case .docs: return .landscape
        case .local: return .pattern
        }
    }

    private static let palettes: [Genre: [[UInt32]]] = [
        .drama: [[0x1B1035, 0x6B2D5C, 0xF2B880], [0x0E1B3D, 0x3A4F8C, 0xE8C9A0], [0x2A0F1E, 0x8C2F39, 0xF5D0A9]],
        .comedy: [[0xFF9A3C, 0xFF3D81, 0xFFF176], [0x00C2A8, 0x3D5AFE, 0xFFEB3B], [0xFF6F91, 0xFFC75F, 0x845EC2]],
        .action: [[0x120B0B, 0xD62828, 0xFCBF49], [0x0B132B, 0x1C7CD6, 0xF77F00], [0x1A1A1A, 0xE85D04, 0xFFBA08]],
        .kids: [[0x6EC6FF, 0xB388FF, 0xFFEB3B], [0xFFB74D, 0xF06292, 0x80DEEA], [0x81C784, 0x4FC3F7, 0xFFF59D]],
        .anime: [[0x2B1055, 0xFF4F8B, 0xFFE66D], [0x0F2027, 0x2C5364, 0xFF6B6B], [0x3A1C71, 0xD76D77, 0xFFAF7B]],
        .reality: [[0x0F0C29, 0x302B63, 0xFF2E93], [0x141E30, 0x243B55, 0x00F5D4], [0x1F1C2C, 0x928DAB, 0xFFD166]],
        .docs: [[0x283E51, 0x4B79A1, 0xF4D58D], [0x2C3E2F, 0x7A9E7E, 0xF3E9D2], [0x3D2C1E, 0xB08968, 0xFFE8D6]],
        .local: [[0x42275A, 0x734B6D, 0xF9D423], [0x134E5E, 0x71B280, 0xFFE29F], [0x7B4397, 0xDC2430, 0xFFE259]],
    ]

    private static let taglines: [Genre: [String]] = [
        .drama: ["Some secrets refuse to stay buried.", "Every family has a breaking point.", "Love. Loss. Consequence.", "The truth costs everything."],
        .comedy: ["Nobody planned this. Everybody regrets it.", "Chaos, but make it funny.", "Good friends. Bad decisions.", "Laugh now, apologize later."],
        .action: ["There is no way back.", "One mission. Zero mercy.", "The clock is already ticking.", "Run. Fight. Survive."],
        .kids: ["A big adventure for little heroes.", "Friendship is the best magic.", "Ready, set, wonder!", "Every day is a new discovery."],
        .anime: ["A legend awakens.", "Their destiny burns brighter.", "Beyond the horizon, a new power.", "The final battle begins."],
        .reality: ["Real people. Real drama.", "Only one will win.", "Nothing is scripted. Almost.", "Trust no one."],
        .docs: ["The story behind the story.", "A world you have never seen.", "What really happened?", "Inside the unbelievable."],
        .local: ["A story from home.", "Rooted in tradition. Alive today.", "Where we come from.", "Told in our own voice."],
    ]

    static func make(for title: Title) -> PosterSpec {
        var rng = SeededRNG(seed: UInt64(truncatingIfNeeded: title.id) &* 0x9E37_79B9_7F4A_7C15 &+ 12_345)
        let options = palettes[title.genre] ?? palettes[.drama]!
        let palette = rng.pick(options).map { PosterColor($0) }
        let seeds = (0..<8).map { _ in rng.nextDouble() }
        let tagline = rng.pick(taglines[title.genre] ?? ["Coming soon."])

        var badge: String?
        if title.isOriginal { badge = "ORIGINAL" }
        else if title.sought { badge = "ICONIC" }
        else if title.license?.exclusive == true { badge = "EXCLUSIVE" }
        else if title.ageWeeks < 4 { badge = "NEW" }

        return PosterSpec(motif: motif(for: title.genre), palette: palette, seeds: seeds, tagline: tagline,
                          titleLines: wrap(title.name), badge: badge)
    }

    /// Greedy word wrap for the poster title treatment.
    static func wrap(_ name: String, maxChars: Int = 11, maxLines: Int = 3) -> [String] {
        var lines: [String] = []
        var current = ""
        for word in name.split(separator: " ").map(String.init) {
            if current.isEmpty {
                current = word
            } else if current.count + 1 + word.count <= maxChars {
                current += " " + word
            } else {
                lines.append(current)
                current = word
            }
        }
        if !current.isEmpty { lines.append(current) }
        if lines.count > maxLines {
            let tail = lines[(maxLines - 1)...].joined(separator: " ")
            lines = Array(lines[..<(maxLines - 1)]) + [tail]
        }
        return lines
    }
}
