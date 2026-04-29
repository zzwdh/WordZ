import Foundation
import XCTest
@testable import WordZWorkspaceCore

@MainActor
final class EngineeringGuardrailTests: XCTestCase {
    func testRepeatedNoOpSettingsSyncStaysWithinBaselineAndAvoidsRebuilds() async {
        let repository = FakeWorkspaceRepository()
        let builder = CountingRootContentSceneBuilder()
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            rootSceneBuilder: builder
        )

        await workspace.initializeIfNeeded()
        let buildCountAfterInitialize = builder.buildCallCount

        let clock = ContinuousClock()
        let elapsed = clock.measure {
            for _ in 0..<250 {
                workspace.syncSceneGraph(source: .settings)
            }
        }

        XCTAssertEqual(builder.buildCallCount, buildCountAfterInitialize)
        XCTAssertLessThan(milliseconds(elapsed), 750)
    }

    func testHotspotFilesStaySplitUnderGuardedBoundaries() throws {
        let sourceRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/WordZMac", isDirectory: true)
        let featureRoot = sourceRoot
            .deletingLastPathComponent()
            .appendingPathComponent("WordZWorkspaceFeature", isDirectory: true)

        let guardedFiles: [(String, Int)] = [
            ("App/WordZMacApp.swift", 90),
            ("Analysis/Support/KeywordSuiteAnalysisSupport.swift", 180),
            ("Analysis/Services/Topics/TopicModelManager.swift", 160),
            ("Analysis/Services/Topics/NativeTopicEngine+PartitionSelection.swift", 220),
            ("ViewModels/Library/LibraryManagementViewModel+Scene.swift", 180),
            ("ViewModels/Pages/KeywordPageViewModel.swift", 320),
            ("ViewModels/Pages/SentimentPageViewModel.swift", 280),
            ("ViewModels/Pages/SentimentPageViewModel+Scene.swift", 400),
            ("Views/Workspace/Pages/Topics/TopicsView+ResultPanes.swift", 160),
            ("Views/Workspace/Pages/Topics/TopicsView+DetailPane.swift", 220),
            ("Views/Workspace/Pages/SentimentView+Controls.swift", 440),
            ("Views/Workspace/Pages/SentimentView+Results.swift", 340),
            ("Views/Workspace/Pages/SentimentView+Inspector.swift", 260),
            ("Models/Analysis/EvidenceWorkbenchDossierModels.swift", 40),
            ("Models/Analysis/EvidenceWorkbenchGroupingMode+Messages.swift", 700),
            ("Models/Workspace/WorkspaceFeatureRegistry.swift", 400),
            ("Models/Workspace/WorkspaceFeatureRegistry+MigratedVerticals.swift", 80),
            ("ViewModels/Workspace/EvidenceWorkbenchViewModel+Mutation.swift", 430),
            ("Workspace/Services/Topics/WorkspaceTopicsWorkflowService.swift", 220),
            ("Workspace/Services/WorkspaceFlowCoordinator.swift", 100),
            ("Workspace/Services/WorkspaceEvidenceWorkflowService.swift", 40),
            ("Workspace/Services/WorkspaceEvidenceWorkflowService+GroupMutations.swift", 520),
            ("Workspace/Services/WorkspaceEvidenceWorkflowService+Support.swift", 280),
            ("Workspace/Services/WorkspaceSentimentWorkflowService.swift", 180),
            ("Workspace/Models/WorkspaceFeaturePageBundle.swift", 30),
            ("Workspace/Models/WorkspaceFeaturePageHandles.swift", 60),
            ("Workspace/Models/WorkspaceFeatureSet.swift", 80),
            ("Workspace/Models/WorkspaceFeatureSet+Defaults.swift", 60),
            ("Workspace/Protocols/WorkspaceFeaturePageProtocols.swift", 140),
            ("Workspace/Protocols/WorkspaceFeatureWorkflowProtocols.swift", 200),
            ("Workspace/Protocols/WorkspaceFeatureWorkflowContexts.swift", 120),
            ("Workspace/Services/WorkspaceFeatureWorkflowFactory.swift", 50)
        ]

        for (relativePath, maxLines) in guardedFiles {
            let url = sourceRoot.appendingPathComponent(relativePath)
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "Missing guarded file: \(relativePath)")
            let contents = try String(contentsOf: url)
            XCTAssertLessThanOrEqual(
                contents.components(separatedBy: .newlines).count - 1,
                maxLines,
                "\(relativePath) exceeded the guardrail limit."
            )
        }

        let companionFiles = [
            "Analysis/Support/KeywordSuiteAnalysisSupport+ImportedReference.swift",
            "Analysis/Support/KeywordSuiteAnalysisSupport+CorpusPreparation.swift",
            "Analysis/Support/KeywordSuiteAnalysisSupport+Aggregation.swift",
            "Analysis/Support/KeywordSuiteAnalysisSupport+Scoring.swift",
            "Analysis/Services/Topics/TopicModelManager+ManifestSupport.swift",
            "Analysis/Services/Topics/TopicModelManager+EmbeddingSupport.swift",
            "App/WordZMacApp+FeatureWindows.swift",
            "Models/Workspace/WorkspaceFeatureRegistry+MigratedVerticals.swift",
            "ViewModels/Library/LibraryManagementViewModel+SceneNavigation.swift",
            "ViewModels/Library/LibraryManagementViewModel+SceneDetail.swift",
            "ViewModels/Library/LibraryManagementViewModel+SceneMaintenance.swift",
            "ViewModels/Pages/SentimentPageViewModel+Selection.swift",
            "ViewModels/Pages/SentimentPageViewModel+Profiles.swift",
            "ViewModels/Pages/SentimentPageViewModel+Actions.swift",
            "Views/Workspace/Pages/Topics/TopicsView+ListPane.swift",
            "Views/Workspace/Pages/Topics/TopicsView+SegmentsPane.swift",
            "Views/Workspace/Pages/Topics/TopicsView+CrossAnalysisPane.swift",
            "Views/Workspace/Pages/Topics/TopicsView+PaneSupport.swift",
            "Views/Workspace/Pages/SentimentView+Support.swift",
            "Workspace/Services/Topics/WorkspaceTopicsWorkflowService+CompareTopics.swift",
            "Workspace/Services/Topics/WorkspaceTopicsWorkflowService+TopicsSentiment.swift",
            "Models/Analysis/EvidenceWorkbenchGroupingSupport.swift",
            "Models/Analysis/EvidenceWorkbenchDossierDraftSupport.swift",
            "Models/Analysis/EvidenceMarkdownDossierSupport.swift",
            "ViewModels/Workspace/EvidenceWorkbenchViewModel+Selection.swift",
            "Workspace/Models/WorkspaceFeaturePageBundle.swift",
            "Workspace/Models/WorkspaceFeaturePageHandles.swift",
            "Workspace/Models/WorkspaceFeatureSet+Defaults.swift",
            "Workspace/Models/WorkspaceFeatureSet+WorkspaceBinding.swift",
            "Workspace/Services/WorkspaceEvidenceWorkflowService+Capture.swift",
            "Workspace/Services/WorkspaceEvidenceWorkflowService+ItemMutations.swift",
            "Workspace/Services/WorkspaceEvidenceWorkflowService+Export.swift",
            "Workspace/Services/WorkspaceEvidenceWorkflowService+Support.swift",
            "Workspace/Services/WorkspaceSentimentWorkflowService+Exports.swift",
            "Workspace/Services/WorkspaceSentimentWorkflowService+LexiconBundles.swift",
            "Workspace/Protocols/WorkspaceFeaturePageProtocols.swift",
            "Workspace/Protocols/WorkspaceFeatureWorkflowProtocols.swift",
            "Workspace/Protocols/WorkspaceFeatureWorkflowContexts.swift",
            "Workspace/Services/WorkspaceFeatureWorkflowFactory.swift"
        ]

        for relativePath in companionFiles {
            let url = sourceRoot.appendingPathComponent(relativePath)
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "Missing hotspot companion file: \(relativePath)")
        }

        XCTAssertTrue(
            FileManager.default.fileExists(atPath: featureRoot.appendingPathComponent("WordZWorkspaceFeatureModule.swift").path),
            "Missing workspace feature module activation file."
        )
        let featureFactoryURL = featureRoot.appendingPathComponent("WorkspaceFeaturePageFactory.swift")
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: featureFactoryURL.path),
            "Missing workspace feature page factory."
        )
        let featureFactoryContents = try String(contentsOf: featureFactoryURL)
        XCTAssertLessThanOrEqual(
            featureFactoryContents.components(separatedBy: .newlines).count - 1,
            20,
            "WorkspaceFeaturePageFactory.swift exceeded the guardrail limit."
        )
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: featureRoot.appendingPathComponent("WordZWorkspaceFeaturePlaceholder.swift").path),
            "Workspace feature placeholder file should be removed once the module is activated."
        )
    }

    func testEngineeringGuardFocusesOnSplitRegressionSuites() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let scriptURL = root.appendingPathComponent("Scripts/engineering-guard.sh")
        let contents = try String(contentsOf: scriptURL, encoding: .utf8)

        XCTAssertTrue(contents.contains("FeatureActivationRegressionTests"))
        XCTAssertTrue(contents.contains("WorkspaceWorkflowChainTests"))
        XCTAssertTrue(contents.contains("WorkspaceActionDispatcherTests"))
        XCTAssertTrue(contents.contains("WorkspaceFeatureRegistryTests"))
        XCTAssertFalse(contents.contains("MainWorkspaceViewModelTests"))
    }

    func testMigratedAnalysisTablesUseSharedSectionAndSnapshots() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let migratedPages = [
            "Sources/WordZMac/Views/Workspace/Pages/ClusterView.swift",
            "Sources/WordZMac/Views/Workspace/Pages/CollocateView+Results.swift",
            "Sources/WordZMac/Views/Workspace/Pages/CompareView+Results.swift",
            "Sources/WordZMac/Views/Workspace/Pages/KeywordView+ResultTable.swift",
            "Sources/WordZMac/Views/Workspace/Pages/KWICView+Results.swift",
            "Sources/WordZMac/Views/Workspace/Pages/LocatorView+Results.swift",
            "Sources/WordZMac/Views/Workspace/Pages/SentimentView+Results.swift",
            "Sources/WordZMac/Views/Workspace/Pages/TokenizeView+Results.swift",
            "Sources/WordZMac/Views/Workspace/Pages/WordView+Results.swift",
            "Sources/WordZMac/Views/Workspace/Pages/StatsView+Results.swift",
            "Sources/WordZMac/Views/Workspace/Pages/NgramView+Results.swift"
        ]

        for relativePath in migratedPages {
            let url = root.appendingPathComponent(relativePath)
            let contents = try String(contentsOf: url, encoding: .utf8)

            XCTAssertTrue(
                contents.contains("AnalysisResultTableSection("),
                "\(relativePath) should use the shared analysis result table section."
            )
            XCTAssertTrue(
                contents.contains("snapshot: scene.tableSnapshot"),
                "\(relativePath) should pass ResultTableSnapshot into NativeTableView."
            )
            XCTAssertFalse(
                contents.contains("WorkbenchTableCard {"),
                "\(relativePath) should not rebuild the shared table card locally."
            )
            XCTAssertFalse(
                contents.contains("NativeTableView("),
                "\(relativePath) should not call NativeTableView directly after migrating to AnalysisResultTableSection."
            )
        }
    }

    func testNativeTableViewSwiftUIBoundaryRequiresSnapshots() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let tableViewURL = root.appendingPathComponent(
            "Sources/WordZMac/Views/Workbench/Table/NativeTableView.swift"
        )
        let tableViewContents = try String(contentsOf: tableViewURL, encoding: .utf8)
        let analysisSectionURL = root.appendingPathComponent(
            "Sources/WordZMac/Views/Workbench/AnalysisResultTableSection.swift"
        )
        let analysisSectionContents = try String(contentsOf: analysisSectionURL, encoding: .utf8)
        XCTAssertFalse(
            analysisSectionContents.contains("AnyView"),
            "AnalysisResultTableSection should keep supplemental controls generic instead of type-erasing them."
        )
        XCTAssertTrue(
            tableViewContents.contains("snapshot: ResultTableSnapshot"),
            "NativeTableView should expose a snapshot initializer at the SwiftUI boundary."
        )
        XCTAssertTrue(
            tableViewContents.contains("@available(*, unavailable") &&
                tableViewContents.contains("Pass ResultTableSnapshot"),
            "NativeTableView(rows:) should stay unavailable so large tables do not fall back to row equality checks."
        )

        let pagesRoot = root.appendingPathComponent("Sources/WordZMac/Views/Workspace/Pages", isDirectory: true)
        let enumerator = FileManager.default.enumerator(
            at: pagesRoot,
            includingPropertiesForKeys: nil
        )
        let swiftFiles = (enumerator?.compactMap { $0 as? URL } ?? [])
            .filter { $0.pathExtension == "swift" }

        for url in swiftFiles {
            let contents = try String(contentsOf: url, encoding: .utf8)
            guard contents.contains("NativeTableView(") else { continue }
            XCTAssertFalse(
                contents.contains("rows:"),
                "\(url.path) should pass a ResultTableSnapshot into NativeTableView instead of rows."
            )
        }
    }

    func testRuntimeStorageSupportKeepsLegacyShardParsingInsideMigratorBoundary() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let storageSupportURL = root.appendingPathComponent(
            "Sources/WordZMac/Storage/Library/NativeCorpusStore+StorageSupport.swift"
        )
        let shardMigratorURL = root.appendingPathComponent(
            "Sources/WordZMac/Storage/Support/CorpusShardMigrator.swift"
        )

        let storageSupportContents = try String(contentsOf: storageSupportURL, encoding: .utf8)
        let shardMigratorContents = try String(contentsOf: shardMigratorURL, encoding: .utf8)

        XCTAssertFalse(storageSupportContents.contains("readStoredCorpusDocumentIfPresent"))
        XCTAssertFalse(storageSupportContents.contains("TextFileDecodingSupport.readTextDocument"))
        XCTAssertTrue(storageSupportContents.contains("shardMigrator.canMigrateStorage(at: url)"))

        XCTAssertTrue(shardMigratorContents.contains("readLegacyJSONDocument"))
        XCTAssertTrue(shardMigratorContents.contains("TextFileDecodingSupport.readTextDocument"))
    }

    private func milliseconds(_ duration: Duration) -> Double {
        let components = duration.components
        let seconds = Double(components.seconds) * 1_000
        let attoseconds = Double(components.attoseconds) / 1_000_000_000_000_000
        return seconds + attoseconds
    }
}
