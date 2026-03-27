// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WordZMac",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "WordZMac", targets: ["WordZMac"])
    ],
    targets: [
        .executableTarget(
            name: "WordZMac",
            path: "Sources/WordZMac"
        ),
        .testTarget(
            name: "WordZMacTests",
            dependencies: ["WordZMac"],
            path: "Tests/WordZMacTests"
        )
    ]
)
