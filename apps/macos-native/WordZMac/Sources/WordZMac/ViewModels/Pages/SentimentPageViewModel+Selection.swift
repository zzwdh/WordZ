import Foundation

extension SentimentPageViewModel {
    func selectedTargetCorpusItems() -> [LibraryCorpusItem] {
        switch selectedReferenceSelection {
        case .automatic:
            return selectedCorpusItems()
        case .corpus(let corpusID):
            return selectedCorpusItems().filter { $0.id != corpusID }
        case .corpusSet:
            let referenceIDs = Set(selectedReferenceCorpusSet()?.corpusIDs ?? [])
            return selectedCorpusItems().filter { !referenceIDs.contains($0.id) }
        }
    }

    func selectedCorpusItems() -> [LibraryCorpusItem] {
        availableCorpora.filter { selectedCorpusIDs.contains($0.id) }
    }

    func selectedReferenceCorpusItem() -> LibraryCorpusItem? {
        guard case .corpus(let corpusID) = selectedReferenceSelection else { return nil }
        return availableCorpora.first(where: { $0.id == corpusID })
    }

    func selectedReferenceCorpusSet() -> LibraryCorpusSetItem? {
        guard case .corpusSet(let corpusSetID) = selectedReferenceSelection else { return nil }
        return availableCorpusSets.first(where: { $0.id == corpusSetID })
    }

    func selectedReferenceCorpusItems() -> [LibraryCorpusItem] {
        switch selectedReferenceSelection {
        case .automatic:
            return []
        case .corpus(let corpusID):
            return availableCorpora.filter { $0.id == corpusID }
        case .corpusSet:
            let referenceIDs = Set(selectedReferenceCorpusSet()?.corpusIDs ?? [])
            return availableCorpora.filter { referenceIDs.contains($0.id) }
        }
    }

    var selectedReferenceOptionID: String {
        selectedReferenceSelection.optionID
    }

    var selectedReferenceCorpusID: String {
        get { selectedReferenceSelection.optionID }
        set { selectedReferenceSelection = CompareReferenceSelection(optionID: newValue) }
    }

    var selectedReferenceCorpusSetID: String? {
        selectedReferenceSelection.corpusSetID
    }

    func applyWorkspaceAnnotationState(_ state: WorkspaceAnnotationState) {
        guard annotationState != state else { return }
        annotationState = state
        rebuildScene()
    }

    func corpusCompareScopeSummary(in mode: AppLanguageMode) -> String {
        let targetLabel = joinedCorpusScopeLabel(
            selectedTargetCorpusItems().map(\.name),
            emptyLabel: wordZText("未选择目标语料", "No target corpora selected", mode: mode)
        )
        switch selectedReferenceSelection {
        case .automatic:
            return "\(wordZText("目标语料", "Target Corpora", mode: mode)): \(targetLabel)"
        case .corpus(let corpusID):
            let referenceLabel = selectedReferenceCorpusItem()?.name ?? corpusID
            return "\(wordZText("目标语料", "Target Corpora", mode: mode)): \(targetLabel) · \(wordZText("参考语料", "Reference Corpus", mode: mode)): \(referenceLabel)"
        case .corpusSet(let corpusSetID):
            let referenceLabel = selectedReferenceCorpusSet()?.name ?? corpusSetID
            return "\(wordZText("目标语料", "Target Corpora", mode: mode)): \(targetLabel) · \(wordZText("参考语料集", "Reference Set", mode: mode)): \(referenceLabel)"
        }
    }

    func syncLibrarySnapshot(_ snapshot: LibrarySnapshot) {
        refreshAvailableBackends()
        availableCorpora = snapshot.corpora
        availableCorpusSets = snapshot.corpusSets
        let validIDs = Set(snapshot.corpora.map(\.id))
        selectedCorpusIDs = selectedCorpusIDs.intersection(validIDs)
        if selectedCorpusIDs.isEmpty, let firstCorpus = snapshot.corpora.first {
            selectedCorpusIDs.insert(firstCorpus.id)
        }
        normalizeReferenceSelection()
        rebuildCorpusOptions()
        rebuildScene()
    }

    func rebuildCorpusOptions() {
        let languageMode = WordZLocalization.shared.effectiveMode
        selectionItems = availableCorpora.map { corpus in
            SentimentSelectableCorpusSceneItem(
                id: corpus.id,
                title: corpus.name,
                subtitle: corpus.folderName,
                isSelected: selectedCorpusIDs.contains(corpus.id)
            )
        }
        let selectedCorpusOptions = selectionItems
            .filter(\.isSelected)
            .map {
                SentimentReferenceOptionSceneItem(
                    id: $0.id,
                    title: wordZText("参考语料：", "Reference Corpus: ", mode: languageMode) + $0.title,
                    subtitle: $0.subtitle
                )
            }
        let corpusSetOptions = availableCorpusSets.map { corpusSet in
            SentimentReferenceOptionSceneItem(
                id: CompareReferenceSelection.corpusSet(corpusSet.id).optionID,
                title: wordZText("参考语料集：", "Reference Set: ", mode: languageMode) + corpusSet.name,
                subtitle: String(
                    format: wordZText("%d 条语料", "%d corpora", mode: languageMode),
                    corpusSet.corpusIDs.count
                )
            )
        }
        referenceOptions = selectedCorpusOptions + corpusSetOptions
        normalizeReferenceSelection()
    }

    func normalizeReferenceSelection() {
        switch selectedReferenceSelection {
        case .automatic:
            return
        case .corpus(let corpusID):
            guard selectedCorpusIDs.contains(corpusID),
                  availableCorpora.contains(where: { $0.id == corpusID }) else {
                selectedReferenceSelection = .automatic
                return
            }
        case .corpusSet(let corpusSetID):
            guard availableCorpusSets.contains(where: { $0.id == corpusSetID }) else {
                selectedReferenceSelection = .automatic
                return
            }
        }
    }

    private func joinedCorpusScopeLabel(
        _ corpusNames: [String],
        emptyLabel: String
    ) -> String {
        let labels = corpusNames.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !labels.isEmpty else { return emptyLabel }
        return labels.joined(separator: ", ")
    }

    func topicSegmentScopeSummary(in mode: AppLanguageMode) -> String {
        if topicSegmentsFocusClusterID != nil {
            return wordZText("当前选中主题", "Selected Topic", mode: mode)
        }
        return wordZText("当前可见主题", "Visible Topics", mode: mode)
    }

    func orderedTopicGroupTitles() -> [String] {
        var seen: Set<String> = []
        return rawResult?.request.texts.compactMap { text in
            let title = text.groupTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !title.isEmpty else { return nil }
            guard seen.insert(title).inserted else { return nil }
            return title
        } ?? []
    }
}
