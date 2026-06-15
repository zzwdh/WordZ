import SwiftUI

import WordZWindowing
import WordZShared
struct LibraryCorpusInfoSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.wordZLanguageMode) private var languageMode
    let scene: LibraryCorpusInfoSceneModel
    let onAction: (LibraryManagementAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            NativeWindowHeader(title: t("语料详情", "Corpus Details"), subtitle: scene.title) {
                Button(t("打开语料", "Open Corpus")) {
                    dismiss()
                    onAction(.openSelectedCorpus)
                }
                Button(t("关闭", "Close")) {
                    dismiss()
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(t("名称：", "Name:"))
                    .font(.callout.weight(.semibold))
                Text(scene.title)
                    .font(.callout)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            ScrollView {
                Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
                    GridRow {
                        Text("")
                            .frame(width: 34, alignment: .trailing)
                        Text(t("Category", "Category"))
                            .font(.callout.weight(.semibold))
                        Text(t("Description", "Description"))
                            .font(.callout.weight(.semibold))
                    }
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)

                    ForEach(Array(detailRows.enumerated()), id: \.offset) { index, row in
                        Divider()
                            .gridCellColumns(3)
                        GridRow {
                            Text("\(index + 1)")
                                .foregroundStyle(.secondary)
                                .frame(width: 34, alignment: .trailing)
                            Text(row.title)
                                .font(.callout.weight(.semibold))
                            Text(row.value)
                                .font(.callout)
                                .textSelection(.enabled)
                                .lineLimit(2)
                                .truncationMode(.middle)
                        }
                        .padding(.vertical, 8)
                    }
                }
                .padding(.horizontal, 10)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(minWidth: 680, minHeight: 500, alignment: .topLeading)
        .librarySheetSurface()
    }

    private var detailRows: [(title: String, value: String)] {
        [
            (t("名称", "Name"), scene.title),
            (t("文件夹", "Folder"), scene.folderName),
            (t("来源", "Source"), sourceSummaryText),
            (t("来源标签", "Source Label"), scene.sourceLabelText),
            (t("年份", "Year"), scene.yearText),
            (t("体裁", "Genre"), scene.genreText),
            (t("标签", "Tags"), scene.tagsText),
            (t("导入时间", "Imported At"), scene.importedAtText),
            (t("整理状态", "Cleaning Status"), scene.cleaningStatusTitle),
            (t("可分析状态", "Readiness"), scene.analysisReadinessTitle),
            (t("状态说明", "Readiness Detail"), scene.analysisReadinessDetail),
            (t("建议", "Action"), scene.missingActionText),
            (t("文件数", "File Count"), scene.fileCountText),
            (t("词数", "Token Count"), scene.tokenCountText),
            (t("类型数", "Type Count"), scene.typeCountText),
            (t("句数", "Sentence Count"), scene.sentenceCountText),
            (t("段落数", "Paragraph Count"), scene.paragraphCountText),
            (t("字符数", "Character Count"), scene.characterCountText),
            ("TTR", scene.ttrText),
            ("STTR", scene.sttrText)
        ]
    }

    private var sourceSummaryText: String {
        let representedPath = scene.representedPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if representedPath.hasPrefix("wordz://corpus-set/") {
            return t("语料集生成", "Created from corpus set")
        }
        guard !representedPath.isEmpty else {
            return t("内置语料", "Built-in corpus")
        }
        let fileName = URL(fileURLWithPath: representedPath).lastPathComponent
        guard !fileName.isEmpty else {
            return t("文件导入", "File import")
        }
        return String(format: t("文件导入：%@", "File import: %@"), fileName)
    }

    private func t(_ zh: String, _ en: String) -> String {
        wordZText(zh, en, mode: languageMode)
    }
}

struct LibraryImportSummarySheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.wordZLanguageMode) private var languageMode
    let scene: LibraryImportSummarySceneModel
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            NativeWindowHeader(title: scene.title, subtitle: scene.subtitle) {
                Button(t("关闭", "Close")) {
                    onDismiss()
                    dismiss()
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 12)], spacing: 12) {
                NativeMetricTile(title: t("已导入", "Imported"), value: scene.importedCountText)
                NativeMetricTile(title: t("已跳过", "Skipped"), value: scene.skippedCountText)
                NativeMetricTile(title: t("已清洗", "Cleaned"), value: scene.cleanedCountText)
                NativeMetricTile(title: t("有变更", "Changed"), value: scene.changedCountText)
            }

            NativeWindowSection(
                title: t("清洗摘要", "Cleaning Summary"),
                subtitle: t("本轮导入后自动清洗产生的聚合结果", "Aggregated auto-cleaning results for this import")
            ) {
                detailRow(title: t("规则命中", "Rule Hits"), value: scene.ruleHitsSummaryText)
                detailRow(title: t("首个失败项", "First Failure"), value: scene.firstFailureText)
            }

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(minWidth: 480, minHeight: 300, alignment: .topLeading)
        .librarySheetSurface()
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
                .adaptiveGlassButtonStyle(prominent: true)
            }

            NativeWindowSection(
                title: t("元数据字段", "Metadata Fields"),
                subtitle: scene.isBatchEdit
                    ? t("本轮批量编辑会替换“来源 / 年份 / 体裁”，并把新标签追加到每条语料上。年份留空表示不修改。", "Batch editing replaces Source / Year / Genre and appends new tags to each corpus. Leave Year empty to keep existing values.")
                    : t("这些字段会进入语料信息面板，也会为后续检索、筛选和导出打基础。", "These fields feed corpus info and prepare later filtering and exports.")
            ) {
                sourceEditorField
                if scene.allowsYearEditing {
                    yearEditorField
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
        .librarySheetSurface()
    }

    private var sourceEditorField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(t("来源", "Source"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                TextField(
                    t("教材、期刊、访谈等", "Textbook, journal, interview, etc."),
                    text: $sourceLabel
                )
                .textFieldStyle(.roundedBorder)

                suggestionMenu(
                    symbol: "list.bullet",
                    primaryTitle: t("常用来源", "Common Sources"),
                    primaryItems: scene.sourcePresetLabels,
                    secondaryTitle: t("最近使用", "Recent Sources"),
                    secondaryItems: scene.recentSourceLabels
                ) { value in
                    sourceLabel = value
                }
            }
        }
    }

    private var yearEditorField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(t("年份", "Year"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                TextField(
                    t("如 2024 或 2018-2020", "For example 2024 or 2018-2020"),
                    text: $yearLabel
                )
                .textFieldStyle(.roundedBorder)

                suggestionMenu(
                    symbol: "calendar",
                    primaryTitle: t("快捷年份", "Quick Years"),
                    primaryItems: scene.quickYearLabels,
                    secondaryTitle: t("库中常见年份", "Common Library Years"),
                    secondaryItems: scene.commonYearLabels
                ) { value in
                    yearLabel = value
                }
            }
        }
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

    private func suggestionMenu(
        symbol: String,
        primaryTitle: String,
        primaryItems: [String],
        secondaryTitle: String,
        secondaryItems: [String],
        onSelect: @escaping (String) -> Void
    ) -> some View {
        Menu {
            if !primaryItems.isEmpty {
                Section(primaryTitle) {
                    ForEach(primaryItems, id: \.self) { item in
                        Button(item) {
                            onSelect(item)
                        }
                    }
                }
            }

            if !secondaryItems.isEmpty {
                Section(secondaryTitle) {
                    ForEach(secondaryItems, id: \.self) { item in
                        Button(item) {
                            onSelect(item)
                        }
                    }
                }
            }
        } label: {
            Image(systemName: symbol)
                .frame(width: 28, height: 28)
        }
        .menuStyle(.borderlessButton)
        .disabled(primaryItems.isEmpty && secondaryItems.isEmpty)
    }

    private func t(_ zh: String, _ en: String) -> String {
        wordZText(zh, en, mode: languageMode)
    }
}

struct LibraryInspectorView: View {
    @Environment(\.wordZLanguageMode) private var languageMode
    let scene: LibraryManagementInspectorSceneModel
    let onAction: (LibraryManagementAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            AdaptiveInspectorSurface {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "sidebar.right")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(scene.title)
                            .font(.headline)
                        Text(scene.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !scene.statusItems.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(scene.statusItems) { item in
                        inspectorStatusRow(item)
                    }
                }
            }

            if !scene.details.isEmpty {
                NativeWindowSection(
                    title: wordZText("详情", "Details", mode: languageMode),
                    subtitle: wordZText("当前选择的关键信息", "Key information for the current selection", mode: languageMode)
                ) {
                    ForEach(scene.details) { detail in
                        inspectorDetailRow(detail)
                    }
                }
            }

            if !scene.actions.isEmpty {
                LibraryInspectorActionsView(
                    actions: scene.actions,
                    onAction: onAction
                )
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func inspectorDetailRow(_ detail: LibraryManagementInspectorDetailItem) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(detail.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 92, alignment: .leading)

            Text(detail.value)
                .font(detailValueFont(for: detail.id))
                .lineLimit(2)
                .truncationMode(.middle)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .help(detail.value)
        }
    }

    private func detailValueFont(for id: String) -> Font {
        switch id {
        case "project-id", "database-file", "source-path":
            return .callout.monospaced()
        default:
            return .callout
        }
    }

    private func inspectorStatusRow(_ item: LibraryManagementInspectorStatusItem) -> some View {
        let tint = statusTint(for: item.level)
        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: item.systemImage)
                .font(.callout.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.caption.weight(.semibold))
                Text(item.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tint.opacity(0.22), lineWidth: 1)
        )
    }

    private func statusTint(for level: LibraryManagementInspectorStatusLevel) -> Color {
        switch level {
        case .info:
            return .secondary
        case .success:
            return .green
        case .warning:
            return .orange
        case .blocked:
            return .red
        }
    }
}

struct LibrarySheetSurfaceModifier: ViewModifier {
    func body(content: Content) -> some View {
        NativePlatformCapabilities.decorateSheetSurface(
            content,
            style: WordZVisualStyle.resolve(for: .library)
        )
    }
}

extension View {
    func librarySheetSurface() -> some View {
        modifier(LibrarySheetSurfaceModifier())
    }
}
