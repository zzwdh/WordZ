import Foundation

extension KeywordPageViewModel {
    func apply(_ snapshot: WorkspaceSnapshotSummary) {
        applyStateChange(rebuildScene: {
            self.normalizeSelections()
            self.rebuildScene()
        }) {
            selectedTargetCorpusID = snapshot.keywordTargetCorpusID.isEmpty ? selectedTargetCorpusID : snapshot.keywordTargetCorpusID
            selectedReferenceCorpusID = snapshot.keywordReferenceCorpusID.isEmpty ? selectedReferenceCorpusID : snapshot.keywordReferenceCorpusID
            lowercased = snapshot.keywordLowercased
            removePunctuation = snapshot.keywordRemovePunctuation
            minimumFrequency = snapshot.keywordMinimumFrequency
            statistic = snapshot.keywordStatistic
            stopwordFilter = snapshot.keywordStopwordFilter
        }
    }

    func syncLibrarySnapshot(_ snapshot: LibrarySnapshot) {
        availableCorpora = snapshot.corpora
        corpusOptions = snapshot.corpora.map {
            KeywordCorpusOptionSceneItem(id: $0.id, title: $0.name, subtitle: $0.folderName)
        }
        normalizeSelections()
    }

    func apply(_ result: KeywordResult) {
        applyStateChange(rebuildScene: rebuildScene) {
            self.result = result
            currentPage = 1
            invalidateSortedRowsCache()
        }
    }

    func recordPendingRunConfiguration() {
        lastRunConfiguration = currentRunConfiguration
    }

    func reset() {
        resetState(cancelPendingSceneBuilds: invalidatePendingSceneBuilds) {
            self.lowercased = true
            self.removePunctuation = true
            self.minimumFrequency = "2"
            self.statistic = .logLikelihood
            self.stopwordFilter = .default
            self.isEditingStopwords = false
            self.result = nil
            self.sortMode = .scoreDescending
            self.pageSize = .fifty
            self.currentPage = 1
            self.visibleColumns = KeywordPageViewModel.defaultVisibleColumns
            self.selectedRowID = nil
            self.lastRunConfiguration = nil
            self.invalidateSortedRowsCache()
            self.scene = nil
            self.normalizeSelections()
        }
    }
}
