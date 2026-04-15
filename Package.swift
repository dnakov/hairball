// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Hairball",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
    ],
    products: [
        .library(name: "Hairball", targets: ["Hairball"]),
        .library(name: "HairballUI", targets: ["HairballUI"]),
        .executable(name: "hairball-fixture-exporter", targets: ["HairballFixtureExporter"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-markdown.git", from: "0.4.0"),
        .package(url: "https://github.com/mgriebling/SwiftMath.git", from: "1.3.5"),
        .package(url: "https://github.com/raspu/Highlightr.git", from: "2.2.1"),
    ],
    targets: [
        .target(
            name: "Hairball",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown"),
            ]
        ),
        .target(
            name: "HairballUI",
            dependencies: [
                "Hairball",
                .product(name: "SwiftMath", package: "SwiftMath"),
                .product(name: "Highlightr", package: "Highlightr"),
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "HairballTests",
            dependencies: ["Hairball", "HairballUI"]
        ),
        .executableTarget(
            name: "HairballFixtureExporter",
            dependencies: ["Hairball"],
            path: "scripts/fixture-exporter"
        ),
    ]
)
