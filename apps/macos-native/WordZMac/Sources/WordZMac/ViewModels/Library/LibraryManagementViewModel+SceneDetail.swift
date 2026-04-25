import Foundation

@MainActor
extension LibraryManagementViewModel {
    func buildInspector(
        visibleCorpora: [LibraryCorpusItem],
        corporaByFolderID: [String: [LibraryCorpusItem]],
        corporaByID: [String: LibraryCorpusItem]
    ) -> LibraryManagementInspectorSceneModel? {
        if let selectedCorpusSet {
            let resolvedCorpora = selectedCorpusSet.corpusIDs.compactMap { corporaByID[$0] }
            return LibraryManagementInspectorSceneModel(
                title: selectedCorpusSet.name,
                subtitle: "命名语料集",
                details: [
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
            let languageMode = WordZLocalization.shared.effectiveMode
            let missingYearCount = currentSelection.filter { $0.metadata.yearLabel.isEmpty }.count
            let missingGenreCount = currentSelection.filter { $0.metadata.genreLabel.isEmpty }.count
            let missingTagsCount = currentSelection.filter { $0.metadata.tags.isEmpty }.count
            return LibraryManagementInspectorSceneModel(
                title: "已选择 \(selectedCorpusIDs.count) 条语料",
                subtitle: "批量操作",
                details: [
                    .init(id: "batch-count", title: "选中数量", value: "\(selectedCorpusIDs.count)"),
                    .init(id: "batch-scope", title: "当前视图", value: currentScopeSummaryForInspector()),
                    .init(id: "batch-pending-cleaning", title: "待清洗", value: "\(currentSelection.filter { $0.cleaningStatus == .pending }.count)"),
                    .init(id: "batch-cleaning-changed", title: "清洗有变更", value: "\(currentSelection.filter { $0.cleaningStatus == .cleanedWithChanges }.count)"),
                    .init(
                        id: "batch-cleaning-hits",
                        title: "规则命中",
                        value: aggregateCleaningHitsSummary(
                            currentSelection.compactMap(\.cleaningSummary),
                            languageMode: languageMode
                        )
                    ),
                    .init(id: "missing-year", title: "缺年份", value: "\(missingYearCount)"),
                    .init(id: "missing-genre", title: "缺体裁", value: "\(missingGenreCount)"),
                    .init(id: "missing-tags", title: "缺标签", value: "\(missingTagsCount)")
                ],
                actions: [
                    .init(id: "batch-clean-metadata", title: "批量清洗所选语料", role: .primary, action: .cleanSelectedCorpora),
                    .init(id: "batch-edit-metadata", title: "批量编辑元数据", role: .primary, action: .editSelectedCorporaMetadata)
                ]
            )
        }

        if let selectedCorpus {
            let languageMode = WordZLocalization.shared.effectiveMode
            let cleaningSummary = selectedCorpus.cleaningSummary
            return LibraryManagementInspectorSceneModel(
                title: selectedCorpus.name,
                subtitle: "语料 · \(selectedCorpus.sourceType.uppercased())",
                details: [
                    .init(id: "folder", title: "文件夹", value: selectedCorpus.folderName),
                    .init(id: "source", title: "来源类型", value: selectedCorpus.sourceType),
                    .init(id: "source-label", title: "来源", value: selectedCorpus.metadata.sourceLabel.isEmpty ? "—" : selectedCorpus.metadata.sourceLabel),
                    .init(id: "year-label", title: "年份", value: selectedCorpus.metadata.yearLabel.isEmpty ? "—" : selectedCorpus.metadata.yearLabel),
                    .init(id: "genre-label", title: "体裁", value: selectedCorpus.metadata.genreLabel.isEmpty ? "—" : selectedCorpus.metadata.genreLabel),
                    .init(id: "tags", title: "标签", value: selectedCorpus.metadata.tagsText.isEmpty ? "—" : selectedCorpus.metadata.tagsText),
                    .init(id: "scope", title: "当前视图", value: currentScopeSummaryForInspector()),
                    .init(id: "clean-status", title: "自动清洗", value: selectedCorpus.cleaningStatus.title(in: languageMode)),
                    .init(id: "cleaned-at", title: "最近清洗", value: cleaningSummary?.cleanedAt.isEmpty == false ? cleaningSummary?.cleanedAt ?? "—" : "—"),
                    .init(
                        id: "clean-char-counts",
                        title: "字符变化",
                        value: cleaningSummary.map { "\($0.originalCharacterCount) -> \($0.cleanedCharacterCount)" } ?? "—"
                    ),
                    .init(
                        id: "clean-rule-hits",
                        title: "规则命中",
                        value: cleaningSummary?.ruleHitsSummary(in: languageMode) ?? "—"
                    )
                ],
                actions: [
                    .init(id: "open", title: "打开语料", role: .primary, action: .openSelectedCorpus),
                    .init(id: "clean-corpus", title: "重新清洗", role: .primary, action: .cleanSelectedCorpus),
                    .init(id: "preview", title: "快速预览", role: .normal, action: .quickLookSelectedCorpus),
                    .init(id: "share", title: "分享语料", role: .normal, action: .shareSelectedCorpus),
                    .init(id: "info", title: "语料信息", role: .normal, action: .showSelectedCorpusInfo),
                    .init(id: "edit-metadata", title: "编辑元数据", role: .normal, action: .editSelectedCorpusMetadata),
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
                details: [
                    .init(id: "folder-corpus-count", title: "语料数量", value: "\(folderCorpora.count)"),
                    .init(id: "visible-count", title: "当前视图", value: "\(visibleCorpora.count) 条语料"),
                    .init(id: "preserve-hierarchy", title: "导入保留层级", value: preserveHierarchy ? "开启" : "关闭")
                ],
                actions: [
                    .init(id: "import-folder", title: "导入到此文件夹", role: .primary, action: .importPaths),
                    .init(id: "rename-folder", title: "重命名文件夹", role: .normal, action: .renameSelectedFolder),
                    .init(id: "delete-folder", title: "删除文件夹", role: .destructive, action: .deleteSelectedFolder)
                ]
            )
        }

        return nil
    }

    func makeCorpusInfoScene(
        summary: CorpusInfoSummary,
        languageMode: AppLanguageMode = WordZLocalization.shared.effectiveMode
    ) -> LibraryCorpusInfoSceneModel {
        let cleaningSummary = summary.cleaningSummary
        return LibraryCorpusInfoSceneModel(
            id: summary.corpusId,
            title: summary.title,
            subtitle: wordZText("语料信息", "Corpus Info", mode: languageMode),
            folderName: summary.folderName,
            sourceType: summary.sourceType,
            sourceLabelText: summary.metadata.sourceLabel.isEmpty ? "—" : summary.metadata.sourceLabel,
            yearText: summary.metadata.yearLabel.isEmpty ? "—" : summary.metadata.yearLabel,
            genreText: summary.metadata.genreLabel.isEmpty ? "—" : summary.metadata.genreLabel,
            tagsText: summary.metadata.tagsText.isEmpty ? "—" : summary.metadata.tagsText,
            importedAtText: summary.importedAt.isEmpty ? "—" : summary.importedAt,
            encodingText: summary.detectedEncoding.isEmpty ? "—" : summary.detectedEncoding,
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
