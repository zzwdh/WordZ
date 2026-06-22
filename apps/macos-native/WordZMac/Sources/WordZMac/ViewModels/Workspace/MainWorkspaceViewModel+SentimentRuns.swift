import Foundation
import WordZShared

@MainActor
extension MainWorkspaceViewModel {
    func runSentiment(token: WorkspaceRequestToken) async {
        let source = sentiment.source
        switch source {
        case .pastedText:
            let trimmed = sentiment.manualText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                sidebar.setError(wordZText("请先输入要分析的文本。", "Enter some text to analyze first.", mode: .system))
                return
            }
        case .kwicVisible:
            guard let scene = kwic.scene, !scene.rows.isEmpty else {
                sidebar.setError(wordZText("请先生成 KWIC 结果。", "Run KWIC first to analyze visible concordance lines.", mode: .system))
                return
            }
        case .corpusCompare:
            guard !sentiment.selectedTargetCorpusItems().isEmpty else {
                sidebar.setError(wordZText("请至少选择一条目标语料。", "Select at least one target corpus first.", mode: .system))
                return
            }
        case .openedCorpus, .topicSegments:
            break
        }

        await performLatestResultRun(
            token: token,
            label: "sentiment",
            descriptor: .sentiment,
            selecting: .sentiment
        ) {
            let request = try await self.sentimentRunRequest(for: source)
            return try await self.flowCoordinator.analysisWorkflow.repository.runSentiment(request)
        } apply: { result in
            self.applyLatestSentimentResult(result)
        }
    }

    private func sentimentRunRequest(for source: SentimentInputSource) async throws -> SentimentRunRequest {
        switch source {
        case .openedCorpus:
            return try await openedCorpusSentimentRunRequest()
        case .pastedText:
            return pastedTextSentimentRunRequest()
        case .kwicVisible:
            return kwicVisibleSentimentRunRequest()
        case .corpusCompare:
            return try await corpusCompareSentimentRunRequest()
        case .topicSegments:
            return try await flowCoordinator.topicSegmentsSentimentRunRequest(features: features)
        }
    }

    private func openedCorpusSentimentRunRequest() async throws -> SentimentRunRequest {
        let corpus = try await performWithoutSceneSyncCallbacks(.navigation) {
            try await flowCoordinator.ensureOpenedCorpus(features: features)
        }
        let text = SentimentInputText(
            id: sidebar.selectedCorpusID ?? UUID().uuidString,
            sourceID: sidebar.selectedCorpusID,
            sourceTitle: corpus.displayName.isEmpty ? wordZText("当前语料", "Opened Corpus", mode: .system) : corpus.displayName,
            text: corpus.content,
            groupID: "target",
            groupTitle: wordZText("目标语料", "Target", mode: .system)
        )
        return sentiment.currentRunRequest(texts: [text])
    }

    private func pastedTextSentimentRunRequest() -> SentimentRunRequest {
        let text = SentimentInputText(
            id: "manual-text",
            sourceTitle: wordZText("粘贴文本", "Pasted Text", mode: .system),
            text: sentiment.manualText.trimmingCharacters(in: .whitespacesAndNewlines),
            groupID: "manual",
            groupTitle: wordZText("手动输入", "Manual Input", mode: .system)
        )
        return sentiment.currentRunRequest(texts: [text])
    }

    private func kwicVisibleSentimentRunRequest() -> SentimentRunRequest {
        let documentText = sessionStore.openedCorpus?.content
        let texts = (kwic.scene?.rows ?? []).map { row in
            SentimentInputText(
                id: row.id,
                sourceID: sidebar.selectedCorpusID,
                sourceTitle: wordZText("KWIC", "KWIC", mode: .system),
                text: row.concordanceText,
                sentenceID: row.sentenceId,
                tokenIndex: row.sentenceTokenIndex,
                groupID: "kwic",
                groupTitle: wordZText("索引行", "Concordance", mode: .system),
                documentText: documentText
            )
        }
        return sentiment.currentRunRequest(texts: texts)
    }

    private func corpusCompareSentimentRunRequest() async throws -> SentimentRunRequest {
        var texts: [SentimentInputText] = []
        for corpus in sentiment.selectedTargetCorpusItems() {
            let opened = try await flowCoordinator.analysisWorkflow.repository.openSavedCorpus(corpusId: corpus.id)
            texts.append(
                SentimentInputText(
                    id: "target::\(corpus.id)",
                    sourceID: corpus.id,
                    sourceTitle: corpus.name,
                    text: opened.content,
                    groupID: "target",
                    groupTitle: wordZText("目标语料", "Target", mode: .system)
                )
            )
        }

        for referenceCorpus in sentiment.selectedReferenceCorpusItems() {
            let opened = try await flowCoordinator.analysisWorkflow.repository.openSavedCorpus(corpusId: referenceCorpus.id)
            texts.append(
                SentimentInputText(
                    id: "reference::\(referenceCorpus.id)",
                    sourceID: referenceCorpus.id,
                    sourceTitle: referenceCorpus.name,
                    text: opened.content,
                    groupID: "reference",
                    groupTitle: wordZText("参照语料", "Reference", mode: .system)
                )
            )
        }
        return sentiment.currentRunRequest(texts: texts)
    }

    private func applyLatestSentimentResult(_ result: SentimentRunResult) {
        sentiment.apply(result)
        guard let presentationResult = sentiment.presentationResult else { return }
        switch result.request.source {
        case .corpusCompare:
            compare.applyCompareSentimentResult(presentationResult, languageMode: .system)
            topics.applySentimentPresentationResult(presentationResult, languageMode: .system)
        case .topicSegments:
            topics.applySentimentPresentationResult(presentationResult, languageMode: .system)
        case .openedCorpus, .pastedText, .kwicVisible:
            break
        }
    }
}
