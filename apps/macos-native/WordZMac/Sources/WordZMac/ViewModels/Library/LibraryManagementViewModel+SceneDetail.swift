import Foundation
import WordZShared

@MainActor
extension LibraryManagementViewModel {
    func buildInspector(
        visibleCorpora: [LibraryCorpusItem],
        corporaByFolderID: [String: [LibraryCorpusItem]],
        corporaByID: [String: LibraryCorpusItem],
        readinessByCorpusID: [String: LibraryCorpusReadinessSceneModel] = [:]
    ) -> LibraryManagementInspectorSceneModel? {
        if let selectedCorpusSet {
            let resolvedCorpora = selectedCorpusSet.corpusIDs.compactMap { corporaByID[$0] }
            let hasResolvedCorpora = !resolvedCorpora.isEmpty
            return LibraryManagementInspectorSceneModel(
                title: selectedCorpusSet.name,
                subtitle: selectedCorpusSet.metadataFilterState.isEmpty ? "固定语料集" : "智能语料集",
                statusItems: [
                    .init(
                        id: "set-db",
                        title: hasResolvedCorpora ? "可分析语料集" : "语料集暂无可用语料",
                        detail: hasResolvedCorpora
                            ? "分析时会打开合并后的语料集，范围来自下方 \(resolvedCorpora.count) 条语料。"
                            : "保存的成员在当前库中不可用，需要重新选择语料后再保存为语料集。",
                        systemImage: hasResolvedCorpora ? "checkmark.seal" : "exclamationmark.triangle",
                        level: hasResolvedCorpora ? .success : .blocked
                    ),
                    .init(
                        id: "set-source-chain",
                        title: "来源范围",
                        detail: selectedCorpusSet.metadataFilterState.isEmpty
                            ? "固定范围：使用保存时选中的语料。"
                            : "智能范围：按元数据筛选动态整理，可继续补齐来源、年份、体裁和标签。",
                        systemImage: "point.3.connected.trianglepath.dotted",
                        level: .info
                    )
                ],
                details: [
                    .init(id: "set-kind", title: "类型", value: selectedCorpusSet.metadataFilterState.isEmpty ? "固定语料集" : "智能语料集"),
                    .init(id: "set-count", title: "语料数量", value: "\(resolvedCorpora.count)"),
                    .init(id: "set-filters", title: "元数据筛选", value: selectedCorpusSet.metadataFilterState.summaryText(in: WordZLocalization.shared.effectiveMode) ?? "无"),
                    .init(id: "set-updated", title: "最近更新", value: selectedCorpusSet.updatedAt.isEmpty ? "—" : selectedCorpusSet.updatedAt)
                ],
                actions: [
                    .init(id: "save-set", title: "更新当前语料集", role: .primary, action: .saveCurrentCorpusSet),
                    .init(id: "delete-set", title: "删除语料集", role: .destructive, action: .deleteSelectedCorpusSet)
                ]
            )
        }

        if selectedCorpusIDs.count > 1 {
            let currentSelection = selectedCorpora
            return LibraryManagementInspectorSceneModel(
                title: "已选择 \(selectedCorpusIDs.count) 条语料",
                subtitle: "Corpus Library",
                statusItems: [
                    .init(
                        id: "batch-build",
                        title: "可保存为命名语料集",
                        detail: "所选语料会保存为一个命名语料集，之后可直接在分析中选择。",
                        systemImage: "tray.full",
                        level: .success
                    ),
                    .init(
                        id: "batch-readiness",
                        title: "批量整理建议",
                        detail: batchReadinessSummary(for: currentSelection),
                        systemImage: "checklist",
                        level: currentSelection.contains(where: { corpus in
                            let level = readinessByCorpusID[corpus.id]?.level
                                ?? makeReadinessScene(for: corpus, languageMode: WordZLocalization.shared.effectiveMode).level
                            return level == .blocked
                        }) ? .warning : .info
                    )
                ],
                details: [
                    .init(id: "batch-count", title: "选中数量", value: "\(selectedCorpusIDs.count)"),
                    .init(id: "batch-scope", title: "当前位置", value: currentScopeSummaryForInspector())
                ],
                actions: [
                    .init(id: "save-set", title: "保存为语料集", role: .primary, action: .saveCurrentCorpusSet)
                ]
            )
        }

        if let selectedCorpus {
            let languageMode = WordZLocalization.shared.effectiveMode
            let readiness = readinessByCorpusID[selectedCorpus.id]
                ?? makeReadinessScene(for: selectedCorpus, languageMode: languageMode)
            return LibraryManagementInspectorSceneModel(
                title: selectedCorpus.name,
                subtitle: "语料",
                statusItems: corpusInspectorStatusItems(
                    readiness: readiness
                ),
                details: [
                    .init(id: "folder", title: "文件夹", value: selectedCorpus.folderName),
                    .init(id: "metadata", title: "元数据", value: selectedCorpus.metadata.compactSummary(in: languageMode))
                ],
                actions: [
                    .init(id: "open", title: "打开语料", role: .primary, action: .openSelectedCorpus),
                    .init(id: "info", title: "详情", role: .normal, action: .showSelectedCorpusInfo),
                    .init(id: "preview", title: "快速预览", role: .normal, action: .quickLookSelectedCorpus),
                    .init(id: "share", title: "分享语料", role: .normal, action: .shareSelectedCorpus),
                    .init(id: "rename-corpus", title: "重命名", role: .normal, action: .renameSelectedCorpus),
                    .init(id: "move-corpus", title: "移动到所选文件夹", role: .normal, action: .moveSelectedCorpusToSelectedFolder),
                    .init(id: "delete-corpus", title: "删除", role: .destructive, action: .deleteSelectedCorpus)
                ]
            )
        }

        if let selectedRecycleEntry {
            return LibraryManagementInspectorSceneModel(
                title: selectedRecycleEntry.name,
                subtitle: "回收站项目 · \(selectedRecycleEntry.type)",
                statusItems: [
                    .init(
                        id: "recycle-blocked",
                        title: "回收站项目不可分析",
                        detail: "先恢复项目，语料才会重新进入 Corpus Library 和分析范围。",
                        systemImage: "trash",
                        level: .blocked
                    )
                ],
                details: [
                    .init(id: "deleted-at", title: "删除时间", value: selectedRecycleEntry.deletedAt),
                    .init(id: "origin-folder", title: "原始文件夹", value: selectedRecycleEntry.originalFolderName),
                    .init(id: "item-count", title: "项目数量", value: "\(selectedRecycleEntry.itemCount)")
                ],
                actions: [
                    .init(id: "restore-recycle", title: "恢复项目", role: .primary, action: .restoreSelectedRecycleEntry),
                    .init(id: "purge-recycle", title: "彻底删除", role: .destructive, action: .purgeSelectedRecycleEntry)
                ]
            )
        }

        if let selectedFolder {
            let folderCorpora = corporaByFolderID[selectedFolder.id] ?? []
            return LibraryManagementInspectorSceneModel(
                title: selectedFolder.name,
                subtitle: "文件夹",
                statusItems: [
                    .init(
                        id: "folder-scope",
                        title: "管理范围，不是分析文件",
                        detail: "文件夹用于组织语料；真正进入分析的是单条语料或命名语料集。",
                        systemImage: "folder",
                        level: .info
                    ),
                    .init(
                        id: "folder-build",
                        title: "可在此导入语料",
                        detail: preserveHierarchy ? "导入会保留文件夹层级，便于后续追溯来源。" : "导入会放入当前文件夹，不保留外部层级。",
                        systemImage: "hammer",
                        level: .success
                    )
                ],
                details: [
                    .init(id: "folder-corpus-count", title: "语料数量", value: "\(folderCorpora.count)"),
                    .init(id: "visible-count", title: "当前视图", value: "\(visibleCorpora.count) 条语料"),
                    .init(id: "preserve-hierarchy", title: "导入保留层级", value: preserveHierarchy ? "开启" : "关闭")
                ],
                actions: [
                    .init(id: "import-folder", title: "在此导入", role: .primary, action: .importPaths),
                    .init(id: "rename-folder", title: "重命名文件夹", role: .normal, action: .renameSelectedFolder),
                    .init(id: "delete-folder", title: "删除文件夹", role: .destructive, action: .deleteSelectedFolder)
                ]
            )
        }

        return nil
    }

    private func corpusInspectorStatusItems(
        readiness: LibraryCorpusReadinessSceneModel
    ) -> [LibraryManagementInspectorStatusItem] {
        [
            .init(
                id: "readiness",
                title: "\(readiness.title) · \(readiness.scoreText)",
                detail: readiness.detailText,
                systemImage: statusImage(for: readiness.level),
                level: statusLevel(for: readiness.level)
            )
        ]
    }

    private func batchReadinessSummary(for corpora: [LibraryCorpusItem]) -> String {
        let languageMode = WordZLocalization.shared.effectiveMode
        let pendingCleaningCount = corpora.filter { $0.cleaningStatus == .pending }.count
        let missingMetadataCount = corpora.filter {
            $0.metadata.sourceLabel.isEmpty
                || $0.metadata.yearLabel.isEmpty
                || $0.metadata.genreLabel.isEmpty
                || $0.metadata.tags.isEmpty
        }.count
        if pendingCleaningCount > 0 {
            return String(
                format: wordZText("建议先清洗 %d 条语料，再保存最终语料集。", "Clean %d corpora before saving the final set.", mode: languageMode),
                pendingCleaningCount
            )
        }
        if missingMetadataCount > 0 {
            return String(
                format: wordZText("有 %d 条语料缺元数据；可先批量编辑，后续筛选和报告会更可靠。", "%d corpora have missing metadata; batch-editing improves filtering and reports.", mode: languageMode),
                missingMetadataCount
            )
        }
        return wordZText("当前选择可直接保存为语料集。", "The current selection can be saved as a corpus set.", mode: languageMode)
    }

    private func statusImage(for level: LibraryCorpusReadinessLevel) -> String {
        switch level {
        case .ready:
            return "checkmark.seal"
        case .attention:
            return "exclamationmark.triangle"
        case .blocked:
            return "xmark.octagon"
        }
    }

    private func statusLevel(for level: LibraryCorpusReadinessLevel) -> LibraryManagementInspectorStatusLevel {
        switch level {
        case .ready:
            return .success
        case .attention:
            return .warning
        case .blocked:
            return .blocked
        }
    }

    private func sourceChainSummary(representedPath: String) -> String {
        let normalizedPath = representedPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalizedPath.hasPrefix("wordz://corpus-set/") {
            return "语料集生成"
        }
        guard !normalizedPath.isEmpty else {
            return "内置语料"
        }
        let fileName = URL(fileURLWithPath: normalizedPath).lastPathComponent
        return fileName.isEmpty ? "文件导入" : "文件导入：\(fileName)"
    }

    private func chineseAnalysisSupportText(mode: AppLanguageMode) -> String {
        wordZText(
            "中英混合 tokenizer 已用于 Stats / KWIC / N-gram / Compare / Keyword / Collocate / Topics / Sentiment。",
            "Mixed Chinese/English tokenization is used by Stats / KWIC / N-gram / Compare / Keyword / Collocate / Topics / Sentiment.",
            mode: mode
        )
    }

    private func readinessActionText(for readiness: LibraryCorpusReadinessSceneModel) -> String {
        readiness.issueTitles.isEmpty ? "可直接分析" : readiness.issueTitles.joined(separator: " · ")
    }

    func makeCorpusInfoScene(
        summary: CorpusInfoSummary,
        languageMode: AppLanguageMode = WordZLocalization.shared.effectiveMode
    ) -> LibraryCorpusInfoSceneModel {
        let cleaningSummary = summary.cleaningSummary
        let readiness = makeCorpusInfoReadiness(summary, languageMode: languageMode)
        let databaseFileName = corpusInfoDatabaseFileName(summary)
        return LibraryCorpusInfoSceneModel(
            id: summary.corpusId,
            title: summary.title,
            subtitle: wordZText("语料信息", "Corpus Info", mode: languageMode),
            projectIDText: summary.corpusId,
            databaseFileNameText: databaseFileName,
            dbProjectSummaryText: wordZText(
                "已加入语料库，可直接用于分析",
                "Added to Library and ready for analysis",
                mode: languageMode
            ),
            sourceChainText: sourceChainSummary(
                representedPath: summary.representedPath
            ),
            analysisReadinessTitle: readiness.title,
            analysisReadinessDetail: readiness.detailText,
            chineseAnalysisText: chineseAnalysisSupportText(mode: languageMode),
            missingActionText: readinessActionText(for: readiness),
            folderName: summary.folderName,
            sourceType: summary.sourceType,
            sourceLabelText: summary.metadata.sourceLabel.isEmpty ? "—" : summary.metadata.sourceLabel,
            yearText: summary.metadata.yearLabel.isEmpty ? "—" : summary.metadata.yearLabel,
            genreText: summary.metadata.genreLabel.isEmpty ? "—" : summary.metadata.genreLabel,
            tagsText: summary.metadata.tagsText.isEmpty ? "—" : summary.metadata.tagsText,
            importedAtText: summary.importedAt.isEmpty ? "—" : summary.importedAt,
            encodingText: summary.detectedEncoding.isEmpty ? "—" : summary.detectedEncoding,
            fileCountText: "\(summary.fileCount)",
            tokenCountText: "\(summary.tokenCount)",
            typeCountText: "\(summary.typeCount)",
            sentenceCountText: "\(summary.sentenceCount)",
            paragraphCountText: "\(summary.paragraphCount)",
            characterCountText: "\(summary.characterCount)",
            ttrText: String(format: "%.4f", summary.ttr),
            sttrText: summary.sttr > 0 ? String(format: "%.4f", summary.sttr) : "—",
            representedPath: summary.representedPath,
            cleaningStatusTitle: summary.cleaningStatus.title(in: languageMode),
            cleanedAtText: cleaningSummary?.cleanedAt.isEmpty == false
                ? cleaningSummary?.cleanedAt ?? "—"
                : "—",
            originalCharacterCountText: cleaningSummary.map { "\($0.originalCharacterCount)" } ?? "—",
            cleanedCharacterCountText: cleaningSummary.map { "\($0.cleanedCharacterCount)" } ?? "—",
            cleaningRuleHitsText: cleaningSummary?.ruleHitsSummary(in: languageMode)
                ?? wordZText("尚未执行自动清洗", "Auto-cleaning not run yet", mode: languageMode)
        )
    }

    private func makeCorpusInfoReadiness(
        _ summary: CorpusInfoSummary,
        languageMode: AppLanguageMode
    ) -> LibraryCorpusReadinessSceneModel {
        let corpus = LibraryCorpusItem(json: [
            "id": summary.corpusId,
            "name": summary.title,
            "folderId": "",
            "folderName": summary.folderName,
            "sourceType": summary.sourceType,
            "representedPath": summary.representedPath,
            "storageFileName": summary.storageFileName,
            "metadata": summary.metadata.jsonObject,
            "cleaningStatus": summary.cleaningStatus.rawValue,
            "cleaningSummary": (summary.cleaningSummary ?? .pending).jsonObject
        ])
        return makeReadinessScene(for: corpus, languageMode: languageMode)
    }

    private func corpusInfoDatabaseFileName(_ summary: CorpusInfoSummary) -> String {
        let storedName = summary.storageFileName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !storedName.isEmpty {
            return storedName
        }
        let title = summary.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return "corpus.db" }
        return title.lowercased().hasSuffix(".db") ? title : "\(title).db"
    }

    func aggregateCleaningHitsSummary(
        _ summaries: [LibraryCorpusCleaningReportSummary],
        languageMode: AppLanguageMode
    ) -> String {
        let merged = summaries
            .flatMap(\.ruleHits)
            .reduce(into: [String: Int]()) { partialResult, hit in
                partialResult[hit.id, default: 0] += hit.count
            }

        guard !merged.isEmpty else {
            return wordZText("无", "None", mode: languageMode)
        }

        return merged.keys.sorted().prefix(3).map { key in
            let hit = LibraryCorpusCleaningRuleHit(id: key, count: merged[key] ?? 0)
            return "\(hit.title(in: languageMode)) \(hit.count)"
        }
        .joined(separator: " · ")
    }
}
