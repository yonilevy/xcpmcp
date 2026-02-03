// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "xcpmcp",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/tuist/XcodeProj.git", .upToNextMajor(from: "8.12.0")),
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", .upToNextMajor(from: "0.10.0")),
    ],
    targets: [
        .executableTarget(
            name: "xcpmcp",
            dependencies: [
                "XcodeProj",
                .product(name: "MCP", package: "swift-sdk"),
            ]
        ),
    ]
)
