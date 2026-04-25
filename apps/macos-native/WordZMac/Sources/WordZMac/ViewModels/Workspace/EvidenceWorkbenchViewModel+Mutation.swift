import Foundation

extension EvidenceWorkbenchViewModel {
    func canMoveSelectedItem(_ direction: EvidenceWorkbenchMoveDirection) -> Bool {
        guard let selectedFilteredIndex else { return false }
        switch direction {
        case .up:
            return selectedFilteredIndex > 0
        case .down:
            return selectedFilteredIndex < filteredItems.index(before: filteredItems.endIndex)
        }
    }

    func reorderedItemsMovingSelected(_ direction: EvidenceWorkbenchMoveDirection) -> [EvidenceItem]? {
        guard let selectedFilteredIndex else { return nil }

        let neighborFilteredIndex: Int
        switch direction {
        case .up:
            guard selectedFilteredIndex > 0 else { return nil }
            neighborFilteredIndex = selectedFilteredIndex - 1
        case .down:
            guard selectedFilteredIndex < filteredItems.index(before: filteredItems.endIndex) else { return nil }
            neighborFilteredIndex = selectedFilteredIndex + 1
        }

        var reorderedVisibleItems = filteredItems
        reorderedVisibleItems.swapAt(selectedFilteredIndex, neighborFilteredIndex)
        return reorderedItemsReplacingFilteredSlots(with: reorderedVisibleItems.map(\.id))
    }

    func canMoveSelectedGroup(_ direction: EvidenceWorkbenchMoveDirection) -> Bool {
        guard let groupID = selectedGroupID(in: .system) else { return false }
        return canMoveGroup(id: groupID, direction, in: .system)
    }

    func reorderedItemsMovingSelectedGroup(_ direction: EvidenceWorkbenchMoveDirection) -> [EvidenceItem]? {
        guard let groupID = selectedGroupID(in: .system) else { return nil }
        return reorderedItemsMovingGroup(id: groupID, direction, in: .system)
    }

    func canMoveGroup(
        id groupID: String,
        _ direction: EvidenceWorkbenchMoveDirection,
        in mode: AppLanguageMode
    ) -> Bool {
        let groups = groupedItems(in: mode)
        guard let groupIndex = groupIndex(for: groupID, in: mode) else { return false }
        switch direction {
        case .up:
            return groupIndex > 0
        case .down:
            return groupIndex < groups.index(before: groups.endIndex)
        }
    }

    func reorderedItemsMovingGroup(
        id groupID: String,
        _ direction: EvidenceWorkbenchMoveDirection,
        in mode: AppLanguageMode
    ) -> [EvidenceItem]? {
        let groups = groupedItems(in: mode)
        guard let groupIndex = groupIndex(for: groupID, in: mode) else { return nil }

        let neighborGroupIndex: Int
        switch direction {
        case .up:
            guard groupIndex > 0 else { return nil }
            neighborGroupIndex = groupIndex - 1
        case .down:
            guard groupIndex < groups.index(before: groups.endIndex) else { return nil }
            neighborGroupIndex = groupIndex + 1
        }

        var reorderedGroups = groups
        reorderedGroups.swapAt(groupIndex, neighborGroupIndex)
        return reorderedItemsReplacingFilteredSlots(with: reorderedGroups.flatMap(\.items).map(\.id))
    }

    func reorderedItemsMovingGroup(
        id sourceGroupID: String,
        to targetGroupID: String,
        placement: EvidenceWorkbenchGroupInsertPlacement,
        in mode: AppLanguageMode
    ) -> [EvidenceItem]? {
        guard sourceGroupID != targetGroupID else { return nil }

        let groups = groupedItems(in: mode)
        guard let sourceIndex = groupIndex(for: sourceGroupID, in: mode),
              let targetIndex = groupIndex(for: targetGroupID, in: mode)
        else {
            return nil
        }

        let movingGroup = groups[sourceIndex]
        var reorderedGroups = groups
        reorderedGroups.remove(at: sourceIndex)

        let adjustedTargetIndex = targetIndex > sourceIndex ? targetIndex - 1 : targetIndex
        let insertionIndex: Int
        switch placement {
        case .before:
            insertionIndex = adjustedTargetIndex
        case .after:
            insertionIndex = adjustedTargetIndex + 1
        }

        guard insertionIndex >= 0, insertionIndex <= reorderedGroups.count else { return nil }
        reorderedGroups.insert(movingGroup, at: insertionIndex)

        let reorderedIDs = reorderedGroups.flatMap(\.items).map(\.id)
        guard reorderedIDs != filteredItems.map(\.id) else { return nil }
        return reorderedItemsReplacingFilteredSlots(with: reorderedIDs)
    }

    func reorderedItemsAssigningItem(
        id itemID: String,
        to targetGroupID: String,
        in mode: AppLanguageMode
    ) -> [EvidenceItem]? {
        guard groupingMode.supportsItemAssignment else { return nil }
        guard let currentGroupID = selectedGroupID(for: itemID, in: mode),
              currentGroupID != targetGroupID,
              let targetGroup = group(id: targetGroupID, in: mode),
              let sourceIndex = filteredItems.firstIndex(where: { $0.id == itemID })
        else {
            return nil
        }

        var reorderedVisibleItems = filteredItems
        var movingItem = reorderedVisibleItems.remove(at: sourceIndex)
        switch groupingMode {
        case .section:
            movingItem.sectionTitle = targetGroup.assignmentValue
        case .claim:
            movingItem.claim = targetGroup.assignmentValue
        case .corpusSet:
            return nil
        }

        let targetItemIDs = targetGroup.items.map(\.id).filter { $0 != itemID }
        let insertionIndex: Int
        if let lastTargetItemID = targetItemIDs.last,
           let targetIndex = reorderedVisibleItems.lastIndex(where: { $0.id == lastTargetItemID })
        {
            insertionIndex = targetIndex + 1
        } else {
            insertionIndex = reorderedVisibleItems.endIndex
        }

        reorderedVisibleItems.insert(movingItem, at: insertionIndex)
        return reorderedItemsReplacingFilteredSlots(with: reorderedVisibleItems)
    }

    func reorderedItemsAssigningItem(
        id itemID: String,
        toNewGroup assignmentValue: String
    ) -> [EvidenceItem]? {
        guard groupingMode.supportsItemAssignment else { return nil }
        let normalizedAssignmentValue = normalizedText(assignmentValue)
        guard let normalizedAssignmentValue,
              let sourceIndex = filteredItems.firstIndex(where: { $0.id == itemID })
        else {
            return nil
        }

        var reorderedVisibleItems = filteredItems
        var movingItem = reorderedVisibleItems.remove(at: sourceIndex)
        switch groupingMode {
        case .section:
            guard normalizedText(movingItem.sectionTitle) != normalizedAssignmentValue else { return nil }
            movingItem.sectionTitle = normalizedAssignmentValue
        case .claim:
            guard normalizedText(movingItem.claim) != normalizedAssignmentValue else { return nil }
            movingItem.claim = normalizedAssignmentValue
        case .corpusSet:
            return nil
        }

        reorderedVisibleItems.append(movingItem)
        return reorderedItemsReplacingFilteredSlots(with: reorderedVisibleItems)
    }

    func reorderedItemsRenamingGroup(
        id sourceGroupID: String,
        to assignmentValue: String
    ) -> [EvidenceItem]? {
        guard groupingMode.supportsItemAssignment,
              let normalizedAssignmentValue = normalizedText(assignmentValue)
        else {
            return nil
        }

        if let matchingTargetGroup = group(
            matchingAssignmentValue: normalizedAssignmentValue,
            in: .system
        ) {
            guard matchingTargetGroup.id != sourceGroupID else { return nil }
            return reorderedItemsMergingGroup(
                id: sourceGroupID,
                into: matchingTargetGroup.id
            )
        }

        let updatedItems = items.map { item in
            guard groupID(for: item) == sourceGroupID else { return item }
            return itemAssigningGroupValue(item, assignmentValue: normalizedAssignmentValue)
        }

        return updatedItems == items ? nil : updatedItems
    }

    func reorderedItemsMergingGroup(
        id sourceGroupID: String,
        into targetGroupID: String
    ) -> [EvidenceItem]? {
        guard groupingMode.supportsItemAssignment,
              sourceGroupID != targetGroupID
        else {
            return nil
        }

        let sourceItems = items.filter { groupID(for: $0) == sourceGroupID }
        let targetItems = items.filter { groupID(for: $0) == targetGroupID }
        guard !sourceItems.isEmpty,
              !targetItems.isEmpty
        else {
            return nil
        }

        let targetAssignmentValue = targetItems
            .compactMap { assignmentValue(for: $0) }
            .first
        let sourceIDs = Set(sourceItems.map(\.id))
        let targetIDs = Set(targetItems.map(\.id))
        let updatedSourceItems = sourceItems.map {
            itemAssigningGroupValue($0, assignmentValue: targetAssignmentValue)
        }

        var reorderedItems = items.filter { !sourceIDs.contains($0.id) }
        guard let targetEndIndex = reorderedItems.lastIndex(where: { targetIDs.contains($0.id) }) else {
            return nil
        }

        reorderedItems.insert(contentsOf: updatedSourceItems, at: targetEndIndex + 1)
        return reorderedItems == items ? nil : reorderedItems
    }

    func reorderedItemsSplittingSelectedGroup(
        to assignmentValue: String
    ) -> [EvidenceItem]? {
        guard groupingMode.supportsItemAssignment,
              let normalizedAssignmentValue = normalizedText(assignmentValue),
              let splitContext = splitSelectionContext()
        else {
            return nil
        }

        if let matchingGroup = group(
            matchingAssignmentValue: normalizedAssignmentValue,
            in: .system
        ) {
            guard matchingGroup.id != splitContext.sourceGroupID else { return nil }
            return nil
        }

        let sourceAssignmentValue = allGroup(
            id: splitContext.sourceGroupID,
            in: .system
        )?.assignmentValue
        guard normalizedLookupKey(sourceAssignmentValue) != normalizedLookupKey(normalizedAssignmentValue) else {
            return nil
        }

        let movingIDs = Set(splitContext.movingItems.map(\.id))
        let updatedMovingItems = splitContext.movingItems.map {
            itemAssigningGroupValue($0, assignmentValue: normalizedAssignmentValue)
        }

        var reorderedItems = items.filter { !movingIDs.contains($0.id) }
        guard let sourceEndIndex = reorderedItems.lastIndex(where: { splitContext.remainingSourceIDs.contains($0.id) }) else {
            return nil
        }

        reorderedItems.insert(contentsOf: updatedMovingItems, at: sourceEndIndex + 1)
        return reorderedItems == items ? nil : reorderedItems
    }

    func isSelectedGroup(id groupID: String, in mode: AppLanguageMode) -> Bool {
        selectedGroupID(in: mode) == groupID
    }

    func selectedGroupID(in mode: AppLanguageMode) -> String? {
        guard let selectedItemID = selectedItem?.id else { return nil }
        return selectedGroupID(for: selectedItemID, in: mode)
    }

    private func selectedGroupID(
        for itemID: String,
        in mode: AppLanguageMode
    ) -> String? {
        let groups = groupedItems(in: mode)
        return groups.firstIndex { group in
            group.items.contains(where: { $0.id == itemID })
        }.map { groups[$0].id }
    }

    private func groupIndex(for groupID: String, in mode: AppLanguageMode) -> Int? {
        groupedItems(in: mode).firstIndex { $0.id == groupID }
    }

    private func groupID(for item: EvidenceItem) -> String {
        EvidenceWorkbenchGroupingSupport.groupID(
            for: item,
            grouping: groupingMode
        )
    }

    private func assignmentValue(for item: EvidenceItem) -> String? {
        EvidenceWorkbenchGroupingSupport.assignmentValue(
            for: item,
            grouping: groupingMode
        )
    }

    private func itemAssigningGroupValue(
        _ item: EvidenceItem,
        assignmentValue: String?
    ) -> EvidenceItem {
        var updatedItem = item
        switch groupingMode {
        case .section:
            updatedItem.sectionTitle = normalizedText(assignmentValue)
        case .claim:
            updatedItem.claim = normalizedText(assignmentValue)
        case .corpusSet:
            break
        }
        return updatedItem
    }

    func normalizedLookupKey(_ value: String?) -> String? {
        normalizedText(value)?
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    func splitSelectionContext() -> (
        sourceGroupID: String,
        remainingSourceIDs: Set<String>,
        movingItems: [EvidenceItem]
    )? {
        guard groupingMode.supportsItemAssignment,
              let selectedItem = selectedItem
        else {
            return nil
        }

        let sourceGroupID = groupID(for: selectedItem)
        let sourceGroupItems = items.filter { groupID(for: $0) == sourceGroupID }
        guard sourceGroupItems.count >= 2,
              let selectedGroupIndex = sourceGroupItems.firstIndex(where: { $0.id == selectedItem.id }),
              selectedGroupIndex > 0
        else {
            return nil
        }

        let remainingSourceIDs = Set(sourceGroupItems[..<selectedGroupIndex].map(\.id))
        let movingItems = Array(sourceGroupItems[selectedGroupIndex...])
        return (
            sourceGroupID: sourceGroupID,
            remainingSourceIDs: remainingSourceIDs,
            movingItems: movingItems
        )
    }

    private func reorderedItemsReplacingFilteredSlots(with reorderedFilteredIDs: [String]) -> [EvidenceItem]? {
        guard reorderedFilteredIDs.count == filteredItems.count else { return nil }

        let itemsByID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        let reorderedFilteredItems = reorderedFilteredIDs.compactMap { itemsByID[$0] }
        guard reorderedFilteredItems.count == reorderedFilteredIDs.count else { return nil }
        return reorderedItemsReplacingFilteredSlots(with: reorderedFilteredItems)
    }

    private func reorderedItemsReplacingFilteredSlots(with reorderedFilteredItems: [EvidenceItem]) -> [EvidenceItem]? {
        guard reorderedFilteredItems.count == filteredItems.count else { return nil }

        var filteredIterator = reorderedFilteredItems.makeIterator()
        var reordered: [EvidenceItem] = []
        reordered.reserveCapacity(items.count)

        for item in items {
            guard reviewFilter.includes(item.reviewStatus) else {
                reordered.append(item)
                continue
            }

            guard let nextItem = filteredIterator.next()
            else {
                return nil
            }
            reordered.append(nextItem)
        }

        guard filteredIterator.next() == nil else { return nil }
        return reordered
    }
}
