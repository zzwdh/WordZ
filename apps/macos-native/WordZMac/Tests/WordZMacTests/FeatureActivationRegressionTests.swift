import Foundation
import XCTest
@testable import WordZWorkspaceCore
@testable import WordZWorkspaceFeature

@MainActor
final class FeatureActivationRegressionTests: XCTestCase {
    func testNativeContainerBuildsWorkspaceThroughFeatureFactoryPages() {
        let workspace = NativeAppContainer(
            makeRepository: { FakeWorkspaceRepository() },
            makeFeaturePages: WordZWorkspaceFeaturePageFactory.makePageBundle,
            makeDialogService: { FakeDialogService() },
            makeHostPreferencesStore: { InMemoryHostPreferencesStore() },
            makeHostActionService: { _ in FakeHostActionService() },
            makeUpdateService: { FakeUpdateService() },
            makeNotificationService: { FakeNotificationService() },
            makeApplicationActivityInspector: { FakeApplicationActivityInspector() },
            makeBuildMetadataProvider: { FakeBuildMetadataProvider() },
            makeQuickLookPreviewFileService: {
                QuickLookPreviewFileService(
                    rootDirectory: FileManager.default.temporaryDirectory.appendingPathComponent(
                        "feature-activation-\(UUID().uuidString)",
                        isDirectory: true
                    )
                )
            }
        ).makeMainWorkspaceViewModel()

        XCTAssertEqual(ObjectIdentifier(type(of: workspace.topics)), ObjectIdentifier(TopicsPageViewModel.self))
        XCTAssertEqual(ObjectIdentifier(type(of: workspace.sentiment)), ObjectIdentifier(SentimentPageViewModel.self))
        XCTAssertEqual(ObjectIdentifier(type(of: workspace.evidenceWorkbench)), ObjectIdentifier(EvidenceWorkbenchViewModel.self))
        XCTAssertEqual(WordZWorkspaceFeatureModule.activationSummary, "topics,sentiment,evidence")
    }

    func testFeatureFactoryAndRegistryStayAlignedForMigratedVerticals() {
        let bundle = WordZWorkspaceFeaturePageFactory.makePageBundle()
        let handles = WorkspaceFeaturePageHandles(bundle: bundle)

        XCTAssertEqual(WordZWorkspaceFeatureModule.activatedVerticals, [.topics, .sentiment, .evidence])
        XCTAssertTrue(handles.topics === bundle.topics)
        XCTAssertTrue(handles.sentiment === bundle.sentiment)
        XCTAssertTrue(handles.evidenceWorkbench === bundle.evidenceWorkbench)
        XCTAssertEqual(
            WorkspaceFeatureRegistry.descriptors.filter { [.topics, .sentiment].contains($0.route) }.map(\.route),
            [.topics, .sentiment]
        )
    }

    func testAppShellSourceRetainsFeatureActivationAndFactoryInjection() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let appShellURL = root.appendingPathComponent("Sources/WordZAppShell/WordZAppShellApp.swift")
        let contents = try String(contentsOf: appShellURL, encoding: .utf8)

        XCTAssertTrue(contents.contains("WordZWorkspaceFeatureModule.activationSummary"))
        XCTAssertTrue(contents.contains("makeFeaturePages: WordZWorkspaceFeaturePageFactory.makePageBundle"))
        XCTAssertTrue(contents.contains("NativeAppContainer.live("))
    }
}
