import Foundation

/// One country outline in map coordinates (an equirectangular-ish Miller projection, `w` x `h` units).
struct WorldCountry: Codable, Equatable {
    let code: String        // ISO code for the playable countries, "" for scenery
    let name: String
    let rings: [[Int]]      // each ring is a flat [x0, y0, x1, y1, ...] list
    let cx: Int             // label / marker position
    let cy: Int
}

struct WorldMap: Codable, Equatable {
    let w: Int
    let h: Int
    let countries: [WorldCountry]

    static func decode(_ data: Data) throws -> WorldMap {
        try JSONDecoder().decode(WorldMap.self, from: data)
    }

    var playable: [WorldCountry] { countries.filter { !$0.code.isEmpty } }
}

/// How a country looks on the Markets map.
enum MapStatus: String, Equatable {
    case live, launching, available, locked
}
