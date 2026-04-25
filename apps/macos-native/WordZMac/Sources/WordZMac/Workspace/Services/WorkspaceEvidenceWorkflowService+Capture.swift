import Foundation

@MainActor
extension WorkspaceEvidenceWorkflowService {
    func refreshEvidenceItems(features: WorkspaceEvidenceWorkflowContext) async {
        do {
            let items = try await repository.listEvidenceItems()
            applyEvidenceItems(items, features: features)
            features.sidebar.clearError()
        } catch {
            features.sidebar.setError(error.localizedDescription)
        }
    }

    func captureCurrentKWICEvidenceItem(
        features: WorkspaceEvidenceWorkflowContext,
        draft: EvidenceCaptureDraft? = nil
    ) async {
        guard let scene = features.kwic.scene, let selectedRow = features.kwic.selectedSceneRow else {
            features.sidebar.setError(wordZText("当前没有可加入的 KWIC 证据条目。", "There is no KWIC row available to add as evidence.", mode: .system))
            return
        }

        let loadedSet = loadedKWICSavedSet(features: features)
        guard let corpus = evidenceCorpusMetadata(features: features, fallbackSet: loadedSet) else {
            features.sidebar.setError(wordZText("当前 KWIC 没有关联语料。", "The current KWIC result is not attached to a corpus.", mode: .system))
            return
        }

        let savedRow = matchingSavedSetRow(for: selectedRow, in: loadedSet)
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let metadataDraft = draft ?? EvidenceCaptureDraft()
        let item = EvidenceItem(
            id: UUID().uuidString,
            sourceKind: .kwic,
            savedSetID: loadedSet?.id,
            savedSetName: loadedSet?.name,
            corpusID: corpus.id,
            corpusName: corpus.name,
            sentenceId: selectedRow.sentenceId,
            sentenceTokenIndex: selectedRow.sentenceTokenIndex,
            leftContext: selectedRow.leftContext,
            keyword: selectedRow.keyword,
            rightContext: selectedRow.rightContext,
            fullSentenceText: normalizedEvidenceText(
                savedRow?.fullSentenceText ?? joinedEvidenceSentence(
                    left: selectedRow.leftContext,
                    keyword: selectedRow.keyword,
                    right: selectedRow.rightContext
                )
            ),
            citationText: normalizedEvidenceText(savedRow?.citationText ?? selectedRow.citationText),
            query: scene.query,
            leftWindow: scene.leftWindow,
            rightWindow: scene.rightWindow,
            searchOptionsSnapshot: scene.searchOptions,
            stopwordFilterSnapshot: scene.stopwordFilter,
            reviewStatus: .pending,
            sectionTitle: metadataDraft.normalizedSectionTitle,
            claim: metadataDraft.normalizedClaim,
            tags: metadataDraft.normalizedTags,
            note: metadataDraft.normalizedNote,
            createdAt: timestamp,
            updatedAt: timestamp
        )

        await saveEvidenceItem(
            item,
            successMessage: wordZText("已加入证据工作台。", "Added the row to the evidence workbench.", mode: .system),
            features: features
        )
    }

    func captureCurrentLocatorEvidenceItem(
        features: WorkspaceEvidenceWorkflowContext,
        draft: EvidenceCaptureDraft? = nil
    ) async {
        guard let scene = features.locator.scene, let selectedRow = features.locator.selectedSceneRow else {
            features.sidebar.setError(wordZText("当前没有可加入的定位证据条目。", "There is no locator row available to add as evidence.", mode: .system))
            return
        }

        let loadedSet = loadedLocatorSavedSet(features: features)
        guard let corpus = evidenceCorpusMetadata(features: features, fallbackSet: loadedSet) else {
            features.sidebar.setError(wordZText("当前定位结果没有关联语料。", "The current locator result is not attached to a corpus.", mode: .system))
            return
        }

        let savedRow = matchingSavedSetRow(for: selectedRow, in: loadedSet)
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let metadataDraft = draft ?? EvidenceCaptureDraft()
        let item = EvidenceItem(
            id: UUID().uuidString,
            sourceKind: .locator,
            savedSetID: loadedSet?.id,
            savedSetName: loadedSet?.name,
            corpusID: corpus.id,
            corpusName: corpus.name,
            sentenceId: selectedRow.sentenceId,
            sentenceTokenIndex: selectedRow.sourceCandidate.nodeIndex,
            leftContext: selectedRow.leftWords,
            keyword: selectedRow.nodeWord,
            rightContext: selectedRow.rightWords,
            fullSentenceText: normalizedEvidenceText(savedRow?.fullSentenceText ?? selectedRow.text),
            citationText: normalizedEvidenceText(savedRow?.citationText ?? selectedRow.citationText),
            query: scene.source.keyword,
            leftWindow: scene.leftWindow,
            rightWindow: scene.rightWindow,
            searchOptionsSnapshot: nil,
            stopwordFilterSnapshot: nil,
            reviewStatus: .pending,
            sectionTitle: metadataDraft.normalizedSectionTitle,
            claim: metadataDraft.normalizedClaim,
            tags: metadataDraft.normalizedTags,
            note: metadataDraft.normalizedNote,
            createdAt: timestamp,
            updatedAt: timestamp
        )

        await saveEvidenceItem(
            item,
            successMessage: wordZText("已加入证据工作台。", "Added the sentence to the evidence workbench.", mode: .system),
            features: features
        )
    }

    func captureSourceReaderEvidenceItem(
        sourceKind: EvidenceSourceKind,
        context: SourceReaderLaunchContext,
        anchor: SourceReaderHitAnchor,
        selection: SourceReaderSelection,
        features: WorkspaceEvidenceWorkflowContext,
        draft: EvidenceCaptureDraft? = nil
    ) async {
        guard let corpus = sourceReaderCorpusMetadata(context: context, features: features) else {
            features.sidebar.setError(wordZText("当前原文阅读结果没有关联语料。", "The current source reader result is not attached to a corpus.", mode: .system))
            return
        }

        let metadataDraft = draft ?? EvidenceCaptureDraft()
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let sentimentMetadata = sourceKind == .sentiment
            ? capturedSentimentMetadata(rowID: anchor.id, features: features)
            : nil
        let crossAnalysisMetadata = sentimentMetadata.flatMap { _ in
            capturedSentimentCrossAnalysisMetadata(rowID: anchor.id, features: features)
        }
        let item = EvidenceItem(
            id: UUID().uuidString,
            sourceKind: sourceKind,
            savedSetID: nil,
            savedSetName: nil,
            corpusID: corpus.id,
            corpusName: corpus.name,
            sentenceId: anchor.sentenceId,
            sentenceTokenIndex: anchor.tokenIndex,
            leftContext: selection.leftContext,
            keyword: selection.keyword,
            rightContext: selection.rightContext,
            fullSentenceText: normalizedEvidenceText(selection.hit.fullSentenceText),
            citationText: normalizedEvidenceText(selection.hit.citationText),
            query: normalizedQuery(context.query, fallback: selection.keyword),
            leftWindow: max(0, context.leftWindow ?? 0),
            rightWindow: max(0, context.rightWindow ?? 0),
            searchOptionsSnapshot: nil,
            stopwordFilterSnapshot: nil,
            reviewStatus: .pending,
            sectionTitle: metadataDraft.normalizedSectionTitle,
            claim: metadataDraft.normalizedClaim,
            tags: metadataDraft.normalizedTags,
            note: metadataDraft.normalizedNote,
            sentimentMetadata: sentimentMetadata,
            crossAnalysisMetadata: crossAnalysisMetadata,
            createdAt: timestamp,
            updatedAt: timestamp
        )

        await saveEvidenceItem(
            item,
            successMessage: wordZText("已从原文阅读器加入证据工作台。", "Added the source reader hit to the evidence workbench.", mode: .system),
            features: features
        )
    }
}
