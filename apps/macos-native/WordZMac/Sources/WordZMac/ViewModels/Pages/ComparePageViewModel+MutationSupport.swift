import Foundation

extension ComparePageViewModel {
    func performSelectionMutation(
        resetResult: Bool = false,
        rebuildScene shouldRebuildScene: Bool,
        mutation: () -> Void
    ) {
        applyStateChange {
            mutation()
            syncSelectionItemsWithSelectedCorpora()
            normalizeReferenceSelection()
            rebuildReferenceOptions()

            if resetResult {
                result = nil
                currentPage = 1
                selectedRowID = nil
                invalidateCaches()
                if !shouldRebuildScene {
                    scene = nil
                }
            } else if shouldRebuildScene {
                currentPage = 1
            }
        }

        onInputChange?()
        if shouldRebuildScene {
            rebuildScene()
        }
    }

    func syncSelectionItemsWithSelectedCorpora() {
        let nextItems = selectionItems.map {
            CompareSelectableCorpusSceneItem(
                id: $0.id,
                title: $0.title,
                subtitle: $0.subtitle,
                isSelected: selectedCorpusIDs.contains($0.id)
            )
        }
        if nextItems != selectionItems {
            selectionItems = nextItems
        }
    }
}
