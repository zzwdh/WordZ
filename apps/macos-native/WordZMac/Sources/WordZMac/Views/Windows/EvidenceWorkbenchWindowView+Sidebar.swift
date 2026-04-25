import SwiftUI

struct EvidenceWorkbenchSidebarList: View {
    @ObservedObject var workbench: EvidenceWorkbenchViewModel
    let languageMode: AppLanguageMode
    let onMoveGroup: (String, EvidenceWorkbenchMoveDirection) -> Void
    let onReorderGroup: (String, String, EvidenceWorkbenchGroupInsertPlacement) -> Void
    let onAssignItemToGroup: (String, String) -> Void
    let onCreateGroupFromItem: (String) -> Void
    let onSplitSelectedGroup: () -> Void
    let onRenameSelectedGroup: () -> Void
    let onMergeSelectedGroup: () -> Void

    @State private var targetedGroupID: String?
    @State private var isCreateGroupTargeted = false

    var body: some View {
        List(selection: $workbench.selectedItemID) {
            ForEach(workbench.groupedItems(in: languageMode)) { group in
                Section {
                    ForEach(group.items) { item in
                        if workbench.groupingMode.supportsItemAssignment {
                            evidenceListRow(item)
                                .tag(item.id)
                                .draggable(
                                    EvidenceWorkbenchSidebarDragPayload
                                        .item(item.id)
                                        .encodedValue
                                )
                        } else {
                            evidenceListRow(item)
                                .tag(item.id)
                        }
                    }
                } header: {
                    EvidenceWorkbenchSidebarGroupHeader(
                        group: group,
                        groupingMode: workbench.groupingMode,
                        languageMode: languageMode,
                        isSelected: workbench.isSelectedGroup(id: group.id, in: languageMode),
                        canSplit: workbench.isSelectedGroup(id: group.id, in: languageMode) && workbench.canSplitSelectedGroup,
                        canMoveUp: workbench.canMoveGroup(id: group.id, .up, in: languageMode),
                        canMoveDown: workbench.canMoveGroup(id: group.id, .down, in: languageMode),
                        isDropTargeted: targetedGroupID == group.id,
                        onMove: { direction in
                            onMoveGroup(group.id, direction)
                        },
                        onSplit: {
                            onSplitSelectedGroup()
                        },
                        onRename: {
                            guard focusGroup(group) else { return }
                            onRenameSelectedGroup()
                        },
                        onMerge: {
                            guard focusGroup(group) else { return }
                            onMergeSelectedGroup()
                        }
                    )
                    .draggable(
                        EvidenceWorkbenchSidebarDragPayload
                            .group(group.id)
                            .encodedValue
                    )
                    .dropDestination(for: String.self) { items, location in
                        guard let rawPayload = items.first,
                              let payload = EvidenceWorkbenchSidebarDragPayload(encodedValue: rawPayload)
                        else {
                            return false
                        }

                        targetedGroupID = nil
                        switch payload {
                        case .group(let sourceGroupID):
                            let placement = location.y >= SidebarDropMetrics.groupMidline
                                ? EvidenceWorkbenchGroupInsertPlacement.after
                                : EvidenceWorkbenchGroupInsertPlacement.before
                            onReorderGroup(sourceGroupID, group.id, placement)
                            return true
                        case .item(let itemID):
                            guard workbench.groupingMode.supportsItemAssignment else { return false }
                            onAssignItemToGroup(itemID, group.id)
                            return true
                        }
                    } isTargeted: { isTargeted in
                        targetedGroupID = isTargeted ? group.id : (targetedGroupID == group.id ? nil : targetedGroupID)
                    }
                }
            }

            if workbench.groupingMode.supportsItemAssignment, !workbench.filteredItems.isEmpty {
                Section {
                    createGroupRow
                }
            }
        }
        .listStyle(.sidebar)
    }

    @ViewBuilder
    private func evidenceListRow(_ item: EvidenceItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(item.keyword.isEmpty ? t("未命名条目", "Untitled Item") : item.keyword)
                    .lineLimit(1)
                Spacer()
                Text(item.reviewStatus.title(in: languageMode))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Text(item.corpusName)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(item.concordanceText)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)

            let dossierSummary = item.dossierSummary(in: languageMode)
            if !dossierSummary.isEmpty {
                Text(dossierSummary)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else if let note = workbench.normalizedNote(item.note) {
                Text(note)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }

    private var createGroupRow: some View {
        Button {
            guard let selectedItemID = workbench.selectedItem?.id else { return }
            onCreateGroupFromItem(selectedItemID)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle")
                    .foregroundStyle(.secondary)
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 2) {
                    Text(workbench.groupingMode.createGroupTitle(in: languageMode))
                        .lineLimit(1)

                    Text(workbench.groupingMode.createGroupDropHint(in: languageMode))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 6)
            .background(createGroupBackground)
        }
        .buttonStyle(.plain)
        .disabled(workbench.selectedItem == nil)
        .contentShape(Rectangle())
        .dropDestination(for: String.self) { items, _ in
            guard let rawPayload = items.first,
                  let payload = EvidenceWorkbenchSidebarDragPayload(encodedValue: rawPayload),
                  case .item(let itemID) = payload,
                  workbench.groupingMode.supportsItemAssignment
            else {
                return false
            }

            isCreateGroupTargeted = false
            onCreateGroupFromItem(itemID)
            return true
        } isTargeted: { isTargeted in
            isCreateGroupTargeted = isTargeted
        }
    }

    private func t(_ zh: String, _ en: String) -> String {
        wordZText(zh, en, mode: languageMode)
    }

    private func focusGroup(_ group: EvidenceWorkbenchGroup) -> Bool {
        if workbench.isSelectedGroup(id: group.id, in: languageMode) {
            return true
        }

        guard let firstVisibleItemID = group.items.first?.id else { return false }
        workbench.selectedItemID = firstVisibleItemID
        return true
    }

    @ViewBuilder
    private var createGroupBackground: some View {
        RoundedRectangle(cornerRadius: 8)
            .strokeBorder(
                isCreateGroupTargeted ? Color.accentColor : Color.secondary.opacity(0.22),
                style: StrokeStyle(lineWidth: 1, dash: [4, 4])
            )
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isCreateGroupTargeted ? Color.accentColor.opacity(0.08) : Color.clear)
            )
    }
}

private struct EvidenceWorkbenchSidebarGroupHeader: View {
    let group: EvidenceWorkbenchGroup
    let groupingMode: EvidenceWorkbenchGroupingMode
    let languageMode: AppLanguageMode
    let isSelected: Bool
    let canSplit: Bool
    let canMoveUp: Bool
    let canMoveDown: Bool
    let isDropTargeted: Bool
    let onMove: (EvidenceWorkbenchMoveDirection) -> Void
    let onSplit: () -> Void
    let onRename: () -> Void
    let onMerge: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(group.title)
                    if isSelected {
                        Text(t("当前", "Current"))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.quaternary, in: Capsule())
                    }
                }

                HStack(spacing: 6) {
                    Text(group.itemCountSummary)
                    if let subtitle = group.subtitle, !subtitle.isEmpty {
                        Text("·")
                        Text(subtitle)
                            .lineLimit(1)
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            HStack(spacing: 4) {
                moveButton(.up, isEnabled: canMoveUp)
                moveButton(.down, isEnabled: canMoveDown)
                if groupingMode.supportsItemAssignment {
                    Menu {
                        groupActionMenu
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .menuStyle(.borderlessButton)
                }
            }
        }
        .padding(.vertical, 2)
        .background(dropTargetBackground)
        .contextMenu {
            groupActionMenu
        }
        .overlay(alignment: .top) {
            if isDropTargeted {
                Rectangle()
                    .fill(.tint)
                    .frame(height: 2)
            }
        }
        .overlay(alignment: .bottom) {
            if isDropTargeted {
                Rectangle()
                    .fill(.tint.opacity(0.65))
                    .frame(height: 2)
            }
        }
    }

    private func moveButton(
        _ direction: EvidenceWorkbenchMoveDirection,
        isEnabled: Bool
    ) -> some View {
        Button {
            onMove(direction)
        } label: {
            Image(systemName: direction.systemImageName)
        }
        .buttonStyle(.borderless)
        .disabled(!isEnabled)
        .help(groupingMode.moveGroupTitle(direction, in: languageMode))
    }

    private func t(_ zh: String, _ en: String) -> String {
        wordZText(zh, en, mode: languageMode)
    }

    @ViewBuilder
    private var groupActionMenu: some View {
        Button {
            onMove(.up)
        } label: {
            Label(
                groupingMode.moveGroupTitle(.up, in: languageMode),
                systemImage: EvidenceWorkbenchMoveDirection.up.systemImageName
            )
        }
        .disabled(!canMoveUp)

        Button {
            onMove(.down)
        } label: {
            Label(
                groupingMode.moveGroupTitle(.down, in: languageMode),
                systemImage: EvidenceWorkbenchMoveDirection.down.systemImageName
            )
        }
        .disabled(!canMoveDown)

        if groupingMode.supportsItemAssignment {
            Divider()

            Button {
                onSplit()
            } label: {
                Label(
                    groupingMode.splitSelectedGroupTitle(in: languageMode),
                    systemImage: "scissors"
                )
            }
            .disabled(!canSplit)

            Button {
                onRename()
            } label: {
                Label(
                    groupingMode.renameSelectedGroupTitle(in: languageMode),
                    systemImage: "pencil"
                )
            }

            Button {
                onMerge()
            } label: {
                Label(
                    groupingMode.mergeSelectedGroupTitle(in: languageMode),
                    systemImage: "arrow.triangle.merge"
                )
            }
        }
    }

    @ViewBuilder
    private var dropTargetBackground: some View {
        if isDropTargeted {
            RoundedRectangle(cornerRadius: 6)
                .fill(.tint.opacity(0.08))
        } else {
            Color.clear
        }
    }
}

private enum SidebarDropMetrics {
    static let groupMidline: CGFloat = 18
}

private enum EvidenceWorkbenchSidebarDragPayload: Hashable {
    case group(String)
    case item(String)

    init?(encodedValue: String) {
        if let value = encodedValue.removingPrefix("group:") {
            self = .group(value)
            return
        }
        if let value = encodedValue.removingPrefix("item:") {
            self = .item(value)
            return
        }
        return nil
    }

    var encodedValue: String {
        switch self {
        case .group(let groupID):
            return "group:\(groupID)"
        case .item(let itemID):
            return "item:\(itemID)"
        }
    }
}

private extension String {
    func removingPrefix(_ prefix: String) -> String? {
        guard hasPrefix(prefix) else { return nil }
        return String(dropFirst(prefix.count))
    }
}
