// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "RecentMessagesDatabaseCheck",
    platforms: [
        .macOS("26.0")
    ],
    products: [
        .executable(
            name: "RecentMessagesDatabaseCheck",
            targets: ["RecentMessagesDatabaseCheck"]
        )
    ],
    dependencies: [
        .package(path: "../..")
    ],
    targets: [
        .executableTarget(
            name: "RecentMessagesDatabaseCheck",
            dependencies: [
                .product(name: "AppMessageKit", package: "AppMessageKit")
            ]
        ),
        .testTarget(
            name: "RecentMessagesDatabaseCheckTests",
            dependencies: ["RecentMessagesDatabaseCheck"]
        )
    ]
)
