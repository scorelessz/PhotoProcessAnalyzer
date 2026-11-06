// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PhotoProcessAnalyzer",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "PhotoProcessAnalyzer",
            path: "Sources/PhotoProcessAnalyzer",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
