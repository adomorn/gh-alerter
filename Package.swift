// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GHAlerter",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "GHAlerter", targets: ["GHAlerterApp"]),
        .library(name: "GHAlerterCore", targets: ["GHAlerterCore"])
    ],
    targets: [
        .executableTarget(
            name: "GHAlerterApp",
            dependencies: ["GHAlerterCore"],
            resources: [.process("Resources")]
        ),
        .target(name: "GHAlerterCore"),
        .testTarget(
            name: "GHAlerterCoreTests",
            dependencies: ["GHAlerterCore"]
        )
    ]
)
