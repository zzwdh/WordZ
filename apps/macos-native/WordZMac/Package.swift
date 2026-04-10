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
            path: "Sources/WordZMac",
            exclude: [
                "README.md",
                "Analysis/README.md",
                "App/README.md",
                "Diagnostics/README.md",
                "Engine/README.md",
                "Export/README.md",
                "Host/README.md",
                "Models/README.md",
                "Resources/README.md",
                "Shared/README.md",
                "Storage/README.md",
                "ViewModels/README.md",
                "Views/README.md",
                "Workspace/README.md"
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "WordZMacTests",
            dependencies: ["WordZMac"],
            path: "Tests/WordZMacTests"
        )
    ]
)
