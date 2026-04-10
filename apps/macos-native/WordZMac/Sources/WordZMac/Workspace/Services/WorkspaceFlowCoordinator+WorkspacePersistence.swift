import Foundation

@MainActor
extension WorkspaceFlowCoordinator {
    func persistWorkspaceState(
        features: WorkspaceFeatureSet,
        refreshPresentationAfterSave: Bool = true,
        syncWindowAfterSave: Bool = true
    ) {
        guard !sessionStore.isRestoringState else { return }
        let draft = currentWorkspaceDraft(features: features)

        Task {
            do {
                try await repository.saveWorkspaceState(draft)
                await MainActor.run {
                    self.sessionStore.applySavedDraft(draft)
                    if refreshPresentationAfterSave {
                        self.applyWorkspacePresentation(features: features)
                    }
                    if syncWindowAfterSave {
                        self.syncWindowDocumentState(features: features)
                    }
                }
            } catch {
                await MainActor.run {
                    features.sidebar.setError(error.localizedDescription)
                }
            }
        }
    }

    func currentWorkspaceDraft(features: WorkspaceFeatureSet) -> WorkspaceStateDraft {
        let searchState = makeSearchPersistenceState(features: features)
        return workspacePersistence.buildDraft(
            selectedTab: features.shell.selectedTab,
            selectedFolderID: features.library.selectedFolderID ?? "all",
            selectedCorpusSetID: features.sidebar.selectedCorpusSetID ?? "",
            selectedCorpus: features.sidebar.selectedCorpus,
            openedCorpus: sessionStore.openedCorpus,
            searchQuery: searchState.query,
            searchOptions: searchState.options,
            stopwordFilter: searchState.stopwordFilter,
            tokenizeLanguagePreset: features.tokenize.languagePreset,
            tokenizeLemmaStrategy: features.tokenize.lemmaStrategy,
            compareReferenceCorpusID: features.compare.selectedReferenceCorpusIDSnapshot,
            compareSelectedCorpusIDs: features.compare.selectedCorpusIDsSnapshot,
            keywordTargetCorpusID: features.keyword.targetCorpusIDSnapshot,
            keywordReferenceCorpusID: features.keyword.referenceCorpusIDSnapshot,
            keywordLowercased: features.keyword.lowercased,
            keywordRemovePunctuation: features.keyword.removePunctuation,
            keywordMinimumFrequency: features.keyword.minimumFrequency,
            keywordStatistic: features.keyword.statistic,
            keywordStopwordFilter: features.keyword.stopwordFilter,
            ngramSize: features.ngram.ngramSize,
            ngramPageSize: features.ngram.pageSizeSnapshotValue,
            kwicLeftWindow: features.kwic.leftWindow,
            kwicRightWindow: features.kwic.rightWindow,
            collocateLeftWindow: features.collocate.leftWindow,
            collocateRightWindow: features.collocate.rightWindow,
            collocateMinFreq: features.collocate.minFreq,
            topicsMinTopicSize: features.topics.minTopicSize,
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

    func makeSearchPersistenceState(features: WorkspaceFeatureSet) -> (
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
        case .keyword:
            return ("", .default, .default)
        case .ngram:
            return (
                features.ngram.normalizedQuery,
                features.ngram.searchOptions,
                features.ngram.stopwordFilter
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

    func sceneStoreTopicsPageSize(_ features: WorkspaceFeatureSet) -> String {
        features.topics.scene?.controls.selectedPageSize.title(in: .system) ?? "50"
    }
}
