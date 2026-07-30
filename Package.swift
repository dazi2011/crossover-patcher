// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "MingchaoPatcher",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "MingchaoPatcher", targets: ["MingchaoPatcher"]),
        .library(name: "PatcherProtocol", targets: ["PatcherProtocol"]),
    ],
    targets: [
        .target(
            name: "PatcherProtocol",
            path: "Sources/PatcherProtocol"
        ),
        .executableTarget(
            name: "MingchaoPatcher",
            dependencies: ["PatcherProtocol"],
            path: "Sources/MingchaoPatcher"
        ),
        .testTarget(
            name: "MingchaoPatcherTests",
            dependencies: ["MingchaoPatcher", "PatcherProtocol"],
            path: "Tests/MingchaoPatcherTests"
        ),
    ]
)
