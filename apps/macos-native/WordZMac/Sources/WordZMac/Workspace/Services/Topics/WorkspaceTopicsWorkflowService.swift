import Foundation

@MainActor
final class WorkspaceTopicsWorkflowService {
    let repository: any WorkspaceRepository
    let sessionStore: WorkspaceSessionStore
    let taskCenter: NativeTaskCenter
    let analysisWorkflow: WorkspaceAnalysisWorkflowService
    var isRunningTopicsAnalysis = false

    init(
        repository: any WorkspaceRepository,
        sessionStore: WorkspaceSessionStore,
        taskCenter: NativeTaskCenter,
        analysisWorkflow: WorkspaceAnalysisWorkflowService
    ) {
        self.repository = repository
        self.sessionStore = sessionStore
        self.taskCenter = taskCenter
        self.analysisWorkflow = analysisWorkflow
    }

    func prepareTopicsKWIC(
        features: WorkspaceTopicsWorkflowContext,
        prepareCorpusSelectionChange: @escaping @MainActor (WorkspaceFeatureSet) -> Void,
        markWorkspaceEdited: @escaping @MainActor (WorkspaceFeatureSet) -> Void,
        syncFeatureContexts: @escaping @MainActor (WorkspaceFeatureSet) -> Void
    ) async -> Bool {
        let featureSet = features.withFeatureSet { $0 }
        guard let result = features.topics.result,
              let row = features.topics.kwicDrilldownRow(from: result) else {
            features.sidebar.setError(
                wordZText(
                    "请先选择一个带原文上下文的 Topics 片段。",
                    "Select a topic segment with source context before opening KWIC.",
                    mode: .system
                )
            )
            return false
        }

        guard let keyword = features.topics.kwicDrilldownKeyword() else {
            features.sidebar.setError(
                wordZText(
                    "当前 Topics 结果还没有可用于 KWIC 的聚焦词项。",
                    "The current Topics result does not have a usable focus term for KWIC yet.",
                    mode: .system
                )
            )
            return false
        }

        let corpusID = row.sourceID ?? features.sidebar.selectedCorpusID ?? sessionStore.openedCorpusSourceID
        guard let corpusID,
              features.sidebar.librarySnapshot.corpora.contains(where: { $0.id == corpusID }) else {
            features.sidebar.setError(
                wordZText(
                    "当前 Topics 片段没有可用的语料范围。",
                    "The selected topic segment does not have a usable corpus scope.",
                    mode: .system
                )
            )
            return false
        }

        do {
            try await analysisWorkflow.prepareDrilldownCorpusSelection(
                corpusID,
                features: featureSet,
                prepareCorpusSelectionChange: prepareCorpusSelectionChange,
                syncFeatureContexts: syncFeatureContexts
            )
        } catch {
            features.sidebar.setError(error.localizedDescription)
            return false
        }

        features.kwic.keyword = keyword
        features.kwic.searchOptions = features.topics.searchOptions
        if features.kwic.leftWindow.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            features.kwic.leftWindow = "5"
        }
        if features.kwic.rightWindow.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            features.kwic.rightWindow = "5"
        }
        features.shell.selectedTab = .kwic
        markWorkspaceEdited(featureSet)
        return true
    }

    func topicAnalysisOptions(
        for viewModel: any WorkspaceTopicsPageState,
        text: String? = nil
    ) -> TopicAnalysisOptions {
        TopicAnalysisOptions(
            granularity: .paragraph,
            language: topicAnalysisLanguage(for: text),
            minTopicSize: viewModel.minTopicSizeValue,
            includeOutliers: viewModel.includeOutliers,
            searchQuery: viewModel.normalizedQuery,
            searchOptions: viewModel.searchOptions,
            stopwordFilter: viewModel.stopwordFilter
        )
    }

    func topicAnalysisLanguage(for text: String?) -> String {
        guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return TopicAnalysisOptions.englishLanguage
        }

        var hasCJK = false
        var hasLatin = false
        for scalar in text.unicodeScalars {
            switch scalar.value {
            case 0x0041...0x005A, 0x0061...0x007A, 0x00C0...0x024F:
                hasLatin = true
            case 0x3040...0x30FF, 0x3400...0x4DBF, 0x4E00...0x9FFF, 0xF900...0xFAFF:
                hasCJK = true
            default:
                continue
            }
            if hasCJK && hasLatin {
                return TokenizeLanguagePreset.mixedChineseEnglish.rawValue
            }
        }

        if hasCJK {
            return TokenizeLanguagePreset.cjkFocused.rawValue
        }
        return TopicAnalysisOptions.englishLanguage
    }
}

extension WorkspaceTopicsWorkflowService: WorkspaceTopicsWorkflowServing {}
