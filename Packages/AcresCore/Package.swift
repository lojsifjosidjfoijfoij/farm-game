// swift-tools-version: 6.0
//
// AcresCore — the pure-Swift heart of Acres.
//
// Everything in here is platform-neutral Foundation code: the game simulation,
// time/calendar, save files, balancing numbers, world map data and the asset
// manifest. No SpriteKit, SwiftUI or UIKit. That keeps it unit-testable with
// `swift test` on macOS *and* Linux, and lets it fast-forward time for offline
// progress without touching the renderer.

import PackageDescription

let package = Package(
    name: "AcresCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "AcresCore", targets: ["AcresCore"]),
    ],
    targets: [
        .target(name: "AcresCore"),
        // Developer tools, e.g. `swift run acres-tools assets > ../../docs/ASSETS.md`.
        .executableTarget(name: "acres-tools", dependencies: ["AcresCore"]),
        .testTarget(name: "AcresCoreTests", dependencies: ["AcresCore"]),
    ]
)
