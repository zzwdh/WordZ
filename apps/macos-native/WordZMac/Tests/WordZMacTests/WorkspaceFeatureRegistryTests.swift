import AppKit
import SwiftUI
import XCTest
@testable import WordZWorkspaceCore
@testable import WordZWorkspaceFeature

@MainActor
final class WorkspaceFeatureRegistryTests: XCTestCase {
    func testWorkspaceFeatureModuleActivatesVerticalsForTopicsSentimentAndEvidence() {
        XCTAssertEqual(
            WordZWorkspaceFeatureModule.activatedVerticals.map(\.rawValue),
            ["topics", "sentiment", "evidence"]
        )
    }

    func testWorkspaceFeaturePageFactoryBuildsConcreteMigratedPages() {
        let bundle = WordZWorkspaceFeaturePageFactory.makePageBundle()

        XCTAssertEqual(ObjectIdentifier(type(of: bundle.topics)), ObjectIdentifier(TopicsPageViewModel.self))
        XCTAssertEqual(ObjectIdentifier(type(of: bundle.sentiment)), ObjectIdentifier(SentimentPageViewModel.self))
        XCTAssertEqual(ObjectIdentifier(type(of: bundle.evidenceWorkbench)), ObjectIdentifier(EvidenceWorkbenchViewModel.self))
    }

    func testRegistryMaintainsStableMainRouteOrderAndIdentifiers() {
        XCTAssertEqual(
            WorkspaceFeatureRegistry.descriptors.map(\.route.rawValue),
            [
                "Stats",
                "Word",
                "Tokenize",
                "Topics",
                "Compare",
                "Sentiment",
                "Keyword",
                "Chi-Square",
                "Plot",
                "N-Gram",
                "Cluster",
                "KWIC",
                "Collocate",
                "Locator"
            ]
        )
        XCTAssertEqual(WorkspaceMainRoute.allCases, WorkspaceFeatureRegistry.mainRoutes)
        XCTAssertEqual(WorkspaceDetailTab.mainWorkspaceTabs, WorkspaceFeatureRegistry.mainTabs)
    }

    func testRegistryBacksFeatureTitlesSymbolsAndToolbarActions() {
        XCTAssertEqual(WorkspaceMainRoute.sentiment.displayTitle(in: .english), "Sentiment")
        XCTAssertEqual(WorkspaceMainRoute.sentiment.symbolName, "waveform.path.ecg.text")
        XCTAssertEqual(WorkspaceDetailTab.cluster.displayTitle(in: .english), "Cluster")
        XCTAssertEqual(WorkspaceDetailTab.cluster.symbolName, "square.stack.3d.up")
        XCTAssertEqual(
            WorkspaceFeatureRegistry.commandDescriptors.compactMap(\.commandAction),
            [
                .runStats,
                .runWord,
                .runTokenize,
                .runTopics,
                .runCompare,
                .runSentiment,
                .runKeyword,
                .runChiSquare,
                .runPlot,
                .runNgram,
                .runCluster,
                .runKWIC,
                .runCollocate,
                .runLocator
            ]
        )
    }

    func testFeatureFactoryBuildsDetailViewsForAllRegisteredRoutes() async {
        let workspace = makeMainWorkspaceViewModel(repository: FakeWorkspaceRepository())
        await workspace.initializeIfNeeded()
        let dispatcher = WorkspaceActionDispatcher(workspace: workspace)

        for descriptor in WorkspaceFeatureRegistry.descriptors {
            let view = WorkspaceFeatureFactory.makeDetailView(
                for: descriptor.route,
                workspace: workspace,
                dispatcher: dispatcher
            )

            XCTAssertNotNil(NSHostingView(rootView: view), "Expected a detail view for \(descriptor.route.rawValue)")
        }
    }
}
