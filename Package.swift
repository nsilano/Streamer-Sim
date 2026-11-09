// swift-tools-version: 5.9
// Headless build of the pure-Swift game core (no UI). Lets the simulation be
// compiled and unit-tested on any OS: `swift test`.
// The iOS app itself is generated from project.yml with XcodeGen.
import PackageDescription

let package = Package(
    name: "StreamEmpireCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "StreamEmpireCore", targets: ["StreamEmpireCore"])],
    targets: [
        .target(
            name: "StreamEmpireCore",
            path: "StreamEmpire",
            sources: ["Models", "Engine", "Data", "Persistence"]
        ),
        .testTarget(
            name: "StreamEmpireCoreTests",
            dependencies: ["StreamEmpireCore"],
            path: "StreamEmpireTests"
        ),
    ]
)
