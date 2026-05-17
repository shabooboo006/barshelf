// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BarShelf",
    platforms: [.macOS("26.0")],
    targets: [
        .target(name: "BarShelfCore"),
        .target(name: "BarShelfCoreTestSupport", dependencies: ["BarShelfCore"]),
        .target(name: "BarShelfBackend", dependencies: ["BarShelfCore"]),
        .target(name: "BarShelfUIKit", dependencies: ["BarShelfCore"]),
        .executableTarget(
            name: "BarShelf",
            dependencies: ["BarShelfCore", "BarShelfBackend", "BarShelfUIKit"],
            exclude: ["Info.plist"],
            resources: [.copy("Resources")],
            // unsafeFlags is acceptable here: BarShelf is a top-level executable, never consumed as a package dependency (where unsafeFlags would be rejected).
            linkerSettings: [
                // Embed Info.plist (LSUIElement agent) into the binary's
                // __TEXT,__info_plist section — standard macOS technique for
                // non-bundle executables; SwiftPM forbids declaring Info.plist
                // as a resource (it reserves the name), so we embed it here.
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Sources/BarShelf/Info.plist",
                ]),
            ]),
        .testTarget(name: "BarShelfCoreTests", dependencies: ["BarShelfCore", "BarShelfCoreTestSupport"]),
        .testTarget(name: "BarShelfBackendTests", dependencies: ["BarShelfBackend", "BarShelfCoreTestSupport"]),
        .testTarget(name: "BarShelfUIKitTests", dependencies: ["BarShelfUIKit", "BarShelfCoreTestSupport"]),
    ]
)
