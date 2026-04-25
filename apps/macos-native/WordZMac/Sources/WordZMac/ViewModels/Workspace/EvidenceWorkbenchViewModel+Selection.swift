import Foundation

extension EvidenceWorkbenchViewModel {
    func groupedItems(in mode: AppLanguageMode) -> [EvidenceWorkbenchGroup] {
        groupedItems(in: mode, items: filteredItems)
    }

    func allGroupedItems(in mode: AppLanguageMode) -> [EvidenceWorkbenchGroup] {
        groupedItems(in: mode, items: items)
    }

    func group(id: String, in mode: AppLanguageMode) -> EvidenceWorkbenchGroup? {
        groupedItems(in: mode).first { $0.id == id }
    }

    func allGroup(id: String, in mode: AppLanguageMode) -> EvidenceWorkbenchGroup? {
        allGroupedItems(in: mode).first { $0.id == id }
    }

    func group(
        matchingAssignmentValue assignmentValue: String,
        in mode: AppLanguageMode
    ) -> EvidenceWorkbenchGroup? {
        let lookupKey = normalizedLookupKey(assignmentValue)
        return allGroupedItems(in: mode).first { group in
            normalizedLookupKey(group.assignmentValue ?? group.title) == lookupKey
        }
    }

    func selectedGroup(in mode: AppLanguageMode) -> EvidenceWorkbenchGroup? {
        guard let groupID = selectedGroupID(in: mode) else { return nil }
        return group(id: groupID, in: mode)
    }

    var selectedItem: EvidenceItem? {
        guard let selectedItemID else { return filteredItems.first }
        return filteredItems.first(where: { $0.id == selectedItemID }) ?? filteredItems.first
    }

    var selectedFilteredIndex: Int? {
        guard let selectedItemID = selectedItem?.id else { return nil }
        return filteredItems.firstIndex(where: { $0.id == selectedItemID })
    }

    var canMoveSelectedItemUp: Bool {
        canMoveSelectedItem(.up)
    }

    var canMoveSelectedItemDown: Bool {
        canMoveSelectedItem(.down)
    }

    var canMoveSelectedGroupUp: Bool {
        canMoveSelectedGroup(.up)
    }

    var canMoveSelectedGroupDown: Bool {
        canMoveSelectedGroup(.down)
    }

    var canSplitSelectedGroup: Bool {
        splitSelectionContext() != nil
    }

    func applyItems(_ items: [EvidenceItem]) {
        self.items = items
        normalizeSelection()
        syncEditorState()
    }

    func normalizeSelection() {
        let filteredIDs = Set(filteredItems.map(\.id))
        if let selectedItemID, filteredIDs.contains(selectedItemID) {
            return
        }
        selectedItemID = filteredItems.first?.id
    }

    func syncEditorState() {
        sectionDraft = selectedItem?.sectionTitle ?? ""
        claimDraft = selectedItem?.claim ?? ""
        tagsDraft = selectedItem?.tagSummaryText ?? ""
        noteDraft = selectedItem?.note ?? ""
    }

    private func groupedItems(
        in mode: AppLanguageMode,
        items: [EvidenceItem]
    ) -> [EvidenceWorkbenchGroup] {
        EvidenceWorkbenchGroupingSupport.makeGroups(
            items: items,
            grouping: groupingMode,
            mode: mode
        )
    }
}
