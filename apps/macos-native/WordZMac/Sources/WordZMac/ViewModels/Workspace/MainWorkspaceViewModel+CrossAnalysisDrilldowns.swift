import Foundation

@MainActor
extension MainWorkspaceViewModel {
    func openKeywordKWIC(scope: KeywordKWICScope) async {
        cancelPendingInputStateSync()
        let prepared = await flowCoordinator.prepareKeywordKWIC(scope: scope, features: features)
        guard prepared else { return }
        await runKWIC()
    }

    func openCompareKWIC() async {
        cancelPendingInputStateSync()
        let prepared = await flowCoordinator.prepareCompareDrilldown(target: .kwic, features: features)
        guard prepared else { return }
        await runKWIC()
    }

    func openCompareCollocate() async {
        cancelPendingInputStateSync()
        let prepared = await flowCoordinator.prepareCompareDrilldown(target: .collocate, features: features)
        guard prepared else { return }
        await runCollocate()
    }

    func openCompareSentiment(
        preferredRowID: String? = nil,
        openSourceReaderAfterSelection: Bool = false
    ) async {
        cancelPendingInputStateSync()
        let prepared = await flowCoordinator.prepareCompareDrilldown(target: .sentiment, features: features)
        guard prepared else { return }
        await runSentiment()
        applySentimentSelection(preferredRowID)
        if openSourceReaderAfterSelection {
            _ = await openCurrentSourceReader()
        }
    }

    func openCompareTopics() async {
        cancelPendingInputStateSync()
        let prepared = await flowCoordinator.prepareCompareDrilldown(target: .topics, features: features)
        guard prepared else { return }
        await runTopics()
    }

    func openTopicsSentiment(
        scope: TopicsSentimentDrilldownScope,
        preferredRowID: String? = nil,
        openSourceReaderAfterSelection: Bool = false
    ) async {
        cancelPendingInputStateSync()
        let prepared = await flowCoordinator.prepareTopicsSentiment(scope: scope, features: features)
        guard prepared else { return }
        await runSentiment()
        applySentimentSelection(preferredRowID)
        if openSourceReaderAfterSelection {
            _ = await openCurrentSourceReader()
        }
    }

    func openTopicsKWIC() async {
        cancelPendingInputStateSync()
        let prepared = await flowCoordinator.prepareTopicsKWIC(features: features)
        guard prepared else { return }
        await runKWIC()
    }

    func openCollocateKWIC() async {
        cancelPendingInputStateSync()
        let prepared = await flowCoordinator.prepareCollocateKWIC(features: features)
        guard prepared else { return }
        await runKWIC()
    }

    func openPlotKWIC() async {
        cancelPendingInputStateSync()
        let prepared = await flowCoordinator.preparePlotKWIC(features: features)
        guard prepared else { return }
        await runKWIC()
    }

    func openClusterKWIC() async {
        cancelPendingInputStateSync()
        let prepared = await flowCoordinator.prepareClusterKWIC(features: features)
        guard prepared else { return }
        await runKWIC()
    }
}
