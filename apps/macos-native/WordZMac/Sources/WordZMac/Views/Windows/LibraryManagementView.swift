import SwiftUI

struct LibraryManagementView: View {
    @Environment(\.wordZLanguageMode) var languageMode
    @ObservedObject var viewModel: LibraryManagementViewModel
    @ObservedObject var sidebar: LibrarySidebarViewModel
    let onAction: (LibraryManagementAction) -> Void
    @State var isShowingMetadataFilters = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            NativeWindowHeader(
                title: t("语料库", "Library"),
                subtitle: viewModel.scene.librarySummary
            )
            libraryUtilityBar
            librarySplitContent
        }
        .padding(20)
        .toolbar {
            if NativeWindowPresentationProfile.profile(for: .library)
                .resolvedToolbarMode(capabilities: .current) == .swiftUIPrimary {
                LibraryWindowToolbar(
                    preserveHierarchy: $viewModel.preserveHierarchy,
                    languageMode: languageMode,
                    canTriggerCleaning: canTriggerCleaning,
                    cleaningToolbarTitle: cleaningToolbarTitle,
                    cleaningToolbarAction: cleaningToolbarAction,
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
        .task(id: viewModel.normalizedSearchQuery) {
            try? await Task.sleep(nanoseconds: 180_000_000)
            guard !Task.isCancelled else { return }
            onAction(.refresh)
        }
        .nativeLibrarySearchPresentation()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .modifier(libraryManagementPresentationModifier)
    }

    func t(_ zh: String, _ en: String) -> String {
        wordZText(zh, en, mode: languageMode)
    }
}
