// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "StarCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "StarCore", targets: ["StarCore"])],
    targets: [
        .target(name: "StarCore"),
        .testTarget(name: "StarCoreTests", dependencies: ["StarCore"]),
    ]
)
