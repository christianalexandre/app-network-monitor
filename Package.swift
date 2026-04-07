// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AppNetworkMonitor",
    platforms: [
        .iOS(.v15),
    ],
    products: [
        .library(
            name: "AppNetworkMonitor",
            targets: ["AppNetworkMonitor"]),
    ],
    dependencies: [
        .package(url: "https://github.com/kean/Pulse.git", from: "4.0.0"),
    ],
    targets: [
        .target(
            name: "AppNetworkMonitor",
            dependencies: [
                .product(name: "Pulse", package: "Pulse"),
                .product(name: "PulseUI", package: "Pulse")
            ],
            swiftSettings: [
                .define("APPNETWORKMONITOR_ENABLED", .when(configuration: .debug))
            ]
        ),
        .testTarget(
            name: "AppNetworkMonitorTests",
            dependencies: ["AppNetworkMonitor"]),
    ]
)
