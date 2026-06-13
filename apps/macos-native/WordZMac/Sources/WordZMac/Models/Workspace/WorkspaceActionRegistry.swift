import Foundation

struct WorkspaceToolbarAvailabilityContext: Equatable, Sendable {
    let actionEnabled: Bool
    let hasSelection: Bool
    let hasSourceReaderContext: Bool
    let hasPreviewableContent: Bool
    let corpusCount: Int
    let hasLocatorSource: Bool
    let hasCopyableContent: Bool
    let hasExportableContent: Bool
    let runSentimentEnabled: Bool
}

enum WorkspaceActionRegistry {
    static let toolbarActions: [WorkspaceToolbarAction] = [
        .refresh,
        .showLibrary,
        .openSelected,
        .openSourceReader,
        .annotationControls,
        .copyCurrentResult,
        .previewCurrentCorpus,
        .shareCurrentContent,
        .runStats,
        .runWord,
        .runTokenize,
        .runTopics,
        .runCompare,
        .runSentiment,
        .runKeyword,
        .runChiSquare,
        .runPlot,
        .runNgram,
        .runCluster,
        .runKWIC,
        .runCollocate,
        .runLocator,
        .exportCurrent
    ]

    static let analysisToolbarPairs: [(WorkspaceToolbarAction, WorkspaceAnalysisIntent)] = [
        (.runStats, .stats),
        (.runWord, .word),
        (.runTokenize, .tokenize),
        (.runTopics, .topics),
        (.runCompare, .compare),
        (.runSentiment, .sentiment),
        (.runKeyword, .keyword),
        (.runChiSquare, .chiSquare),
        (.runPlot, .plot),
        (.runNgram, .ngram),
        (.runCluster, .cluster),
        (.runKWIC, .kwic),
        (.runCollocate, .collocate),
        (.runLocator, .locator)
    ]

    static func toolbarItems(
        languageMode: AppLanguageMode,
        availability: WorkspaceToolbarAvailabilityContext
    ) -> [WorkspaceToolbarActionItem] {
        toolbarActions.map { action in
            WorkspaceToolbarActionItem(
                action: action,
                title: title(for: action, languageMode: languageMode),
                systemImage: systemImage(for: action),
                nativeCommand: nativeCommand(for: action),
                isEnabled: isEnabled(action, availability: availability)
            )
        }
    }

    static func title(
        for action: WorkspaceToolbarAction,
        languageMode: AppLanguageMode
    ) -> String {
        switch action {
        case .refresh:
            return wordZText("刷新", "Refresh", mode: languageMode)
        case .showLibrary:
            return wordZText("语料库", "Library", mode: languageMode)
        case .openSelected:
            return wordZText("打开选中", "Open Selected", mode: languageMode)
        case .openSourceReader:
            return wordZText("来源文本", "Source Text", mode: languageMode)
        case .annotationControls:
            return wordZText("标注显示", "Annotation Display", mode: languageMode)
        case .copyCurrentResult:
            return wordZText("复制结果", "Copy Result", mode: languageMode)
        case .previewCurrentCorpus:
            return wordZText("快速预览", "Quick Look", mode: languageMode)
        case .shareCurrentContent:
            return wordZText("分享当前", "Share Current", mode: languageMode)
        case .runStats:
            return wordZText("统计", "Stats", mode: languageMode)
        case .runWord:
            return wordZText("词表", "Word", mode: languageMode)
        case .runTokenize:
            return wordZText("分词", "Tokenize", mode: languageMode)
        case .runTopics:
            return wordZText("主题", "Topics", mode: languageMode)
        case .runCompare:
            return wordZText("对比", "Compare", mode: languageMode)
        case .runSentiment:
            return wordZText("情感", "Sentiment", mode: languageMode)
        case .runKeyword:
            return wordZText("关键词", "Keyword", mode: languageMode)
        case .runChiSquare:
            return wordZText("卡方", "Chi-Square", mode: languageMode)
        case .runPlot:
            return wordZText("图表", "Plot", mode: languageMode)
        case .runNgram:
            return "N-Gram"
        case .runCluster:
            return wordZText("词串簇", "Cluster", mode: languageMode)
        case .runKWIC:
            return "KWIC"
        case .runCollocate:
            return wordZText("搭配词", "Collocate", mode: languageMode)
        case .runLocator:
            return wordZText("定位", "Locator", mode: languageMode)
        case .exportCurrent:
            return wordZText("导出当前", "Export Current", mode: languageMode)
        }
    }

    static func systemImage(for action: WorkspaceToolbarAction) -> String {
        switch action {
        case .refresh:
            return "arrow.clockwise"
        case .showLibrary:
            return "books.vertical"
        case .openSelected:
            return "arrow.up.right.square"
        case .openSourceReader:
            return "doc.text.magnifyingglass"
        case .annotationControls:
            return "slider.horizontal.3"
        case .copyCurrentResult:
            return "tablecells"
        case .previewCurrentCorpus:
            return "space"
        case .shareCurrentContent:
            return "square.and.arrow.up"
        case .runStats, .runWord, .runTokenize, .runTopics, .runCompare, .runSentiment,
             .runKeyword, .runChiSquare, .runPlot, .runNgram, .runCluster, .runKWIC,
             .runCollocate, .runLocator:
            return "play.fill"
        case .exportCurrent:
            return "square.and.arrow.down"
        }
    }

    static func nativeCommand(for action: WorkspaceToolbarAction) -> NativeAppCommand? {
        switch action {
        case .refresh:
            return .refreshWorkspace
        case .showLibrary:
            return .showLibrary
        case .openSelected:
            return .openSelectedCorpus
        case .openSourceReader:
            return .openSourceReader
        case .annotationControls:
            return nil
        case .copyCurrentResult:
            return .copyCurrentResult
        case .previewCurrentCorpus:
            return .quickLookCurrentCorpus
        case .shareCurrentContent:
            return .shareCurrentContent
        case .runStats:
            return .runStats
        case .runWord:
            return .runWord
        case .runTokenize:
            return .runTokenize
        case .runTopics:
            return .runTopics
        case .runCompare:
            return .runCompare
        case .runSentiment:
            return .runSentiment
        case .runKeyword:
            return .runKeyword
        case .runChiSquare:
            return .runChiSquare
        case .runPlot:
            return .runPlot
        case .runNgram:
            return .runNgram
        case .runCluster:
            return .runCluster
        case .runKWIC:
            return .runKWIC
        case .runCollocate:
            return .runCollocate
        case .runLocator:
            return .runLocator
        case .exportCurrent:
            return .exportCurrent
        }
    }

    static func intent(for action: WorkspaceToolbarAction) -> WorkspaceIntent {
        if let analysisIntent = analysisIntent(for: action) {
            return .runAnalysis(analysisIntent)
        }

        switch action {
        case .refresh:
            return .refreshWorkspace
        case .showLibrary:
            return .openWindow(.library)
        case .openSelected:
            return .openSelectedCorpus
        case .openSourceReader:
            return .openSourceReader
        case .annotationControls:
            return .noOp
        case .copyCurrentResult:
            return .resultArtifact(.copy)
        case .previewCurrentCorpus:
            return .resultArtifact(.preview)
        case .shareCurrentContent:
            return .resultArtifact(.share)
        case .exportCurrent:
            return .resultArtifact(.export)
        case .runStats, .runWord, .runTokenize, .runTopics, .runCompare, .runSentiment,
             .runKeyword, .runChiSquare, .runPlot, .runNgram, .runCluster, .runKWIC,
             .runCollocate, .runLocator:
            return .noOp
        }
    }

    static func analysisIntent(for action: WorkspaceToolbarAction) -> WorkspaceAnalysisIntent? {
        analysisToolbarPairs.first(where: { $0.0 == action })?.1
    }

    static func analysisIntent(for nativeCommand: NativeAppCommand) -> WorkspaceAnalysisIntent? {
        analysisToolbarPairs.first(where: { Self.nativeCommand(for: $0.0) == nativeCommand })?.1
    }

    static func toolbarAction(for analysisIntent: WorkspaceAnalysisIntent) -> WorkspaceToolbarAction {
        guard let pair = analysisToolbarPairs.first(where: { $0.1 == analysisIntent }) else {
            assertionFailure("Missing toolbar action for \(analysisIntent)")
            return .runStats
        }
        return pair.0
    }

    private static func isEnabled(
        _ action: WorkspaceToolbarAction,
        availability: WorkspaceToolbarAvailabilityContext
    ) -> Bool {
        guard availability.actionEnabled else { return false }

        switch action {
        case .refresh, .showLibrary, .annotationControls, .runChiSquare:
            return true
        case .openSelected, .runStats, .runWord, .runTokenize, .runTopics, .runPlot,
             .runNgram, .runCluster, .runKWIC, .runCollocate:
            return availability.hasSelection
        case .openSourceReader:
            return availability.hasSourceReaderContext
        case .copyCurrentResult:
            return availability.hasCopyableContent
        case .previewCurrentCorpus, .shareCurrentContent:
            return availability.hasPreviewableContent
        case .runCompare, .runKeyword:
            return availability.corpusCount >= 2
        case .runSentiment:
            return availability.runSentimentEnabled
        case .runLocator:
            return availability.hasSelection && availability.hasLocatorSource
        case .exportCurrent:
            return availability.hasExportableContent
        }
    }
}
