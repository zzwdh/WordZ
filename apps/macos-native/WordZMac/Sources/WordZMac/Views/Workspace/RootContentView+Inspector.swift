import SwiftUI

extension RootContentView {
    private var noneSelectionID: String { "__wordz_none__" }

    var workspaceInspector: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                workspaceInspectorHeader
                workspaceScopeInspectorSection
                workspaceCurrentCorpusInspectorSection
                workspaceResultsInspectorSection
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(WordZTheme.workspaceBackground(for: WordZVisualStyle.resolve(for: .mainWorkspace)))
    }

    var workspaceInspectorHeader: some View {
        AdaptiveInspectorSurface {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: viewModel.selectedRoute.symbolName)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.selectedRoute.displayTitle(in: languageMode))
                        .font(.headline)
                    Text(workspaceInspectorHeaderSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    var workspaceInspectorHeaderSubtitle: String {
        if let artifact = viewModel.currentResultArtifact {
            return resultAccessorySubtitle(for: artifact)
        }
        return viewModel.shell.scene.workspaceSummary
    }

    var workspaceScopeInspectorSection: some View {
        NativeWindowSection(
            title: wordZText("语料范围", "Corpus Scope", mode: languageMode),
            subtitle: wordZText("选择当前分析的目标语料和参照语料", "Choose target and reference corpora for the current analysis", mode: languageMode)
        ) {
            VStack(alignment: .leading, spacing: 12) {
                inspectorPicker(
                    title: wordZText("目标语料", "Target Corpus", mode: languageMode),
                    selection: targetCorpusSelectionBinding
                ) {
                    if viewModel.sidebar.scene.corpusOptions.isEmpty {
                        Text(wordZText("没有可用语料", "No corpora available", mode: languageMode))
                            .tag("")
                    } else {
                        ForEach(viewModel.sidebar.scene.corpusOptions) { item in
                            Text(item.title)
                                .tag(item.id)
                        }
                    }
                }
                .disabled(viewModel.sidebar.scene.corpusOptions.isEmpty)

                inspectorPicker(
                    title: wordZText("参照语料", "Reference Corpus", mode: languageMode),
                    selection: referenceCorpusSelectionBinding
                ) {
                    Text(wordZText("不使用参照语料", "No reference corpus", mode: languageMode))
                        .tag(noneSelectionID)
                    ForEach(viewModel.sidebar.scene.corpusOptions) { item in
                        Text(item.title)
                            .tag(item.id)
                    }
                }

                if let metadataFilterSummary = viewModel.sidebar.scene.metadataFilterSummary {
                    Label(metadataFilterSummary, systemImage: "line.3.horizontal.decrease.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    var workspaceCurrentCorpusInspectorSection: some View {
        let targetCorpus = viewModel.sidebar.scene.targetCorpus

        NativeWindowSection(
            title: wordZText("当前语料", "Current Corpus", mode: languageMode),
            subtitle: targetCorpus.summary
        ) {
            VStack(alignment: .leading, spacing: 12) {
                Text(targetCorpus.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                workspaceCurrentCorpusActions(corpusID: targetCorpus.corpusID)
            }
        }
    }

    var workspaceResultsInspectorSection: some View {
        NativeWindowSection(
            title: wordZText("结果与导出", "Results & Export", mode: languageMode),
            subtitle: viewModel.sidebar.scene.results?.title
        ) {
            VStack(alignment: .leading, spacing: 12) {
                if let results = viewModel.sidebar.scene.results {
                    Text(results.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(wordZText("运行分析后，当前结果摘要和导出入口会显示在这里。", "Run an analysis to show the current result summary and export entry here.", mode: languageMode))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                workspaceInspectorResultActions
            }
        }
    }

    @ViewBuilder
    func workspaceCurrentCorpusActions(corpusID: String?) -> some View {
        AdaptiveSelectionAccessorySurface {
            HStack(spacing: 8) {
                inspectorActionButton(
                    title: wordZText("打开 DB", "Open DB", mode: languageMode),
                    systemImage: "arrow.up.right.square",
                    isProminent: true,
                    isEnabled: viewModel.shell.scene.toolbar.item(for: .openSelected)?.isEnabled ?? false
                ) {
                    dispatcher.handleToolbarAction(.openSelected)
                }

                if let corpusID {
                    inspectorActionButton(
                        title: "Quick Look",
                        systemImage: "eye"
                    ) {
                        dispatcher.handleSidebarAction(.quickLookSelected(corpusID))
                    }

                    inspectorActionButton(
                        title: wordZText("DB 信息", "DB Info", mode: languageMode),
                        systemImage: "info.circle"
                    ) {
                        dispatcher.handleSidebarAction(.showCorpusInfoSelected(corpusID))
                    }
                }
            }
            .padding(10)
        }
    }

    @ViewBuilder
    var workspaceInspectorResultActions: some View {
        if let artifact = viewModel.currentResultArtifact {
            AdaptiveSelectionAccessorySurface {
                VStack(alignment: .leading, spacing: 10) {
                    Label(
                        artifact.title,
                        systemImage: artifact.sourceTab.symbolName
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        ForEach(artifact.actionDescriptors(in: languageMode)) { descriptor in
                            inspectorResultActionButton(descriptor)
                        }
                    }
                }
                .padding(10)
            }
        } else {
            Button {
                dispatcher.handleToolbarAction(.exportCurrent)
            } label: {
                Label(
                    wordZText("导出当前结果", "Export Current Result", mode: languageMode),
                    systemImage: "square.and.arrow.down"
                )
            }
            .controlSize(.small)
            .adaptiveGlassButtonStyle()
            .disabled(true)
        }
    }

    func inspectorActionButton(
        title: String,
        systemImage: String,
        isProminent: Bool = false,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .frame(width: 18, height: 18)
                .contentShape(Rectangle())
        }
        .controlSize(.small)
        .adaptiveGlassButtonStyle(prominent: isProminent)
        .help(title)
        .accessibilityLabel(title)
        .disabled(!isEnabled)
    }

    func inspectorResultActionButton(
        _ descriptor: WorkspaceResultArtifactActionDescriptor
    ) -> some View {
        inspectorActionButton(
            title: descriptor.title,
            systemImage: descriptor.systemImage,
            isProminent: descriptor.isProminent
        ) {
            dispatcher.handleWorkspaceIntent(.resultArtifact(descriptor.action))
        }
        .help(descriptor.help)
    }

    func inspectorPicker<Content: View>(
        title: String,
        selection: Binding<String>,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker(title, selection: selection) {
                content()
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    var targetCorpusSelectionBinding: Binding<String> {
        Binding(
            get: {
                viewModel.sidebar.scene.targetCorpus.corpusID
                    ?? viewModel.sidebar.scene.corpusOptions.first?.id
                    ?? ""
            },
            set: { nextValue in
                guard !nextValue.isEmpty else { return }
                dispatcher.handleSidebarAction(.selectTargetCorpus(nextValue))
            }
        )
    }

    var referenceCorpusSelectionBinding: Binding<String> {
        Binding(
            get: {
                viewModel.sidebar.scene.referenceCorpus.corpusID ?? noneSelectionID
            },
            set: { nextValue in
                dispatcher.handleSidebarAction(
                    .selectReferenceCorpus(nextValue == noneSelectionID ? nil : nextValue)
                )
            }
        )
    }
}
