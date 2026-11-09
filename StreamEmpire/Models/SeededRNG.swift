import Foundation

/// SplitMix64 generator. Deterministic for a given seed and Codable, so the
/// RNG state can live inside `GameState` (reproducible runs and saves).
struct SeededRNG: RandomNumberGenerator, Codable, Equatable {
    private(set) var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Uniform in [0, 1).
    mutating func nextDouble() -> Double {
        Double(next() >> 11) / 9_007_199_254_740_992.0
    }

    mutating func nextDouble(in range: ClosedRange<Double>) -> Double {
        range.lowerBound + nextDouble() * (range.upperBound - range.lowerBound)
    }

    mutating func nextInt(in range: ClosedRange<Int>) -> Int {
        let span = UInt64(range.upperBound - range.lowerBound + 1)
        return range.lowerBound + Int(next() % span)
    }

    mutating func chance(_ probability: Double) -> Bool {
        nextDouble() < probability
    }

    mutating func pick<T>(_ items: [T]) -> T {
        items[nextInt(in: 0...(items.count - 1))]
    }

    /// Picks an item with probability proportional to its weight.
    mutating func pickWeighted<T>(_ items: [(T, Double)]) -> T {
        let total = items.reduce(0) { $0 + $1.1 }
        var roll = nextDouble() * total
        for (item, weight) in items {
            roll -= weight
            if roll <= 0 { return item }
        }
        return items[items.count - 1].0
    }

    // JSON-safe: store the 64-bit state as a string.
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let text = try container.decode(String.self)
        state = UInt64(text) ?? 1
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(String(state))
    }
}
