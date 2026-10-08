// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "LanDrop",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "LanDrop", path: "Sources/LanDrop")
    ]
)
