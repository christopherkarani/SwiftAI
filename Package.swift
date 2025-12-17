// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SwiftAI",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "SwiftAI",
            targets: ["SwiftAI"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/ml-explore/mlx-swift.git", from: "0.21.0"),
        .package(url: "https://github.com/ml-explore/mlx-swift-lm.git", from: "2.29.0"),
        .package(url: "https://github.com/huggingface/swift-huggingface.git", from: "0.4.0"),
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "509.0.0"),
    ],
    targets: [
        .target(
            name: "SwiftAI",
            dependencies: [
                .product(name: "MLX", package: "mlx-swift"),
                .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
                .product(name: "MLXLLM", package: "mlx-swift-lm"),
                .product(name: "HuggingFace", package: "swift-huggingface"),
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "SwiftAITests",
            dependencies: ["SwiftAI"]
        ),
    ]
)
