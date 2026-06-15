import Foundation

import WordZWindowing
@MainActor
extension MainWorkspaceViewModel {
    func exportSentimentSummary(preferredWindowRoute: NativeWindowRoute? = nil) async {
        await flowCoordinator.exportSentimentSummary(
            features: features,
            preferredRoute: preferredWindowRoute
        )
        syncResultContentSceneGraph(for: .sentiment)
    }

    func importSentimentUserLexiconBundle(preferredWindowRoute: NativeWindowRoute? = nil) async {
        await flowCoordinator.importSentimentUserLexiconBundle(
            features: features,
            preferredRoute: preferredWindowRoute
        )
        syncResultContentSceneGraph(for: .sentiment)
    }

    func exportSentimentStructuredJSON(preferredWindowRoute: NativeWindowRoute? = nil) async {
        await flowCoordinator.exportSentimentStructuredJSON(
            features: features,
            preferredRoute: preferredWindowRoute
        )
        syncResultContentSceneGraph(for: .sentiment)
    }

    func confirmSelectedSentimentRow() async {
        await flowCoordinator.confirmSelectedSentimentRow(features: features)
        syncResultContentSceneGraph(for: .sentiment)
    }

    func overrideSelectedSentimentRow(_ label: SentimentLabel) async {
        await flowCoordinator.overrideSelectedSentimentRow(label, features: features)
        syncResultContentSceneGraph(for: .sentiment)
    }

    func clearSelectedSentimentReview() async {
        await flowCoordinator.clearSelectedSentimentReview(features: features)
        syncResultContentSceneGraph(for: .sentiment)
    }

    func applySentimentSelection(_ rowID: String?) {
        guard let rowID else { return }
        sentiment.handle(.selectRow(rowID))
        syncResultContentSceneGraph(for: .sentiment)
    }
}
