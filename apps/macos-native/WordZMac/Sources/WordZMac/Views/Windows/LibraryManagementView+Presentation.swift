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
        VStack(alignment: .leading, spacing: 16) {
            NativeWindowHeader(
                title: viewModel.scene.content.title,
                subtitle: viewModel.scene.content.subtitle
            )
            libraryManagerCommandBar
            libraryPrimaryContentPane
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var libraryManagerCommandBar: some View {
        AdaptiveToolbarSurface {
            HStack(spacing: 12) {
                Label(viewModel.scene.currentScopeSummary, systemImage: "externaldrive")
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)

                Spacer(minLength: 12)

                if let importProgress = viewModel.scene.importProgress {
                    ProgressView(value: importProgress)
                        .frame(width: 120)
                    Text(viewModel.scene.importDetail ?? viewModel.scene.statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Button {
                    onAction(.showCorpusBuilder)
                } label: {
                    Label(t("构建器", "Builder"), systemImage: "hammer")
                }
                .controlSize(.small)

                Button {
                    onAction(.importPaths)
                } label: {
                    Label(t("制作 DB", "Build DB"), systemImage: "plus")
                }
                .controlSize(.small)
                .adaptiveGlassButtonStyle(prominent: true)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
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
            AdaptiveEmptyStateSurface {
                ContentUnavailableView(
                    t("选择项目", "Select an Item"),
                    systemImage: "sidebar.right",
                    description: Text(t("选择文件夹、语料集或语料后查看详情。", "Select a folder, corpus set, or corpus to inspect details."))
                )
                .padding(24)
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
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
