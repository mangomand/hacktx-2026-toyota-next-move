// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "VisionCore", products: [.library(name: "VisionCore", targets: ["VisionCore"])], targets: [.target(name: "VisionCore"), .testTarget(name: "VisionCoreTests", dependencies: ["VisionCore"])])
