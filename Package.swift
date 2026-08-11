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
        // 6.3.x requires _TestingInterop outside the default Command Line Tools linker path.
        .package(url: "https://github.com/swiftlang/swift-testing.git", "6.2.4"..<"6.3.0"),
    ],
    targets: [
        .executableTarget(
            name: "FluidTranscriptionCLI",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "FluidAudio", package: "FluidAudio"),
            ]
        ),
        .testTarget(
            name: "FluidTranscriptionCLITests",
            dependencies: [
                "FluidTranscriptionCLI",
                .product(name: "Testing", package: "swift-testing"),
            ]
        ),
    ]
)
