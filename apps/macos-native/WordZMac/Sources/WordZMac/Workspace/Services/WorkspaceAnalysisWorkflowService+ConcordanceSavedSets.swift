import Foundation

@MainActor
extension WorkspaceAnalysisWorkflowService {
    func refreshConcordanceSavedSets(features: WorkspaceFeatureSet) async {
        do {
            let sets = try await repository.listConcordanceSavedSets()
            applyConcordanceSavedSets(sets, features: features)
            features.sidebar.clearError()
        } catch {
            features.sidebar.setError(error.localizedDescription)
        }
    }

    func importConcordanceSavedSetsJSON(
        features: WorkspaceFeatureSet,
        preferredRoute: NativeWindowRoute? = nil
    ) async {
        guard let path = await dialogService.chooseOpenPath(
            title: wordZText("导入命中集 JSON", "Import Hit Set JSON", mode: .system),
            message: wordZText("选择通过 KWIC 或 Locator 导出的命中集 JSON 文件。", "Choose a JSON file exported from KWIC or Locator hit sets.", mode: .system),
            allowedExtensions: ["json"],
            preferredRoute: preferredRoute
        ) else {
            return
        }

        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            let existingSets = try await repository.listConcordanceSavedSets()
            let importedSets = try ConcordanceSavedSetTransferSupport.importedSets(from: data, existingSets: existingSets)
            guard !importedSets.isEmpty else {
                features.sidebar.setError(wordZText("JSON 中没有可导入的命中集。", "There are no hit sets to import from this JSON file.", mode: .system))
                return
            }
            for set in importedSets {
                _ = try await repository.saveConcordanceSavedSet(set)
            }
            let refreshedSets = try await repository.listConcordanceSavedSets()
            applyConcordanceSavedSets(refreshedSets, features: features)
            features.library.setStatus(
                String(
                    format: wordZText(
                        "已导入 %d 份命中集。",
                        "Imported %d hit sets.",
                        mode: .system
                    ),
                    importedSets.count
                )
            )
            features.sidebar.clearError()
        } catch {
            features.sidebar.setError(error.localizedDescription)
        }
    }

    func saveKWICConcordanceSavedSet(
        scope: ConcordanceSavedSetScope,
        features: WorkspaceFeatureSet,
        preferredRoute: NativeWindowRoute? = nil
    ) async {
        guard let scene = features.kwic.scene else {
            features.sidebar.setError(wordZText("当前没有可保存的 KWIC 结果。", "There are no KWIC results to save yet.", mode: .system))
            return
        }
        let rows = kwicRows(for: scope, features: features)
        guard !rows.isEmpty else {
            features.sidebar.setError(wordZText("当前没有可保存的 KWIC 命中行。", "There are no KWIC hit rows available to save.", mode: .system))
            return
        }
        guard let corpus = currentOpenedScopeCorpus(features: features) else {
            features.sidebar.setError(wordZText("当前 KWIC 没有关联语料。", "The current KWIC result is not attached to a corpus.", mode: .system))
            return
        }

        let defaultName = defaultKWICSavedSetName(query: scene.query, scope: scope)
        guard let name = await dialogService.promptText(
            title: wordZText("保存命中集", "Save Hit Set", mode: .system),
            message: wordZText("为当前 KWIC 命中结果输入一个名称。", "Enter a name for the current KWIC hit result.", mode: .system),
            defaultValue: defaultName,
            confirmTitle: wordZText("保存", "Save", mode: .system),
            preferredRoute: preferredRoute
        ) else {
            return
        }

        let timestamp = ISO8601DateFormatter().string(from: Date())
        let set = ConcordanceSavedSet(
            id: UUID().uuidString,
            name: name,
            kind: .kwic,
            corpusID: corpus.id,
            corpusName: corpus.name,
            query: scene.query,
            sourceSentenceId: nil,
            leftWindow: scene.leftWindow,
            rightWindow: scene.rightWindow,
            searchOptions: scene.searchOptions,
            stopwordFilter: scene.stopwordFilter,
            createdAt: timestamp,
            updatedAt: timestamp,
            rows: rows
        )

        await saveConcordanceSavedSet(
            set,
            successMessage: wordZText("已保存 KWIC 命中集。", "Saved KWIC hit set.", mode: .system),
            features: features
        )
    }

    func saveLocatorConcordanceSavedSet(
        scope: ConcordanceSavedSetScope,
        features: WorkspaceFeatureSet,
        preferredRoute: NativeWindowRoute? = nil
    ) async {
        guard let scene = features.locator.scene else {
            features.sidebar.setError(wordZText("当前没有可保存的 Locator 结果。", "There are no Locator results to save yet.", mode: .system))
            return
        }
        let rows = locatorRows(for: scope, features: features)
        guard !rows.isEmpty else {
            features.sidebar.setError(wordZText("当前没有可保存的 Locator 命中行。", "There are no Locator hit rows available to save.", mode: .system))
            return
        }
        guard let corpus = currentOpenedScopeCorpus(features: features) else {
            features.sidebar.setError(wordZText("当前 Locator 没有关联语料。", "The current Locator result is not attached to a corpus.", mode: .system))
            return
        }

        let defaultName = defaultLocatorSavedSetName(query: scene.source.keyword, scope: scope)
        guard let name = await dialogService.promptText(
            title: wordZText("保存命中集", "Save Hit Set", mode: .system),
            message: wordZText("为当前 Locator 命中结果输入一个名称。", "Enter a name for the current Locator hit result.", mode: .system),
            defaultValue: defaultName,
            confirmTitle: wordZText("保存", "Save", mode: .system),
            preferredRoute: preferredRoute
        ) else {
            return
        }

        let timestamp = ISO8601DateFormatter().string(from: Date())
        let set = ConcordanceSavedSet(
            id: UUID().uuidString,
            name: name,
            kind: .locator,
            corpusID: corpus.id,
            corpusName: corpus.name,
            query: scene.source.keyword,
            sourceSentenceId: scene.source.sentenceId,
            leftWindow: scene.leftWindow,
            rightWindow: scene.rightWindow,
            searchOptions: nil,
            stopwordFilter: nil,
            createdAt: timestamp,
            updatedAt: timestamp,
            rows: rows
        )

        await saveConcordanceSavedSet(
            set,
            successMessage: wordZText("已保存 Locator 命中集。", "Saved Locator hit set.", mode: .system),
            features: features
        )
    }

    func deleteConcordanceSavedSet(
        setID: String,
        features: WorkspaceFeatureSet
    ) async {
        let selectedSet = (features.kwic.savedSets + features.locator.savedSets)
            .first { $0.id == setID }
        let setName = selectedSet?.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedSetName: String
        if let setName, !setName.isEmpty {
            resolvedSetName = setName
        } else {
            resolvedSetName = wordZText("该命中集", "this hit set", mode: .system)
        }
        let confirmed = await dialogService.confirm(
            title: wordZText("删除命中集", "Delete Hit Set", mode: .system),
            message: wordZText(
                "确定要删除「\(resolvedSetName)」吗？此操作无法撤销。",
                "Delete \"\(resolvedSetName)\"? This cannot be undone.",
                mode: .system
            ),
            confirmTitle: wordZText("删除", "Delete", mode: .system),
            preferredRoute: .mainWorkspace
        )
        guard confirmed else { return }

        do {
            try await repository.deleteConcordanceSavedSet(setID: setID)
            let sets = try await repository.listConcordanceSavedSets()
            applyConcordanceSavedSets(sets, features: features)
            features.library.setStatus(wordZText("已删除命中集。", "Deleted hit set.", mode: .system))
            features.sidebar.clearError()
        } catch {
            features.sidebar.setError(error.localizedDescription)
        }
    }

    func saveRefinedConcordanceSavedSet(
        kind: ConcordanceSavedSetKind,
        features: WorkspaceFeatureSet,
        preferredRoute: NativeWindowRoute? = nil
    ) async {
        guard let selectedSet = selectedConcordanceSavedSet(kind: kind, features: features) else {
            features.sidebar.setError(wordZText("请先选择一份已保存命中集。", "Choose a saved hit set first.", mode: .system))
            return
        }
        let filteredRows = refinedConcordanceSavedSetRows(kind: kind, features: features)
        guard !filteredRows.isEmpty else {
            features.sidebar.setError(wordZText("当前筛选没有可保存的命中行。", "The current refinement does not contain any rows to save.", mode: .system))
            return
        }

        let defaultName = defaultRefinedSavedSetName(baseName: selectedSet.name)
        guard let name = await dialogService.promptText(
            title: wordZText("保存精炼命中集", "Save Refined Hit Set", mode: .system),
            message: wordZText("为当前筛选后的命中结果输入一个名称。", "Enter a name for the refined hit set.", mode: .system),
            defaultValue: defaultName,
            confirmTitle: wordZText("保存", "Save", mode: .system),
            preferredRoute: preferredRoute
        ) else {
            return
        }

        let timestamp = ISO8601DateFormatter().string(from: Date())
        let set = ConcordanceSavedSet(
            id: UUID().uuidString,
            name: name,
            kind: selectedSet.kind,
            corpusID: selectedSet.corpusID,
            corpusName: selectedSet.corpusName,
            query: selectedSet.query,
            sourceSentenceId: selectedSet.sourceSentenceId,
            leftWindow: selectedSet.leftWindow,
            rightWindow: selectedSet.rightWindow,
            searchOptions: selectedSet.searchOptions,
            stopwordFilter: selectedSet.stopwordFilter,
            createdAt: timestamp,
            updatedAt: timestamp,
            notes: normalizedSavedSetNotes(currentSavedSetNotesDraft(kind: kind, features: features)),
            rows: filteredRows
        )

        await saveConcordanceSavedSet(
            set,
            successMessage: wordZText("已保存精炼命中集。", "Saved refined hit set.", mode: .system),
            features: features
        )
    }

    func saveSelectedConcordanceSavedSetNotes(
        kind: ConcordanceSavedSetKind,
        features: WorkspaceFeatureSet
    ) async {
        guard let selectedSet = selectedConcordanceSavedSet(kind: kind, features: features) else {
            features.sidebar.setError(wordZText("请先选择一份已保存命中集。", "Choose a saved hit set first.", mode: .system))
            return
        }

        let nextNotes = normalizedSavedSetNotes(currentSavedSetNotesDraft(kind: kind, features: features))
        if normalizedSavedSetNotes(selectedSet.notes) == nextNotes {
            features.library.setStatus(wordZText("命中集备注没有变化。", "The hit set notes are already up to date.", mode: .system))
            features.sidebar.clearError()
            return
        }

        var updatedSet = selectedSet
        updatedSet.notes = nextNotes
        await saveConcordanceSavedSet(
            updatedSet,
            successMessage: wordZText("已保存命中集备注。", "Saved hit set notes.", mode: .system),
            features: features
        )
    }

    func exportSelectedConcordanceSavedSetJSON(
        kind: ConcordanceSavedSetKind,
        features: WorkspaceFeatureSet,
        preferredRoute: NativeWindowRoute? = nil
    ) async {
        let selectedSet: ConcordanceSavedSet?
        switch kind {
        case .kwic:
            selectedSet = features.kwic.selectedSavedSet
        case .locator:
            selectedSet = features.locator.selectedSavedSet
        }
        guard let selectedSet else {
            features.sidebar.setError(wordZText("请先选择一份已保存命中集。", "Choose a saved hit set first.", mode: .system))
            return
        }

        let suggestedName = "\(slug(selectedSet.name, fallback: kind.rawValue))-hit-set.json"
        guard let path = await dialogService.chooseSavePath(
            title: wordZText("导出命中集 JSON", "Export Hit Set JSON", mode: .system),
            suggestedName: suggestedName,
            allowedExtension: "json",
            preferredRoute: preferredRoute
        ) else {
            return
        }

        do {
            let data = try ConcordanceSavedSetTransferSupport.exportData(sets: [selectedSet])
            try data.write(to: URL(fileURLWithPath: path), options: .atomic)
            features.library.setStatus(
                l10nFormat(
                    "已导出命中集“%@”。",
                    table: "Errors",
                    mode: .system,
                    fallback: "Exported hit set \"%@\".",
                    selectedSet.name
                )
            )
            features.sidebar.clearError()
        } catch {
            features.sidebar.setError(error.localizedDescription)
        }
    }

    func loadSelectedConcordanceSavedSet(
        kind: ConcordanceSavedSetKind,
        features: WorkspaceFeatureSet,
        prepareCorpusSelectionChange: @escaping @MainActor (WorkspaceFeatureSet) -> Void,
        markWorkspaceEdited: @escaping @MainActor (WorkspaceFeatureSet) -> Void,
        syncFeatureContexts: @escaping @MainActor (WorkspaceFeatureSet) -> Void
    ) async {
        let selectedSet = selectedConcordanceSavedSet(kind: kind, features: features)
        guard let selectedSet else {
            features.sidebar.setError(wordZText("请先选择一份已保存命中集。", "Choose a saved hit set first.", mode: .system))
            return
        }
        let refinedRows = refinedConcordanceSavedSetRows(kind: kind, features: features)
        guard !refinedRows.isEmpty else {
            features.sidebar.setError(wordZText("当前筛选没有可载入的命中行。", "The current refinement does not contain any rows to load.", mode: .system))
            return
        }

        guard features.sidebar.librarySnapshot.corpora.contains(where: { $0.id == selectedSet.corpusID }) else {
            features.sidebar.setError(
                l10nFormat(
                    "命中集“%@”关联的语料已不存在，无法载入。",
                    table: "Errors",
                    mode: .system,
                    fallback: "The corpus linked to hit set \"%@\" is no longer available.",
                    selectedSet.name
                )
            )
            return
        }

        do {
            try await prepareConcordanceSavedSetCorpusSelection(
                selectedSet.corpusID,
                features: features,
                prepareCorpusSelectionChange: prepareCorpusSelectionChange,
                syncFeatureContexts: syncFeatureContexts
            )
            let effectiveSet = savedSet(selectedSet, replacingRows: refinedRows)
            switch kind {
            case .kwic:
                applyKWICSavedSet(effectiveSet, features: features)
            case .locator:
                applyLocatorSavedSet(effectiveSet, features: features)
            }
            features.library.setStatus(
                String(
                    format: wordZText(
                        "已载入命中集“%@”的 %d 行结果。",
                        "Loaded %2$d rows from hit set \"%1$@\".",
                        mode: .system
                    ),
                    selectedSet.name,
                    refinedRows.count
                )
            )
            features.sidebar.clearError()
            markWorkspaceEdited(features)
        } catch {
            features.sidebar.setError(error.localizedDescription)
        }
    }

    private func saveConcordanceSavedSet(
        _ set: ConcordanceSavedSet,
        successMessage: String,
        features: WorkspaceFeatureSet
    ) async {
        do {
            _ = try await repository.saveConcordanceSavedSet(set)
            let sets = try await repository.listConcordanceSavedSets()
            applyConcordanceSavedSets(sets, features: features)
            features.library.setStatus(successMessage)
            features.sidebar.clearError()
        } catch {
            features.sidebar.setError(error.localizedDescription)
        }
    }

    private func applyConcordanceSavedSets(_ sets: [ConcordanceSavedSet], features: WorkspaceFeatureSet) {
        features.kwic.applySavedSets(sets.filter { $0.kind == .kwic })
        features.locator.applySavedSets(sets.filter { $0.kind == .locator })
    }

    private func selectedConcordanceSavedSet(
        kind: ConcordanceSavedSetKind,
        features: WorkspaceFeatureSet
    ) -> ConcordanceSavedSet? {
        switch kind {
        case .kwic:
            return features.kwic.selectedSavedSet
        case .locator:
            return features.locator.selectedSavedSet
        }
    }

    private func refinedConcordanceSavedSetRows(
        kind: ConcordanceSavedSetKind,
        features: WorkspaceFeatureSet
    ) -> [ConcordanceSavedSetRow] {
        switch kind {
        case .kwic:
            return features.kwic.filteredSelectedSavedSetRows
        case .locator:
            return features.locator.filteredSelectedSavedSetRows
        }
    }

    private func currentSavedSetNotesDraft(
        kind: ConcordanceSavedSetKind,
        features: WorkspaceFeatureSet
    ) -> String? {
        switch kind {
        case .kwic:
            return features.kwic.savedSetNotesDraft
        case .locator:
            return features.locator.savedSetNotesDraft
        }
    }

    private func applyKWICSavedSet(_ set: ConcordanceSavedSet, features: WorkspaceFeatureSet) {
        let keyword = resolvedSavedSetKeyword(set)
        let result = KWICResult(
            rows: set.rows.map { row in
                KWICRow(
                    id: row.id,
                    left: row.leftContext,
                    node: row.keyword,
                    right: row.rightContext,
                    sentenceId: row.sentenceId,
                    sentenceTokenIndex: row.sentenceTokenIndex ?? 0
                )
            }
        )

        features.kwic.applyStateChange(rebuildScene: features.kwic.rebuildScene) {
            features.kwic.keyword = keyword
            features.kwic.leftWindow = "\(set.leftWindow)"
            features.kwic.rightWindow = "\(set.rightWindow)"
            features.kwic.searchOptions = set.searchOptions ?? .default
            features.kwic.stopwordFilter = set.stopwordFilter ?? .default
            features.kwic.result = result
            features.kwic.loadedSavedSetID = set.id
            features.kwic.currentPage = 1
            features.kwic.selectedRowID = result.rows.first?.id
            features.kwic.selectedSavedSetID = set.id
            features.kwic.invalidateCaches()
        }

        if let firstRow = result.rows.first {
            let locatorKeyword = firstRow.node.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? keyword : firstRow.node
            features.locator.updateSource(
                LocatorSource(
                    keyword: locatorKeyword,
                    sentenceId: firstRow.sentenceId,
                    nodeIndex: firstRow.sentenceTokenIndex
                )
            )
        } else {
            features.locator.updateSource(nil)
        }
        features.shell.setSelectedTab(.kwic, notifyTabChange: false)
    }

    private func applyLocatorSavedSet(_ set: ConcordanceSavedSet, features: WorkspaceFeatureSet) {
        let sourceRow = preferredLocatorSourceRow(in: set)
        let keyword = resolvedSavedSetKeyword(set, fallback: sourceRow?.keyword ?? "")
        let source = LocatorSource(
            keyword: keyword,
            sentenceId: sourceRow?.sentenceId ?? set.sourceSentenceId ?? 0,
            nodeIndex: sourceRow?.sentenceTokenIndex ?? 0
        )
        let result = LocatorResult(
            sentenceCount: max(Set(set.rows.map(\.sentenceId)).count, set.rows.count),
            rows: set.rows.map { row in
                LocatorRow(
                    sentenceId: row.sentenceId,
                    text: row.fullSentenceText,
                    leftWords: row.leftContext,
                    nodeWord: row.keyword,
                    rightWords: row.rightContext,
                    status: row.status
                )
            }
        )

        features.locator.leftWindow = "\(set.leftWindow)"
        features.locator.rightWindow = "\(set.rightWindow)"
        features.locator.apply(result, source: source, loadedSavedSetID: set.id)
        features.locator.selectedRowID = sourceRow.map { String($0.sentenceId) } ?? result.rows.first.map { String($0.sentenceId) }
        features.locator.selectedSavedSetID = set.id
        features.shell.setSelectedTab(.locator, notifyTabChange: false)
    }

    private func kwicRows(
        for scope: ConcordanceSavedSetScope,
        features: WorkspaceFeatureSet
    ) -> [ConcordanceSavedSetRow] {
        let sceneRows: [KWICSceneRow]
        switch scope {
        case .current:
            sceneRows = features.kwic.selectedSceneRow.map { [$0] } ?? []
        case .visible:
            sceneRows = features.kwic.scene?.rows ?? []
        }
        return sceneRows.map {
            ConcordanceSavedSetRow(
                id: $0.id,
                sentenceId: $0.sentenceId,
                sentenceTokenIndex: $0.sentenceTokenIndex,
                status: "",
                leftContext: $0.leftContext,
                keyword: $0.keyword,
                rightContext: $0.rightContext,
                concordanceText: $0.concordanceText,
                citationText: $0.citationText,
                fullSentenceText: joinedSentence(
                    left: $0.leftContext,
                    keyword: $0.keyword,
                    right: $0.rightContext
                )
            )
        }
    }

    private func locatorRows(
        for scope: ConcordanceSavedSetScope,
        features: WorkspaceFeatureSet
    ) -> [ConcordanceSavedSetRow] {
        let sceneRows: [LocatorSceneRow]
        switch scope {
        case .current:
            sceneRows = features.locator.selectedSceneRow.map { [$0] } ?? []
        case .visible:
            sceneRows = features.locator.scene?.rows ?? []
        }
        return sceneRows.map {
            ConcordanceSavedSetRow(
                id: $0.id,
                sentenceId: $0.sentenceId,
                sentenceTokenIndex: $0.sourceCandidate.nodeIndex,
                status: $0.status,
                leftContext: $0.leftWords,
                keyword: $0.nodeWord,
                rightContext: $0.rightWords,
                concordanceText: $0.concordanceText,
                citationText: $0.citationText,
                fullSentenceText: $0.text
            )
        }
    }

    private func currentOpenedScopeCorpus(features: WorkspaceFeatureSet) -> LibraryCorpusItem? {
        let corpusID = features.sidebar.selectedCorpusID ?? sessionStore.openedCorpusSourceID
        guard let corpusID else { return nil }
        return features.sidebar.librarySnapshot.corpora.first(where: { $0.id == corpusID })
    }

    private func prepareConcordanceSavedSetCorpusSelection(
        _ corpusID: String,
        features: WorkspaceFeatureSet,
        prepareCorpusSelectionChange: @escaping @MainActor (WorkspaceFeatureSet) -> Void,
        syncFeatureContexts: @escaping @MainActor (WorkspaceFeatureSet) -> Void
    ) async throws {
        try await prepareDrilldownCorpusSelection(
            corpusID,
            features: features,
            prepareCorpusSelectionChange: prepareCorpusSelectionChange,
            syncFeatureContexts: syncFeatureContexts
        )
    }

    private func defaultKWICSavedSetName(query: String, scope: ConcordanceSavedSetScope) -> String {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let suffix = scope == .current
            ? wordZText("当前行", "Current Row", mode: .system)
            : wordZText("当前页", "Visible Rows", mode: .system)
        if trimmedQuery.isEmpty {
            return wordZText("KWIC 命中集", "KWIC Hit Set", mode: .system) + " · " + suffix
        }
        return trimmedQuery + " · " + suffix
    }

    private func defaultLocatorSavedSetName(query: String, scope: ConcordanceSavedSetScope) -> String {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let suffix = scope == .current
            ? wordZText("当前句", "Current Sentence", mode: .system)
            : wordZText("当前页", "Visible Rows", mode: .system)
        if trimmedQuery.isEmpty {
            return wordZText("Locator 命中集", "Locator Hit Set", mode: .system) + " · " + suffix
        }
        return trimmedQuery + " · " + suffix
    }

    private func joinedSentence(left: String, keyword: String, right: String) -> String {
        [left, keyword, right]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func preferredLocatorSourceRow(in set: ConcordanceSavedSet) -> ConcordanceSavedSetRow? {
        if let sourceSentenceId = set.sourceSentenceId,
           let matchingRow = set.rows.first(where: { $0.sentenceId == sourceSentenceId }) {
            return matchingRow
        }
        return set.rows.first
    }

    private func savedSet(
        _ set: ConcordanceSavedSet,
        replacingRows rows: [ConcordanceSavedSetRow]
    ) -> ConcordanceSavedSet {
        ConcordanceSavedSet(
            id: set.id,
            name: set.name,
            kind: set.kind,
            corpusID: set.corpusID,
            corpusName: set.corpusName,
            query: set.query,
            sourceSentenceId: set.sourceSentenceId,
            leftWindow: set.leftWindow,
            rightWindow: set.rightWindow,
            searchOptions: set.searchOptions,
            stopwordFilter: set.stopwordFilter,
            createdAt: set.createdAt,
            updatedAt: set.updatedAt,
            notes: set.notes,
            rows: rows
        )
    }

    private func resolvedSavedSetKeyword(
        _ set: ConcordanceSavedSet,
        fallback: String = ""
    ) -> String {
        let trimmedQuery = set.query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedQuery.isEmpty {
            return trimmedQuery
        }
        let trimmedFallback = fallback.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedFallback.isEmpty {
            return trimmedFallback
        }
        return set.rows.first?.keyword.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func defaultRefinedSavedSetName(baseName: String) -> String {
        let trimmedBaseName = baseName.trimmingCharacters(in: .whitespacesAndNewlines)
        let suffix = wordZText("精炼", "Refined", mode: .system)
        if trimmedBaseName.isEmpty {
            return wordZText("命中集", "Hit Set", mode: .system) + " · " + suffix
        }
        return trimmedBaseName + " · " + suffix
    }

    private func normalizedSavedSetNotes(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func slug(_ value: String, fallback: String) -> String {
        let normalized = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "/", with: "-")
        return normalized.isEmpty ? fallback : normalized
    }
}
