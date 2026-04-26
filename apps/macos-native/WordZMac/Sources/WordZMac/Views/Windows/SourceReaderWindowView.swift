import SwiftUI

struct SourceReaderWindowView: View {
    @Environment(\.wordZLanguageMode) private var languageMode
    @ObservedObject var workspace: MainWorkspaceViewModel
    @ObservedObject private var sourceReader: SourceReaderViewModel

    init(workspace: MainWorkspaceViewModel) {
        self.workspace = workspace
        _sourceReader = ObservedObject(wrappedValue: workspace.sourceReader)
    }

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            Divider()
            contentSection
        }
        .adaptiveWindowScaffold(for: .sourceReader)
        .bindWindowRoute(.sourceReader, titleProvider: { mode in
            sourceReader.scene?.title ?? NativeWindowRoute.sourceReader.title(in: mode)
        })
        .focusedValue(\.workspaceCommandContext, workspace.commandContext(for: .sourceReader))
        .task {
            await workspace.initializeIfNeeded()
        }
        .frame(minWidth: 1080, minHeight: 760)
    }

    private var headerSection: some View {
        AdaptiveHeaderSurface {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(sourceReader.scene?.title ?? t("原文阅读器", "Source Reader"))
                            .font(.title3.weight(.semibold))
                        if let subtitle = sourceReader.scene?.subtitle, !subtitle.isEmpty {
                            Text(subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                        if let originSummary = sourceReader.scene?.originSummary, !originSummary.isEmpty {
                            Text(originSummary)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        if let annotationSummary = sourceReader.scene?.annotationSummary, !annotationSummary.isEmpty {
                            Text(annotationSummary)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    HStack(spacing: 8) {
                        Button {
                            sourceReader.selectAdjacentHit(offset: -1)
                        } label: {
                            Label(t("上一条", "Previous"), systemImage: "chevron.up")
                        }
                        .disabled(!sourceReader.canSelectPreviousHit)

                        Button {
                            sourceReader.selectAdjacentHit(offset: 1)
                        } label: {
                            Label(t("下一条", "Next"), systemImage: "chevron.down")
                        }
                        .disabled(!sourceReader.canSelectNextHit)

                        Button(t("复制引文", "Copy Citation")) {
                            workspace.copySourceReaderCitation()
                        }
                        .disabled(sourceReader.currentCitationText == nil)

                        Button(t("加入摘录", "Add to Clips")) {
                            Task { await workspace.captureCurrentSourceReaderEvidenceItem() }
                        }
                        .disabled(!sourceReader.canAddEvidence)

                        Button(t("打开原文件", "Open Source File")) {
                            Task { await workspace.openSourceReaderOriginalFile() }
                        }
                        .disabled(sourceReader.currentFilePath == nil)

                        Button("Quick Look") {
                            Task { await workspace.quickLookSourceReaderContent() }
                        }
                    }
                    .buttonStyle(.bordered)
                }

                if let hitCountSummary = sourceReader.scene?.hitCountSummary {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(hitCountSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let captureDraftSummary = sourceReader.captureDraftSummary {
                            Text(captureDraftSummary)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(20)
        }
    }

    @ViewBuilder
    private var contentSection: some View {
        if sourceReader.isLoading {
            VStack(spacing: 12) {
                ProgressView()
                Text(t("正在准备原文阅读内容…", "Preparing source reader content…"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let scene = sourceReader.scene {
            NavigationSplitView {
                List(
                    selection: Binding(
                        get: { sourceReader.scene?.selectedHitID },
                        set: { sourceReader.selectHit($0) }
                    )
                ) {
                    ForEach(scene.hitItems) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Text("\(t("句", "Sentence")) \(item.sentenceLabel)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(item.keyword)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                            }

                            Text(item.concordanceText)
                                .font(.subheadline)
                                .lineLimit(2)

                            Text(item.fullSentenceText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        .padding(.vertical, 4)
                        .tag(item.id)
                    }
                }
                .listStyle(.sidebar)
            } detail: {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if let selection = scene.selection {
                            WorkbenchSectionCard {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack(spacing: 12) {
                                        Text(t("当前命中", "Current Hit"))
                                            .font(.headline)
                                        Spacer()
                                        Text("\(t("句", "Sentence")) \(selection.hit.sentenceLabel)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .monospacedDigit()
                                    }

                                    WorkbenchConcordanceLineView(
                                        leftContext: selection.leftContext,
                                        keyword: selection.keyword,
                                        rightContext: selection.rightContext
                                    )

                                    detailBlock(
                                        title: t("完整原句", "Full Sentence"),
                                        content: selection.hit.fullSentenceText
                                    )

                                    detailBlock(
                                        title: t("引文", "Citation"),
                                        content: selection.hit.citationText
                                    )

                                    if !selection.annotationItems.isEmpty {
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text(t("命中标注", "Hit Annotation"))
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(.secondary)
                                            annotationGrid(selection.annotationItems)
                                        }
                                    }
                                }
                            }
                        }

                        if sourceReader.canAddEvidence {
                            SourceReaderCaptureDraftCard(sourceReader: sourceReader)
                        }

                        WorkbenchSectionCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(t("原文句子", "Source Sentences"))
                                    .font(.headline)

                                LazyVStack(alignment: .leading, spacing: 8) {
                                    ForEach(scene.sentences) { sentence in
                                        VStack(alignment: .leading, spacing: 6) {
                                            HStack(spacing: 8) {
                                                Text("\(t("句", "Sentence")) \(sentence.sentenceLabel)")
                                                    .font(.caption.weight(.semibold))
                                                    .foregroundStyle(.secondary)
                                                if sentence.containsHit {
                                                    Text(t("含命中", "Contains Hit"))
                                                        .font(.caption2.weight(.medium))
                                                        .foregroundStyle(.secondary)
                                                }
                                            }

                                            Text(sentence.text)
                                                .font(.body)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .textSelection(.enabled)
                                        }
                                        .padding(12)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .fill(sentence.isSelected ? Color.accentColor.opacity(0.12) : WordZTheme.primarySurfaceSoft)
                                        )
                                    }
                                }
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationSplitViewStyle(.balanced)
        } else {
            WorkbenchEmptyStateCard(
                title: t("还没有原文阅读内容", "No source reader content yet"),
                systemImage: "doc.text.magnifyingglass",
                message: t(
                    "先从 KWIC、定位器或 Plot 选择一条带 provenance 的结果，再打开原文阅读器。",
                    "Select a provenance-backed result from KWIC, Locator, or Plot, then open the source reader."
                )
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(20)
        }
    }

    private func detailBlock(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(content)
                .font(.callout)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
    }

    private func annotationGrid(_ items: [SourceReaderAnnotationSceneItem]) -> some View {
        LazyVGrid(
            columns: [
                GridItem(.adaptive(minimum: 140), alignment: .leading)
            ],
            alignment: .leading,
            spacing: 8
        ) {
            ForEach(items) { item in
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(item.value)
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(WordZTheme.primarySurfaceSoft)
                )
            }
        }
    }

    private func t(_ zh: String, _ en: String) -> String {
        wordZText(zh, en, mode: languageMode)
    }
}
