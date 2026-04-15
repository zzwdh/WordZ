import Foundation

extension KeywordPageViewModel {
    func apply(_ snapshot: WorkspaceSnapshotSummary) {
        let configuration = snapshot.keywordSuiteConfiguration
        applyStateChange(rebuildScene: {
            self.normalizeSelections()
            self.rebuildScene()
        }) {
            activeTab = snapshot.keywordActiveTab
            focusSelectionKind = configuration.focusSelection.kind
            selectedFocusCorpusID = configuration.focusSelection.corpusIDs.first
            selectedFocusCorpusIDs = Set(configuration.focusSelection.corpusIDs)
            selectedFocusCorpusSetID = configuration.focusSelection.corpusSetID.isEmpty ? nil : configuration.focusSelection.corpusSetID
            referenceSourceKind = configuration.referenceSource.kind
            selectedReferenceCorpusID = configuration.referenceSource.corpusID.isEmpty ? nil : configuration.referenceSource.corpusID
            selectedReferenceCorpusSetID = configuration.referenceSource.corpusSetID.isEmpty ? nil : configuration.referenceSource.corpusSetID
            importedReferenceListText = configuration.referenceSource.importedListText
            importedReferenceListSourceName = configuration.referenceSource.importedListSourceName
            importedReferenceListImportedAt = configuration.referenceSource.importedListImportedAt
            unit = configuration.unit
            direction = configuration.direction
            statistic = configuration.statistic
            languagePreset = configuration.tokenFilters.languagePreset
            stopwordFilter = configuration.tokenFilters.stopwordFilter
            minFocusFrequency = "\(configuration.thresholds.minFocusFreq)"
            minReferenceFrequency = "\(configuration.thresholds.minReferenceFreq)"
            minCombinedFrequency = "\(configuration.thresholds.minCombinedFreq)"
            maxPValue = String(configuration.thresholds.maxPValue)
            minAbsLogRatio = String(configuration.thresholds.minAbsLogRatio)
            selectedScripts = Set(configuration.tokenFilters.scripts)
            selectedLexicalClasses = Set(configuration.tokenFilters.lexicalClasses)
        }
    }

    func syncLibrarySnapshot(_ snapshot: LibrarySnapshot) {
        availableCorpora = snapshot.corpora
        availableCorpusSets = snapshot.corpusSets
        corpusOptions = snapshot.corpora.map {
            KeywordCorpusOptionSceneItem(id: $0.id, title: $0.name, subtitle: $0.folderName)
        }
        corpusSetOptions = snapshot.corpusSets.map {
            KeywordCorpusSetOptionSceneItem(
                id: $0.id,
                title: $0.name,
                subtitle: "\($0.corpusIDs.count) \(wordZText("条语料", "corpora", mode: .system))"
            )
        }
        normalizeSelections()
        rebuildScene()
    }

    func apply(_ result: KeywordSuiteResult) {
        applyStateChange(rebuildScene: rebuildScene) {
            self.result = result
            currentPage = 1
        }
    }

    func apply(_ result: KeywordResult) {
        let suiteResult = KeywordSuiteResult(
            configuration: suiteConfiguration,
            focusSummary: KeywordSuiteScopeSummary(
                label: result.targetCorpus.corpusName,
                corpusCount: 1,
                corpusIDs: [result.targetCorpus.corpusId],
                corpusNames: [result.targetCorpus.corpusName],
                tokenCount: result.targetCorpus.tokenCount,
                typeCount: result.targetCorpus.typeCount,
                isWordList: false
            ),
            referenceSummary: KeywordSuiteScopeSummary(
                label: result.referenceCorpus.corpusName,
                corpusCount: 1,
                corpusIDs: [result.referenceCorpus.corpusId],
                corpusNames: [result.referenceCorpus.corpusName],
                tokenCount: result.referenceCorpus.tokenCount,
                typeCount: result.referenceCorpus.typeCount,
                isWordList: false
            ),
            words: result.rows.map {
                KeywordSuiteRow(
                    group: .words,
                    item: $0.word,
                    direction: .positive,
                    focusFrequency: $0.targetFrequency,
                    referenceFrequency: $0.referenceFrequency,
                    focusNormalizedFrequency: $0.targetNormalizedFrequency,
                    referenceNormalizedFrequency: $0.referenceNormalizedFrequency,
                    keynessScore: $0.keynessScore,
                    logRatio: $0.logRatio,
                    pValue: $0.pValue,
                    focusRange: 1,
                    referenceRange: $0.referenceFrequency > 0 ? 1 : 0,
                    example: "",
                    focusExampleCorpusID: result.targetCorpus.corpusId,
                    referenceExampleCorpusID: result.referenceCorpus.corpusId
                )
            },
            terms: [],
            ngrams: []
        )
        apply(suiteResult)
    }

    func applySavedLists(_ lists: [KeywordSavedList]) {
        applyStateChange(rebuildScene: rebuildScene) {
            self.savedLists = lists.sorted { $0.updatedAt > $1.updatedAt }
            normalizeSavedListSelections()
        }
    }

    func recordPendingRunConfiguration() {
        lastRunConfiguration = currentRunConfiguration
    }

    func applyImportedReferenceList(
        text: String,
        sourceName: String?,
        importedAt: String
    ) {
        applyStateChange(rebuildScene: rebuildScene) {
            referenceSourceKind = .importedWordList
            importedReferenceListText = text
            importedReferenceListSourceName = sourceName
            importedReferenceListImportedAt = importedAt
        }
    }

    func reset() {
        resetState(cancelPendingSceneBuilds: invalidatePendingSceneBuilds) {
            self.activeTab = .words
            self.focusSelectionKind = .singleCorpus
            self.referenceSourceKind = .singleCorpus
            self.selectedFocusCorpusID = nil
            self.selectedFocusCorpusIDs = []
            self.selectedFocusCorpusSetID = nil
            self.selectedReferenceCorpusID = nil
            self.selectedReferenceCorpusSetID = nil
            self.importedReferenceListText = ""
            self.importedReferenceListSourceName = nil
            self.importedReferenceListImportedAt = nil
            self.unit = .normalizedSurface
            self.direction = .positive
            self.statistic = .logLikelihood
            self.languagePreset = .mixedChineseEnglish
            self.stopwordFilter = .default
            self.minFocusFrequency = "2"
            self.minReferenceFrequency = "0"
            self.minCombinedFrequency = "2"
            self.maxPValue = "1.0"
            self.minAbsLogRatio = "0.0"
            self.selectedScripts = []
            self.selectedLexicalClasses = []
            self.isEditingStopwords = false
            self.savedListName = ""
            self.savedListViewMode = .pairwiseDiff
            self.selectedSavedListID = nil
            self.comparisonSavedListID = nil
            self.result = nil
            self.sortMode = .keynessDescending
            self.pageSize = .fifty
            self.currentPage = 1
            self.visibleColumns = Self.defaultVisibleColumns
            self.selectedRowID = nil
            self.lastRunConfiguration = nil
            self.scene = nil
            self.normalizeSelections()
        }
    }
}
