// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CaptureCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "CaptureCore", targets: ["CaptureCore"]),
        .executable(name: "CaptureDemo", targets: ["CaptureDemo"])
    ],
    dependencies: [
        .package(path: "../vision")
    ],
    targets: [
        .target(name: "CaptureCore", resources: [.process("Resources")]),
        .executableTarget(name: "CaptureDemo", dependencies: ["CaptureCore", .product(name: "VisionCore", package: "vision")]),
        .testTarget(name: "CaptureCoreTests", dependencies: ["CaptureCore", .product(name: "VisionCore", package: "vision")])
    ]
)
