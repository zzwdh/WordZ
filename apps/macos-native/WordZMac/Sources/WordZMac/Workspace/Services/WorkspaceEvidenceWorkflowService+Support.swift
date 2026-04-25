import Foundation

@MainActor
extension WorkspaceEvidenceWorkflowService {
    func saveEvidenceItem(
        _ item: EvidenceItem,
        successMessage: String,
        features: WorkspaceEvidenceWorkflowContext
    ) async {
        do {
            let savedItem = try await repository.saveEvidenceItem(item)
            let items = try await repository.listEvidenceItems()
            applyEvidenceItems(items, features: features)
            restoreEvidenceSelection(afterSaving: savedItem, features: features)
            features.library.setStatus(successMessage)
            features.sidebar.clearError()
        } catch {
            features.sidebar.setError(error.localizedDescription)
        }
    }

    func exportTextDocument(
        _ document: PlainTextExportDocument,
        title: String,
        successStatus: String,
        features: WorkspaceEvidenceWorkflowContext,
        preferredRoute: NativeWindowRoute?
    ) async {
        do {
            if let savedPath = try await exportCoordinator.export(
                textDocument: document,
                title: title,
                preferredRoute: preferredRoute
            ) {
                features.library.setStatus("\(successStatus) \(savedPath)")
                features.sidebar.clearError()
            }
        } catch {
            features.sidebar.setError(error.localizedDescription)
        }
    }

    func applyEvidenceItems(
        _ items: [EvidenceItem],
        features: WorkspaceEvidenceWorkflowContext
    ) {
        features.evidenceWorkbench.applyItems(items)
    }

    func restoreEvidenceSelection(
        afterSaving item: EvidenceItem,
        features: WorkspaceEvidenceWorkflowContext
    ) {
        if features.evidenceWorkbench.reviewFilter.includes(item.reviewStatus) {
            features.evidenceWorkbench.selectedItemID = item.id
        } else {
            restoreEvidenceSelection(
                preferredItemID: nil,
                features: features
            )
        }
    }

    func restoreEvidenceSelection(
        preferredItemID: String?,
        features: WorkspaceEvidenceWorkflowContext
    ) {
        if let preferredItemID,
           features.evidenceWorkbench.filteredItems.contains(where: { $0.id == preferredItemID }) {
            features.evidenceWorkbench.selectedItemID = preferredItemID
        } else {
            features.evidenceWorkbench.normalizeSelection()
        }
    }

    func evidenceCorpusMetadata(
        features: WorkspaceEvidenceWorkflowContext,
        fallbackSet: ConcordanceSavedSet?
    ) -> (id: String, name: String)? {
        if let corpus = currentEvidenceScopeCorpus(features: features) {
            return (corpus.id, corpus.name)
        }
        if let fallbackSet {
            return (fallbackSet.corpusID, fallbackSet.corpusName)
        }
        guard let corpusID = features.sidebar.selectedCorpusID ?? sessionStore.openedCorpusSourceID else {
            return nil
        }
        let corpusName = features.sidebar.librarySnapshot.corpora.first(where: { $0.id == corpusID })?.name
            ?? wordZText("未命名语料", "Untitled Corpus", mode: .system)
        return (corpusID, corpusName)
    }

    func sourceReaderCorpusMetadata(
        context: SourceReaderLaunchContext,
        features: WorkspaceEvidenceWorkflowContext
    ) -> (id: String, name: String)? {
        if let corpusID = normalizedValue(context.corpusID) {
            let corpusName = normalizedValue(context.corpusName)
                ?? features.sidebar.librarySnapshot.corpora.first(where: { $0.id == corpusID })?.name
                ?? wordZText("未命名语料", "Untitled Corpus", mode: .system)
            return (corpusID, corpusName)
        }
        return evidenceCorpusMetadata(features: features, fallbackSet: nil)
    }

    func capturedSentimentMetadata(
        rowID: String,
        features: WorkspaceEvidenceWorkflowContext
    ) -> EvidenceSentimentMetadata? {
        guard let rawResult = features.sentiment.rawResult,
              let rawRow = rawResult.rows.first(where: { $0.id == rowID }),
              let effectiveRow = features.sentiment.presentationResult?.effectiveRows.first(where: { $0.id == rowID })
        else {
            return nil
        }

        let topRuleTraceSteps = rawRow.diagnostics.ruleTraces
            .flatMap(\.appliedSteps)
            .prefix(8)
            .map { $0 }

        return EvidenceSentimentMetadata(
            source: rawResult.request.source,
            unit: rawResult.request.unit,
            contextBasis: rawResult.request.contextBasis,
            backendKind: rawResult.backendKind,
            backendRevision: rawResult.backendRevision,
            resourceRevision: rawResult.resourceRevision,
            providerID: rawResult.providerID ?? rawRow.diagnostics.providerID,
            providerFamily: rawResult.providerFamily ?? rawRow.diagnostics.providerFamily,
            domainPackID: rawResult.request.resolvedDomainPackID,
            ruleProfileID: rawResult.request.ruleProfile.id,
            calibrationProfileRevision: rawResult.calibrationProfileRevision,
            activePackIDs: rawResult.activePackIDs,
            rawLabel: rawRow.finalLabel,
            rawScores: rawRow.scoreTriple,
            effectiveLabel: effectiveRow.effectiveLabel,
            effectiveScores: effectiveRow.effectiveScores,
            reviewDecision: effectiveRow.reviewDecision,
            reviewStatus: effectiveRow.reviewStatus,
            reviewNote: effectiveRow.reviewNote,
            reviewSampleID: effectiveRow.reviewSampleID,
            reviewedAt: effectiveRow.reviewedAt,
            rowID: rawRow.id,
            sourceID: rawRow.sourceID,
            sentenceID: rawRow.sentenceID,
            tokenIndex: rawRow.tokenIndex,
            ruleSummary: rawRow.diagnostics.ruleSummary,
            topRuleTraceSteps: topRuleTraceSteps,
            inferencePath: rawRow.diagnostics.inferencePath,
            modelInputKind: rawRow.diagnostics.modelInputKind
        )
    }

    func capturedSentimentCrossAnalysisMetadata(
        rowID: String,
        features: WorkspaceEvidenceWorkflowContext
    ) -> EvidenceCrossAnalysisMetadata? {
        guard let rawResult = features.sentiment.rawResult,
              let rawRow = rawResult.rows.first(where: { $0.id == rowID })
        else {
            return nil
        }

        switch rawResult.request.source {
        case .corpusCompare:
            return EvidenceCrossAnalysisMetadata(
                originKind: .compareSentiment,
                scopeSummary: features.sentiment.corpusCompareScopeSummary(in: .system),
                focusTerm: normalizedValue(features.sentiment.rowFilterQuery),
                focusedTopicID: nil,
                groupTitle: normalizedValue(rawRow.groupTitle),
                compareSide: normalizedValue(rawRow.groupID),
                topicTitle: nil
            )
        case .topicSegments:
            let scopeSummary: String
            if features.sentiment.topicSegmentsFocusClusterID != nil {
                scopeSummary = wordZText("当前选中主题", "Selected Topic", mode: .system)
            } else {
                scopeSummary = wordZText("当前可见主题", "Visible Topics", mode: .system)
            }
            return EvidenceCrossAnalysisMetadata(
                originKind: .topicsSentiment,
                scopeSummary: scopeSummary,
                focusTerm: nil,
                focusedTopicID: normalizedValue(features.sentiment.topicSegmentsFocusClusterID),
                groupTitle: normalizedValue(rawRow.groupTitle),
                compareSide: nil,
                topicTitle: normalizedValue(rawRow.groupTitle)
            )
        case .openedCorpus, .pastedText, .kwicVisible:
            return EvidenceCrossAnalysisMetadata(
                originKind: .sentimentDirect,
                scopeSummary: rawResult.request.source.title(in: .system),
                focusTerm: normalizedValue(features.sentiment.rowFilterQuery),
                focusedTopicID: nil,
                groupTitle: normalizedValue(rawRow.groupTitle),
                compareSide: normalizedValue(rawRow.groupID),
                topicTitle: nil
            )
        }
    }

    func loadedKWICSavedSet(features: WorkspaceEvidenceWorkflowContext) -> ConcordanceSavedSet? {
        guard let loadedSavedSetID = features.kwic.loadedSavedSetID else { return nil }
        return features.kwic.savedSets.first(where: { $0.id == loadedSavedSetID })
    }

    func loadedLocatorSavedSet(features: WorkspaceEvidenceWorkflowContext) -> ConcordanceSavedSet? {
        guard let loadedSavedSetID = features.locator.loadedSavedSetID else { return nil }
        return features.locator.savedSets.first(where: { $0.id == loadedSavedSetID })
    }

    func matchingSavedSetRow(
        for row: KWICSceneRow,
        in set: ConcordanceSavedSet?
    ) -> ConcordanceSavedSetRow? {
        guard let set else { return nil }
        if let directMatch = set.rows.first(where: { $0.id == row.id }) {
            return directMatch
        }
        return set.rows.first {
            $0.sentenceId == row.sentenceId && $0.sentenceTokenIndex == row.sentenceTokenIndex
        }
    }

    func matchingSavedSetRow(
        for row: LocatorSceneRow,
        in set: ConcordanceSavedSet?
    ) -> ConcordanceSavedSetRow? {
        guard let set else { return nil }
        return set.rows.first {
            $0.sentenceId == row.sentenceId &&
                ($0.sentenceTokenIndex == row.sourceCandidate.nodeIndex || $0.keyword == row.nodeWord)
        } ?? set.rows.first(where: { $0.sentenceId == row.sentenceId })
    }

    func normalizedEvidenceText(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? value : trimmed
    }

    func normalizedQuery(_ value: String, fallback: String) -> String {
        normalizedValue(value) ?? normalizedValue(fallback) ?? ""
    }

    func joinedEvidenceSentence(left: String, keyword: String, right: String) -> String {
        [left, keyword, right]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    func currentEvidenceScopeCorpus(features: WorkspaceEvidenceWorkflowContext) -> LibraryCorpusItem? {
        let corpusID = features.sidebar.selectedCorpusID ?? sessionStore.openedCorpusSourceID
        guard let corpusID else { return nil }
        return features.sidebar.librarySnapshot.corpora.first(where: { $0.id == corpusID })
    }

    func normalizedValue(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
