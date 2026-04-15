import Foundation

@MainActor
extension MainWorkspaceViewModel {
    func analyzeCompareSelectionInKeywordSuite() {
        let focusCorpusIDs: [String]
        switch compare.selectedReferenceSelection {
        case .automatic:
            focusCorpusIDs = compare.selectedCorpusIDsSnapshot
        case .corpus, .corpusSet:
            focusCorpusIDs = compare.selectedTargetCorpusItems().map(\.id)
        }
        keyword.applyCompareSelection(
            selectedCorpusIDs: focusCorpusIDs,
            referenceSelection: compare.selectedReferenceSelection
        )
        selectedTab = .keyword
        flowCoordinator.markWorkspaceEdited(features: features)
        syncSceneGraph(source: .navigation)
    }

    func openCompareDistributionFromKeyword() {
        if let row = keyword.selectedKeywordRow {
            compare.query = row.item
        }

        let selectedIDs = Set(keyword.resolvedFocusCorpusItems().map(\.id) + keyword.resolvedReferenceCorpusItems().map(\.id))
        if !selectedIDs.isEmpty {
            compare.selectedCorpusIDs = selectedIDs
            compare.selectionItems = compare.selectionItems.map {
                CompareSelectableCorpusSceneItem(
                    id: $0.id,
                    title: $0.title,
                    subtitle: $0.subtitle,
                    isSelected: selectedIDs.contains($0.id)
                )
            }
            switch keyword.referenceSourceKind {
            case .singleCorpus:
                if let referenceID = keyword.selectedReferenceCorpusItem()?.id {
                    compare.selectedReferenceSelection = .corpus(referenceID)
                }
            case .namedCorpusSet:
                if let referenceSetID = keyword.selectedReferenceCorpusSet()?.id {
                    compare.selectedReferenceSelection = .corpusSet(referenceSetID)
                }
            case .importedWordList:
                compare.selectedReferenceSelection = .automatic
            }
            compare.normalizeReferenceSelection()
            compare.rebuildReferenceOptions()
            compare.rebuildScene()
        }

        selectedTab = .compare
        flowCoordinator.markWorkspaceEdited(features: features)
        syncSceneGraph(source: .navigation)
    }
}
