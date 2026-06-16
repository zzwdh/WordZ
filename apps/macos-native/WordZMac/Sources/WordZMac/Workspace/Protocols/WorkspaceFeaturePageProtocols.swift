import Foundation
import WordZShared

@MainActor
protocol WorkspaceTopicsPageState: AnyObject {
    var compareDrilldownContext: TopicsCompareDrilldownContext? { get set }
    var scene: TopicsSceneModel? { get }
    var result: TopicAnalysisResult? { get }
    var searchOptions: SearchOptionsState { get }
    var stopwordFilter: StopwordFilterState { get }
    var normalizedQuery: String { get }
    var minTopicSize: String { get }
    var keywordDisplayCount: String { get }
    var includeOutliers: Bool { get }
    var minTopicSizeValue: Int { get }
    var canAnalyzeVisibleTopicsInSentiment: Bool { get }
    var selectedClusterID: String? { get set }
    var selectedRowID: String? { get set }
    var query: String { get set }
    func apply(_ snapshot: WorkspaceSnapshotSummary)
    func apply(_ result: TopicAnalysisResult)
    func applySentimentPresentationResult(_ result: SentimentPresentationResult, languageMode: AppLanguageMode)
    func visibleTopicSegmentsForSentiment(from result: TopicAnalysisResult, focusedClusterID: String?) -> [TopicSegmentRow]
    func kwicDrilldownKeyword() -> String?
    func kwicDrilldownRow(from result: TopicAnalysisResult) -> TopicSegmentRow?
    func reset()
}

@MainActor
protocol WorkspaceSentimentPageState: AnyObject {
    var source: SentimentInputSource { get set }
    var unit: SentimentAnalysisUnit { get set }
    var contextBasis: SentimentContextBasis { get set }
    var backend: SentimentBackendKind { get }
    var selectedDomainPackID: SentimentDomainPackID { get }
    var selectedRuleProfileID: String { get }
    var selectedCalibrationProfileID: String { get }
    var chartKind: SentimentChartKind { get }
    var thresholdPreset: SentimentThresholdPreset { get }
    var decisionThreshold: Double { get }
    var minimumEvidence: Double { get }
    var neutralBias: Double { get }
    var rowFilterQuery: String { get set }
    var labelFilter: SentimentLabel? { get set }
    var reviewFilter: SentimentReviewFilter { get }
    var reviewStatusFilter: SentimentReviewStatusFilter { get }
    var showOnlyHardCases: Bool { get }
    var workspaceCalibrationProfile: SentimentCalibrationProfile { get }
    var importedLexiconBundles: [SentimentUserLexiconBundle] { get }
    var manualText: String { get set }
    var rawResult: SentimentRunResult? { get }
    var presentationResult: SentimentPresentationResult? { get }
    var reviewSamples: [SentimentReviewSample] { get }
    var selectedCorpusIDs: Set<String> { get set }
    var selectedReferenceCorpusID: String { get set }
    var topicSegmentsFocusClusterID: String? { get set }
    var selectedResultRow: SentimentRowResult? { get }
    var selectedEffectiveRow: SentimentEffectiveRow? { get }
    var selectedReviewSample: SentimentReviewSample? { get }
    func currentRunRequest(texts: [SentimentInputText]) -> SentimentRunRequest
    func apply(_ snapshot: WorkspaceSnapshotSummary)
    func apply(_ result: SentimentRunResult)
    func applyReviewSamples(_ samples: [SentimentReviewSample])
    func exportMetadataLines(annotationSummary: String, languageMode: AppLanguageMode) -> [String]
    func makeSelectedReviewSample(decision: SentimentReviewDecision) -> SentimentReviewSample?
    func selectedTargetCorpusItems() -> [LibraryCorpusItem]
    func selectedReferenceCorpusItems() -> [LibraryCorpusItem]
    func importUserLexiconBundle(_ bundle: SentimentUserLexiconBundle)
    func corpusCompareScopeSummary(in mode: AppLanguageMode) -> String
    func syncLibrarySnapshot(_ snapshot: LibrarySnapshot)
    func canRun(hasOpenedCorpus: Bool, hasKWICRows: Bool, hasTopicRows: Bool) -> Bool
    func reset()
}

extension TopicsPageViewModel: WorkspaceTopicsPageState {}
extension SentimentPageViewModel: WorkspaceSentimentPageState {}
