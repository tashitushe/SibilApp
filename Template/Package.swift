// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "TemplateRuntime",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "TemplateRuntime", path: "Sources/TemplateRuntime")
    ]
)
