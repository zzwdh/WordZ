// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WordZMac",
    defaultLocalization: "zh-Hans",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "WordZMac", targets: ["WordZMac"])
    ],
    targets: [
        .executableTarget(
            name: "WordZMac",
            dependencies: [
                "WordZAppShell"
            ],
            path: "Sources/WordZMacExecutable"
        ),
        .target(
            name: "WordZWorkspaceCore",
            dependencies: [
                "WordZAnalysis",
                "WordZEngine",
                "WordZHost",
                "WordZWindowing",
                "WordZShared"
            ],
            path: "Sources/WordZMac",
            exclude: [
                "Analysis/README.md",
                "App/README.md",
                "Diagnostics/README.md",
                "Engine/README.md",
                "Export/README.md",
                "Host/README.md",
                "Models/README.md",
                "README.md",
                "Resources",
                "Shared/README.md",
                "Storage/README.md",
                "ViewModels/README.md",
                "Views/README.md",
                "Workspace/README.md"
            ]
        ),
        .target(
            name: "WordZShared",
            path: "Sources/WordZShared",
            sources: [
                "WordZSharedResources.swift"
            ],
            resources: [
                .process("Resources/en.lproj"),
                .process("Resources/zh-Hans.lproj")
            ]
        ),
        .target(
            name: "WordZAnalysis",
            path: "Sources/WordZAnalysis",
            sources: [
                "WordZAnalysisResources.swift"
            ],
            resources: [
                .copy("Resources/Sentiment"),
                .process("Resources/TopicLocalEmbeddingModel.json"),
                .process("Resources/TopicModelManifest.json")
            ]
        ),
        .target(
            name: "WordZAppShell",
            dependencies: [
                "WordZWorkspaceCore",
                "WordZWorkspaceFeature",
                "WordZLibraryFeature",
                "WordZWindowing",
                "WordZHost",
                "WordZExport",
                "WordZDiagnostics",
                "WordZShared"
            ],
            path: "Sources/WordZAppShell"
        ),
        .target(
            name: "WordZWorkspaceFeature",
            dependencies: [
                "WordZWorkspaceCore",
                "WordZLibraryFeature",
                "WordZWorkbenchUI",
                "WordZWindowing",
                "WordZAnalysis",
                "WordZHost",
                "WordZShared"
            ],
            path: "Sources/WordZWorkspaceFeature"
        ),
        .target(
            name: "WordZLibraryFeature",
            dependencies: [
                "WordZWorkspaceCore",
                "WordZWorkbenchUI",
                "WordZWindowing",
                "WordZHost",
                "WordZShared"
            ],
            path: "Sources/WordZLibraryFeature"
        ),
        .target(
            name: "WordZWorkbenchUI",
            dependencies: [
                "WordZShared"
            ],
            path: "Sources/WordZWorkbenchUI"
        ),
        .target(
            name: "WordZWindowing",
            dependencies: [
                "WordZShared"
            ],
            path: "Sources/WordZWindowing"
        ),
        .target(
            name: "WordZStorage",
            dependencies: [
                "WordZShared"
            ],
            path: "Sources/WordZStorage"
        ),
        .target(
            name: "WordZEngine",
            dependencies: [
                "WordZShared"
            ],
            path: "Sources/WordZEngine"
        ),
        .target(
            name: "WordZHost",
            dependencies: [
                "WordZShared"
            ],
            path: "Sources/WordZHost"
        ),
        .target(
            name: "WordZExport",
            dependencies: [
                "WordZShared"
            ],
            path: "Sources/WordZExport"
        ),
        .target(
            name: "WordZDiagnostics",
            dependencies: [
                "WordZShared"
            ],
            path: "Sources/WordZDiagnostics"
        ),
        .testTarget(
            name: "WordZWorkspaceCoreTests",
            dependencies: [
                "WordZWorkspaceCore",
                "WordZWorkspaceFeature",
                "WordZEngine"
            ],
            path: "Tests/WordZMacTests",
            resources: [
                .copy("Fixtures")
            ]
        )
    ]
)
