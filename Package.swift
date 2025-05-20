// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "Scanner",
    platforms: [.iOS(.v13)],
    products: [
        .library(
            name: "Scanner",
            targets: ["Scanner", "CardScanner", "QRScanner", "BarScanner"]
        )
    ],
    targets: [
        .target(
            name: "Scanner",
            dependencies: []
        ),
        .target(
            name: "CardScanner",
            dependencies: ["Scanner"]
        ),
        .target(
            name: "QRScanner",
            dependencies: ["Scanner"]
        ),
        .target(
            name: "BarScanner",
            dependencies: ["Scanner"]
        ),
        .testTarget(
            name: "ScannerTests",
            dependencies: ["Scanner", "CardScanner", "QRScanner", "BarScanner"]
        ),
    ]
)
