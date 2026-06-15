import Foundation
import WordZShared

@MainActor
extension WorkspaceAnalysisWorkflowService {
    func runPlot(
        features: WorkspaceFeatureSet,
        syncFeatureContexts: @escaping @MainActor (WorkspaceFeatureSet) -> Void
    ) async {
        let normalizedQuery = features.plot.normalizedQuery
        guard !normalizedQuery.isEmpty else {
            features.sidebar.setError(wordZText("请输入 Plot 检索词。", "Enter a Plot query first.", mode: .system))
            return
        }

        await performResultRunTask(
            .plot,
            selecting: .plot,
            features: features,
            syncFeatureContexts: syncFeatureContexts
        ) {
            let scope = self.resolvedPlotScope(features: features)
            let entries = try await self.buildPlotEntries(
                scope: scope,
                features: features,
                syncFeatureContexts: syncFeatureContexts
            )
            let request = features.plot.currentRunRequest(entries: entries, scope: scope)
            let result = try await self.repository.runPlot(request)
            features.plot.apply(result)
        }
    }

    func runCluster(
        features: WorkspaceFeatureSet,
        syncFeatureContexts: @escaping @MainActor (WorkspaceFeatureSet) -> Void
    ) async {
        await performOpenedCorpusRunTask(
            .cluster,
            selecting: .cluster,
            features: features,
            syncFeatureContexts: syncFeatureContexts
        ) { corpus in
            let targetEntry = ClusterCorpusEntry(
                corpusId: features.sidebar.selectedCorpusID ?? corpus.filePath,
                corpusName: corpus.displayName,
                content: corpus.content
            )
            let referenceEntries: [ClusterCorpusEntry]
            let trimmedReferenceCorpusID = features.cluster.referenceCorpusID
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if features.cluster.mode == .targetReference,
               !trimmedReferenceCorpusID.isEmpty,
               trimmedReferenceCorpusID != targetEntry.corpusId {
                let openedReference = try await self.repository.openSavedCorpus(corpusId: trimmedReferenceCorpusID)
                let referenceName = features.sidebar.librarySnapshot.corpora.first(where: { $0.id == trimmedReferenceCorpusID })?.name
                    ?? openedReference.displayName
                referenceEntries = [
                    ClusterCorpusEntry(
                        corpusId: trimmedReferenceCorpusID,
                        corpusName: referenceName,
                        content: openedReference.content
                    )
                ]
            } else {
                referenceEntries = []
            }

            let request = ClusterRunRequest(
                targetEntries: [targetEntry],
                referenceEntries: referenceEntries,
                caseSensitive: features.cluster.caseSensitive,
                stopwordFilter: features.cluster.stopwordFilter,
                punctuationMode: features.cluster.punctuationMode,
                nValues: [2, 3, 4, 5]
            )
            let result = try await self.repository.runCluster(request)
            features.cluster.apply(result)
        }
    }
}
