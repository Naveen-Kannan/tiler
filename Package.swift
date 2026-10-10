// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "tiler",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "Tiler", targets: ["Tiler"]),
    ],
    targets: [
        .target(name: "Tiler", path: "Sources/Tiler"),
        .testTarget(name: "TilerTests", dependencies: ["Tiler"]),
    ]
)
