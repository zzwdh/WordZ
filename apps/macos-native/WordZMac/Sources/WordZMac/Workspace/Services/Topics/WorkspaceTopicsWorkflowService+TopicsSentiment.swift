import Foundation

private struct TopicSentimentCorpusContext: Equatable, Sendable {
    let corpusID: String?
    let sourceTitle: String
    let text: String
}

private struct TopicSentimentIndexedDocument {
    let document: ParsedDocument
    let sentencesByID: [Int: ParsedSentence]
    let paragraphsByID: [Int: ParsedParagraph]
    let normalizedParagraphs: [(paragraph: ParsedParagraph, normalizedText: String)]

    init(text: String) {
        let document = ParsedDocument(text: text)
        self.document = document
        self.sentencesByID = Dictionary(uniqueKeysWithValues: document.sentences.map { ($0.sentenceId, $0) })
        self.paragraphsByID = Dictionary(uniqueKeysWithValues: document.paragraphs.map { ($0.paragraphId, $0) })
        self.normalizedParagraphs = document.paragraphs.map {
            ($0, TopicSentimentIndexedDocument.normalizeParagraphText($0.text))
        }
    }

    private static func normalizeParagraphText(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

@MainActor
extension WorkspaceTopicsWorkflowService {
    func prepareTopicsSentiment(
        scope: TopicsSentimentDrilldownScope,
        features: WorkspaceTopicsWorkflowContext,
        markWorkspaceEdited: @escaping @MainActor (WorkspaceFeatureSet) -> Void
    ) async -> Bool {
        let featureSet = features.withFeatureSet { $0 }
        guard let result = features.topics.result else {
            features.sidebar.setError(
                wordZText(
                    "请先生成 Topics 结果。",
                    "Run Topics first before opening sentiment drilldown.",
                    mode: .system
                )
            )
            return false
        }

        let focusedClusterID: String?
        switch scope {
        case .visibleTopics:
            focusedClusterID = nil
        case .selectedTopic:
            guard let selectedClusterID = features.topics.selectedClusterID else {
                features.sidebar.setError(
                    wordZText(
                        "请先选择一个主题。",
                        "Select a topic before opening the topic sentiment drilldown.",
                        mode: .system
                    )
                )
                return false
            }
            focusedClusterID = selectedClusterID
        }

        let visibleSegments = features.topics.visibleTopicSegmentsForSentiment(
            from: result,
            focusedClusterID: focusedClusterID
        )
        guard !visibleSegments.isEmpty else {
            features.sidebar.setError(topicSentimentUnavailableMessage(features: features))
            return false
        }

        features.sentiment.source = .topicSegments
        features.sentiment.topicSegmentsFocusClusterID = focusedClusterID
        features.sentiment.unit = .sourceSentence
        features.sentiment.contextBasis = .fullSentenceWhenAvailable
        features.sentiment.rowFilterQuery = ""
        features.sentiment.labelFilter = nil
        features.shell.selectedTab = .sentiment
        markWorkspaceEdited(featureSet)
        return true
    }

    func runTopicSegmentsSentiment(
        features: WorkspaceTopicsWorkflowContext,
        syncFeatureContexts: @escaping @MainActor (WorkspaceFeatureSet) -> Void
    ) async {
        let featureSet = features.withFeatureSet { $0 }
        guard let topicsResult = features.topics.result else {
            features.sidebar.setError(
                wordZText(
                    "请先生成 Topics 结果。",
                    "Run Topics first before analyzing topic segments in Sentiment.",
                    mode: .system
                )
            )
            return
        }

        let visibleSegments = features.topics.visibleTopicSegmentsForSentiment(
            from: topicsResult,
            focusedClusterID: features.sentiment.topicSegmentsFocusClusterID
        )
        guard !visibleSegments.isEmpty else {
            features.sidebar.setError(topicSentimentUnavailableMessage(features: features))
            return
        }

        await analysisWorkflow.performResultRunTask(
            .sentiment,
            selecting: .sentiment,
            features: featureSet,
            syncFeatureContexts: syncFeatureContexts
        ) {
            let corpusContexts = try await self.topicSentimentCorpusContexts(
                for: visibleSegments,
                features: features,
                syncFeatureContexts: syncFeatureContexts
            )
            let texts = self.buildTopicSentimentInputs(
                segments: visibleSegments,
                corpusContexts: corpusContexts,
                result: topicsResult
            )

            guard !texts.isEmpty else {
                throw NSError(
                    domain: "WordZMac.TopicsSentiment",
                    code: 1,
                    userInfo: [
                        NSLocalizedDescriptionKey: wordZText(
                            "当前 Topics 片段无法映射回原始句子，暂时不能进入情感分析。",
                            "The visible topic segments could not be mapped back to source sentences for sentiment analysis.",
                            mode: .system
                        )
                    ]
                )
            }

            let request = features.sentiment.currentRunRequest(texts: texts)
            let result = try await self.repository.runSentiment(request)
            features.sentiment.apply(result)
            if let presentationResult = features.sentiment.presentationResult {
                features.topics.applySentimentPresentationResult(presentationResult, languageMode: .system)
            }
        }
    }

    private func topicSentimentCorpusContexts(
        for segments: [TopicSegmentRow],
        features: WorkspaceTopicsWorkflowContext,
        syncFeatureContexts: @escaping @MainActor (WorkspaceFeatureSet) -> Void
    ) async throws -> [String: TopicSentimentCorpusContext] {
        let sourceIDs = Set(segments.compactMap { normalizedTopicSentimentValue($0.sourceID) })
        if sourceIDs.isEmpty {
            let fallback = try await topicSentimentFallbackCorpusContext(
                features: features,
                syncFeatureContexts: syncFeatureContexts
            )
            return ["__current__": fallback]
        }

        var contexts: [String: TopicSentimentCorpusContext] = [:]
        for sourceID in sourceIDs.sorted() {
            let openedCorpus = try await repository.openSavedCorpus(corpusId: sourceID)
            let sourceTitle: String
            if let info = try? await repository.loadCorpusInfo(corpusId: sourceID),
               !info.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                sourceTitle = info.title
            } else if !openedCorpus.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                sourceTitle = openedCorpus.displayName
            } else {
                sourceTitle = wordZText("当前语料", "Opened Corpus", mode: .system)
            }
            contexts[sourceID] = TopicSentimentCorpusContext(
                corpusID: sourceID,
                sourceTitle: sourceTitle,
                text: openedCorpus.content
            )
        }
        return contexts
    }

    private func topicSentimentFallbackCorpusContext(
        features: WorkspaceTopicsWorkflowContext,
        syncFeatureContexts: @escaping @MainActor (WorkspaceFeatureSet) -> Void
    ) async throws -> TopicSentimentCorpusContext {
        let featureSet = features.withFeatureSet { $0 }
        let corpusID = features.sidebar.selectedCorpusID ?? sessionStore.openedCorpusSourceID

        if let openedCorpus = sessionStore.openedCorpus,
           corpusID == nil || sessionStore.matchesOpenedCorpusSource(corpusID) {
            let sourceTitle = openedCorpus.displayName.isEmpty
                ? wordZText("当前语料", "Opened Corpus", mode: .system)
                : openedCorpus.displayName
            return TopicSentimentCorpusContext(
                corpusID: corpusID,
                sourceTitle: sourceTitle,
                text: openedCorpus.content
            )
        }

        let openedCorpus = try await analysisWorkflow.ensureOpenedCorpus(
            features: featureSet,
            syncFeatureContexts: syncFeatureContexts
        )
        let sourceTitle = openedCorpus.displayName.isEmpty
            ? wordZText("当前语料", "Opened Corpus", mode: .system)
            : openedCorpus.displayName
        return TopicSentimentCorpusContext(
            corpusID: features.sidebar.selectedCorpusID ?? sessionStore.openedCorpusSourceID,
            sourceTitle: sourceTitle,
            text: openedCorpus.content
        )
    }

    private func buildTopicSentimentInputs(
        segments: [TopicSegmentRow],
        corpusContexts: [String: TopicSentimentCorpusContext],
        result: TopicAnalysisResult
    ) -> [SentimentInputText] {
        let languageMode = WordZLocalization.shared.effectiveMode
        let clusterTitleByID = Dictionary(
            uniqueKeysWithValues: result.clusters.map {
                ($0.id, defaultTopicSentimentGroupTitle(topicID: $0.id, result: result, mode: languageMode))
            }
        )
        var indexedDocuments: [String: TopicSentimentIndexedDocument] = [:]
        var texts: [SentimentInputText] = []
        var seenInputIDs: Set<String> = []

        for segment in segments {
            let corpusContext = resolvedTopicSentimentCorpusContext(
                for: segment,
                contexts: corpusContexts
            )
            guard let corpusContext else { continue }
            let documentKey = normalizedTopicSentimentValue(corpusContext.corpusID) ?? "__current__"
            let indexedDocument: TopicSentimentIndexedDocument
            if let cachedDocument = indexedDocuments[documentKey] {
                indexedDocument = cachedDocument
            } else {
                let nextDocument = TopicSentimentIndexedDocument(text: corpusContext.text)
                indexedDocuments[documentKey] = nextDocument
                indexedDocument = nextDocument
            }
            guard let paragraph = topicSentimentParagraph(for: segment, indexedDocument: indexedDocument) else { continue }
            let groupTitle = clusterTitleByID[segment.topicID]
                ?? defaultTopicSentimentGroupTitle(
                    topicID: segment.topicID,
                    result: result,
                    mode: languageMode
                )
            for sentenceID in paragraph.sentenceIDs {
                guard let sentence = indexedDocument.sentencesByID[sentenceID] else { continue }
                let inputID = "\(segment.id)::sentence::\(sentenceID)"
                guard seenInputIDs.insert(inputID).inserted else { continue }
                texts.append(
                    SentimentInputText(
                        id: inputID,
                        sourceID: corpusContext.corpusID,
                        sourceTitle: corpusContext.sourceTitle,
                        text: sentence.text,
                        sentenceID: sentence.sentenceId,
                        tokenIndex: sentence.tokens.first?.tokenIndex,
                        groupID: segment.topicID,
                        groupTitle: groupTitle,
                        documentText: corpusContext.text
                    )
                )
            }
        }

        return texts
    }

    private func resolvedTopicSentimentCorpusContext(
        for segment: TopicSegmentRow,
        contexts: [String: TopicSentimentCorpusContext]
    ) -> TopicSentimentCorpusContext? {
        if let sourceID = normalizedTopicSentimentValue(segment.sourceID),
           let context = contexts[sourceID] {
            return context
        }
        return contexts["__current__"]
    }

    private func topicSentimentParagraph(
        for segment: TopicSegmentRow,
        indexedDocument: TopicSentimentIndexedDocument
    ) -> ParsedParagraph? {
        let sourceParagraphIndex = segment.sourceParagraphIndex ?? segment.paragraphIndex
        let paragraphID = max(0, sourceParagraphIndex - 1)
        if let indexedParagraph = indexedDocument.paragraphsByID[paragraphID] {
            return indexedParagraph
        }

        let normalizedSegment = normalizedTopicSentimentText(segment.text)
        return indexedDocument.normalizedParagraphs.first { paragraph, normalizedParagraph in
            return normalizedParagraph.contains(normalizedSegment) || normalizedSegment.contains(normalizedParagraph)
        }?.paragraph
    }

    private func defaultTopicSentimentGroupTitle(
        topicID: String,
        result: TopicAnalysisResult,
        mode: AppLanguageMode
    ) -> String {
        guard let cluster = result.cluster(for: topicID) else { return topicID }
        if cluster.isOutlier {
            return wordZText("离群主题", "Outlier Topic", mode: mode)
        }
        return String(
            format: wordZText("主题 %d", "Topic %d", mode: mode),
            cluster.index
        )
    }

    private func normalizedTopicSentimentText(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizedTopicSentimentValue(_ value: String?) -> String? {
        guard let value else { return nil }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    private func topicSentimentUnavailableMessage(features: WorkspaceTopicsWorkflowContext) -> String {
        let mode = WordZLocalization.shared.effectiveMode
        let normalizedQuery = features.topics.normalizedQuery
        if !normalizedQuery.isEmpty {
            return wordZText(
                "当前 Topics 搜索条件“\(normalizedQuery)”没有留下可用于情感分析的可见片段，请先清除或调整过滤。",
                "The current Topics query \"\(normalizedQuery)\" leaves no visible segments for sentiment analysis. Clear or adjust the filter first.",
                mode: mode
            )
        }
        if features.topics.stopwordFilter.enabled {
            return wordZText(
                "当前 Topics 停用词过滤后没有可用于情感分析的可见片段，请先调整过滤条件。",
                "The current Topics stopword filter leaves no visible segments for sentiment analysis. Adjust the filter first.",
                mode: mode
            )
        }
        return wordZText(
            "当前 Topics 结果没有可用于情感分析的可见片段。",
            "There are no visible topic segments available for sentiment analysis.",
            mode: mode
        )
    }
}
