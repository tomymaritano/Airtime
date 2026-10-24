// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "DevWifiBar",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(name: "DevWifiCore", targets: ["DevWifiCore"]),
        .library(name: "DevWifiUI", targets: ["DevWifiUI"]),
        .executable(name: "DevWifiBar", targets: ["DevWifiBar"]),
    ],
    targets: [
        .target(
            name: "DevWifiCore",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
            ]
        ),
        .target(
            name: "DevWifiUI",
            dependencies: ["DevWifiCore"],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
            ]
        ),
        .executableTarget(
            name: "DevWifiBar",
            dependencies: ["DevWifiCore", "DevWifiUI"],
            exclude: ["Info.plist", "DevWifiBar.entitlements"],
            resources: [
                .process("Resources"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
            ]
        ),
        .testTarget(
            name: "DevWifiCoreTests",
            dependencies: ["DevWifiCore"],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
            ]
        ),
    ]
)
