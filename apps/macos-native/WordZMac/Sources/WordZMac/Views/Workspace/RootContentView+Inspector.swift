import SwiftUI

extension RootContentView {
    private var noneSelectionID: String { "__wordz_none__" }

    var workspaceInspector: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                NativeWindowHeader(
                    title: wordZText("检查器", "Inspector", mode: languageMode),
                    subtitle: viewModel.selectedRoute.displayTitle(in: languageMode)
                )

                workspaceScopeInspectorSection
                workspaceCurrentCorpusInspectorSection
                workspaceResultsInspectorSection
                workspaceStatusInspectorSection
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    var workspaceScopeInspectorSection: some View {
        NativeWindowSection(
            title: wordZText("语料范围", "Corpus Scope", mode: languageMode),
            subtitle: viewModel.sidebar.scene.selectedCorpusSetSummary
        ) {
            VStack(alignment: .leading, spacing: 12) {
                inspectorPicker(
                    title: wordZText("语料集", "Corpus Set", mode: languageMode),
                    selection: corpusSetSelectionBinding
                ) {
                    Text(wordZText("全部语料", "All Corpora", mode: languageMode))
                        .tag(noneSelectionID)
                    ForEach(viewModel.sidebar.scene.corpusSets) { item in
                        Text(item.title)
                            .tag(item.id)
                    }
                }

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

                HStack(spacing: 8) {
                    Button(wordZText("打开语料", "Open Corpus", mode: languageMode)) {
                        dispatcher.handleToolbarAction(.openSelected)
                    }
                    .disabled(!(viewModel.shell.scene.toolbar.item(for: .openSelected)?.isEnabled ?? false))

                    if let corpusID = targetCorpus.corpusID {
                        Button("Quick Look") {
                            dispatcher.handleSidebarAction(.quickLookSelected(corpusID))
                        }

                        Button(wordZText("语料信息", "Corpus Info", mode: languageMode)) {
                            dispatcher.handleSidebarAction(.showCorpusInfoSelected(corpusID))
                        }
                    }
                }
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

                Button(wordZText("导出当前结果", "Export Current Result", mode: languageMode)) {
                    dispatcher.handleToolbarAction(.exportCurrent)
                }
                .disabled(!(viewModel.shell.scene.toolbar.item(for: .exportCurrent)?.isEnabled ?? false))
            }
        }
    }

    var workspaceStatusInspectorSection: some View {
        NativeWindowSection(
            title: wordZText("状态", "Status", mode: languageMode),
            subtitle: viewModel.shell.scene.workspaceSummary
        ) {
            VStack(alignment: .leading, spacing: 12) {
                Label(viewModel.sidebar.scene.engineStatus, systemImage: inspectorEngineSymbolName)
                    .foregroundStyle(inspectorEngineTint)

                if let metadataFilterSummary = viewModel.sidebar.scene.metadataFilterSummary {
                    Label(metadataFilterSummary, systemImage: "line.3.horizontal.decrease.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !viewModel.sidebar.scene.errorMessage.isEmpty {
                    Text(viewModel.sidebar.scene.errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text(viewModel.shell.scene.buildSummary)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
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

    var corpusSetSelectionBinding: Binding<String> {
        Binding(
            get: {
                viewModel.sidebar.scene.corpusSets.first(where: \.isSelected)?.id ?? noneSelectionID
            },
            set: { nextValue in
                dispatcher.handleSidebarAction(
                    .applyCorpusSet(nextValue == noneSelectionID ? nil : nextValue)
                )
            }
        )
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

    var inspectorEngineSymbolName: String {
        switch viewModel.sidebar.scene.engineState {
        case .connecting:
            return "bolt.horizontal.circle"
        case .connected:
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        }
    }

    var inspectorEngineTint: Color {
        switch viewModel.sidebar.scene.engineState {
        case .connecting:
            return .secondary
        case .connected:
            return .green
        case .failed:
            return .orange
        }
    }
}
