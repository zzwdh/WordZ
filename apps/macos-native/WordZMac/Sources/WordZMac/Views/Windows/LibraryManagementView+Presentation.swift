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
            .sheet(item: $viewModel.importSummarySheet) { scene in
                LibraryImportSummarySheetView(
                    scene: scene,
                    onDismiss: {
                        viewModel.dismissImportSummary()
                    }
                )
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
                                        yearLabel: profile.yearLabel,
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
                viewModel.applyRecentCorpusSetIDs(sidebar.recentCorpusSetIDs)
                viewModel.selectCorpusSet(sidebar.selectedCorpusSetID)
                viewModel.syncSidebarSelection(sidebar.selectedCorpusID)
            }
            .onChange(of: sidebar.recentCorpusSetIDs) { _, nextRecentCorpusSetIDs in
                viewModel.applyRecentCorpusSetIDs(nextRecentCorpusSetIDs)
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
            navigationPane
                .frame(minWidth: 220, idealWidth: 240)

            libraryPrimaryContentPane
                .frame(minWidth: 420, idealWidth: 540)

            if let inspector = viewModel.scene.inspector {
                NativeWindowSection(
                    title: t("详情", "Inspector"),
                    subtitle: inspector.subtitle
                ) {
                    LibraryInspectorView(
                        scene: inspector,
                        onAction: onAction
                    )
                }
                .frame(minWidth: 280, idealWidth: 320)
            }
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
