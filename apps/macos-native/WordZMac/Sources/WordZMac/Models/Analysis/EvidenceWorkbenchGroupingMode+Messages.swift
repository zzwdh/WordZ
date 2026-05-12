import Foundation

extension EvidenceWorkbenchGroupingMode {
    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .section:
            return wordZText("按证据组", "By Evidence Group", mode: mode)
        case .claim:
            return wordZText("按发现线索", "By Finding", mode: mode)
        case .corpusSet:
            return wordZText("按命中集", "By Hit Set", mode: mode)
        }
    }

    func unitTitle(in mode: AppLanguageMode) -> String {
        switch self {
        case .section:
            return wordZText("证据组", "Evidence Group", mode: mode)
        case .claim:
            return wordZText("发现线索", "Finding", mode: mode)
        case .corpusSet:
            return wordZText("命中集", "Hit Set", mode: mode)
        }
    }

    func currentGroupTitle(in mode: AppLanguageMode) -> String {
        String(
            format: wordZText("当前%@", "Current %@", mode: mode),
            unitTitle(in: mode)
        )
    }

    func currentGroupToolbarSummary(
        group: EvidenceWorkbenchGroup?,
        in mode: AppLanguageMode
    ) -> String {
        guard let group else {
            return String(
                format: wordZText("未选择%@", "No %@ Selected", mode: mode),
                unitTitle(in: mode)
            )
        }
        return group.title + " · " + group.itemCountSummary
    }

    func currentGroupWindowTitle(
        baseTitle: String,
        group: EvidenceWorkbenchGroup?,
        in mode: AppLanguageMode
    ) -> String {
        guard let group else { return baseTitle }
        let separator = switch mode {
        case .english:
            ": "
        case .system, .chinese:
            "："
        }
        return (
            baseTitle +
            " · " +
            currentGroupTitle(in: mode) +
            separator +
            group.title +
            " · " +
            group.itemCountSummary
        )
    }

    func moveSelectedGroupTitle(
        _ direction: EvidenceWorkbenchMoveDirection,
        in mode: AppLanguageMode
    ) -> String {
        switch direction {
        case .up:
            return String(
                format: wordZText("上移当前%@", "Move %@ Up", mode: mode),
                unitTitle(in: mode)
            )
        case .down:
            return String(
                format: wordZText("下移当前%@", "Move %@ Down", mode: mode),
                unitTitle(in: mode)
            )
        }
    }

    func moveGroupTitle(
        _ direction: EvidenceWorkbenchMoveDirection,
        in mode: AppLanguageMode
    ) -> String {
        switch direction {
        case .up:
            return String(
                format: wordZText("上移%@", "Move %@ Up", mode: mode),
                unitTitle(in: mode)
            )
        case .down:
            return String(
                format: wordZText("下移%@", "Move %@ Down", mode: mode),
                unitTitle(in: mode)
            )
        }
    }

    func moveSelectedGroupSuccessStatus(
        _ direction: EvidenceWorkbenchMoveDirection,
        in mode: AppLanguageMode
    ) -> String {
        switch direction {
        case .up:
            return String(
                format: wordZText("已上移当前%@。", "Moved the current %@ up.", mode: mode),
                unitTitle(in: mode)
            )
        case .down:
            return String(
                format: wordZText("已下移当前%@。", "Moved the current %@ down.", mode: mode),
                unitTitle(in: mode)
            )
        }
    }

    func moveGroupSuccessStatus(
        _ direction: EvidenceWorkbenchMoveDirection,
        groupTitle: String,
        in mode: AppLanguageMode
    ) -> String {
        switch direction {
        case .up:
            return String(
                format: wordZText("已上移%@：%@。", "Moved %@ up: %@.", mode: mode),
                unitTitle(in: mode),
                groupTitle
            )
        case .down:
            return String(
                format: wordZText("已下移%@：%@。", "Moved %@ down: %@.", mode: mode),
                unitTitle(in: mode),
                groupTitle
            )
        }
    }

    func moveSelectedGroupBoundaryStatus(
        _ direction: EvidenceWorkbenchMoveDirection,
        in mode: AppLanguageMode
    ) -> String {
        switch direction {
        case .up:
            return String(
                format: wordZText("当前%@已经位于最前。", "The current %@ is already at the top.", mode: mode),
                unitTitle(in: mode)
            )
        case .down:
            return String(
                format: wordZText("当前%@已经位于最后。", "The current %@ is already at the bottom.", mode: mode),
                unitTitle(in: mode)
            )
        }
    }

    func moveGroupBoundaryStatus(
        _ direction: EvidenceWorkbenchMoveDirection,
        groupTitle: String,
        in mode: AppLanguageMode
    ) -> String {
        switch direction {
        case .up:
            return String(
                format: wordZText("%@“%@”已经位于最前。", "%@ \"%@\" is already at the top.", mode: mode),
                unitTitle(in: mode),
                groupTitle
            )
        case .down:
            return String(
                format: wordZText("%@“%@”已经位于最后。", "%@ \"%@\" is already at the bottom.", mode: mode),
                unitTitle(in: mode),
                groupTitle
            )
        }
    }

    func missingGroupStatus(in mode: AppLanguageMode) -> String {
        String(
            format: wordZText("未找到要整理的%@。", "The %@ to reorganize could not be found.", mode: mode),
            unitTitle(in: mode).lowercased()
        )
    }

    func unsupportedItemAssignmentStatus(in mode: AppLanguageMode) -> String {
        switch self {
        case .section:
            return wordZText("当前证据组视图不支持该拖放操作。", "This drag operation is not supported in the evidence group view.", mode: mode)
        case .claim:
            return wordZText("当前发现线索视图不支持该拖放操作。", "This drag operation is not supported in the finding view.", mode: mode)
        case .corpusSet:
            return wordZText("命中集分组来自来源记录，本轮不支持手工拖入。", "Hit set grouping comes from source records and cannot accept manual drops in this release.", mode: mode)
        }
    }

    func assignItemSuccessStatus(
        groupTitle: String,
        in mode: AppLanguageMode
    ) -> String {
        switch self {
        case .section:
            return String(
                format: wordZText("已将证据条目归入证据组：%@。", "Assigned the evidence item to evidence group: %@.", mode: mode),
                groupTitle
            )
        case .claim:
            return String(
                format: wordZText("已将证据条目标注为发现线索：%@。", "Assigned the evidence item to finding: %@.", mode: mode),
                groupTitle
            )
        case .corpusSet:
            return unsupportedItemAssignmentStatus(in: mode)
        }
    }

    func createGroupTitle(in mode: AppLanguageMode) -> String {
        switch self {
        case .section:
            return wordZText("新建证据组…", "New Evidence Group…", mode: mode)
        case .claim:
            return wordZText("新建发现线索…", "New Finding…", mode: mode)
        case .corpusSet:
            return wordZText("新建命中集…", "New Hit Set…", mode: mode)
        }
    }

    func createGroupDropHint(in mode: AppLanguageMode) -> String {
        switch self {
        case .section:
            return wordZText("拖入条目，或使用当前选中条目新建证据组。", "Drop an item here, or use the current selection to create an evidence group.", mode: mode)
        case .claim:
            return wordZText("拖入条目，或使用当前选中条目新建发现线索。", "Drop an item here, or use the current selection to create a finding.", mode: mode)
        case .corpusSet:
            return wordZText("当前命中集视图不支持新建分组。", "Creating a new group is not supported in the hit set view.", mode: mode)
        }
    }

    func createGroupPromptTitle(in mode: AppLanguageMode) -> String {
        switch self {
        case .section:
            return wordZText("新建证据组", "New Evidence Group", mode: mode)
        case .claim:
            return wordZText("新建发现线索", "New Finding", mode: mode)
        case .corpusSet:
            return wordZText("新建命中集", "New Hit Set", mode: mode)
        }
    }

    func createGroupPromptMessage(in mode: AppLanguageMode) -> String {
        switch self {
        case .section:
            return wordZText("输入新的证据组名称，拖入的证据会归入这里。", "Enter a new evidence group name and the dragged evidence will be assigned to it.", mode: mode)
        case .claim:
            return wordZText("输入新的发现线索名称，拖入的证据会归入这里。", "Enter a new finding name and the dragged evidence will be assigned to it.", mode: mode)
        case .corpusSet:
            return wordZText("当前命中集视图不支持新建分组。", "Creating a new group is not supported in the hit set view.", mode: mode)
        }
    }

    func createGroupConfirmTitle(in mode: AppLanguageMode) -> String {
        switch self {
        case .section:
            return wordZText("创建并归入", "Create and Assign", mode: mode)
        case .claim:
            return wordZText("创建并归入", "Create and Assign", mode: mode)
        case .corpusSet:
            return wordZText("创建", "Create", mode: mode)
        }
    }

    func missingCreatedGroupNameStatus(in mode: AppLanguageMode) -> String {
        switch self {
        case .section:
            return wordZText("请输入新的证据组名称。", "Enter a new evidence group name.", mode: mode)
        case .claim:
            return wordZText("请输入新的发现线索名称。", "Enter a new finding name.", mode: mode)
        case .corpusSet:
            return wordZText("当前命中集视图不支持新建分组。", "Creating a new group is not supported in the hit set view.", mode: mode)
        }
    }

    func createGroupSuccessStatus(
        groupTitle: String,
        in mode: AppLanguageMode
    ) -> String {
        switch self {
        case .section:
            return String(
                format: wordZText("已创建证据组并归入证据：%@。", "Created the evidence group and assigned the evidence: %@.", mode: mode),
                groupTitle
            )
        case .claim:
            return String(
                format: wordZText("已创建发现线索并归入证据：%@。", "Created the finding and assigned the evidence: %@.", mode: mode),
                groupTitle
            )
        case .corpusSet:
            return unsupportedItemAssignmentStatus(in: mode)
        }
    }

    func splitSelectedGroupTitle(in mode: AppLanguageMode) -> String {
        switch self {
        case .section:
            return wordZText("拆分当前证据组…", "Split Current Evidence Group…", mode: mode)
        case .claim:
            return wordZText("拆分当前发现线索…", "Split Current Finding…", mode: mode)
        case .corpusSet:
            return wordZText("拆分当前命中集…", "Split Current Hit Set…", mode: mode)
        }
    }

    func splitGroupPromptTitle(in mode: AppLanguageMode) -> String {
        switch self {
        case .section:
            return wordZText("拆分证据组", "Split Evidence Group", mode: mode)
        case .claim:
            return wordZText("拆分发现线索", "Split Finding", mode: mode)
        case .corpusSet:
            return wordZText("拆分命中集", "Split Hit Set", mode: mode)
        }
    }

    func splitGroupPromptMessage(
        sourceGroupTitle: String,
        in mode: AppLanguageMode
    ) -> String {
        switch self {
        case .section:
            return String(
                format: wordZText(
                    "为从证据组“%@”拆出的后半部分输入新名称。当前选中条目及其后续同组证据会移到这里。",
                    "Enter a new name for the evidence group split out of \"%@\". The selected item and later evidence from the same group will move there.",
                    mode: mode
                ),
                sourceGroupTitle
            )
        case .claim:
            return String(
                format: wordZText(
                    "为从发现线索“%@”拆出的后半部分输入新名称。当前选中条目及其后续同线索证据会移到这里。",
                    "Enter a new name for the finding split out of \"%@\". The selected item and later evidence from the same finding will move there.",
                    mode: mode
                ),
                sourceGroupTitle
            )
        case .corpusSet:
            return wordZText("当前命中集视图不支持拆分分组。", "Splitting groups is not supported in the hit set view.", mode: mode)
        }
    }

    func splitGroupConfirmTitle(in mode: AppLanguageMode) -> String {
        switch self {
        case .section, .claim:
            return wordZText("拆分", "Split", mode: mode)
        case .corpusSet:
            return wordZText("拆分", "Split", mode: mode)
        }
    }

    func splitGroupUnavailableStatus(in mode: AppLanguageMode) -> String {
        switch self {
        case .section:
            return wordZText(
                "请先选中当前证据组中的非首条证据，再执行拆分。",
                "Select a non-leading evidence item in the current evidence group before splitting.",
                mode: mode
            )
        case .claim:
            return wordZText(
                "请先选中当前发现线索中的非首条证据，再执行拆分。",
                "Select a non-leading evidence item in the current finding before splitting.",
                mode: mode
            )
        case .corpusSet:
            return wordZText("当前命中集视图不支持拆分分组。", "Splitting groups is not supported in the hit set view.", mode: mode)
        }
    }

    func missingSplitGroupNameStatus(in mode: AppLanguageMode) -> String {
        switch self {
        case .section:
            return wordZText("请输入新证据组名称。", "Enter the new evidence group name.", mode: mode)
        case .claim:
            return wordZText("请输入新发现线索名称。", "Enter the new finding name.", mode: mode)
        case .corpusSet:
            return wordZText("当前命中集视图不支持拆分分组。", "Splitting groups is not supported in the hit set view.", mode: mode)
        }
    }

    func splitGroupAlreadyExistsStatus(
        groupTitle: String,
        in mode: AppLanguageMode
    ) -> String {
        switch self {
        case .section:
            return String(
                format: wordZText(
                    "证据组“%@”已存在；如需并入请使用合并。",
                    "Evidence group \"%@\" already exists. Use Merge instead if you want to combine groups.",
                    mode: mode
                ),
                groupTitle
            )
        case .claim:
            return String(
                format: wordZText(
                    "发现线索“%@”已存在；如需并入请使用合并。",
                    "Finding \"%@\" already exists. Use Merge instead if you want to combine groups.",
                    mode: mode
                ),
                groupTitle
            )
        case .corpusSet:
            return unsupportedItemAssignmentStatus(in: mode)
        }
    }

    func splitGroupSuccessStatus(
        sourceGroupTitle: String,
        targetGroupTitle: String,
        in mode: AppLanguageMode
    ) -> String {
        switch self {
        case .section:
            return String(
                format: wordZText("已从证据组“%@”拆出新证据组“%@”。", "Split evidence group \"%@\" into a new evidence group \"%@\".", mode: mode),
                sourceGroupTitle,
                targetGroupTitle
            )
        case .claim:
            return String(
                format: wordZText("已从发现线索“%@”拆出新发现线索“%@”。", "Split finding \"%@\" into a new finding \"%@\".", mode: mode),
                sourceGroupTitle,
                targetGroupTitle
            )
        case .corpusSet:
            return unsupportedItemAssignmentStatus(in: mode)
        }
    }

    func renameSelectedGroupTitle(in mode: AppLanguageMode) -> String {
        switch self {
        case .section:
            return wordZText("重命名当前证据组", "Rename Current Evidence Group", mode: mode)
        case .claim:
            return wordZText("重命名当前发现线索", "Rename Current Finding", mode: mode)
        case .corpusSet:
            return wordZText("重命名当前命中集", "Rename Current Hit Set", mode: mode)
        }
    }

    func renameGroupPromptTitle(in mode: AppLanguageMode) -> String {
        switch self {
        case .section:
            return wordZText("重命名证据组", "Rename Evidence Group", mode: mode)
        case .claim:
            return wordZText("重命名发现线索", "Rename Finding", mode: mode)
        case .corpusSet:
            return wordZText("重命名命中集", "Rename Hit Set", mode: mode)
        }
    }

    func renameGroupPromptMessage(
        currentGroupTitle: String,
        in mode: AppLanguageMode
    ) -> String {
        switch self {
        case .section:
            return String(
                format: wordZText("为证据组“%@”输入新名称；如果名称已存在，会自动并入那个证据组。", "Enter a new name for evidence group \"%@\". If the name already exists, the items will merge into that evidence group.", mode: mode),
                currentGroupTitle
            )
        case .claim:
            return String(
                format: wordZText("为发现线索“%@”输入新名称；如果名称已存在，会自动并入那个发现线索。", "Enter a new name for finding \"%@\". If the name already exists, the items will merge into that finding.", mode: mode),
                currentGroupTitle
            )
        case .corpusSet:
            return wordZText("当前命中集视图不支持重命名分组。", "Renaming groups is not supported in the hit set view.", mode: mode)
        }
    }

    func renameGroupConfirmTitle(in mode: AppLanguageMode) -> String {
        switch self {
        case .section, .claim:
            return wordZText("重命名", "Rename", mode: mode)
        case .corpusSet:
            return wordZText("重命名", "Rename", mode: mode)
        }
    }

    func missingRenamedGroupNameStatus(in mode: AppLanguageMode) -> String {
        switch self {
        case .section:
            return wordZText("请输入新的证据组名称。", "Enter a new evidence group name.", mode: mode)
        case .claim:
            return wordZText("请输入新的发现线索名称。", "Enter a new finding name.", mode: mode)
        case .corpusSet:
            return wordZText("当前命中集视图不支持重命名分组。", "Renaming groups is not supported in the hit set view.", mode: mode)
        }
    }

    func renameGroupSuccessStatus(
        oldGroupTitle: String,
        newGroupTitle: String,
        in mode: AppLanguageMode
    ) -> String {
        switch self {
        case .section:
            return String(
                format: wordZText("已将证据组“%@”重命名为“%@”。", "Renamed evidence group \"%@\" to \"%@\".", mode: mode),
                oldGroupTitle,
                newGroupTitle
            )
        case .claim:
            return String(
                format: wordZText("已将发现线索“%@”重命名为“%@”。", "Renamed finding \"%@\" to \"%@\".", mode: mode),
                oldGroupTitle,
                newGroupTitle
            )
        case .corpusSet:
            return unsupportedItemAssignmentStatus(in: mode)
        }
    }

    func mergeSelectedGroupTitle(in mode: AppLanguageMode) -> String {
        switch self {
        case .section:
            return wordZText("合并当前证据组…", "Merge Current Evidence Group…", mode: mode)
        case .claim:
            return wordZText("合并当前发现线索…", "Merge Current Finding…", mode: mode)
        case .corpusSet:
            return wordZText("合并当前命中集…", "Merge Current Hit Set…", mode: mode)
        }
    }

    func mergeGroupPromptTitle(in mode: AppLanguageMode) -> String {
        switch self {
        case .section:
            return wordZText("合并证据组", "Merge Evidence Group", mode: mode)
        case .claim:
            return wordZText("合并发现线索", "Merge Finding", mode: mode)
        case .corpusSet:
            return wordZText("合并命中集", "Merge Hit Set", mode: mode)
        }
    }

    func mergeGroupPromptMessage(
        sourceGroupTitle: String,
        in mode: AppLanguageMode
    ) -> String {
        switch self {
        case .section:
            return String(
                format: wordZText("输入要把证据组“%@”并入的已有证据组名。", "Enter the existing evidence group name that evidence group \"%@\" should merge into.", mode: mode),
                sourceGroupTitle
            )
        case .claim:
            return String(
                format: wordZText("输入要把发现线索“%@”并入的已有发现线索名。", "Enter the existing finding name that finding \"%@\" should merge into.", mode: mode),
                sourceGroupTitle
            )
        case .corpusSet:
            return wordZText("当前命中集视图不支持合并分组。", "Merging groups is not supported in the hit set view.", mode: mode)
        }
    }

    func mergeGroupConfirmTitle(in mode: AppLanguageMode) -> String {
        switch self {
        case .section, .claim:
            return wordZText("合并", "Merge", mode: mode)
        case .corpusSet:
            return wordZText("合并", "Merge", mode: mode)
        }
    }

    func missingMergeTargetStatus(in mode: AppLanguageMode) -> String {
        switch self {
        case .section:
            return wordZText("请输入要并入的证据组名称。", "Enter the evidence group name to merge into.", mode: mode)
        case .claim:
            return wordZText("请输入要并入的发现线索名称。", "Enter the finding name to merge into.", mode: mode)
        case .corpusSet:
            return wordZText("当前命中集视图不支持合并分组。", "Merging groups is not supported in the hit set view.", mode: mode)
        }
    }

    func mergeIntoSameGroupStatus(
        groupTitle: String,
        in mode: AppLanguageMode
    ) -> String {
        switch self {
        case .section:
            return String(
                format: wordZText("证据组“%@”已经是当前分组。", "Evidence group \"%@\" is already the current group.", mode: mode),
                groupTitle
            )
        case .claim:
            return String(
                format: wordZText("发现线索“%@”已经是当前分组。", "Finding \"%@\" is already the current group.", mode: mode),
                groupTitle
            )
        case .corpusSet:
            return unsupportedItemAssignmentStatus(in: mode)
        }
    }

    func mergeGroupNotFoundStatus(
        groupTitle: String,
        in mode: AppLanguageMode
    ) -> String {
        switch self {
        case .section:
            return String(
                format: wordZText("未找到要并入的证据组：%@。", "Could not find the evidence group to merge into: %@.", mode: mode),
                groupTitle
            )
        case .claim:
            return String(
                format: wordZText("未找到要并入的发现线索：%@。", "Could not find the finding to merge into: %@.", mode: mode),
                groupTitle
            )
        case .corpusSet:
            return unsupportedItemAssignmentStatus(in: mode)
        }
    }

    func mergeGroupSuccessStatus(
        sourceGroupTitle: String,
        targetGroupTitle: String,
        in mode: AppLanguageMode
    ) -> String {
        switch self {
        case .section:
            return String(
                format: wordZText("已将证据组“%@”并入“%@”。", "Merged evidence group \"%@\" into \"%@\".", mode: mode),
                sourceGroupTitle,
                targetGroupTitle
            )
        case .claim:
            return String(
                format: wordZText("已将发现线索“%@”并入“%@”。", "Merged finding \"%@\" into \"%@\".", mode: mode),
                sourceGroupTitle,
                targetGroupTitle
            )
        case .corpusSet:
            return unsupportedItemAssignmentStatus(in: mode)
        }
    }
}
