import Foundation

extension EvidenceWorkbenchGroupingMode {
    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .section:
            return wordZText("按章节", "By Section", mode: mode)
        case .claim:
            return wordZText("按论点", "By Claim", mode: mode)
        case .corpusSet:
            return wordZText("按命中集", "By Hit Set", mode: mode)
        }
    }

    func unitTitle(in mode: AppLanguageMode) -> String {
        switch self {
        case .section:
            return wordZText("章节", "Section", mode: mode)
        case .claim:
            return wordZText("论点", "Claim", mode: mode)
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
            return wordZText("当前章节视图不支持该拖放操作。", "This drag operation is not supported in the section view.", mode: mode)
        case .claim:
            return wordZText("当前论点视图不支持该拖放操作。", "This drag operation is not supported in the claim view.", mode: mode)
        case .corpusSet:
            return wordZText("命中集分组来自 provenance，本轮不支持手工拖入。", "Hit set grouping is provenance-based and cannot accept manual drops in this release.", mode: mode)
        }
    }

    func assignItemSuccessStatus(
        groupTitle: String,
        in mode: AppLanguageMode
    ) -> String {
        switch self {
        case .section:
            return String(
                format: wordZText("已将证据条目归入章节：%@。", "Assigned the evidence item to section: %@.", mode: mode),
                groupTitle
            )
        case .claim:
            return String(
                format: wordZText("已将证据条目归入论点：%@。", "Assigned the evidence item to claim: %@.", mode: mode),
                groupTitle
            )
        case .corpusSet:
            return unsupportedItemAssignmentStatus(in: mode)
        }
    }

    func createGroupTitle(in mode: AppLanguageMode) -> String {
        switch self {
        case .section:
            return wordZText("新建章节…", "New Section…", mode: mode)
        case .claim:
            return wordZText("新建论点…", "New Claim…", mode: mode)
        case .corpusSet:
            return wordZText("新建命中集…", "New Hit Set…", mode: mode)
        }
    }

    func createGroupDropHint(in mode: AppLanguageMode) -> String {
        switch self {
        case .section:
            return wordZText("拖入条目，或使用当前选中条目新建章节。", "Drop an item here, or use the current selection to create a section.", mode: mode)
        case .claim:
            return wordZText("拖入条目，或使用当前选中条目新建论点。", "Drop an item here, or use the current selection to create a claim.", mode: mode)
        case .corpusSet:
            return wordZText("当前命中集视图不支持新建分组。", "Creating a new group is not supported in the hit set view.", mode: mode)
        }
    }

    func createGroupPromptTitle(in mode: AppLanguageMode) -> String {
        switch self {
        case .section:
            return wordZText("新建章节", "New Section", mode: mode)
        case .claim:
            return wordZText("新建论点", "New Claim", mode: mode)
        case .corpusSet:
            return wordZText("新建命中集", "New Hit Set", mode: mode)
        }
    }

    func createGroupPromptMessage(in mode: AppLanguageMode) -> String {
        switch self {
        case .section:
            return wordZText("输入新的章节标题，拖入的证据会归入这里。", "Enter a new section title and the dragged evidence will be assigned to it.", mode: mode)
        case .claim:
            return wordZText("输入新的论点名称，拖入的证据会归入这里。", "Enter a new claim name and the dragged evidence will be assigned to it.", mode: mode)
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
            return wordZText("请输入新的章节标题。", "Enter a new section title.", mode: mode)
        case .claim:
            return wordZText("请输入新的论点名称。", "Enter a new claim name.", mode: mode)
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
                format: wordZText("已创建章节并归入证据：%@。", "Created the section and assigned the evidence: %@.", mode: mode),
                groupTitle
            )
        case .claim:
            return String(
                format: wordZText("已创建论点并归入证据：%@。", "Created the claim and assigned the evidence: %@.", mode: mode),
                groupTitle
            )
        case .corpusSet:
            return unsupportedItemAssignmentStatus(in: mode)
        }
    }

    func splitSelectedGroupTitle(in mode: AppLanguageMode) -> String {
        switch self {
        case .section:
            return wordZText("拆分当前章节…", "Split Current Section…", mode: mode)
        case .claim:
            return wordZText("拆分当前论点…", "Split Current Claim…", mode: mode)
        case .corpusSet:
            return wordZText("拆分当前命中集…", "Split Current Hit Set…", mode: mode)
        }
    }

    func splitGroupPromptTitle(in mode: AppLanguageMode) -> String {
        switch self {
        case .section:
            return wordZText("拆分章节", "Split Section", mode: mode)
        case .claim:
            return wordZText("拆分论点", "Split Claim", mode: mode)
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
                    "为从章节“%@”拆出的后半部分输入新标题。当前选中条目及其后续同章节证据会移到这里。",
                    "Enter a new title for the section split out of \"%@\". The selected item and later evidence from the same section will move there.",
                    mode: mode
                ),
                sourceGroupTitle
            )
        case .claim:
            return String(
                format: wordZText(
                    "为从论点“%@”拆出的后半部分输入新名称。当前选中条目及其后续同论点证据会移到这里。",
                    "Enter a new name for the claim split out of \"%@\". The selected item and later evidence from the same claim will move there.",
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
                "请先选中当前章节中的非首条证据，再执行拆分。",
                "Select a non-leading evidence item in the current section before splitting.",
                mode: mode
            )
        case .claim:
            return wordZText(
                "请先选中当前论点中的非首条证据，再执行拆分。",
                "Select a non-leading evidence item in the current claim before splitting.",
                mode: mode
            )
        case .corpusSet:
            return wordZText("当前命中集视图不支持拆分分组。", "Splitting groups is not supported in the hit set view.", mode: mode)
        }
    }

    func missingSplitGroupNameStatus(in mode: AppLanguageMode) -> String {
        switch self {
        case .section:
            return wordZText("请输入新章节标题。", "Enter the new section title.", mode: mode)
        case .claim:
            return wordZText("请输入新论点名称。", "Enter the new claim name.", mode: mode)
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
                    "章节“%@”已存在；如需并入请使用合并。",
                    "Section \"%@\" already exists. Use Merge instead if you want to combine groups.",
                    mode: mode
                ),
                groupTitle
            )
        case .claim:
            return String(
                format: wordZText(
                    "论点“%@”已存在；如需并入请使用合并。",
                    "Claim \"%@\" already exists. Use Merge instead if you want to combine groups.",
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
                format: wordZText("已从章节“%@”拆出新章节“%@”。", "Split section \"%@\" into a new section \"%@\".", mode: mode),
                sourceGroupTitle,
                targetGroupTitle
            )
        case .claim:
            return String(
                format: wordZText("已从论点“%@”拆出新论点“%@”。", "Split claim \"%@\" into a new claim \"%@\".", mode: mode),
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
            return wordZText("重命名当前章节", "Rename Current Section", mode: mode)
        case .claim:
            return wordZText("重命名当前论点", "Rename Current Claim", mode: mode)
        case .corpusSet:
            return wordZText("重命名当前命中集", "Rename Current Hit Set", mode: mode)
        }
    }

    func renameGroupPromptTitle(in mode: AppLanguageMode) -> String {
        switch self {
        case .section:
            return wordZText("重命名章节", "Rename Section", mode: mode)
        case .claim:
            return wordZText("重命名论点", "Rename Claim", mode: mode)
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
                format: wordZText("为章节“%@”输入新标题；如果名称已存在，会自动并入那个章节。", "Enter a new title for section \"%@\". If the name already exists, the items will merge into that section.", mode: mode),
                currentGroupTitle
            )
        case .claim:
            return String(
                format: wordZText("为论点“%@”输入新名称；如果名称已存在，会自动并入那个论点。", "Enter a new name for claim \"%@\". If the name already exists, the items will merge into that claim.", mode: mode),
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
            return wordZText("请输入新的章节标题。", "Enter a new section title.", mode: mode)
        case .claim:
            return wordZText("请输入新的论点名称。", "Enter a new claim name.", mode: mode)
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
                format: wordZText("已将章节“%@”重命名为“%@”。", "Renamed section \"%@\" to \"%@\".", mode: mode),
                oldGroupTitle,
                newGroupTitle
            )
        case .claim:
            return String(
                format: wordZText("已将论点“%@”重命名为“%@”。", "Renamed claim \"%@\" to \"%@\".", mode: mode),
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
            return wordZText("合并当前章节…", "Merge Current Section…", mode: mode)
        case .claim:
            return wordZText("合并当前论点…", "Merge Current Claim…", mode: mode)
        case .corpusSet:
            return wordZText("合并当前命中集…", "Merge Current Hit Set…", mode: mode)
        }
    }

    func mergeGroupPromptTitle(in mode: AppLanguageMode) -> String {
        switch self {
        case .section:
            return wordZText("合并章节", "Merge Section", mode: mode)
        case .claim:
            return wordZText("合并论点", "Merge Claim", mode: mode)
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
                format: wordZText("输入要把章节“%@”并入的已有章节名。", "Enter the existing section name that section \"%@\" should merge into.", mode: mode),
                sourceGroupTitle
            )
        case .claim:
            return String(
                format: wordZText("输入要把论点“%@”并入的已有论点名。", "Enter the existing claim name that claim \"%@\" should merge into.", mode: mode),
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
            return wordZText("请输入要并入的章节名称。", "Enter the section name to merge into.", mode: mode)
        case .claim:
            return wordZText("请输入要并入的论点名称。", "Enter the claim name to merge into.", mode: mode)
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
                format: wordZText("章节“%@”已经是当前分组。", "Section \"%@\" is already the current group.", mode: mode),
                groupTitle
            )
        case .claim:
            return String(
                format: wordZText("论点“%@”已经是当前分组。", "Claim \"%@\" is already the current group.", mode: mode),
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
                format: wordZText("未找到要并入的章节：%@。", "Could not find the section to merge into: %@.", mode: mode),
                groupTitle
            )
        case .claim:
            return String(
                format: wordZText("未找到要并入的论点：%@。", "Could not find the claim to merge into: %@.", mode: mode),
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
                format: wordZText("已将章节“%@”并入“%@”。", "Merged section \"%@\" into \"%@\".", mode: mode),
                sourceGroupTitle,
                targetGroupTitle
            )
        case .claim:
            return String(
                format: wordZText("已将论点“%@”并入“%@”。", "Merged claim \"%@\" into \"%@\".", mode: mode),
                sourceGroupTitle,
                targetGroupTitle
            )
        case .corpusSet:
            return unsupportedItemAssignmentStatus(in: mode)
        }
    }
}
