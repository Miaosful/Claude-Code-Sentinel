// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CCSentinel",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "CCSentinelCore", targets: ["CCSentinelCore"]),
        .executable(name: "CCSentinelApp", targets: ["CCSentinelApp"]),
        .executable(name: "CCSentinelCoreTestRunner", targets: ["CCSentinelCoreTestRunner"]),
        .executable(name: "cc-sentinel-debug-receiver", targets: ["CCSentinelDebugReceiver"]),
        .executable(name: "cc-sentinel-dump-state", targets: ["CCSentinelDumpState"]),
        .executable(name: "cc-sentinel-hook", targets: ["CCSentinelHook"]),
        .executable(name: "cc-sentinel-wrapper", targets: ["CCSentinelWrapper"])
    ],
    targets: [
        .target(name: "CCSentinelCore"),
        .executableTarget(
            name: "CCSentinelApp",
            dependencies: ["CCSentinelCore"],
            resources: [.process("Resources")]
        ),
        .executableTarget(name: "CCSentinelCoreTestRunner", dependencies: ["CCSentinelCore"]),
        .executableTarget(name: "CCSentinelDebugReceiver", dependencies: ["CCSentinelCore"]),
        .executableTarget(name: "CCSentinelDumpState", dependencies: ["CCSentinelCore"]),
        .executableTarget(name: "CCSentinelHook", dependencies: ["CCSentinelCore"]),
        .executableTarget(name: "CCSentinelWrapper", dependencies: ["CCSentinelCore"])
    ]
)
