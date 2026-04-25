import Foundation
import NaturalLanguage

private struct CompareTopicsParagraphContext: Equatable, Sendable {
    let globalParagraphIndex: Int
    let sourceParagraphIndex: Int
    let sourceID: String
    let sourceTitle: String
    let groupID: String
    let groupTitle: String
}

@MainActor
extension WorkspaceTopicsWorkflowService {
    func prepareCompareTopics(
        features: WorkspaceTopicsWorkflowContext,
        markWorkspaceEdited: @escaping @MainActor (WorkspaceFeatureSet) -> Void
    ) -> Bool {
        let featureSet = features.withFeatureSet { $0 }
        guard let row = selectedCompareResultRow(features: features) else {
            features.sidebar.setError("请先选择一条 Compare 结果。")
            return false
        }

        let targetCorpora = features.compare.selectedTargetCorpusItems()
        guard !targetCorpora.isEmpty else {
            features.sidebar.setError(
                wordZText(
                    "请至少保留一条目标语料后再打开 Compare x Topics。",
                    "Keep at least one target corpus selected before opening Compare x Topics.",
                    mode: .system
                )
            )
            return false
        }

        let referenceCorpora = features.compare.selectedReferenceCorpusItems()
        guard !referenceCorpora.isEmpty else {
            features.sidebar.setError(
                wordZText(
                    "Compare x Topics 需要固定参考语料或参考语料集，请先选择 reference scope。",
                    "Compare x Topics needs a fixed reference corpus or corpus set. Choose a reference scope first.",
                    mode: .system
                )
            )
            return false
        }

        features.topics.compareDrilldownContext = TopicsCompareDrilldownContext(
            focusTerm: row.word,
            targetCorpora: targetCorpora,
            referenceCorpora: referenceCorpora
        )
        features.topics.query = row.word
        features.topics.selectedClusterID = nil
        features.topics.selectedRowID = nil
        features.shell.selectedTab = .topics
        markWorkspaceEdited(featureSet)
        return true
    }

    func runCompareTopics(
        context: TopicsCompareDrilldownContext,
        features: WorkspaceTopicsWorkflowContext,
        syncFeatureContexts: @escaping @MainActor (WorkspaceFeatureSet) -> Void
    ) async {
        let featureSet = features.withFeatureSet { $0 }
        guard !isRunningTopicsAnalysis else { return }
        isRunningTopicsAnalysis = true
        var taskID: UUID?
        defer { isRunningTopicsAnalysis = false }

        do {
            guard context.hasReferenceScope else {
                features.sidebar.setError(
                    wordZText(
                        "Compare x Topics 需要固定参考语料范围。",
                        "Compare x Topics requires a fixed reference scope.",
                        mode: .system
                    )
                )
                return
            }

            analysisWorkflow.setBusy(true, features: featureSet)
            defer { analysisWorkflow.setBusy(false, features: featureSet) }

            let options = topicAnalysisOptions(for: features.topics)
            let payload = try await buildCompareTopicsPayload(context: context)
            let createdTaskID = taskCenter.beginTask(
                title: wordZText("Compare x Topics", "Compare x Topics", mode: .system),
                detail: wordZText("正在准备 target / reference 主题建模…", "Preparing target / reference topic modeling…", mode: .system),
                progress: 0
            )
            taskID = createdTaskID

            let analysisTask = Task { () throws -> TopicAnalysisResult in
                if let progressRepository = repository as? TopicProgressReportingRepository {
                    return try await progressRepository.runTopics(text: payload.text, options: options) { [weak taskCenter] progress in
                        Task { @MainActor in
                            taskCenter?.updateTask(
                                id: createdTaskID,
                                detail: self.analysisWorkflow.localizedTopicProgressDetail(progress),
                                progress: progress.progress
                            )
                        }
                    }
                }
                return try await self.repository.runTopics(text: payload.text, options: options)
            }
            taskCenter.registerCancelHandler(id: createdTaskID) {
                analysisTask.cancel()
            }

            let result = try await analysisTask.value
            features.topics.apply(
                applyingCompareTopicsParagraphContexts(
                    payload.paragraphContexts,
                    to: result
                )
            )
            analysisWorkflow.completeRun(
                selecting: .topics,
                features: featureSet,
                syncFeatureContexts: syncFeatureContexts
            )
            features.sidebar.clearError()
            taskCenter.completeTask(
                id: createdTaskID,
                detail: wordZText("Compare x Topics 结果已准备完成。", "Compare x Topics results are ready.", mode: .system)
            )
        } catch is CancellationError {
            features.sidebar.clearError()
        } catch {
            features.sidebar.setError(error.localizedDescription)
            if let taskID {
                taskCenter.failTask(id: taskID, detail: error.localizedDescription)
            }
        }
    }

    private func buildCompareTopicsPayload(
        context: TopicsCompareDrilldownContext
    ) async throws -> (text: String, paragraphContexts: [Int: CompareTopicsParagraphContext]) {
        var combinedParagraphs: [String] = []
        var paragraphContexts: [Int: CompareTopicsParagraphContext] = [:]
        var globalParagraphIndex = 0

        for corpus in context.targetCorpora {
            let opened = try await repository.openSavedCorpus(corpusId: corpus.id)
            let paragraphTexts = topicParagraphTexts(in: opened.content)
            for (sourceParagraphIndex, paragraphText) in paragraphTexts.enumerated() {
                globalParagraphIndex += 1
                combinedParagraphs.append(paragraphText)
                paragraphContexts[globalParagraphIndex] = CompareTopicsParagraphContext(
                    globalParagraphIndex: globalParagraphIndex,
                    sourceParagraphIndex: sourceParagraphIndex + 1,
                    sourceID: corpus.id,
                    sourceTitle: corpus.name,
                    groupID: "target",
                    groupTitle: wordZText("目标语料", "Target", mode: .system)
                )
            }
        }

        for corpus in context.referenceCorpora {
            let opened = try await repository.openSavedCorpus(corpusId: corpus.id)
            let paragraphTexts = topicParagraphTexts(in: opened.content)
            for (sourceParagraphIndex, paragraphText) in paragraphTexts.enumerated() {
                globalParagraphIndex += 1
                combinedParagraphs.append(paragraphText)
                paragraphContexts[globalParagraphIndex] = CompareTopicsParagraphContext(
                    globalParagraphIndex: globalParagraphIndex,
                    sourceParagraphIndex: sourceParagraphIndex + 1,
                    sourceID: corpus.id,
                    sourceTitle: corpus.name,
                    groupID: "reference",
                    groupTitle: wordZText("参考语料", "Reference", mode: .system)
                )
            }
        }

        let text = combinedParagraphs.joined(separator: "\n\n")
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NSError(
                domain: "WordZMac.CompareTopics",
                code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey: wordZText(
                        "当前 Compare scope 没有可用于 Topics 建模的文本段落。",
                        "The current compare scope does not contain paragraphs that can be used for topic modeling.",
                        mode: .system
                    )
                ]
            )
        }

        return (text, paragraphContexts)
    }

    private func topicParagraphTexts(in text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .paragraph)
        tokenizer.string = text
        var paragraphs: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let paragraph = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !paragraph.isEmpty {
                paragraphs.append(paragraph)
            }
            return true
        }
        return paragraphs
    }

    private func applyingCompareTopicsParagraphContexts(
        _ paragraphContexts: [Int: CompareTopicsParagraphContext],
        to result: TopicAnalysisResult
    ) -> TopicAnalysisResult {
        let enrichedSegments = result.segments.map { segment in
            let context = paragraphContexts[segment.paragraphIndex]
            return TopicSegmentRow(
                id: segment.id,
                topicID: segment.topicID,
                paragraphIndex: segment.paragraphIndex,
                text: segment.text,
                similarityScore: segment.similarityScore,
                isOutlier: segment.isOutlier,
                sourceID: context?.sourceID,
                sourceTitle: context?.sourceTitle,
                groupID: context?.groupID,
                groupTitle: context?.groupTitle,
                sourceParagraphIndex: context?.sourceParagraphIndex
            )
        }

        return TopicAnalysisResult(
            modelVersion: result.modelVersion,
            modelProvider: result.modelProvider,
            usesFallbackProvider: result.usesFallbackProvider,
            diagnostics: result.diagnostics,
            clusters: result.clusters,
            segments: enrichedSegments,
            totalSegments: result.totalSegments,
            clusteredSegments: result.clusteredSegments,
            outlierCount: result.outlierCount,
            warnings: result.warnings
        )
    }

    private func selectedCompareResultRow(features: WorkspaceTopicsWorkflowContext) -> CompareRow? {
        guard let result = features.compare.result else { return nil }
        let rowID = features.compare.selectedSceneRow?.id ?? features.compare.selectedRowID
        guard let rowID else { return result.rows.first }
        return result.rows.first(where: { $0.id == rowID }) ?? result.rows.first
    }
}
