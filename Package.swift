// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BarShelf",
    platforms: [.macOS("26.0")],
    targets: [
        .target(name: "BarShelfCore"),
        .executableTarget(
            name: "BarShelf",
            dependencies: ["BarShelfCore"],
            exclude: ["Info.plist"],
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
        .testTarget(name: "BarShelfCoreTests", dependencies: ["BarShelfCore"]),
    ]
)
