// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "VibeWave",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "VibeWave",
            targets: ["VibeWave"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift", from: "6.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "VibeWave",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
            ],
            exclude: [
                "Resources/Info.plist"
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "VibeWaveTests",
            dependencies: ["VibeWave"],
            path: "VibeWaveTests"
        )
    ]
)
