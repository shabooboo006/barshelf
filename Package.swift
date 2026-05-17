// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BarShelf",
    platforms: [.macOS("26.0")],
    targets: [
        .target(name: "BarShelfCore"),
        .executableTarget(
            name: "BarShelf",
            dependencies: ["BarShelfCore"]),
        .testTarget(name: "BarShelfCoreTests", dependencies: ["BarShelfCore"]),
    ]
)
