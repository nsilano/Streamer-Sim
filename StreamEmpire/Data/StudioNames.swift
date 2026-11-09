import Foundation

enum StudioNames {
    private static let prefixes = ["Lantern", "Northwind", "Copper Hill", "Blue Harbor", "Silverfern", "Red Door",
                                   "Paper Moon", "Ironbridge", "Wildflower", "Skyline", "Maple Street", "Starling"]
    private static let suffixes = ["Pictures", "Studios", "Films", "Productions"]

    static func make(rng: inout SeededRNG) -> String {
        "\(rng.pick(prefixes)) \(rng.pick(suffixes))"
    }
}
