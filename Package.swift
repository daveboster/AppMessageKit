// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "AppMessageKit",
    platforms: [
        .macOS("26.0")
    ],
    products: [
        .library(name: "AppMessageKit", targets: ["AppMessageKit"])
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.10.0")
    ],
    targets: [
        .target(
            name: "AppMessageKit",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift")
            ]
        ),
        .testTarget(
            name: "AppMessageKitTests",
            dependencies: ["AppMessageKit"]
        ),
        .testTarget(
            name: "AppMessageKitIntegrationTests",
            dependencies: ["AppMessageKit"]
        )
    ]
)
