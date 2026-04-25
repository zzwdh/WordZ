import Foundation

@MainActor
final class WorkspacePersistenceWorkflowService {
    let repository: any WorkspaceRepository
    let workspacePersistence: WorkspacePersistenceService
    let workspacePresentation: WorkspacePresentationService
    let sceneStore: WorkspaceSceneStore
    let windowDocumentController: any WindowDocumentSyncing
    let sessionStore: WorkspaceSessionStore
    let hostPreferencesStore: any NativeHostPreferencesStoring
    let hostActionService: any NativeHostActionServicing
    let persistenceActor: WorkspacePersistenceActor

    init(
        repository: any WorkspaceRepository,
        workspacePersistence: WorkspacePersistenceService,
        workspacePresentation: WorkspacePresentationService,
        sceneStore: WorkspaceSceneStore,
        windowDocumentController: any WindowDocumentSyncing,
        sessionStore: WorkspaceSessionStore,
        hostPreferencesStore: any NativeHostPreferencesStoring,
        hostActionService: any NativeHostActionServicing
    ) {
        self.repository = repository
        self.workspacePersistence = workspacePersistence
        self.workspacePresentation = workspacePresentation
        self.sceneStore = sceneStore
        self.windowDocumentController = windowDocumentController
        self.sessionStore = sessionStore
        self.hostPreferencesStore = hostPreferencesStore
        self.hostActionService = hostActionService
        self.persistenceActor = WorkspacePersistenceActor(
            saveOperation: { draft in
                try await repository.saveWorkspaceState(draft)
            }
        )
    }

    func persistWorkspaceState(
        features: WorkspaceFeatureSet,
        strategy: WorkspacePersistenceStrategy = .immediate,
        refreshPresentationAfterSave: Bool = true,
        syncWindowAfterSave: Bool = true,
        syncFeatureContexts: @escaping @MainActor (WorkspaceFeatureSet) -> Void
    ) {
        guard !sessionStore.isRestoringState else { return }
        let draft = currentWorkspaceDraft(features: features)

        Task {
            await self.persistenceActor.schedule(
                draft: draft,
                strategy: strategy,
                onPersisted: { savedDraft in
                    self.sessionStore.applySavedDraft(savedDraft)
                    if refreshPresentationAfterSave {
                        self.applyWorkspacePresentation(
                            features: features,
                            syncFeatureContexts: syncFeatureContexts
                        )
                    }
                    if syncWindowAfterSave {
                        self.syncWindowDocumentState(features: features)
                    }
                },
                onError: { error in
                    features.sidebar.setError(error.localizedDescription)
                }
            )
        }
    }

    func currentWorkspaceDraft(features: WorkspaceFeatureSet) -> WorkspaceStateDraft {
        let searchState = makeSearchPersistenceState(features: features)
        let annotationState = WorkspaceAnnotationState(
            profile: features.tokenize.annotationProfile,
            lexicalClasses: Array(features.keyword.selectedLexicalClasses).sorted { $0.rawValue < $1.rawValue },
            scripts: Array(features.keyword.selectedScripts).sorted { $0.rawValue < $1.rawValue }
        )
        return workspacePersistence.buildDraft(
            selectedTab: features.shell.selectedTab,
            selectedFolderID: features.library.selectedFolderID ?? "all",
            selectedCorpusSetID: features.sidebar.selectedCorpusSetID ?? "",
            selectedCorpus: features.sidebar.selectedCorpus,
            openedCorpus: sessionStore.openedCorpus,
            searchQuery: searchState.query,
            searchOptions: searchState.options,
            stopwordFilter: searchState.stopwordFilter,
            annotationProfile: annotationState.profile,
            annotationLexicalClasses: annotationState.lexicalClasses,
            annotationScripts: annotationState.scripts,
            tokenizeLanguagePreset: features.tokenize.languagePreset,
            tokenizeLemmaStrategy: features.tokenize.lemmaStrategy,
            compareReferenceCorpusID: features.compare.selectedReferenceCorpusIDSnapshot,
            compareSelectedCorpusIDs: features.compare.selectedCorpusIDsSnapshot,
            sentimentSource: features.sentiment.source,
            sentimentUnit: features.sentiment.unit,
            sentimentContextBasis: features.sentiment.contextBasis,
            sentimentBackend: features.sentiment.backend,
            sentimentDomainPackID: features.sentiment.selectedDomainPackID,
            sentimentRuleProfileID: features.sentiment.selectedRuleProfileID,
            sentimentCalibrationProfileID: features.sentiment.selectedCalibrationProfileID,
            sentimentChartKind: features.sentiment.chartKind,
            sentimentThresholdPreset: features.sentiment.thresholdPreset,
            sentimentDecisionThreshold: features.sentiment.decisionThreshold,
            sentimentMinimumEvidence: features.sentiment.minimumEvidence,
            sentimentNeutralBias: features.sentiment.neutralBias,
            sentimentRowFilterQuery: features.sentiment.rowFilterQuery,
            sentimentLabelFilter: features.sentiment.labelFilter,
            sentimentReviewFilter: features.sentiment.reviewFilter,
            sentimentReviewStatusFilter: features.sentiment.reviewStatusFilter,
            sentimentShowOnlyHardCases: features.sentiment.showOnlyHardCases,
            sentimentWorkspaceCalibrationProfile: features.sentiment.workspaceCalibrationProfile,
            sentimentImportedLexiconBundles: features.sentiment.importedLexiconBundles,
            sentimentSelectedCorpusIDs: Array(features.sentiment.selectedCorpusIDs).sorted(),
            sentimentReferenceCorpusID: features.sentiment.selectedReferenceCorpusID,
            keywordActiveTab: features.keyword.activeTab,
            keywordSuiteConfiguration: features.keyword.suiteConfiguration,
            keywordTargetCorpusID: features.keyword.targetCorpusIDSnapshot,
            keywordReferenceCorpusID: features.keyword.referenceCorpusIDSnapshot,
            keywordLowercased: features.keyword.lowercased,
            keywordRemovePunctuation: features.keyword.removePunctuation,
            keywordMinimumFrequency: features.keyword.minimumFrequency,
            keywordStatistic: features.keyword.statistic,
            keywordStopwordFilter: features.keyword.stopwordFilter,
            plotQuery: features.plot.normalizedQuery,
            plotSearchOptions: features.plot.searchOptions,
            ngramSize: features.ngram.ngramSize,
            ngramPageSize: features.ngram.pageSizeSnapshotValue,
            clusterSelectedN: features.cluster.selectedN,
            clusterMinFrequency: features.cluster.minimumFrequency,
            clusterSortMode: features.cluster.sortMode,
            clusterCaseSensitive: features.cluster.caseSensitive,
            clusterStopwordFilter: features.cluster.stopwordFilter,
            clusterPunctuationMode: features.cluster.punctuationMode,
            clusterSelectedPhrase: features.cluster.selectedRowID ?? "",
            clusterPageSize: features.cluster.pageSizeSnapshotValue,
            clusterReferenceCorpusID: features.cluster.referenceCorpusID,
            kwicLeftWindow: features.kwic.leftWindow,
            kwicRightWindow: features.kwic.rightWindow,
            collocateLeftWindow: features.collocate.leftWindow,
            collocateRightWindow: features.collocate.rightWindow,
            collocateMinFreq: features.collocate.minFreq,
            topicsMinTopicSize: features.topics.minTopicSize,
            topicsKeywordDisplayCount: features.topics.keywordDisplayCount,
            topicsIncludeOutliers: features.topics.includeOutliers,
            topicsPageSize: sceneStoreTopicsPageSize(features),
            topicsActiveTopicID: features.topics.scene?.selectedClusterID ?? "",
            frequencyNormalizationUnit: features.stats.metricDefinition.normalizationUnit,
            frequencyRangeMode: features.stats.metricDefinition.rangeMode,
            chiSquareA: features.chiSquare.a,
            chiSquareB: features.chiSquare.b,
            chiSquareC: features.chiSquare.c,
            chiSquareD: features.chiSquare.d,
            chiSquareUseYates: features.chiSquare.useYates
        )
    }

    func applyWorkspacePresentation(
        features: WorkspaceFeatureSet,
        syncFeatureContexts: @escaping @MainActor (WorkspaceFeatureSet) -> Void
    ) {
        let presentation = workspacePresentation.buildPresentation(
            appInfo: sceneStore.appInfoSnapshot,
            selectedCorpus: features.sidebar.selectedCorpus,
            openedCorpus: sessionStore.openedCorpus,
            workspaceSnapshot: sessionStore.workspaceSnapshot
        )
        sceneStore.applyPresentation(presentation)
        syncFeatureContexts(features)
    }

    func syncWindowDocumentState(features: WorkspaceFeatureSet) {
        let presentation = workspacePresentation.buildPresentation(
            appInfo: sceneStore.appInfoSnapshot,
            selectedCorpus: features.sidebar.selectedCorpus,
            openedCorpus: sessionStore.openedCorpus,
            workspaceSnapshot: sessionStore.workspaceSnapshot
        )
        windowDocumentController.sync(
            displayName: presentation.displayName,
            representedPath: presentation.representedPath,
            edited: sessionStore.isDocumentEdited
        )
    }

    func refreshRecentDocuments(features: WorkspaceFeatureSet) {
        guard let selectedCorpus = features.sidebar.selectedCorpus,
              let openedCorpus = sessionStore.openedCorpus else {
            return
        }
        do {
            let snapshot = try hostPreferencesStore.recordRecentDocument(
                corpusID: selectedCorpus.id,
                title: openedCorpus.displayName.isEmpty ? selectedCorpus.name : openedCorpus.displayName,
                subtitle: selectedCorpus.folderName,
                representedPath: openedCorpus.filePath
            )
            Task { await self.hostActionService.noteRecentDocument(path: openedCorpus.filePath) }
            features.settings.applyHostPreferences(snapshot, preservingRuntimeUpdatePolicy: true)
        } catch {
            features.settings.setSupportStatus("最近打开写入失败：\(error.localizedDescription)")
        }
    }

    private func makeSearchPersistenceState(features: WorkspaceFeatureSet) -> (
        query: String,
        options: SearchOptionsState,
        stopwordFilter: StopwordFilterState
    ) {
        switch features.shell.selectedTab {
        case .word:
            return (
                features.word.query.trimmingCharacters(in: .whitespacesAndNewlines),
                features.word.searchOptions,
                features.word.stopwordFilter
            )
        case .tokenize:
            return (
                features.tokenize.query.trimmingCharacters(in: .whitespacesAndNewlines),
                features.tokenize.searchOptions,
                features.tokenize.stopwordFilter
            )
        case .topics:
            return (
                features.topics.normalizedQuery,
                features.topics.searchOptions,
                features.topics.stopwordFilter
            )
        case .compare:
            return (
                features.compare.query.trimmingCharacters(in: .whitespacesAndNewlines),
                features.compare.searchOptions,
                features.compare.stopwordFilter
            )
        case .sentiment:
            return (
                features.sentiment.rowFilterQuery.trimmingCharacters(in: .whitespacesAndNewlines),
                .default,
                .default
            )
        case .keyword:
            return ("", .default, .default)
        case .ngram:
            return (
                features.ngram.normalizedQuery,
                features.ngram.searchOptions,
                features.ngram.stopwordFilter
            )
        case .plot:
            return (
                features.plot.normalizedQuery,
                features.plot.searchOptions,
                .default
            )
        case .cluster:
            return (
                features.cluster.normalizedQuery,
                features.cluster.searchOptions,
                .default
            )
        case .kwic:
            return (
                features.kwic.normalizedKeyword,
                features.kwic.searchOptions,
                features.kwic.stopwordFilter
            )
        case .collocate:
            return (
                features.collocate.normalizedKeyword,
                features.collocate.searchOptions,
                features.collocate.stopwordFilter
            )
        default:
            return ("", .default, .default)
        }
    }

    private func sceneStoreTopicsPageSize(_ features: WorkspaceFeatureSet) -> String {
        features.topics.scene?.controls.selectedPageSize.title(in: .system) ?? "50"
    }
}
