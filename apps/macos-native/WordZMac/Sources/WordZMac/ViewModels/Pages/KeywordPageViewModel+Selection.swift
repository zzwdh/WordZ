import Foundation

extension KeywordPageViewModel {
    var canRun: Bool {
        canResolveFocusSelection && canResolveReferenceSelection
    }

    var canResolveFocusSelection: Bool {
        switch focusSelectionKind {
        case .singleCorpus:
            return selectedTargetCorpusItem() != nil
        case .selectedCorpora, .namedCorpusSet:
            return !resolvedFocusCorpusItems().isEmpty
        }
    }

    var canResolveReferenceSelection: Bool {
        switch referenceSourceKind {
        case .singleCorpus:
            return selectedReferenceCorpusItem() != nil
        case .namedCorpusSet:
            return !resolvedReferenceCorpusItems().isEmpty
        case .importedWordList:
            return importedReferenceParseResult.hasAcceptedItems
        }
    }

    var targetCorpusIDSnapshot: String {
        selectedTargetCorpusItem()?.id ?? resolvedFocusCorpusItems().first?.id ?? ""
    }

    var referenceCorpusIDSnapshot: String {
        selectedReferenceCorpusItem()?.id ?? resolvedReferenceCorpusItems().first?.id ?? ""
    }

    var selectedSceneRow: KeywordSceneRow? {
        guard let scene else { return nil }
        if let selectedRowID,
           let row = scene.rows.first(where: { $0.id == selectedRowID }) {
            return row
        }
        return scene.rows.first
    }

    var selectedKeywordRow: KeywordSuiteRow? {
        guard activeTab != .lists,
              let selectedRowID else {
            return currentKeywordRows.first
        }
        return currentKeywordRows.first(where: { $0.id == selectedRowID }) ?? currentKeywordRows.first
    }

    var selectedSavedList: KeywordSavedList? {
        guard let selectedSavedListID else { return savedLists.first }
        return savedLists.first(where: { $0.id == selectedSavedListID }) ?? savedLists.first
    }

    var comparisonSavedList: KeywordSavedList? {
        guard let comparisonSavedListID else {
            return savedLists.first(where: { $0.id != selectedSavedListID })
        }
        return savedLists.first(where: { $0.id == comparisonSavedListID })
    }

    var currentKeywordRows: [KeywordSuiteRow] {
        guard let result else { return [] }
        switch activeTab {
        case .words:
            return result.words
        case .terms:
            return result.terms
        case .ngrams:
            return result.ngrams
        case .lists:
            return []
        }
    }

    var currentResultGroup: KeywordResultGroup? {
        switch activeTab {
        case .words:
            return .words
        case .terms:
            return .terms
        case .ngrams:
            return .ngrams
        case .lists:
            return nil
        }
    }

    var orderedFocusCorpusIDs: [String] {
        availableCorpora.map(\.id).filter { selectedFocusCorpusIDs.contains($0) }
    }

    func selectedTargetCorpusItem() -> LibraryCorpusItem? {
        guard focusSelectionKind == .singleCorpus,
              let selectedFocusCorpusID else { return nil }
        return availableCorpora.first(where: { $0.id == selectedFocusCorpusID })
    }

    func selectedReferenceCorpusItem() -> LibraryCorpusItem? {
        guard referenceSourceKind == .singleCorpus,
              let selectedReferenceCorpusID else { return nil }
        return availableCorpora.first(where: { $0.id == selectedReferenceCorpusID })
    }

    func selectedFocusCorpusSet() -> LibraryCorpusSetItem? {
        guard let selectedFocusCorpusSetID else { return nil }
        return availableCorpusSets.first(where: { $0.id == selectedFocusCorpusSetID })
    }

    func selectedReferenceCorpusSet() -> LibraryCorpusSetItem? {
        guard let selectedReferenceCorpusSetID else { return nil }
        return availableCorpusSets.first(where: { $0.id == selectedReferenceCorpusSetID })
    }

    func resolvedFocusCorpusItems() -> [LibraryCorpusItem] {
        switch focusSelectionKind {
        case .singleCorpus:
            return selectedTargetCorpusItem().map { [$0] } ?? []
        case .selectedCorpora:
            return availableCorpora.filter { selectedFocusCorpusIDs.contains($0.id) }
        case .namedCorpusSet:
            let setIDs = Set(selectedFocusCorpusSet()?.corpusIDs ?? [])
            return availableCorpora.filter { setIDs.contains($0.id) }
        }
    }

    func resolvedReferenceCorpusItems() -> [LibraryCorpusItem] {
        switch referenceSourceKind {
        case .singleCorpus:
            return selectedReferenceCorpusItem().map { [$0] } ?? []
        case .namedCorpusSet:
            let setIDs = Set(selectedReferenceCorpusSet()?.corpusIDs ?? [])
            return availableCorpora.filter { setIDs.contains($0.id) }
        case .importedWordList:
            return []
        }
    }
}
