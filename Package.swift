// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Nameplate",
    platforms: [
        .macOS(.v15),
    ],
    targets: [
        .target(
            name: "NameplateCore",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
            ]),
        .executableTarget(
            name: "Nameplate",
            dependencies: [
                "NameplateCore",
            ],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
            ]),
        .testTarget(
            name: "NameplateCoreTests",
            dependencies: ["NameplateCore"],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
            ]),
    ])
