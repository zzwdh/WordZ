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
            .sheet(item: $viewModel.importPreflightSheet) { scene in
                LibraryImportPreflightSheetView(
                    scene: scene,
                    onConfirm: { paths, corpusName in
                        onAction(.confirmImportPreflight(paths: paths, corpusName: corpusName))
                    },
                    onDismiss: {
                        viewModel.dismissImportPreflight()
                    }
                )
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
    var libraryContentColumn: some View {
        VStack(alignment: .leading, spacing: 14) {
            libraryHubHeader
            libraryHubOverviewBand
            libraryPrimaryContentPane
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    var libraryInspectorColumn: some View {
        if let inspector = viewModel.scene.inspector {
            ScrollView {
                LibraryInspectorView(
                    scene: inspector,
                    onAction: onAction
                )
                .padding(20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            ScrollView {
                libraryHubEmptyInspector
                    .padding(20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    var libraryManagementPresentationModifier: LibraryManagementPresentationModifier {
        LibraryManagementPresentationModifier(
            viewModel: viewModel,
            sidebar: sidebar,
            onAction: onAction
        )
    }
}
