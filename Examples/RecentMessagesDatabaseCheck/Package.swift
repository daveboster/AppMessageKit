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
        .package(url: "https://github.com/daveboster/AppMessageKit.git", exact: "0.1.0-alpha.3")
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
