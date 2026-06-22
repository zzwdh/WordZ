import Foundation
import WordZShared

@MainActor
extension MainWorkspaceViewModel {
    func runPlot(token: WorkspaceRequestToken) async {
        let normalizedQuery = plot.normalizedQuery
        guard !normalizedQuery.isEmpty else {
            sidebar.setError(wordZText("请输入 Plot 检索词。", "Enter a Plot query first.", mode: .system))
            return
        }
        let searchOptions = plot.searchOptions

        await performLatestResultRun(
            token: token,
            label: "plot",
            descriptor: .plot,
            selecting: .plot
        ) {
            let scope = self.flowCoordinator.resolvedPlotScope(features: self.features)
            let entries = try await self.performWithoutSceneSyncCallbacks(.navigation) {
                try await self.flowCoordinator.buildPlotEntries(
                    scope: scope,
                    features: self.features
                )
            }
            let request = PlotRunRequest(
                entries: entries,
                query: normalizedQuery,
                searchOptions: searchOptions,
                scope: scope
            )
            return try await self.flowCoordinator.analysisWorkflow.repository.runPlot(request)
        } apply: { result in
            self.plot.apply(result)
        }
    }

    func runNgram(token: WorkspaceRequestToken) async {
        let ngramSize = ngram.ngramSizeValue

        await performLatestResultRun(
            token: token,
            label: "ngram",
            descriptor: .ngram,
            selecting: .ngram
        ) {
            let corpus = try await self.performWithoutSceneSyncCallbacks(.navigation) {
                try await self.flowCoordinator.ensureOpenedCorpus(features: self.features)
            }
            return try await self.flowCoordinator.analysisWorkflow.repository.runNgram(
                text: corpus.content,
                n: ngramSize
            )
        } apply: { result in
            self.ngram.apply(result)
        }
    }

    func runCluster(token: WorkspaceRequestToken) async {
        await performLatestResultRun(
            token: token,
            label: "cluster",
            descriptor: .cluster,
            selecting: .cluster
        ) {
            let corpus = try await self.performWithoutSceneSyncCallbacks(.navigation) {
                try await self.flowCoordinator.ensureOpenedCorpus(features: self.features)
            }
            let targetEntry = ClusterCorpusEntry(
                corpusId: self.sidebar.selectedCorpusID ?? corpus.filePath,
                corpusName: corpus.displayName,
                content: corpus.content
            )
            let referenceEntries = try await self.clusterReferenceEntries(excluding: targetEntry.corpusId)
            let request = ClusterRunRequest(
                targetEntries: [targetEntry],
                referenceEntries: referenceEntries,
                caseSensitive: self.cluster.caseSensitive,
                stopwordFilter: self.cluster.stopwordFilter,
                punctuationMode: self.cluster.punctuationMode,
                nValues: [2, 3, 4, 5]
            )
            return try await self.flowCoordinator.analysisWorkflow.repository.runCluster(request)
        } apply: { result in
            self.cluster.apply(result)
        }
    }

    func runCollocate(token: WorkspaceRequestToken) async {
        let keyword = collocate.normalizedKeyword
        guard !keyword.isEmpty else {
            sidebar.setError(wordZText("请输入 Collocate 节点词。", "Enter a Collocate node word first.", mode: .system))
            return
        }
        let leftWindow = collocate.leftWindowValue
        let rightWindow = collocate.rightWindowValue
        let minFreq = collocate.minFreqValue
        let searchOptions = collocate.searchOptions
        collocate.recordPendingRunConfiguration()

        await performLatestResultRun(
            token: token,
            label: "collocate",
            descriptor: .collocate,
            selecting: .collocate
        ) {
            let corpus = try await self.performWithoutSceneSyncCallbacks(.navigation) {
                try await self.flowCoordinator.ensureOpenedCorpus(features: self.features)
            }
            return try await self.flowCoordinator.analysisWorkflow.repository.runCollocate(
                text: corpus.content,
                keyword: keyword,
                leftWindow: leftWindow,
                rightWindow: rightWindow,
                minFreq: minFreq,
                searchOptions: searchOptions
            )
        } apply: { result in
            self.collocate.apply(result)
        }
    }

    private func clusterReferenceEntries(excluding targetCorpusID: String) async throws -> [ClusterCorpusEntry] {
        let trimmedReferenceCorpusID = cluster.referenceCorpusID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard cluster.mode == .targetReference,
              !trimmedReferenceCorpusID.isEmpty,
              trimmedReferenceCorpusID != targetCorpusID else {
            return []
        }

        let openedReference = try await flowCoordinator.analysisWorkflow.repository.openSavedCorpus(
            corpusId: trimmedReferenceCorpusID
        )
        let referenceName = sidebar.librarySnapshot.corpora.first(where: { $0.id == trimmedReferenceCorpusID })?.name
            ?? openedReference.displayName
        return [
            ClusterCorpusEntry(
                corpusId: trimmedReferenceCorpusID,
                corpusName: referenceName,
                content: openedReference.content
            )
        ]
    }
}
