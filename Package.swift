// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "FluidTranscription",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(
            name: "FluidTranscriptionCLI",
            targets: ["FluidTranscriptionCLI"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.8.2"),
        .package(url: "https://github.com/FluidInference/FluidAudio.git", exact: "0.15.5"),
    ],
    targets: [
        .executableTarget(
            name: "FluidTranscriptionCLI",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "FluidAudio", package: "FluidAudio"),
            ]
        ),
    ]
)
