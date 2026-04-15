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

    func captureCurrentSourceReaderEvidenceItem() async {
        guard let origin = sourceReader.launchContext?.origin,
              let selectedHitID = sourceReader.scene?.selectedHitID
        else { return }

        switch origin {
        case .kwic:
            kwic.selectedRowID = selectedHitID
            await captureCurrentKWICEvidenceItem()
        case .locator:
            locator.selectedRowID = selectedHitID
            await captureCurrentLocatorEvidenceItem()
        case .plot:
            let message = t("Plot 来源的原文阅读暂不支持直接加入证据工作台。", "Source Reader items opened from Plot cannot be added to the evidence workbench yet.")
            settings.setSupportStatus(message)
            activeIssue = WorkspaceIssueBanner(
                tone: .warning,
                title: t("暂不支持该来源", "This Source Is Not Yet Supported"),
                message: message,
                recoveryAction: .refreshWorkspace
            )
        }
    }

    var canOpenSourceReaderCurrentContent: Bool {
        switch selectedTab {
        case .kwic:
            return kwic.selectedSceneRow != nil && sidebar.selectedCorpusID != nil
        case .locator:
            return locator.selectedSceneRow != nil && sidebar.selectedCorpusID != nil
        case .plot:
            return plot.selectedSceneRow?.markers.isEmpty == false
        case .stats, .word, .tokenize, .topics, .compare, .sentiment, .keyword, .chiSquare, .ngram, .cluster, .collocate, .library, .settings:
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
        case .stats, .word, .tokenize, .topics, .compare, .sentiment, .keyword, .chiSquare, .ngram, .cluster, .collocate, .library, .settings:
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
}
