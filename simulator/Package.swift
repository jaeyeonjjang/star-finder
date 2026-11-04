// swift-tools-version:5.9
// 브라우저 시뮬레이터용 데이터 생성기. StarCore를 그대로 가져다 쓴다.
import PackageDescription

let package = Package(
    name: "StarSim",
    platforms: [.macOS(.v14)],
    dependencies: [.package(path: "../StarCore")],
    targets: [
        .executableTarget(name: "StarSim", dependencies: [.product(name: "StarCore", package: "StarCore")]),
    ]
)
