import Foundation

@MainActor
extension WorkspaceAnalysisWorkflowService {
    func runSourceAwareKWIC(
        features: WorkspaceFeatureSet,
        keyword: String,
        leftWindow: Int,
        rightWindow: Int,
        searchOptions: SearchOptionsState,
        ensureOpenedCorpus: () async throws -> OpenedCorpus
    ) async throws -> KWICResult {
        let openedCorpus = try await ensureOpenedCorpus()
        if let corpusSet = features.sidebar.selectedCorpusSet {
            return try await runKWICForCorpusSet(
                corpusSet,
                keyword: keyword,
                leftWindow: leftWindow,
                rightWindow: rightWindow,
                searchOptions: searchOptions,
                librarySnapshot: features.sidebar.librarySnapshot,
                fallbackOpenedCorpus: openedCorpus
            )
        }

        let result = try await repository.runKWIC(
            text: openedCorpus.content,
            keyword: keyword,
            leftWindow: leftWindow,
            rightWindow: rightWindow,
            searchOptions: searchOptions
        )
        guard let corpus = selectedSingleKWICCorpus(features: features) else {
            return result
        }
        let info = try? await repository.loadCorpusInfo(corpusId: corpus.id)
        let context = kwicSourceContext(
            for: corpus,
            openedCorpus: openedCorpus,
            info: info,
            sourceIndex: 1
        )
        return KWICResult(rows: result.rows.map {
            $0.withSourceContext(context, globalSentenceOffset: 0, preservingRowID: true)
        })
    }

    private func runKWICForCorpusSet(
        _ corpusSet: LibraryCorpusSetItem,
        keyword: String,
        leftWindow: Int,
        rightWindow: Int,
        searchOptions: SearchOptionsState,
        librarySnapshot: LibrarySnapshot,
        fallbackOpenedCorpus: OpenedCorpus
    ) async throws -> KWICResult {
        let corporaByID = Dictionary(uniqueKeysWithValues: librarySnapshot.corpora.map { ($0.id, $0) })
        let members = corpusSet.corpusIDs.compactMap { corporaByID[$0] }
        guard !members.isEmpty else {
            return try await repository.runKWIC(
                text: fallbackOpenedCorpus.content,
                keyword: keyword,
                leftWindow: leftWindow,
                rightWindow: rightWindow,
                searchOptions: searchOptions
            )
        }

        var mergedRows: [KWICRow] = []
        var sentenceOffset = 0
        for (index, corpus) in members.enumerated() {
            let openedMember = try await repository.openSavedCorpus(corpusId: corpus.id)
            let info = try? await repository.loadCorpusInfo(corpusId: corpus.id)
            let memberResult = try await repository.runKWIC(
                text: openedMember.content,
                keyword: keyword,
                leftWindow: leftWindow,
                rightWindow: rightWindow,
                searchOptions: searchOptions
            )
            let context = kwicSourceContext(
                for: corpus,
                openedCorpus: openedMember,
                info: info,
                sourceIndex: index + 1
            )
            mergedRows.append(contentsOf: memberResult.rows.map {
                $0.withSourceContext(context, globalSentenceOffset: sentenceOffset)
            })
            sentenceOffset += await resolvedKWICSentenceCount(
                info: info,
                text: openedMember.content,
                result: memberResult
            )
        }
        return KWICResult(rows: mergedRows)
    }

    private func selectedSingleKWICCorpus(features: WorkspaceFeatureSet) -> LibraryCorpusItem? {
        let corpusID = features.sidebar.selectedCorpusID ?? sessionStore.openedCorpusSourceID
        guard let corpusID else {
            return features.sidebar.selectedCorpus
        }
        return features.sidebar.librarySnapshot.corpora.first(where: { $0.id == corpusID })
            ?? features.sidebar.selectedCorpus
    }

    private func kwicSourceContext(
        for corpus: LibraryCorpusItem,
        openedCorpus: OpenedCorpus,
        info: CorpusInfoSummary?,
        sourceIndex: Int
    ) -> KWICSourceContext {
        let metadata = (info?.metadata ?? .empty).merged(over: corpus.metadata)
        let sourceFilePath = kwicNormalizedValue(info?.representedPath)
            ?? kwicNormalizedValue(corpus.representedPath)
            ?? kwicNormalizedValue(openedCorpus.filePath)
            ?? ""
        let fallbackName = kwicNormalizedValue(openedCorpus.displayName)
            ?? kwicNormalizedValue(corpus.name)
            ?? kwicNormalizedValue(corpus.storageFileName)
            ?? corpus.id
        let sourceFileName = kwicFileName(from: sourceFilePath, fallback: fallbackName)
        let sourceTitle = kwicNormalizedValue(corpus.name)
            ?? kwicNormalizedValue(info?.title)
            ?? fallbackName
        return KWICSourceContext(
            sourceID: corpus.id,
            sourceTitle: sourceTitle,
            sourceFilePath: sourceFilePath,
            sourceFileName: sourceFileName,
            sourceType: kwicNormalizedValue(info?.sourceType) ?? kwicNormalizedValue(openedCorpus.sourceType) ?? corpus.sourceType,
            sourceIndex: sourceIndex,
            metadata: metadata
        )
    }

    private func resolvedKWICSentenceCount(
        info: CorpusInfoSummary?,
        text: String,
        result: KWICResult
    ) async -> Int {
        let metadataSentenceCount = max(0, info?.sentenceCount ?? 0)
        let hitSentenceCount = (result.rows.map(\.sentenceId).max() ?? -1) + 1
        if metadataSentenceCount > 0 {
            return max(metadataSentenceCount, hitSentenceCount)
        }
        let statsSentenceCount = (try? await repository.runStats(text: text))?.sentenceCount ?? 0
        return max(statsSentenceCount, hitSentenceCount)
    }

    private func kwicFileName(from path: String, fallback: String) -> String {
        let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPath.isEmpty else { return fallback }
        if URL(string: trimmedPath)?.scheme == "wordz" {
            return fallback
        }
        let lastPathComponent = URL(fileURLWithPath: trimmedPath).lastPathComponent
        return lastPathComponent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? fallback
            : lastPathComponent
    }

    private func kwicNormalizedValue(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
