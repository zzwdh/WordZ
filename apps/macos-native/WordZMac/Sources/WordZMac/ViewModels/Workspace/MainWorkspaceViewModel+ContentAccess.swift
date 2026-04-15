import Foundation

@MainActor
extension MainWorkspaceViewModel {
    enum CurrentContentTarget {
        case file(String)
        case tableSnapshot(NativeTableExportSnapshot)
        case textDocument(PlainTextExportDocument)
    }

    func t(_ zh: String, _ en: String) -> String {
        wordZText(zh, en, mode: languageMode)
    }

    var currentPreviewablePath: String? {
        if let selectedCorpusPreviewablePath {
            return selectedCorpusPreviewablePath
        }
        let trimmedOpenedPath = sessionStore.openedCorpus?.filePath.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmedOpenedPath.isEmpty ? nil : trimmedOpenedPath
    }

    var selectedCorpusPreviewablePath: String? {
        let trimmedSelectedPath = library.selectedCorpus?.representedPath.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmedSelectedPath.isEmpty ? nil : trimmedSelectedPath
    }

    var currentContentTarget: CurrentContentTarget? {
        currentContentTarget(in: sceneGraph, selectedTab: selectedTab)
    }

    func currentContentTarget(
        in graph: WorkspaceSceneGraph,
        selectedTab: WorkspaceDetailTab
    ) -> CurrentContentTarget? {
        switch selectedTab {
        case .tokenize:
            if let document = tokenize.exportDocument {
                return .textDocument(document)
            }
        case .stats, .word, .topics, .compare, .sentiment, .keyword, .chiSquare, .plot, .ngram, .cluster, .kwic, .collocate, .locator:
            if let snapshot = currentExportSnapshot(in: graph, selectedTab: selectedTab) {
                return .tableSnapshot(snapshot)
            }
        case .library, .settings:
            break
        }

        guard let path = currentPreviewablePath else { return nil }
        return .file(path)
    }

    func preparedPath(for target: CurrentContentTarget) throws -> String {
        switch target {
        case .file(let path):
            return path
        case .tableSnapshot(let snapshot):
            return try quickLookPreviewFileService.prepare(snapshot: snapshot)
        case .textDocument(let document):
            return try quickLookPreviewFileService.prepare(textDocument: document)
        }
    }

    func presentQuickLookUnavailableIssue() {
        let status = t("当前没有可预览的内容。", "There is no previewable content available right now.")
        settings.setSupportStatus(status)
        activeIssue = WorkspaceIssueBanner(
            tone: .warning,
            title: t("没有可预览文件", "No Preview Available"),
            message: status,
            recoveryAction: .refreshWorkspace
        )
    }

    func presentShareUnavailableIssue() {
        let status = t("当前没有可分享的内容。", "There is no shareable content available right now.")
        settings.setSupportStatus(status)
        activeIssue = WorkspaceIssueBanner(
            tone: .warning,
            title: t("没有可分享内容", "No Shareable Content"),
            message: status,
            recoveryAction: .refreshWorkspace
        )
    }

    var currentExportSnapshot: NativeTableExportSnapshot? {
        currentExportSnapshot(in: sceneGraph, selectedTab: selectedTab)
    }

    func hasPreviewableCurrentContent(
        in graph: WorkspaceSceneGraph,
        selectedTab: WorkspaceDetailTab
    ) -> Bool {
        switch selectedTab {
        case .tokenize:
            return tokenize.exportDocument != nil || currentPreviewablePath != nil
        case .stats, .word, .topics, .compare, .sentiment, .keyword, .chiSquare, .plot, .ngram, .cluster, .kwic, .collocate, .locator:
            return hasExportableCurrentContent(in: graph, selectedTab: selectedTab)
        case .library, .settings:
            return currentPreviewablePath != nil
        }
    }

    func hasExportableCurrentContent(
        in graph: WorkspaceSceneGraph,
        selectedTab: WorkspaceDetailTab
    ) -> Bool {
        currentResultSceneNode(in: graph, selectedTab: selectedTab)?.isExportable == true
    }

    func currentExportSnapshot(
        in graph: WorkspaceSceneGraph,
        selectedTab: WorkspaceDetailTab
    ) -> NativeTableExportSnapshot? {
        currentResultSceneNode(in: graph, selectedTab: selectedTab)?.exportSnapshot
    }

    var currentReportTextDocuments: [AnalysisReportBundleTextDocument] {
        var documents: [AnalysisReportBundleTextDocument] = []

        if selectedTab == .tokenize, let document = tokenize.exportDocument {
            documents.append(
                AnalysisReportBundleTextDocument(
                    relativePath: "tokenize/tokenized-text.txt",
                    description: "Current tokenized text export.",
                    document: document
                )
            )
        }

        if let readingDocument = currentReadingExportDocument {
            documents.append(readingDocument)
        }

        if let sourceReaderDocument = sourceReader.currentReadingExportDocument {
            documents.append(
                AnalysisReportBundleTextDocument(
                    relativePath: "reading/source-reader-current.txt",
                    description: "Current source reader citation and sentence export.",
                    document: sourceReaderDocument
                )
            )
        }

        return documents
    }

    var currentReadingExportDocument: AnalysisReportBundleTextDocument? {
        switch selectedTab {
        case .kwic:
            guard let scene = kwic.scene else { return nil }
            let document: PlainTextExportDocument
            if let selectedSceneRow = kwic.selectedSceneRow {
                document = ReadingExportSupport.document(for: .citation, currentKWICRow: selectedSceneRow, scene: scene)
            } else if !scene.rows.isEmpty {
                document = ReadingExportSupport.document(for: .citation, visibleKWICRows: scene.rows, scene: scene)
            } else {
                return nil
            }
            return AnalysisReportBundleTextDocument(
                relativePath: "reading/kwic-citation.txt",
                description: "Current KWIC reading export in citation format.",
                document: document
            )
        case .locator:
            guard let scene = locator.scene else { return nil }
            let document: PlainTextExportDocument
            if let selectedSceneRow = locator.selectedSceneRow {
                document = ReadingExportSupport.document(for: .citation, currentLocatorRow: selectedSceneRow, scene: scene)
            } else if !scene.rows.isEmpty {
                document = ReadingExportSupport.document(for: .citation, visibleLocatorRows: scene.rows, scene: scene)
            } else {
                return nil
            }
            return AnalysisReportBundleTextDocument(
                relativePath: "reading/locator-citation.txt",
                description: "Current locator reading export in citation format.",
                document: document
            )
        case .compare:
            guard let scene = compare.scene else { return nil }
            let document: PlainTextExportDocument
            if let selectedSceneRow = compare.selectedSceneRow {
                document = ReadingExportSupport.document(currentCompareRow: selectedSceneRow, scene: scene)
            } else if !scene.rows.isEmpty {
                document = ReadingExportSupport.document(visibleCompareRows: scene.rows, scene: scene)
            } else {
                return nil
            }
            return AnalysisReportBundleTextDocument(
                relativePath: "reading/compare-summary.txt",
                description: "Current compare research summary export.",
                document: document
            )
        case .sentiment:
            guard let result = sentiment.result else { return nil }
            let lines = [
                "WordZ Sentiment Summary",
                "",
                "Source: \(result.request.source.rawValue)",
                "Unit: \(result.request.unit.rawValue)",
                "Positive: \(result.overallSummary.positiveCount)",
                "Neutral: \(result.overallSummary.neutralCount)",
                "Negative: \(result.overallSummary.negativeCount)"
            ]
            return AnalysisReportBundleTextDocument(
                relativePath: "reading/sentiment-summary.txt",
                description: "Current sentiment summary export.",
                document: PlainTextExportDocument(
                    suggestedName: "sentiment-summary.txt",
                    text: lines.joined(separator: "\n")
                )
            )
        case .collocate:
            guard let scene = collocate.scene else { return nil }
            let document: PlainTextExportDocument
            if let selectedSceneRow = collocate.selectedSceneRow {
                document = ReadingExportSupport.document(currentCollocateRow: selectedSceneRow, scene: scene)
            } else if !scene.rows.isEmpty {
                document = ReadingExportSupport.document(visibleCollocateRows: scene.rows, scene: scene)
            } else {
                return nil
            }
            return AnalysisReportBundleTextDocument(
                relativePath: "reading/collocate-summary.txt",
                description: "Current collocate research summary export.",
                document: document
            )
        default:
            return nil
        }
    }
}
