import Foundation

@MainActor
final class WorkspaceSentimentWorkflowService {
    let analysisWorkflow: WorkspaceAnalysisWorkflowService

    init(analysisWorkflow: WorkspaceAnalysisWorkflowService) {
        self.analysisWorkflow = analysisWorkflow
    }

    func runSentiment(
        features: WorkspaceSentimentWorkflowContext,
        syncFeatureContexts: @escaping @MainActor (WorkspaceFeatureSet) -> Void
    ) async {
        let featureSet = features.withFeatureSet { $0 }
        switch features.sentiment.source {
        case .openedCorpus:
            await analysisWorkflow.performOpenedCorpusRunTask(
                .sentiment,
                selecting: .sentiment,
                features: featureSet,
                syncFeatureContexts: syncFeatureContexts
            ) { corpus in
                let text = SentimentInputText(
                    id: features.sidebar.selectedCorpusID ?? UUID().uuidString,
                    sourceID: features.sidebar.selectedCorpusID,
                    sourceTitle: corpus.displayName.isEmpty ? wordZText("当前语料", "Opened Corpus", mode: .system) : corpus.displayName,
                    text: corpus.content,
                    groupID: "target",
                    groupTitle: wordZText("目标语料", "Target", mode: .system)
                )
                let request = features.sentiment.currentRunRequest(texts: [text])
                let result = try await self.analysisWorkflow.repository.runSentiment(request)
                features.sentiment.apply(result)
            }
        case .pastedText:
            let trimmed = features.sentiment.manualText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                features.sidebar.setError(wordZText("请先输入要分析的英文文本。", "Enter some English text to analyze first.", mode: .system))
                return
            }
            await analysisWorkflow.performResultRunTask(
                .sentiment,
                selecting: .sentiment,
                features: featureSet,
                syncFeatureContexts: syncFeatureContexts
            ) {
                let text = SentimentInputText(
                    id: "manual-text",
                    sourceTitle: wordZText("粘贴文本", "Pasted Text", mode: .system),
                    text: trimmed,
                    groupID: "manual",
                    groupTitle: wordZText("手动输入", "Manual Input", mode: .system)
                )
                let request = features.sentiment.currentRunRequest(texts: [text])
                let result = try await self.analysisWorkflow.repository.runSentiment(request)
                features.sentiment.apply(result)
            }
        case .kwicVisible:
            guard let scene = features.kwic.scene, !scene.rows.isEmpty else {
                features.sidebar.setError(wordZText("请先生成 KWIC 结果。", "Run KWIC first to analyze visible concordance lines.", mode: .system))
                return
            }
            let documentText = analysisWorkflow.sessionStore.openedCorpus?.content
            await analysisWorkflow.performResultRunTask(
                .sentiment,
                selecting: .sentiment,
                features: featureSet,
                syncFeatureContexts: syncFeatureContexts
            ) {
                let texts = scene.rows.map { row in
                    SentimentInputText(
                        id: row.id,
                        sourceID: features.sidebar.selectedCorpusID,
                        sourceTitle: wordZText("KWIC", "KWIC", mode: .system),
                        text: row.concordanceText,
                        sentenceID: row.sentenceId,
                        tokenIndex: row.sentenceTokenIndex,
                        groupID: "kwic",
                        groupTitle: wordZText("索引行", "Concordance", mode: .system),
                        documentText: documentText
                    )
                }
                let request = features.sentiment.currentRunRequest(texts: texts)
                let result = try await self.analysisWorkflow.repository.runSentiment(request)
                features.sentiment.apply(result)
            }
        case .corpusCompare:
            let targetCorpora = features.sentiment.selectedTargetCorpusItems()
            guard !targetCorpora.isEmpty else {
                features.sidebar.setError(wordZText("请至少选择一条目标语料。", "Select at least one target corpus first.", mode: .system))
                return
            }
            let referenceCorpora = features.sentiment.selectedReferenceCorpusItems()

            await analysisWorkflow.performResultRunTask(
                .sentiment,
                selecting: .sentiment,
                features: featureSet,
                syncFeatureContexts: syncFeatureContexts
            ) {
                var texts: [SentimentInputText] = []
                for corpus in targetCorpora {
                    let opened = try await self.analysisWorkflow.repository.openSavedCorpus(corpusId: corpus.id)
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

                for referenceCorpus in referenceCorpora {
                    let opened = try await self.analysisWorkflow.repository.openSavedCorpus(corpusId: referenceCorpus.id)
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

                let request = features.sentiment.currentRunRequest(texts: texts)
                let result = try await self.analysisWorkflow.repository.runSentiment(request)
                features.sentiment.apply(result)
                if let presentationResult = features.sentiment.presentationResult {
                    features.compare.applyCompareSentimentResult(presentationResult, languageMode: .system)
                    features.topics.applySentimentPresentationResult(presentationResult, languageMode: .system)
                }
            }
        case .topicSegments:
            assertionFailure("WorkspaceFlowCoordinator should route topic segment sentiment through WorkspaceTopicsWorkflowService.")
        }
    }
}

extension WorkspaceSentimentWorkflowService: WorkspaceSentimentWorkflowServing {}
