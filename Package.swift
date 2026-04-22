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
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
        .package(url: "https://github.com/FluidInference/FluidAudio.git", exact: "0.13.6"),
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
