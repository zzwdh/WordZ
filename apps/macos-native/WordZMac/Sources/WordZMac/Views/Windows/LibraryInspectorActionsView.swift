import SwiftUI

struct LibraryInspectorActionsView: View {
    @Environment(\.wordZLanguageMode) private var languageMode

    let actions: [LibraryManagementInspectorActionItem]
    let onAction: (LibraryManagementAction) -> Void

    var body: some View {
        AdaptiveSelectionAccessorySurface {
            HStack(alignment: .center, spacing: 10) {
                ForEach(primaryVisibleActions) { item in
                    inspectorActionButton(
                        item,
                        prominent: item.id == primaryVisibleActions.first?.id
                    )
                }

                Spacer(minLength: 0)

                if !overflowActions.isEmpty {
                    Menu {
                        ForEach(normalOverflowActions) { item in
                            Button {
                                onAction(item.action)
                            } label: {
                                Label(item.title, systemImage: systemImage(for: item))
                            }
                        }

                        if !destructiveOverflowActions.isEmpty {
                            if !normalOverflowActions.isEmpty {
                                Divider()
                            }
                            ForEach(destructiveOverflowActions) { item in
                                Button(role: .destructive) {
                                    onAction(item.action)
                                } label: {
                                    Label(item.title, systemImage: systemImage(for: item))
                                }
                            }
                        }
                    } label: {
                        Label(t("更多", "More"), systemImage: "ellipsis.circle")
                    }
                    .controlSize(.small)
                    .adaptiveGlassButtonStyle()
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var primaryVisibleActions: [LibraryManagementInspectorActionItem] {
        let primaryActions = actions.filter { $0.role == .primary }
        if !primaryActions.isEmpty {
            return primaryActions
        }
        return actions.filter { $0.role == .normal }.prefix(1).map { $0 }
    }

    private var overflowActions: [LibraryManagementInspectorActionItem] {
        let visibleIDs = Set(primaryVisibleActions.map(\.id))
        return actions.filter { !visibleIDs.contains($0.id) }
    }

    private var normalOverflowActions: [LibraryManagementInspectorActionItem] {
        overflowActions.filter { $0.role != .destructive }
    }

    private var destructiveOverflowActions: [LibraryManagementInspectorActionItem] {
        overflowActions.filter { $0.role == .destructive }
    }

    private func inspectorActionButton(
        _ item: LibraryManagementInspectorActionItem,
        prominent: Bool
    ) -> some View {
        Button {
            onAction(item.action)
        } label: {
            Label(item.title, systemImage: systemImage(for: item))
        }
        .controlSize(.small)
        .adaptiveGlassButtonStyle(prominent: prominent)
        .help(item.title)
    }

    private func systemImage(for item: LibraryManagementInspectorActionItem) -> String {
        switch item.action {
        case .importPaths:
            return "tray.and.arrow.down"
        case .showCorpusBuilder:
            return "hammer"
        case .openSelectedCorpus:
            return "doc.text.magnifyingglass"
        case .quickLookSelectedCorpus:
            return "eye"
        case .shareSelectedCorpus:
            return "square.and.arrow.up"
        case .showSelectedCorpusInfo:
            return "info.circle"
        case .cleanSelectedCorpus, .cleanSelectedCorpora:
            return "wand.and.sparkles"
        case .editSelectedCorpusMetadata, .editSelectedCorporaMetadata:
            return "slider.horizontal.3"
        case .renameSelectedCorpus, .renameSelectedFolder:
            return "pencil"
        case .moveSelectedCorpusToSelectedFolder:
            return "folder"
        case .saveCurrentCorpusSet:
            return "tray.full"
        case .restoreSelectedRecycleEntry:
            return "arrow.uturn.backward"
        case .backupLibrary:
            return "archivebox"
        case .restoreLibrary:
            return "arrow.counterclockwise"
        case .repairLibrary:
            return "wrench.adjustable"
        case .deleteSelectedCorpus,
             .deleteSelectedFolder,
             .deleteSelectedCorpusSet,
             .purgeSelectedRecycleEntry:
            return "trash"
        default:
            return item.role == .destructive ? "trash" : "ellipsis.circle"
        }
    }

    private func t(_ zh: String, _ en: String) -> String {
        wordZText(zh, en, mode: languageMode)
    }
}
