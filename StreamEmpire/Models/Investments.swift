import Foundation

/// A hostile takeover bid in progress.
struct TakeoverBid: Codable, Equatable {
    var rivalID: String
    var premium: Double          // 0.1...1.0 over the market price
    var escrow: Double           // cash set aside for the bid
    var weeksLeft: Int           // shareholders vote when this reaches 0
    var startStake: Double       // your stake when you launched
}
