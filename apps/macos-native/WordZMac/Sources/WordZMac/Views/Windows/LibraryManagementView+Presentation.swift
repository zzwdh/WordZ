import SwiftUI

struct LibraryManagementPresentationModifier: ViewModifier {
    @ObservedObject var viewModel: LibraryManagementViewModel
    @ObservedObject var sidebar: LibrarySidebarViewModel
    let onAction: (LibraryManagementAction) -> Void

    func body(content: Content) -> some View {
        content
            .sheet(item: $viewModel.corpusInfoSheet) { scene in
                LibraryCorpusInfoSheetView(scene: scene, onAction: onAction)
            }
            .sheet(item: $viewModel.metadataEditorSheet) { scene in
                LibraryCorpusMetadataEditorSheetView(
                    scene: scene,
                    onSave: { profile in
                        if scene.isBatchEdit {
                            onAction(
                                .applySelectedCorporaMetadataPatch(
                                    BatchCorpusMetadataPatch(
                                        sourceLabel: profile.sourceLabel,
                                        genreLabel: profile.genreLabel,
                                        tagsToAdd: profile.tags
                                    )
                                )
                            )
                        } else {
                            onAction(.saveSelectedCorpusMetadata(profile))
                        }
                    },
                    onCancel: {
                        viewModel.dismissMetadataEditor()
                    }
                )
            }
            .task {
                viewModel.applyMetadataFilterState(sidebar.metadataFilterState)
                viewModel.selectCorpusSet(sidebar.selectedCorpusSetID)
                viewModel.syncSidebarSelection(sidebar.selectedCorpusID)
            }
            .onChange(of: sidebar.selectedCorpusSetID) { _, nextCorpusSetID in
                viewModel.selectCorpusSet(nextCorpusSetID)
            }
            .onChange(of: sidebar.metadataFilterState) { _, nextState in
                viewModel.applyMetadataFilterState(nextState)
            }
            .onChange(of: sidebar.selectedCorpusID) { _, nextSelectedCorpusID in
                if viewModel.selectedCorpusIDs.count <= 1 {
                    viewModel.syncSidebarSelection(nextSelectedCorpusID)
                }
            }
    }
}

extension LibraryManagementView {
    var librarySplitContent: some View {
        HSplitView {
            folderPane
                .frame(minWidth: 220, idealWidth: 240)

            corpusPane
                .frame(minWidth: 360, idealWidth: 420)

            VSplitView {
                recyclePane
                    .frame(minHeight: 220)

                NativeWindowSection(
                    title: t("详情", "Inspector"),
                    subtitle: viewModel.scene.inspector.subtitle
                ) {
                    LibraryInspectorView(
                        scene: viewModel.scene.inspector,
                        onAction: onAction
                    )
                }
                .frame(minHeight: 220)
            }
            .frame(minWidth: 280, idealWidth: 320)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var libraryManagementPresentationModifier: LibraryManagementPresentationModifier {
        LibraryManagementPresentationModifier(
            viewModel: viewModel,
            sidebar: sidebar,
            onAction: onAction
        )
    }
}
