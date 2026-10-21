// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ez-secret",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "ez-secret", targets: ["ez-secret"]),
        .library(name: "EzSecretCore", targets: ["EzSecretCore"]),
    ],
    targets: [
        .target(
            name: "EzSecretCore",
            path: "Sources/EzSecretCore"
        ),
        .executableTarget(
            name: "ez-secret",
            dependencies: ["EzSecretCore"],
            path: "Sources/ez-secret"
        ),
        .testTarget(
            name: "EzSecretCoreTests",
            dependencies: ["EzSecretCore"],
            path: "Tests/EzSecretCoreTests"
        ),
    ]
)
