import Foundation

@MainActor
extension MainWorkspaceViewModel {
    func openCurrentSourceReader() async -> Bool {
        guard let context = await currentSourceReaderLaunchContext() else {
            let message = t("当前页面没有可打开的原文定位。", "The current page does not have a source location to open.")
            settings.setSupportStatus(message)
            activeIssue = WorkspaceIssueBanner(
                tone: .warning,
                title: t("无法打开原文阅读器", "Unable to Open Source Reader"),
                message: message,
                recoveryAction: .refreshWorkspace
            )
            return false
        }

        do {
            try await sourceReader.load(context: context, repository: appCoordinator.repository)
            settings.setSupportStatus(t("已更新原文阅读器。", "Updated the source reader."))
            clearActiveIssue()
            return true
        } catch {
            presentIssue(error, titleZh: "无法打开原文阅读器", titleEn: "Unable to Open Source Reader")
            return false
        }
    }

    func openSourceReaderOriginalFile() async {
        guard let filePath = sourceReader.currentFilePath else {
            presentIssue(
                NSError(
                    domain: "WordZMac.SourceReader",
                    code: 1,
                    userInfo: [
                        NSLocalizedDescriptionKey: t("当前没有可打开的原始文件。", "There is no source file available to open right now.")
                    ]
                ),
                titleZh: "无法打开原始文件",
                titleEn: "Unable to Open Source File"
            )
            return
        }
        do {
            try await hostActionService.openFile(path: filePath)
            settings.setSupportStatus(t("已打开原始文件。", "Opened the source file."))
            clearActiveIssue()
        } catch {
            presentIssue(error, titleZh: "无法打开原始文件", titleEn: "Unable to Open Source File")
        }
    }

    func quickLookSourceReaderContent() async {
        let targetPath: String?
        if let filePath = sourceReader.currentFilePath,
           FileManager.default.fileExists(atPath: filePath) {
            targetPath = filePath
        } else if let document = sourceReader.currentReadingExportDocument {
            targetPath = try? quickLookPreviewFileService.prepare(textDocument: document)
        } else {
            targetPath = nil
        }

        guard let targetPath else {
            presentQuickLookUnavailableIssue()
            return
        }

        do {
            try await hostActionService.quickLook(path: targetPath)
            settings.setSupportStatus(t("已打开原文阅读内容的 Quick Look 预览。", "Opened Quick Look for the source reader content."))
            clearActiveIssue()
        } catch {
            presentIssue(error, titleZh: "无法打开 Quick Look 预览", titleEn: "Unable to Open Quick Look")
        }
    }

    func copySourceReaderCitation() {
        guard let citationText = sourceReader.currentCitationText else { return }
        hostActionService.copyTextToClipboard(citationText)
        settings.setSupportStatus(t("已复制当前引文。", "Copied the current citation."))
        clearActiveIssue()
    }

    func captureCurrentSourceReaderEvidenceItem(
        draft overrideDraft: EvidenceCaptureDraft? = nil
    ) async {
        guard let origin = sourceReader.launchContext?.origin,
              let context = sourceReader.launchContext,
              let scene = sourceReader.scene,
              let selectedHitID = scene.selectedHitID
        else { return }

        let sourceDraft = sourceReader.currentEvidenceCaptureDraft
        let draft = mergedEvidenceCaptureDraft(base: overrideDraft, fallback: sourceDraft)
        switch origin {
        case .kwic:
            kwic.selectedRowID = selectedHitID
            await captureCurrentKWICEvidenceItem(draft: draft)
        case .locator:
            locator.selectedRowID = selectedHitID
            await captureCurrentLocatorEvidenceItem(draft: draft)
        case .plot:
            guard let anchor = context.hitAnchors.first(where: { $0.id == selectedHitID }),
                  let selection = scene.selection
            else { return }
            await captureSourceReaderEvidenceItem(
                sourceKind: .plot,
                context: context,
                anchor: anchor,
                selection: selection,
                draft: draft
            )
        case .sentiment:
            guard let anchor = context.hitAnchors.first(where: { $0.id == selectedHitID }),
                  let selection = scene.selection
            else { return }
            await captureSourceReaderEvidenceItem(
                sourceKind: .sentiment,
                context: context,
                anchor: anchor,
                selection: selection,
                draft: draft
            )
        case .topics:
            guard let anchor = context.hitAnchors.first(where: { $0.id == selectedHitID }),
                  let selection = scene.selection
            else { return }
            await captureSourceReaderEvidenceItem(
                sourceKind: .topics,
                context: context,
                anchor: anchor,
                selection: selection,
                draft: draft
            )
        }
    }

    private func mergedEvidenceCaptureDraft(
        base: EvidenceCaptureDraft?,
        fallback: EvidenceCaptureDraft
    ) -> EvidenceCaptureDraft {
        guard let base else { return fallback }
        return EvidenceCaptureDraft(
            sectionTitle: base.sectionTitle.isEmpty ? fallback.sectionTitle : base.sectionTitle,
            claim: base.claim.isEmpty ? fallback.claim : base.claim,
            tagsText: [base.tagsText, fallback.tagsText]
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .joined(separator: ", "),
            note: [base.note, fallback.note]
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .joined(separator: " | ")
        )
    }

    var canOpenSourceReaderCurrentContent: Bool {
        switch selectedTab {
        case .kwic:
            return kwic.selectedSceneRow != nil && sidebar.selectedCorpusID != nil
        case .locator:
            return locator.selectedSceneRow != nil && sidebar.selectedCorpusID != nil
        case .plot:
            return plot.selectedSceneRow?.markers.isEmpty == false
        case .sentiment:
            return sentiment.canOpenSelectedRowSourceReader
        case .topics:
            return topics.selectedSceneRow != nil &&
                (normalizedValue(topics.selectedSceneRow?.sourceID) != nil || sidebar.selectedCorpusID != nil)
        case .stats, .word, .tokenize, .compare, .keyword, .chiSquare, .ngram, .cluster, .collocate, .library, .settings:
            return false
        }
    }

    private var sourceReaderFileDisplayName: String {
        if let title = sourceReader.launchContext?.displayName,
           !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return title
        }
        return t("原文阅读器", "Source Reader")
    }

    private func currentSourceReaderLaunchContext() async -> SourceReaderLaunchContext? {
        if let preferredContext = await sourceReaderLaunchContext(for: selectedTab) {
            return preferredContext
        }

        for fallbackTab in WorkspaceDetailTab.mainWorkspaceTabs where fallbackTab != selectedTab {
            if let fallbackContext = await sourceReaderLaunchContext(for: fallbackTab) {
                return fallbackContext
            }
        }

        return nil
    }

    private func sourceReaderLaunchContext(for tab: WorkspaceDetailTab) async -> SourceReaderLaunchContext? {
        switch tab {
        case .kwic:
            return await currentKWICSourceReaderLaunchContext()
        case .locator:
            return await currentLocatorSourceReaderLaunchContext()
        case .plot:
            return await currentPlotSourceReaderLaunchContext()
        case .sentiment:
            return await currentSentimentSourceReaderLaunchContext()
        case .topics:
            return await currentTopicsSourceReaderLaunchContext()
        case .stats, .word, .tokenize, .compare, .keyword, .chiSquare, .ngram, .cluster, .collocate, .library, .settings:
            return nil
        }
    }

    private func currentKWICSourceReaderLaunchContext() async -> SourceReaderLaunchContext? {
        guard let scene = kwic.scene,
              let selectedRow = kwic.selectedSceneRow
        else { return nil }

        let resolved = await resolveSourceReaderDocumentContext(
            corpusID: sidebar.selectedCorpusID,
            fallbackFilePath: sessionStore.openedCorpus?.filePath,
            fallbackDisplayName: sessionStore.openedCorpus?.displayName ?? library.selectedCorpus?.name
        )

        return SourceReaderLaunchContext(
            origin: .kwic,
            corpusID: sidebar.selectedCorpusID,
            corpusName: resolved.corpusName,
            displayName: resolved.displayName,
            filePath: resolved.filePath,
            query: scene.query,
            leftWindow: scene.leftWindow,
            rightWindow: scene.rightWindow,
            searchOptionsSummary: scene.searchOptions.summaryText,
            hitAnchors: scene.rows.map { row in
                SourceReaderHitAnchor(
                    id: row.id,
                    sentenceId: row.sentenceId,
                    tokenIndex: row.sentenceTokenIndex,
                    keyword: row.keyword,
                    leftContext: row.leftContext,
                    rightContext: row.rightContext,
                    concordanceText: row.concordanceText,
                    citationText: row.citationText,
                    fullSentenceText: [row.leftContext, row.keyword, row.rightContext]
                        .filter { !$0.isEmpty }
                        .joined(separator: " ")
                )
            },
            selectedHitID: selectedRow.id,
            fallbackText: resolved.fallbackText
        )
    }

    private func currentLocatorSourceReaderLaunchContext() async -> SourceReaderLaunchContext? {
        guard let scene = locator.scene,
              let selectedRow = locator.selectedSceneRow
        else { return nil }

        let resolved = await resolveSourceReaderDocumentContext(
            corpusID: sidebar.selectedCorpusID,
            fallbackFilePath: sessionStore.openedCorpus?.filePath,
            fallbackDisplayName: sessionStore.openedCorpus?.displayName ?? library.selectedCorpus?.name
        )

        return SourceReaderLaunchContext(
            origin: .locator,
            corpusID: sidebar.selectedCorpusID,
            corpusName: resolved.corpusName,
            displayName: resolved.displayName,
            filePath: resolved.filePath,
            query: scene.source.keyword,
            leftWindow: scene.leftWindow,
            rightWindow: scene.rightWindow,
            searchOptionsSummary: nil,
            hitAnchors: scene.rows.map { row in
                SourceReaderHitAnchor(
                    id: row.id,
                    sentenceId: row.sentenceId,
                    tokenIndex: row.sourceCandidate.nodeIndex,
                    keyword: row.nodeWord,
                    leftContext: row.leftWords,
                    rightContext: row.rightWords,
                    concordanceText: row.concordanceText,
                    citationText: row.citationText,
                    fullSentenceText: row.text
                )
            },
            selectedHitID: selectedRow.id,
            fallbackText: resolved.fallbackText
        )
    }

    private func currentPlotSourceReaderLaunchContext() async -> SourceReaderLaunchContext? {
        guard let scene = plot.scene,
              let selectedRow = plot.selectedSceneRow,
              let selectedMarker = plot.selectedSceneMarker ?? selectedRow.markers.first
        else { return nil }

        let resolved = await resolveSourceReaderDocumentContext(
            corpusID: normalizedValue(selectedRow.corpusId),
            fallbackFilePath: normalizedValue(selectedRow.filePath),
            fallbackDisplayName: normalizedValue(selectedRow.displayName)
        )

        return SourceReaderLaunchContext(
            origin: .plot,
            corpusID: normalizedValue(selectedRow.corpusId),
            corpusName: resolved.corpusName,
            displayName: resolved.displayName,
            filePath: resolved.filePath,
            query: scene.query,
            leftWindow: nil,
            rightWindow: nil,
            searchOptionsSummary: scene.searchOptions.summaryText,
            hitAnchors: selectedRow.markers.map { marker in
                SourceReaderHitAnchor(
                    id: marker.id,
                    sentenceId: marker.sentenceId,
                    tokenIndex: marker.tokenIndex,
                    keyword: scene.query,
                    leftContext: nil,
                    rightContext: nil,
                    concordanceText: nil,
                    citationText: nil,
                    fullSentenceText: nil
                )
            },
            selectedHitID: selectedMarker.id,
            fallbackText: resolved.fallbackText
        )
    }

    private func currentSentimentSourceReaderLaunchContext() async -> SourceReaderLaunchContext? {
        guard let result = sentiment.result,
              let selectedRow = sentiment.selectedResultRow,
              let sourceID = normalizedValue(selectedRow.sourceID),
              selectedRow.sentenceID != nil
        else { return nil }

        let matchingInput = result.request.texts.first(where: { normalizedValue($0.sourceID) == sourceID })
        let resolved = await resolveSourceReaderDocumentContext(
            corpusID: sourceID,
            fallbackFilePath: nil,
            fallbackDisplayName: normalizedValue(selectedRow.sourceTitle)
        )

        let anchors = result.rows.compactMap { row -> SourceReaderHitAnchor? in
            guard normalizedValue(row.sourceID) == sourceID,
                  let sentenceID = row.sentenceID
            else { return nil }
            return SourceReaderHitAnchor(
                id: row.id,
                sentenceId: sentenceID,
                tokenIndex: row.tokenIndex ?? row.evidence.first?.tokenIndex,
                keyword: sentimentSourceReaderKeyword(for: row),
                leftContext: nil,
                rightContext: nil,
                concordanceText: nil,
                citationText: nil,
                fullSentenceText: row.text
            )
        }

        guard !anchors.isEmpty else { return nil }

        return SourceReaderLaunchContext(
            origin: .sentiment,
            corpusID: sourceID,
            corpusName: resolved.corpusName,
            displayName: resolved.displayName,
            filePath: resolved.filePath,
            query: sentimentSourceReaderKeyword(for: selectedRow),
            leftWindow: nil,
            rightWindow: nil,
            searchOptionsSummary: nil,
            hitAnchors: anchors,
            selectedHitID: selectedRow.id,
            fallbackText: normalizedValue(matchingInput?.documentText) ?? normalizedValue(matchingInput?.text) ?? resolved.fallbackText
        )
    }

    private func currentTopicsSourceReaderLaunchContext() async -> SourceReaderLaunchContext? {
        guard let scene = topics.scene,
              let selectedRow = topics.selectedSceneRow
        else { return nil }

        let corpusID = normalizedValue(selectedRow.sourceID) ?? sidebar.selectedCorpusID

        let resolved = await resolveSourceReaderDocumentContext(
            corpusID: corpusID,
            fallbackFilePath: sessionStore.openedCorpus?.filePath,
            fallbackDisplayName: normalizedValue(selectedRow.sourceTitle) ?? sessionStore.openedCorpus?.displayName ?? library.selectedCorpus?.name
        )
        guard let documentText = normalizedValue(resolved.fallbackText) else { return nil }

        let parsedDocument = ParsedDocument(text: documentText)
        let anchors = scene.segmentRows.compactMap { row -> SourceReaderHitAnchor? in
            if let rowSourceID = normalizedValue(row.sourceID),
               let corpusID,
               rowSourceID != corpusID {
                return nil
            }
            return topicsSourceReaderAnchor(
                for: row,
                scene: scene,
                document: parsedDocument
            )
        }
        guard !anchors.isEmpty else { return nil }

        return SourceReaderLaunchContext(
            origin: .topics,
            corpusID: corpusID,
            corpusName: resolved.corpusName,
            displayName: resolved.displayName,
            filePath: resolved.filePath,
            query: topicsSourceReaderKeyword(for: selectedRow, scene: scene),
            leftWindow: nil,
            rightWindow: nil,
            searchOptionsSummary: scene.searchOptions.summaryText,
            hitAnchors: anchors,
            selectedHitID: anchors.contains(where: { $0.id == selectedRow.id }) ? selectedRow.id : anchors.first?.id,
            fallbackText: documentText
        )
    }

    private func resolveSourceReaderDocumentContext(
        corpusID: String?,
        fallbackFilePath: String?,
        fallbackDisplayName: String?
    ) async -> (filePath: String, displayName: String, corpusName: String, fallbackText: String?) {
        var filePath = normalizedValue(fallbackFilePath) ?? ""
        var displayName = normalizedValue(fallbackDisplayName) ?? ""
        var corpusName = displayName
        var fallbackText = normalizedValue(sessionStore.openedCorpus?.content)

        if let corpusID {
            if sidebar.selectedCorpusID == corpusID,
               let openedCorpus = sessionStore.openedCorpus,
               !openedCorpus.content.isEmpty {
                fallbackText = normalizedValue(openedCorpus.content) ?? fallbackText
                filePath = normalizedValue(openedCorpus.filePath) ?? filePath
                displayName = normalizedValue(openedCorpus.displayName) ?? displayName
            } else if let openedCorpus = try? await appCoordinator.repository.openSavedCorpus(corpusId: corpusID) {
                fallbackText = normalizedValue(openedCorpus.content) ?? fallbackText
                filePath = normalizedValue(openedCorpus.filePath) ?? filePath
                displayName = normalizedValue(openedCorpus.displayName) ?? displayName
            }

            if let info = try? await appCoordinator.repository.loadCorpusInfo(corpusId: corpusID) {
                filePath = normalizedValue(info.representedPath) ?? filePath
                displayName = normalizedValue(info.title) ?? displayName
                corpusName = normalizedValue(info.title) ?? corpusName
            }
        }

        if corpusName.isEmpty {
            corpusName = displayName.isEmpty ? sourceReaderFileDisplayName : displayName
        }
        if displayName.isEmpty {
            displayName = corpusName
        }

        return (filePath, displayName, corpusName, fallbackText)
    }

    private func normalizedValue(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func sentimentSourceReaderKeyword(for row: SentimentRowResult) -> String {
        if let surface = normalizedValue(row.evidence.first?.surface) {
            return surface
        }
        return row.finalLabel.title(in: languageMode)
    }

    private func topicsSourceReaderAnchor(
        for row: TopicSegmentRow,
        scene: TopicsSceneModel,
        document: ParsedDocument
    ) -> SourceReaderHitAnchor? {
        let sourceParagraphIndex = row.sourceParagraphIndex ?? row.paragraphIndex
        let paragraphID = max(0, sourceParagraphIndex - 1)
        guard let paragraph = document.paragraphs.first(where: { $0.paragraphId == paragraphID }),
              let sentenceID = topicsSourceReaderSentenceID(for: row, paragraph: paragraph, document: document)
        else { return nil }

        let keyword = topicsSourceReaderKeyword(for: row, scene: scene)
        return SourceReaderHitAnchor(
            id: row.id,
            sentenceId: sentenceID,
            tokenIndex: topicsSourceReaderTokenIndex(for: keyword, sentenceID: sentenceID, document: document),
            keyword: keyword,
            leftContext: nil,
            rightContext: nil,
            concordanceText: row.text,
            citationText: "\(t("段落", "Paragraph")) \(sourceParagraphIndex): \(row.text)",
            fullSentenceText: row.text
        )
    }

    private func topicsSourceReaderSentenceID(
        for row: TopicSegmentRow,
        paragraph: ParsedParagraph,
        document: ParsedDocument
    ) -> Int? {
        let paragraphSentences = paragraph.sentenceIDs.compactMap { sentenceID in
            document.sentences.first(where: { $0.sentenceId == sentenceID })
        }
        let normalizedSegment = normalizedComparisonText(row.text)

        if let matchedSentence = paragraphSentences.first(where: { sentence in
            let normalizedSentence = normalizedComparisonText(sentence.text)
            return normalizedSegment.contains(normalizedSentence) || normalizedSentence.contains(normalizedSegment)
        }) {
            return matchedSentence.sentenceId
        }

        return paragraph.sentenceIDs.first
    }

    private func topicsSourceReaderTokenIndex(
        for keyword: String,
        sentenceID: Int,
        document: ParsedDocument
    ) -> Int? {
        guard let sentence = document.sentences.first(where: { $0.sentenceId == sentenceID }) else {
            return nil
        }
        let searchTerms = keyword
            .lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
            .filter { !$0.isEmpty }

        for term in searchTerms {
            if let token = sentence.tokens.first(where: {
                $0.normalized == term || $0.normalized.contains(term)
            }) {
                return token.tokenIndex
            }
        }
        return nil
    }

    private func topicsSourceReaderKeyword(
        for row: TopicSegmentRow,
        scene: TopicsSceneModel
    ) -> String {
        if let query = normalizedValue(scene.query) {
            return query
        }
        if let keyword = scene.selectedCluster?.keywords.first?.term {
            return keyword
        }
        return "\(t("主题片段", "Topic Segment")) \(row.paragraphIndex)"
    }

    private func normalizedComparisonText(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
