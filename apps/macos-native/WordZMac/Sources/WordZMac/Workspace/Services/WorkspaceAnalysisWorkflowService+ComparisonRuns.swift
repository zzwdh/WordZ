import Foundation

@MainActor
extension WorkspaceAnalysisWorkflowService {
    func runCompare(
        features: WorkspaceFeatureSet,
        syncFeatureContexts: @escaping @MainActor (WorkspaceFeatureSet) -> Void
    ) async {
        let allCorporaByID = Dictionary(uniqueKeysWithValues: features.sidebar.librarySnapshot.corpora.map { ($0.id, $0) })
        let selectedCorpora = features.compare.selectedCorpusItems()
        let referenceCorpusSet = features.compare.selectedReferenceCorpusSet()
        let referenceSetCorpora = referenceCorpusSet?.corpusIDs.compactMap { allCorporaByID[$0] } ?? []
        let targetCorpora: [LibraryCorpusItem]
        if let referenceCorpusSet {
            let referenceIDs = Set(referenceCorpusSet.corpusIDs)
            targetCorpora = selectedCorpora.filter { !referenceIDs.contains($0.id) }
        } else {
            targetCorpora = selectedCorpora
        }

        guard targetCorpora.count >= 2 || (referenceCorpusSet != nil && !targetCorpora.isEmpty) else {
            features.sidebar.setError(wordZText("Compare 至少需要选择 2 条目标语料；如果使用命名参考语料集，至少保留 1 条目标语料。", "Compare needs at least 2 target corpora, or at least 1 target corpus when a named reference set is used.", mode: .system))
            return
        }
        if referenceCorpusSet != nil && referenceSetCorpora.isEmpty {
            features.sidebar.setError(wordZText("当前命名参考语料集没有可用语料。", "The current named reference corpus set has no usable corpora.", mode: .system))
            return
        }

        await performResultRunTask(
            .compare,
            selecting: .compare,
            features: features,
            syncFeatureContexts: syncFeatureContexts
        ) {
            let comparisonEntries = try await self.buildComparisonEntries(from: targetCorpora + referenceSetCorpora)
            let result = try await self.repository.runCompare(comparisonEntries: comparisonEntries)
            features.compare.apply(result)
        }
    }

    func runKeyword(
        features: WorkspaceFeatureSet,
        syncFeatureContexts: @escaping @MainActor (WorkspaceFeatureSet) -> Void
    ) async {
        let focusCorpora = features.keyword.resolvedFocusCorpusItems()
        let referenceCorpora = features.keyword.resolvedReferenceCorpusItems()
        let importedReferenceParseResult = features.keyword.referenceSourceKind == .importedWordList
            ? KeywordSuiteAnalyzer.parseImportedReference(features.keyword.importedReferenceListText)
            : .empty
        let importedReferenceItems = importedReferenceParseResult.items

        guard !focusCorpora.isEmpty else {
            features.sidebar.setError(wordZText("请先选择要分析的目标语料。", "Choose a focus corpus before running keyword analysis.", mode: .system))
            return
        }
        guard !referenceCorpora.isEmpty || !importedReferenceItems.isEmpty else {
            features.sidebar.setError(wordZText("请先选择参照语料、参照语料集，或导入参照词表。", "Choose a reference corpus, reference set, or imported word list before running keyword analysis.", mode: .system))
            return
        }

        let focusIDs = Set(focusCorpora.map(\.id))
        let referenceIDs = Set(referenceCorpora.map(\.id))
        if importedReferenceItems.isEmpty,
           focusIDs == referenceIDs,
           focusIDs.count == focusCorpora.count,
           referenceIDs.count == referenceCorpora.count {
            features.sidebar.setError(wordZText("目标语料和参照语料不能完全相同。", "Focus and Reference cannot be identical.", mode: .system))
            return
        }

        await performResultRunTask(
            .keyword,
            selecting: .keyword,
            features: features,
            syncFeatureContexts: syncFeatureContexts
        ) {
            let focusEntries = try await self.buildKeywordRequestEntries(from: focusCorpora)
            let referenceEntries = try await self.buildKeywordRequestEntries(from: referenceCorpora)
            let request = KeywordSuiteRunRequest(
                focusEntries: focusEntries,
                referenceEntries: referenceEntries,
                importedReferenceItems: importedReferenceItems,
                focusLabel: features.keyword.focusSelectionSummary,
                referenceLabel: features.keyword.referenceSelectionSummary,
                configuration: features.keyword.suiteConfiguration
            )
            features.keyword.recordPendingRunConfiguration()
            let result = try await self.repository.runKeywordSuite(request)
            features.keyword.apply(result)
        }
    }

    func runChiSquare(
        features: WorkspaceFeatureSet,
        syncFeatureContexts: @escaping @MainActor (WorkspaceFeatureSet) -> Void
    ) async {
        do {
            let inputs = try features.chiSquare.validatedInputs()
            await performResultRunTask(
                .chiSquare,
                selecting: .chiSquare,
                features: features,
                syncFeatureContexts: syncFeatureContexts
            ) {
                let result = try await self.repository.runChiSquare(
                    a: inputs.0,
                    b: inputs.1,
                    c: inputs.2,
                    d: inputs.3,
                    yates: features.chiSquare.useYates
                )
                features.chiSquare.apply(result)
            }
        } catch {
            features.sidebar.setError(error.localizedDescription)
        }
    }
}
