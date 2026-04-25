import Foundation

@MainActor
extension WorkspaceEvidenceWorkflowService {
    func moveSelectedEvidenceGroup(
        direction: EvidenceWorkbenchMoveDirection,
        features: WorkspaceEvidenceWorkflowContext
    ) async {
        guard let selectedGroup = features.evidenceWorkbench.selectedGroup(in: .system) else {
            features.sidebar.setError(wordZText("请先选择一个证据条目。", "Select an evidence item first.", mode: .system))
            return
        }

        await moveEvidenceGroup(
            groupID: selectedGroup.id,
            direction: direction,
            features: features
        )
    }

    func moveEvidenceGroup(
        groupID: String,
        direction: EvidenceWorkbenchMoveDirection,
        features: WorkspaceEvidenceWorkflowContext
    ) async {
        guard let group = features.evidenceWorkbench.group(id: groupID, in: .system) else {
            features.sidebar.setError(
                features.evidenceWorkbench.groupingMode.missingGroupStatus(in: .system)
            )
            return
        }

        let preservedSelectionID = features.evidenceWorkbench.selectedItem?.id
        guard let reorderedItems = features.evidenceWorkbench.reorderedItemsMovingGroup(
            id: groupID,
            direction,
            in: .system
        ) else {
            features.library.setStatus(
                features.evidenceWorkbench.groupingMode.moveGroupBoundaryStatus(
                    direction,
                    groupTitle: group.title,
                    in: .system
                )
            )
            features.sidebar.clearError()
            return
        }

        do {
            try await repository.replaceEvidenceItems(reorderedItems)
            let items = try await repository.listEvidenceItems()
            applyEvidenceItems(items, features: features)
            if let preservedSelectionID {
                features.evidenceWorkbench.selectedItemID = preservedSelectionID
            }
            features.library.setStatus(
                features.evidenceWorkbench.groupingMode.moveGroupSuccessStatus(
                    direction,
                    groupTitle: group.title,
                    in: .system
                )
            )
            features.sidebar.clearError()
        } catch {
            features.sidebar.setError(error.localizedDescription)
        }
    }

    func moveEvidenceGroup(
        groupID: String,
        to targetGroupID: String,
        placement: EvidenceWorkbenchGroupInsertPlacement,
        features: WorkspaceEvidenceWorkflowContext
    ) async {
        guard let group = features.evidenceWorkbench.group(id: groupID, in: .system) else {
            features.sidebar.setError(
                features.evidenceWorkbench.groupingMode.missingGroupStatus(in: .system)
            )
            return
        }

        guard features.evidenceWorkbench.group(id: targetGroupID, in: .system) != nil else {
            features.sidebar.setError(
                features.evidenceWorkbench.groupingMode.missingGroupStatus(in: .system)
            )
            return
        }

        let preservedSelectionID = features.evidenceWorkbench.selectedItem?.id
        guard let reorderedItems = features.evidenceWorkbench.reorderedItemsMovingGroup(
            id: groupID,
            to: targetGroupID,
            placement: placement,
            in: .system
        ) else {
            features.sidebar.clearError()
            return
        }

        do {
            try await repository.replaceEvidenceItems(reorderedItems)
            let items = try await repository.listEvidenceItems()
            applyEvidenceItems(items, features: features)
            if let preservedSelectionID {
                features.evidenceWorkbench.selectedItemID = preservedSelectionID
            }
            features.library.setStatus(
                String(
                    format: wordZText("已重新排列%@：%@。", "Reordered %@: %@.", mode: .system),
                    features.evidenceWorkbench.groupingMode.unitTitle(in: .system),
                    group.title
                )
            )
            features.sidebar.clearError()
        } catch {
            features.sidebar.setError(error.localizedDescription)
        }
    }

    func assignEvidenceItem(
        itemID: String,
        to targetGroupID: String,
        features: WorkspaceEvidenceWorkflowContext
    ) async {
        guard features.evidenceWorkbench.groupingMode.supportsItemAssignment else {
            features.sidebar.setError(
                features.evidenceWorkbench.groupingMode.unsupportedItemAssignmentStatus(in: .system)
            )
            return
        }

        guard features.evidenceWorkbench.filteredItems.contains(where: { $0.id == itemID }) else {
            features.sidebar.setError(wordZText("未找到要整理的证据条目。", "The evidence item to reorganize could not be found.", mode: .system))
            return
        }

        guard let targetGroup = features.evidenceWorkbench.group(id: targetGroupID, in: .system) else {
            features.sidebar.setError(
                features.evidenceWorkbench.groupingMode.missingGroupStatus(in: .system)
            )
            return
        }

        let preservedSelectionID = features.evidenceWorkbench.selectedItemID
        guard let reorderedItems = features.evidenceWorkbench.reorderedItemsAssigningItem(
            id: itemID,
            to: targetGroupID,
            in: .system
        ) else {
            features.sidebar.clearError()
            return
        }

        do {
            try await repository.replaceEvidenceItems(reorderedItems)
            let items = try await repository.listEvidenceItems()
            applyEvidenceItems(items, features: features)
            restoreEvidenceSelection(
                preferredItemID: preservedSelectionID,
                features: features
            )
            features.library.setStatus(
                features.evidenceWorkbench.groupingMode.assignItemSuccessStatus(
                    groupTitle: targetGroup.title,
                    in: .system
                )
            )
            features.sidebar.clearError()
        } catch {
            features.sidebar.setError(error.localizedDescription)
        }
    }

    func createGroupAndAssignEvidenceItem(
        itemID: String,
        features: WorkspaceEvidenceWorkflowContext,
        preferredRoute: NativeWindowRoute? = .evidenceWorkbench
    ) async {
        let groupingMode = features.evidenceWorkbench.groupingMode
        guard groupingMode.supportsItemAssignment else {
            features.sidebar.setError(
                groupingMode.unsupportedItemAssignmentStatus(in: .system)
            )
            return
        }

        guard features.evidenceWorkbench.filteredItems.contains(where: { $0.id == itemID }) else {
            features.sidebar.setError(wordZText("未找到要整理的证据条目。", "The evidence item to reorganize could not be found.", mode: .system))
            return
        }

        guard let createdGroupName = await dialogService.promptText(
            title: groupingMode.createGroupPromptTitle(in: .system),
            message: groupingMode.createGroupPromptMessage(in: .system),
            defaultValue: "",
            confirmTitle: groupingMode.createGroupConfirmTitle(in: .system),
            preferredRoute: preferredRoute
        ) else {
            return
        }

        guard let normalizedGroupName = normalizedValue(createdGroupName) else {
            features.sidebar.setError(
                groupingMode.missingCreatedGroupNameStatus(in: .system)
            )
            return
        }

        let preservedSelectionID = features.evidenceWorkbench.selectedItemID
        guard let reorderedItems = features.evidenceWorkbench.reorderedItemsAssigningItem(
            id: itemID,
            toNewGroup: normalizedGroupName
        ) else {
            features.sidebar.clearError()
            return
        }

        do {
            try await repository.replaceEvidenceItems(reorderedItems)
            let items = try await repository.listEvidenceItems()
            applyEvidenceItems(items, features: features)
            restoreEvidenceSelection(
                preferredItemID: preservedSelectionID,
                features: features
            )
            features.library.setStatus(
                groupingMode.createGroupSuccessStatus(
                    groupTitle: normalizedGroupName,
                    in: .system
                )
            )
            features.sidebar.clearError()
        } catch {
            features.sidebar.setError(error.localizedDescription)
        }
    }

    func renameSelectedEvidenceGroup(
        features: WorkspaceEvidenceWorkflowContext,
        preferredRoute: NativeWindowRoute? = .evidenceWorkbench
    ) async {
        let groupingMode = features.evidenceWorkbench.groupingMode
        guard groupingMode.supportsItemAssignment else {
            features.sidebar.setError(
                groupingMode.unsupportedItemAssignmentStatus(in: .system)
            )
            return
        }

        guard let sourceGroup = features.evidenceWorkbench.selectedGroup(in: .system) else {
            features.sidebar.setError(wordZText("请先选择一个证据条目。", "Select an evidence item first.", mode: .system))
            return
        }

        guard let renamedGroupName = await dialogService.promptText(
            title: groupingMode.renameGroupPromptTitle(in: .system),
            message: groupingMode.renameGroupPromptMessage(
                currentGroupTitle: sourceGroup.title,
                in: .system
            ),
            defaultValue: sourceGroup.assignmentValue ?? "",
            confirmTitle: groupingMode.renameGroupConfirmTitle(in: .system),
            preferredRoute: preferredRoute
        ) else {
            return
        }

        guard let normalizedGroupName = normalizedValue(renamedGroupName) else {
            features.sidebar.setError(
                groupingMode.missingRenamedGroupNameStatus(in: .system)
            )
            return
        }

        let mergeTargetGroup = features.evidenceWorkbench.group(
            matchingAssignmentValue: normalizedGroupName,
            in: .system
        )
        let preservedSelectionID = features.evidenceWorkbench.selectedItemID
        guard let reorderedItems = features.evidenceWorkbench.reorderedItemsRenamingGroup(
            id: sourceGroup.id,
            to: normalizedGroupName
        ) else {
            features.library.setStatus(
                groupingMode.mergeIntoSameGroupStatus(
                    groupTitle: normalizedGroupName,
                    in: .system
                )
            )
            features.sidebar.clearError()
            return
        }

        do {
            try await repository.replaceEvidenceItems(reorderedItems)
            let items = try await repository.listEvidenceItems()
            applyEvidenceItems(items, features: features)
            restoreEvidenceSelection(
                preferredItemID: preservedSelectionID,
                features: features
            )
            if let mergeTargetGroup, mergeTargetGroup.id != sourceGroup.id {
                features.library.setStatus(
                    groupingMode.mergeGroupSuccessStatus(
                        sourceGroupTitle: sourceGroup.title,
                        targetGroupTitle: mergeTargetGroup.title,
                        in: .system
                    )
                )
            } else {
                features.library.setStatus(
                    groupingMode.renameGroupSuccessStatus(
                        oldGroupTitle: sourceGroup.title,
                        newGroupTitle: normalizedGroupName,
                        in: .system
                    )
                )
            }
            features.sidebar.clearError()
        } catch {
            features.sidebar.setError(error.localizedDescription)
        }
    }

    func splitSelectedEvidenceGroup(
        features: WorkspaceEvidenceWorkflowContext,
        preferredRoute: NativeWindowRoute? = .evidenceWorkbench
    ) async {
        let groupingMode = features.evidenceWorkbench.groupingMode
        guard groupingMode.supportsItemAssignment else {
            features.sidebar.setError(
                groupingMode.unsupportedItemAssignmentStatus(in: .system)
            )
            return
        }

        guard let sourceGroup = features.evidenceWorkbench.selectedGroup(in: .system) else {
            features.sidebar.setError(wordZText("请先选择一个证据条目。", "Select an evidence item first.", mode: .system))
            return
        }

        guard features.evidenceWorkbench.canSplitSelectedGroup else {
            features.library.setStatus(
                groupingMode.splitGroupUnavailableStatus(in: .system)
            )
            features.sidebar.clearError()
            return
        }

        guard let splitGroupName = await dialogService.promptText(
            title: groupingMode.splitGroupPromptTitle(in: .system),
            message: groupingMode.splitGroupPromptMessage(
                sourceGroupTitle: sourceGroup.title,
                in: .system
            ),
            defaultValue: "",
            confirmTitle: groupingMode.splitGroupConfirmTitle(in: .system),
            preferredRoute: preferredRoute
        ) else {
            return
        }

        guard let normalizedGroupName = normalizedValue(splitGroupName) else {
            features.sidebar.setError(
                groupingMode.missingSplitGroupNameStatus(in: .system)
            )
            return
        }

        if let existingGroup = features.evidenceWorkbench.group(
            matchingAssignmentValue: normalizedGroupName,
            in: .system
        ) {
            features.sidebar.setError(
                groupingMode.splitGroupAlreadyExistsStatus(
                    groupTitle: existingGroup.title,
                    in: .system
                )
            )
            return
        }

        let preservedSelectionID = features.evidenceWorkbench.selectedItemID
        guard let reorderedItems = features.evidenceWorkbench.reorderedItemsSplittingSelectedGroup(
            to: normalizedGroupName
        ) else {
            features.library.setStatus(
                groupingMode.splitGroupUnavailableStatus(in: .system)
            )
            features.sidebar.clearError()
            return
        }

        do {
            try await repository.replaceEvidenceItems(reorderedItems)
            let items = try await repository.listEvidenceItems()
            applyEvidenceItems(items, features: features)
            restoreEvidenceSelection(
                preferredItemID: preservedSelectionID,
                features: features
            )
            features.library.setStatus(
                groupingMode.splitGroupSuccessStatus(
                    sourceGroupTitle: sourceGroup.title,
                    targetGroupTitle: normalizedGroupName,
                    in: .system
                )
            )
            features.sidebar.clearError()
        } catch {
            features.sidebar.setError(error.localizedDescription)
        }
    }

    func mergeSelectedEvidenceGroup(
        features: WorkspaceEvidenceWorkflowContext,
        preferredRoute: NativeWindowRoute? = .evidenceWorkbench
    ) async {
        let groupingMode = features.evidenceWorkbench.groupingMode
        guard groupingMode.supportsItemAssignment else {
            features.sidebar.setError(
                groupingMode.unsupportedItemAssignmentStatus(in: .system)
            )
            return
        }

        guard let sourceGroup = features.evidenceWorkbench.selectedGroup(in: .system) else {
            features.sidebar.setError(wordZText("请先选择一个证据条目。", "Select an evidence item first.", mode: .system))
            return
        }

        guard let targetGroupName = await dialogService.promptText(
            title: groupingMode.mergeGroupPromptTitle(in: .system),
            message: groupingMode.mergeGroupPromptMessage(
                sourceGroupTitle: sourceGroup.title,
                in: .system
            ),
            defaultValue: "",
            confirmTitle: groupingMode.mergeGroupConfirmTitle(in: .system),
            preferredRoute: preferredRoute
        ) else {
            return
        }

        guard let normalizedTargetGroupName = normalizedValue(targetGroupName) else {
            features.sidebar.setError(
                groupingMode.missingMergeTargetStatus(in: .system)
            )
            return
        }

        guard let targetGroup = features.evidenceWorkbench.group(
            matchingAssignmentValue: normalizedTargetGroupName,
            in: .system
        ) else {
            features.sidebar.setError(
                groupingMode.mergeGroupNotFoundStatus(
                    groupTitle: normalizedTargetGroupName,
                    in: .system
                )
            )
            return
        }

        guard targetGroup.id != sourceGroup.id else {
            features.library.setStatus(
                groupingMode.mergeIntoSameGroupStatus(
                    groupTitle: targetGroup.title,
                    in: .system
                )
            )
            features.sidebar.clearError()
            return
        }

        let preservedSelectionID = features.evidenceWorkbench.selectedItemID
        guard let reorderedItems = features.evidenceWorkbench.reorderedItemsMergingGroup(
            id: sourceGroup.id,
            into: targetGroup.id
        ) else {
            features.sidebar.clearError()
            return
        }

        do {
            try await repository.replaceEvidenceItems(reorderedItems)
            let items = try await repository.listEvidenceItems()
            applyEvidenceItems(items, features: features)
            restoreEvidenceSelection(
                preferredItemID: preservedSelectionID,
                features: features
            )
            features.library.setStatus(
                groupingMode.mergeGroupSuccessStatus(
                    sourceGroupTitle: sourceGroup.title,
                    targetGroupTitle: targetGroup.title,
                    in: .system
                )
            )
            features.sidebar.clearError()
        } catch {
            features.sidebar.setError(error.localizedDescription)
        }
    }
}
