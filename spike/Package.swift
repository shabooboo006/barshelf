// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "BarShelfSpike",
    platforms: [.macOS("26.0")],
    targets: [
        .target(
            name: "CSkyLight",
            publicHeadersPath: "include"
        ),
        .executableTarget(
            name: "BarShelfSpike",
            dependencies: ["CSkyLight"],
            linkerSettings: [
                .unsafeFlags([
                    "-F", "/System/Library/PrivateFrameworks",
                    "-framework", "SkyLight",
                ])
            ]
        ),
    ]
)
