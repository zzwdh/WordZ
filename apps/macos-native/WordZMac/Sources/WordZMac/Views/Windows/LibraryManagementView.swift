import SwiftUI

struct LibraryManagementView: View {
    @Environment(\.wordZLanguageMode) var languageMode
    @ObservedObject var viewModel: LibraryManagementViewModel
    @ObservedObject var sidebar: LibrarySidebarViewModel
    let onAction: (LibraryManagementAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            NativeWindowHeader(
                title: t("语料库", "Library"),
                subtitle: viewModel.scene.librarySummary
            ) {
                Toggle(t("保留目录结构", "Preserve Folder Structure"), isOn: $viewModel.preserveHierarchy)
                    .toggleStyle(.switch)
                    .frame(maxWidth: 220)
            }
            libraryMetadataToolbarSection
            libraryActionToolbarSection
            librarySplitContent
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .modifier(libraryManagementPresentationModifier)
    }

    func t(_ zh: String, _ en: String) -> String {
        wordZText(zh, en, mode: languageMode)
    }
}
