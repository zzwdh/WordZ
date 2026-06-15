import SwiftUI

import WordZWindowing
import WordZShared
struct LibraryManagementView: View {
    @Environment(\.wordZLanguageMode) var languageMode
    @ObservedObject var viewModel: LibraryManagementViewModel
    @ObservedObject var sidebar: LibrarySidebarViewModel
    let onAction: (LibraryManagementAction) -> Void
    @State var isShowingMetadataFilters = false
    @State var isShowingLibraryReadiness = false
    @State var isShowingMetadataStudio = false

    var body: some View {
        NavigationSplitView {
            libraryNavigationSidebar
                .navigationSplitViewColumnWidth(min: 220, ideal: 260)
        } content: {
            libraryContentColumn
                .navigationSplitViewColumnWidth(min: 480, ideal: 620)
        } detail: {
            libraryInspectorColumn
                .navigationSplitViewColumnWidth(min: 300, ideal: 340)
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            if NativeWindowPresentationProfile.profile(for: .library)
                .resolvedToolbarMode(capabilities: .current) == .swiftUIPrimary {
                LibraryWindowToolbar(
                    preserveHierarchy: $viewModel.preserveHierarchy,
                    languageMode: languageMode,
                    canTriggerCleaning: canTriggerCleaning,
                    cleaningToolbarTitle: cleaningToolbarTitle,
                    cleaningToolbarAction: cleaningToolbarAction,
                    status: libraryToolbarStatus,
                    overflowActions: viewModel.scene.overflowActions,
                    onAction: onAction
                )
            }
        }
        .searchable(
            text: $viewModel.searchQuery,
            placement: .toolbar,
            prompt: t("搜索语料或文件夹", "Search corpora or folders")
        )
        .searchSuggestions {
            librarySearchSuggestions
        }
        .nativeLibrarySearchPresentation()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .modifier(libraryManagementPresentationModifier)
    }

    func t(_ zh: String, _ en: String) -> String {
        wordZText(zh, en, mode: languageMode)
    }
}

private struct LibrarySearchSuggestion: Identifiable {
    let id: String
    let title: String
    let detail: String
    let systemImage: String
    let completion: String
}

extension LibraryManagementView {
    @ViewBuilder
    var librarySearchSuggestions: some View {
        ForEach(searchSuggestionItems) { item in
            Label {
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.title)
                    if !item.detail.isEmpty {
                        Text(item.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } icon: {
                Image(systemName: item.systemImage)
            }
            .searchCompletion(item.completion)
        }
    }

    private var searchSuggestionItems: [LibrarySearchSuggestion] {
        var suggestions: [LibrarySearchSuggestion] = []

        suggestions.append(contentsOf: viewModel.scene.corpora.prefix(5).map { corpus in
            LibrarySearchSuggestion(
                id: "corpus-\(corpus.id)",
                title: corpus.title,
                detail: corpus.metadataSummary,
                systemImage: "doc.text",
                completion: corpus.title
            )
        })

        suggestions.append(contentsOf: viewModel.scene.folders.prefix(3).map { folder in
            LibrarySearchSuggestion(
                id: "folder-\(folder.id)",
                title: folder.title,
                detail: folder.subtitle,
                systemImage: "folder",
                completion: folder.title
            )
        })

        suggestions.append(contentsOf: viewModel.scene.recentCorpusSets.prefix(3).map { corpusSet in
            LibrarySearchSuggestion(
                id: "recent-set-\(corpusSet.id)",
                title: corpusSet.title,
                detail: corpusSet.filterSummary,
                systemImage: corpusSet.isSmart ? "line.3.horizontal.decrease.circle" : "tray.full",
                completion: corpusSet.title
            )
        })

        suggestions.append(contentsOf: viewModel.scene.corpusSets.prefix(3).map { corpusSet in
            LibrarySearchSuggestion(
                id: "set-\(corpusSet.id)",
                title: corpusSet.title,
                detail: corpusSet.filterSummary,
                systemImage: corpusSet.isSmart ? "line.3.horizontal.decrease.circle" : "tray.full",
                completion: corpusSet.title
            )
        })

        return Array(suggestions.prefix(10))
    }
}
