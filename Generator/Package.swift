// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "SibilApp",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "SibilApp", path: "Sources/SibilApp")
    ]
)
