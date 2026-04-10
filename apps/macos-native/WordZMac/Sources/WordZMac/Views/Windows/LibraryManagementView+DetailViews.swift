import SwiftUI

struct LibraryCorpusInfoSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.wordZLanguageMode) private var languageMode
    let scene: LibraryCorpusInfoSceneModel
    let onAction: (LibraryManagementAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            NativeWindowHeader(title: scene.title, subtitle: scene.subtitle) {
                Button(t("编辑元数据", "Edit Metadata")) {
                    dismiss()
                    onAction(.editSelectedCorpusMetadata)
                }
                Button(t("关闭", "Close")) {
                    dismiss()
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                NativeMetricTile(title: "Tokens", value: scene.tokenCountText)
                NativeMetricTile(title: "Types", value: scene.typeCountText)
                NativeMetricTile(title: "TTR", value: scene.ttrText)
                NativeMetricTile(title: "STTR", value: scene.sttrText)
                NativeMetricTile(title: "Sentences", value: scene.sentenceCountText)
                NativeMetricTile(title: "Paragraphs", value: scene.paragraphCountText)
                NativeMetricTile(title: "Characters", value: scene.characterCountText)
                NativeMetricTile(title: "Encoding", value: scene.encodingText)
            }

            NativeWindowSection(
                title: t("语料详情", "Corpus Details"),
                subtitle: t("当前语料的基础统计与来源信息", "Core statistics and source information for the selected corpus")
            ) {
                detailRow(title: t("文件夹", "Folder"), value: scene.folderName)
                detailRow(title: t("来源类型", "Source Type"), value: scene.sourceType.uppercased())
                detailRow(title: t("来源", "Source"), value: scene.sourceLabelText)
                detailRow(title: t("年份", "Year"), value: scene.yearText)
                detailRow(title: t("体裁", "Genre"), value: scene.genreText)
                detailRow(title: t("标签", "Tags"), value: scene.tagsText)
                detailRow(title: t("导入时间", "Imported At"), value: scene.importedAtText)
                detailRow(title: t("文本编码", "Text Encoding"), value: scene.encodingText)
                detailRow(title: t("原始路径", "Original Path"), value: scene.representedPath.isEmpty ? "—" : scene.representedPath)
            }

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(minWidth: 560, minHeight: 360, alignment: .topLeading)
    }

    private func detailRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func t(_ zh: String, _ en: String) -> String {
        wordZText(zh, en, mode: languageMode)
    }
}

struct LibraryCorpusMetadataEditorSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.wordZLanguageMode) private var languageMode
    let scene: LibraryCorpusMetadataEditorSceneModel
    let onSave: (CorpusMetadataProfile) -> Void
    let onCancel: () -> Void

    @State private var sourceLabel: String
    @State private var yearLabel: String
    @State private var genreLabel: String
    @State private var tagsText: String

    init(
        scene: LibraryCorpusMetadataEditorSceneModel,
        onSave: @escaping (CorpusMetadataProfile) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.scene = scene
        self.onSave = onSave
        self.onCancel = onCancel
        _sourceLabel = State(initialValue: scene.sourceLabel)
        _yearLabel = State(initialValue: scene.yearLabel)
        _genreLabel = State(initialValue: scene.genreLabel)
        _tagsText = State(initialValue: scene.tagsText)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            NativeWindowHeader(title: scene.title, subtitle: scene.subtitle) {
                Button(t("取消", "Cancel")) {
                    onCancel()
                    dismiss()
                }
                Button(t("保存", "Save")) {
                    onSave(
                        CorpusMetadataProfile(
                            sourceLabel: sourceLabel,
                            yearLabel: scene.allowsYearEditing ? yearLabel : "",
                            genreLabel: genreLabel,
                            tags: tagsText
                                .split(separator: ",")
                                .map(String.init)
                        )
                    )
                }
                .buttonStyle(.borderedProminent)
            }

            NativeWindowSection(
                title: t("元数据字段", "Metadata Fields"),
                subtitle: scene.isBatchEdit
                    ? t("本轮批量编辑会替换“来源 / 体裁”，并把新标签追加到每条语料上。年份暂不支持批量改写。", "Batch editing replaces Source / Genre and appends new tags to each corpus. Year stays single-edit only in this version.")
                    : t("这些字段会进入语料信息面板，也会为后续检索、筛选和导出打基础。", "These fields feed corpus info and prepare later filtering and exports.")
            ) {
                editorField(title: t("来源", "Source"), text: $sourceLabel, prompt: t("教材、期刊、访谈等", "Textbook, journal, interview, etc."))
                if scene.allowsYearEditing {
                    editorField(title: t("年份", "Year"), text: $yearLabel, prompt: t("如 2024 或 2018-2020", "For example 2024 or 2018-2020"))
                }
                editorField(title: t("体裁", "Genre"), text: $genreLabel, prompt: t("新闻、学术、小说等", "News, academic, fiction, etc."))
                editorField(
                    title: t("标签", "Tags"),
                    text: $tagsText,
                    prompt: scene.isBatchEdit
                        ? t("新增标签，多个用逗号分隔", "Tags to append, separated by commas")
                        : t("多个标签用逗号分隔", "Separate multiple tags with commas")
                )
            }

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(minWidth: 520, minHeight: 320, alignment: .topLeading)
    }

    private func editorField(title: String, text: Binding<String>, prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            TextField(prompt, text: text)
                .textFieldStyle(.roundedBorder)
        }
    }

    private func t(_ zh: String, _ en: String) -> String {
        wordZText(zh, en, mode: languageMode)
    }
}

struct LibraryInspectorView: View {
    let scene: LibraryManagementInspectorSceneModel
    let onAction: (LibraryManagementAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(scene.title)
                .font(.headline)
            Text(scene.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)

            if !scene.details.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(scene.details) { detail in
                        HStack(alignment: .firstTextBaseline) {
                            Text(detail.title)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 84, alignment: .leading)
                            Text(detail.value)
                                .font(.callout)
                                .textSelection(.enabled)
                        }
                    }
                }
            }

            if !scene.actions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(scene.actions) { item in
                        if item.role == .primary {
                            Button(item.title) { onAction(item.action) }
                                .buttonStyle(.borderedProminent)
                        } else {
                            Button(item.title) { onAction(item.action) }
                                .buttonStyle(.bordered)
                                .tint(item.role == .destructive ? .red : .accentColor)
                        }
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}
