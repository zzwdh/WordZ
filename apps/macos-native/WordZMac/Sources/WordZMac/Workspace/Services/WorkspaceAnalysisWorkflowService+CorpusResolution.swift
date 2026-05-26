import Foundation

@MainActor
extension WorkspaceAnalysisWorkflowService {
    func buildComparisonEntries(from selectedCorpora: [LibraryCorpusItem]) async throws -> [CompareRequestEntry] {
        var entries: [CompareRequestEntry] = []
        var seenCorpusIDs: Set<String> = []
        for corpus in selectedCorpora {
            guard seenCorpusIDs.insert(corpus.id).inserted else { continue }
            let opened = try await repository.openSavedCorpus(corpusId: corpus.id)
            entries.append(
                CompareRequestEntry(
                    corpusId: corpus.id,
                    corpusName: corpus.name,
                    folderId: corpus.folderId,
                    folderName: corpus.folderName,
                    sourceType: opened.sourceType,
                    content: opened.content
                )
            )
        }
        return entries
    }

    func buildKeywordRequestEntries(
        from corpora: [LibraryCorpusItem]
    ) async throws -> [KeywordRequestEntry] {
        var entries: [KeywordRequestEntry] = []
        for corpus in corpora {
            let opened = try await repository.openSavedCorpus(corpusId: corpus.id)
            entries.append(
                KeywordRequestEntry(
                    corpusId: corpus.id,
                    corpusName: corpus.name,
                    folderName: corpus.folderName,
                    content: opened.content
                )
            )
        }
        return entries
    }

    func resolvedPlotScope(features: WorkspaceFeatureSet) -> PlotScopeResolution {
        if features.sidebar.selectedCorpusSetID != nil {
            return .singleCorpus
        }
        if features.sidebar.hasAnyMetadataFilterInput {
            return .corpusRange
        }
        return .singleCorpus
    }

    func buildPlotEntries(
        scope: PlotScopeResolution,
        features: WorkspaceFeatureSet,
        syncFeatureContexts: @escaping @MainActor (WorkspaceFeatureSet) -> Void
    ) async throws -> [PlotCorpusEntry] {
        switch scope {
        case .singleCorpus:
            let openedCorpus = try await ensureOpenedCorpus(
                features: features,
                syncFeatureContexts: syncFeatureContexts
            )
            let selectedCorpus = features.sidebar.selectedCorpus
            let corpusID = features.sidebar.selectedCorpusSetID.map { CorpusSetSourceID.sourceID(for: $0) }
                ?? features.sidebar.selectedCorpusID
                ?? sessionStore.openedCorpusSourceID
                ?? selectedCorpus?.id
                ?? UUID().uuidString
            return [
                PlotCorpusEntry(
                    corpusId: corpusID,
                    displayName: features.sidebar.selectedCorpusSet?.name ?? selectedCorpus?.name ?? openedCorpus.displayName,
                    filePath: openedCorpus.filePath,
                    content: openedCorpus.content
                )
            ]
        case .corpusRange:
            var entries: [PlotCorpusEntry] = []
            for corpus in features.sidebar.filteredCorpora {
                let openedCorpus = try await repository.openSavedCorpus(corpusId: corpus.id)
                entries.append(
                    PlotCorpusEntry(
                        corpusId: corpus.id,
                        displayName: corpus.name,
                        filePath: openedCorpus.filePath,
                        content: openedCorpus.content
                    )
                )
            }
            return entries
        }
    }

    func selectedCompareResultRow(features: WorkspaceFeatureSet) -> CompareRow? {
        guard let result = features.compare.result else { return nil }
        let rowID = features.compare.selectedSceneRow?.id ?? features.compare.selectedRowID
        guard let rowID else { return result.rows.first }
        return result.rows.first(where: { $0.id == rowID }) ?? result.rows.first
    }

    func resolveCompareDrilldownCorpus(
        for row: CompareRow,
        features: WorkspaceFeatureSet
    ) -> ComparePerCorpusValue? {
        let referenceCorpusIDs = compareReferenceCorpusIDs(features: features)
        guard !referenceCorpusIDs.isEmpty else {
            return preferredCompareCorpus(from: row.perCorpus)
        }

        let referenceEntries = row.perCorpus.filter { referenceCorpusIDs.contains($0.corpusId) }
        let targetEntries = row.perCorpus.filter { !referenceCorpusIDs.contains($0.corpusId) }
        guard !referenceEntries.isEmpty, !targetEntries.isEmpty else {
            return preferredCompareCorpus(from: row.perCorpus)
        }

        let preferredEntries = compareGroupNormFrequency(for: targetEntries) >= compareGroupNormFrequency(for: referenceEntries)
            ? targetEntries
            : referenceEntries
        return preferredCompareCorpus(from: preferredEntries) ?? preferredCompareCorpus(from: row.perCorpus)
    }

    func compareReferenceCorpusIDs(features: WorkspaceFeatureSet) -> Set<String> {
        switch features.compare.selectedReferenceSelection {
        case .automatic:
            return []
        case .corpus(let corpusID):
            return [corpusID]
        case .corpusSet:
            return Set(features.compare.selectedReferenceCorpusSet()?.corpusIDs ?? [])
        }
    }

    func compareGroupNormFrequency(for entries: [ComparePerCorpusValue]) -> Double {
        let tokenCount = entries.reduce(0) { $0 + $1.tokenCount }
        guard tokenCount > 0 else { return 0 }
        let totalCount = entries.reduce(0) { $0 + $1.count }
        return (Double(totalCount) / Double(tokenCount)) * 10_000
    }

    func preferredCompareCorpus(from entries: [ComparePerCorpusValue]) -> ComparePerCorpusValue? {
        entries.max { lhs, rhs in
            if lhs.normFreq != rhs.normFreq {
                return lhs.normFreq < rhs.normFreq
            }
            if lhs.count != rhs.count {
                return lhs.count < rhs.count
            }
            return lhs.corpusId > rhs.corpusId
        }
    }
}
