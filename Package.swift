// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "Scanner",
    defaultLocalization: "en",
    platforms: [.iOS(.v13)],
    products: [
        .library(
            name: "Scanner",
            targets: [
                "Scanner", "CardScanner", "QRScanner", "BarScanner",
            ]
        )
    ],
    targets: [
        .target(
            name: "Scanner",
            dependencies: []
        ),
        .target(
            name: "Localization",
            dependencies: [],
            resources: [.process("Resources")]
        ),
        .target(
            name: "CardScanner",
            dependencies: ["Scanner", "Extensions", "Localization"]
        ),
        .target(
            name: "QRScanner",
            dependencies: ["Scanner", "Localization"]
        ),
        .target(
            name: "BarScanner",
            dependencies: ["Scanner", "Localization"]
        ),
        .target(
            name: "Extensions",
            dependencies: ["Scanner"]
        ),
        .testTarget(
            name: "ScannerTests",
            dependencies: ["Scanner", "CardScanner", "QRScanner", "BarScanner"]
        ),
    ]
)
