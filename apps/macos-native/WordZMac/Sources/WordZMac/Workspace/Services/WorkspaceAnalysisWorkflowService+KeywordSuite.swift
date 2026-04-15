import Foundation

@MainActor
extension WorkspaceAnalysisWorkflowService {
    func importKeywordReferenceWordList(
        features: WorkspaceFeatureSet,
        preferredRoute: NativeWindowRoute? = nil,
        markWorkspaceEdited: @escaping @MainActor (WorkspaceFeatureSet) -> Void
    ) async {
        guard let path = await dialogService.chooseOpenPath(
            title: wordZText("导入 Reference 词表", "Import Reference Word List", mode: .system),
            message: wordZText(
                "选择 TXT 或 TSV 词表文件。支持每行一个词项，或 term<TAB>freq。",
                "Choose a TXT or TSV word list. Supports one term per line, or term<TAB>freq.",
                mode: .system
            ),
            allowedExtensions: ["txt", "tsv", "text"],
            preferredRoute: preferredRoute
        ) else {
            return
        }

        do {
            let document = try TextFileDecodingSupport.readImportedTextDocument(at: URL(fileURLWithPath: path))
            let parseResult = KeywordSuiteAnalyzer.parseImportedReference(document.text)
            let importedAt = ISO8601DateFormatter().string(from: Date())
            features.keyword.applyImportedReferenceList(
                text: document.text,
                sourceName: URL(fileURLWithPath: path).lastPathComponent,
                importedAt: importedAt
            )
            markWorkspaceEdited(features)

            if parseResult.hasAcceptedItems {
                features.library.setStatus(
                    String(
                        format: wordZText(
                            "已导入 Reference 词表：%d 项，接受 %d 行，拒绝 %d 行。",
                            "Imported reference word list: %d items, %d accepted lines, %d rejected lines.",
                            mode: .system
                        ),
                        parseResult.acceptedItemCount,
                        parseResult.acceptedLineCount,
                        parseResult.rejectedLineCount
                    )
                )
                features.sidebar.clearError()
            } else {
                features.sidebar.setError(
                    wordZText(
                        "导入完成，但当前词表没有可用词项。请检查空行或频次列。",
                        "Import completed, but the word list has no usable items. Check blank lines and frequency values.",
                        mode: .system
                    )
                )
            }
        } catch {
            features.sidebar.setError(error.localizedDescription)
        }
    }

    func refreshKeywordSavedLists(features: WorkspaceFeatureSet) async {
        do {
            let lists = try await repository.listKeywordSavedLists()
            features.keyword.applySavedLists(lists)
            features.sidebar.clearError()
        } catch {
            features.sidebar.setError(error.localizedDescription)
        }
    }

    func saveKeywordCurrentList(features: WorkspaceFeatureSet) async {
        guard let result = features.keyword.result,
              let group = features.keyword.currentResultGroup
        else {
            features.sidebar.setError("当前没有可保存的关键词结果。")
            return
        }
        let rows = features.keyword.currentKeywordRows
        guard !rows.isEmpty else {
            features.sidebar.setError("当前页签没有可保存的结果行。")
            return
        }
        let name = features.keyword.savedListName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            features.sidebar.setError("请先输入要保存的词表名称。")
            return
        }

        let timestamp = ISO8601DateFormatter().string(from: Date())
        let list = KeywordSavedList(
            id: UUID().uuidString,
            name: name,
            group: group,
            createdAt: timestamp,
            updatedAt: timestamp,
            focusLabel: result.focusSummary.label,
            referenceLabel: result.referenceSummary.label,
            configuration: result.configuration,
            rows: rows
        )

        do {
            _ = try await repository.saveKeywordSavedList(list)
            let lists = try await repository.listKeywordSavedLists()
            features.keyword.savedListName = ""
            features.keyword.applySavedLists(lists)
            features.library.setStatus(wordZText("已保存关键词词表。", "Saved keyword list.", mode: .system))
            features.sidebar.clearError()
        } catch {
            features.sidebar.setError(error.localizedDescription)
        }
    }

    func deleteKeywordSavedList(listID: String, features: WorkspaceFeatureSet) async {
        do {
            try await repository.deleteKeywordSavedList(listID: listID)
            let lists = try await repository.listKeywordSavedLists()
            features.keyword.applySavedLists(lists)
            features.library.setStatus(wordZText("已删除关键词词表。", "Deleted keyword list.", mode: .system))
            features.sidebar.clearError()
        } catch {
            features.sidebar.setError(error.localizedDescription)
        }
    }

    func importKeywordSavedListsJSON(
        features: WorkspaceFeatureSet,
        preferredRoute: NativeWindowRoute? = nil
    ) async {
        guard let path = await dialogService.chooseOpenPath(
            title: wordZText("导入关键词词表 JSON", "Import Keyword Lists JSON", mode: .system),
            message: wordZText("选择通过 Keyword Suite 导出的 JSON 词表文件。", "Choose a JSON file exported from Keyword Suite.", mode: .system),
            allowedExtensions: ["json"],
            preferredRoute: preferredRoute
        ) else {
            return
        }

        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            let existingLists = try await repository.listKeywordSavedLists()
            let importedLists = try KeywordSavedListTransferSupport.importedLists(from: data, existingLists: existingLists)
            for list in importedLists {
                _ = try await repository.saveKeywordSavedList(list)
            }
            let refreshedLists = try await repository.listKeywordSavedLists()
            features.keyword.applySavedLists(refreshedLists)
            features.library.setStatus(
                String(
                    format: wordZText(
                        "已导入 %d 份关键词词表。",
                        "Imported %d keyword lists.",
                        mode: .system
                    ),
                    importedLists.count
                )
            )
            features.sidebar.clearError()
        } catch {
            features.sidebar.setError(error.localizedDescription)
        }
    }

    func exportKeywordSavedListsJSON(
        scope: KeywordSavedListExportScope,
        features: WorkspaceFeatureSet,
        preferredRoute: NativeWindowRoute? = nil
    ) async {
        let lists: [KeywordSavedList]
        let suggestedName: String
        switch scope {
        case .selected:
            guard let selectedList = features.keyword.selectedSavedList else {
                features.sidebar.setError("请先选择一份已保存词表。")
                return
            }
            lists = [selectedList]
            let slug = selectedList.name
                .lowercased()
                .replacingOccurrences(of: " ", with: "-")
                .replacingOccurrences(of: "/", with: "-")
            suggestedName = "\(slug.isEmpty ? "keyword-list" : slug).json"
        case .all:
            lists = features.keyword.savedLists
            suggestedName = "keyword-saved-lists.json"
        }

        guard !lists.isEmpty else {
            features.sidebar.setError("当前没有可导出的关键词词表。")
            return
        }

        guard let path = await dialogService.chooseSavePath(
            title: wordZText("导出关键词词表 JSON", "Export Keyword Lists JSON", mode: .system),
            suggestedName: suggestedName,
            allowedExtension: "json",
            preferredRoute: preferredRoute
        ) else {
            return
        }

        do {
            let data = try KeywordSavedListTransferSupport.exportData(lists: lists)
            try data.write(to: URL(fileURLWithPath: path), options: .atomic)
            features.library.setStatus(
                String(
                    format: wordZText(
                        "已导出 %d 份关键词词表到 %@",
                        "Exported %d keyword lists to %@",
                        mode: .system
                    ),
                    lists.count,
                    path
                )
            )
            features.sidebar.clearError()
        } catch {
            features.sidebar.setError(error.localizedDescription)
        }
    }

    func exportKeywordRowContext(
        features: WorkspaceFeatureSet,
        preferredRoute: NativeWindowRoute? = nil
    ) async {
        guard let scene = features.keyword.scene,
              let row = features.keyword.selectedKeywordRow,
              features.keyword.activeTab != .lists
        else {
            features.sidebar.setError("请先选择一条关键词结果。")
            return
        }

        await exportTextDocument(
            ReadingExportSupport.keywordRowContextDocument(row: row, scene: scene),
            title: wordZText("导出关键词上下文", "Export Keyword Row Context", mode: .system),
            successStatus: wordZText("已导出关键词上下文到", "Exported keyword row context to", mode: .system),
            features: features,
            preferredRoute: preferredRoute
        )
    }

    func prepareKeywordKWIC(
        scope: KeywordKWICScope,
        features: WorkspaceFeatureSet,
        prepareCorpusSelectionChange: @escaping @MainActor (WorkspaceFeatureSet) -> Void,
        markWorkspaceEdited: @escaping @MainActor (WorkspaceFeatureSet) -> Void,
        syncFeatureContexts: @escaping @MainActor (WorkspaceFeatureSet) -> Void
    ) async -> Bool {
        guard let row = features.keyword.selectedKeywordRow else {
            features.sidebar.setError("请先选择一条关键词结果。")
            return false
        }

        let corpusID: String?
        switch scope {
        case .focus:
            corpusID = row.focusExampleCorpusID ?? features.keyword.resolvedFocusCorpusItems().first?.id
        case .reference:
            corpusID = row.referenceExampleCorpusID ?? features.keyword.resolvedReferenceCorpusItems().first?.id
        }

        guard let corpusID,
              features.sidebar.librarySnapshot.corpora.contains(where: { $0.id == corpusID }) else {
            features.sidebar.setError("当前关键词行没有可用的 KWIC 语料范围。")
            return false
        }

        do {
            try await prepareDrilldownCorpusSelection(
                corpusID,
                features: features,
                prepareCorpusSelectionChange: prepareCorpusSelectionChange,
                syncFeatureContexts: syncFeatureContexts
            )
        } catch {
            features.sidebar.setError(error.localizedDescription)
            return false
        }

        features.kwic.keyword = row.item
        features.shell.selectedTab = .kwic
        markWorkspaceEdited(features)
        return true
    }
}
