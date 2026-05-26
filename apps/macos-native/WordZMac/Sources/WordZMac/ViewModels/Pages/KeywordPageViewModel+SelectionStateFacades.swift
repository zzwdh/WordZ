import Foundation

extension KeywordPageViewModel {
    var focusSelectionKind: KeywordTargetSelectionKind {
        get { selectionState.focusSelectionKind }
        set {
            guard selectionState.focusSelectionKind != newValue else { return }
            updateSelectionState { $0.focusSelectionKind = newValue }
            handleSelectionConfigurationChange()
        }
    }

    var referenceSourceKind: KeywordReferenceSourceKind {
        get { selectionState.referenceSourceKind }
        set {
            guard selectionState.referenceSourceKind != newValue else { return }
            updateSelectionState { $0.referenceSourceKind = newValue }
            handleSelectionConfigurationChange()
        }
    }

    var selectedFocusCorpusID: String? {
        get { selectionState.selectedFocusCorpusID }
        set {
            guard selectionState.selectedFocusCorpusID != newValue else { return }
            updateSelectionState { $0.selectedFocusCorpusID = newValue }
            handleSelectionConfigurationChange()
        }
    }

    var selectedFocusCorpusIDs: Set<String> {
        get { selectionState.selectedFocusCorpusIDs }
        set {
            guard selectionState.selectedFocusCorpusIDs != newValue else { return }
            updateSelectionState { $0.selectedFocusCorpusIDs = newValue }
            handleSelectionConfigurationChange()
        }
    }

    var selectedFocusCorpusSetID: String? {
        get { selectionState.selectedFocusCorpusSetID }
        set {
            guard selectionState.selectedFocusCorpusSetID != newValue else { return }
            updateSelectionState { $0.selectedFocusCorpusSetID = newValue }
            handleSelectionConfigurationChange()
        }
    }

    var selectedReferenceCorpusID: String? {
        get { selectionState.selectedReferenceCorpusID }
        set {
            guard selectionState.selectedReferenceCorpusID != newValue else { return }
            updateSelectionState { $0.selectedReferenceCorpusID = newValue }
            handleSelectionConfigurationChange()
        }
    }

    var selectedReferenceCorpusSetID: String? {
        get { selectionState.selectedReferenceCorpusSetID }
        set {
            guard selectionState.selectedReferenceCorpusSetID != newValue else { return }
            updateSelectionState { $0.selectedReferenceCorpusSetID = newValue }
            handleSelectionConfigurationChange()
        }
    }

    var importedReferenceListText: String {
        get { selectionState.importedReferenceListText }
        set {
            guard selectionState.importedReferenceListText != newValue else { return }
            updateSelectionState { $0.importedReferenceListText = newValue }
            handleInputChange()
        }
    }

    var importedReferenceListSourceName: String? {
        get { selectionState.importedReferenceListSourceName }
        set { updateSelectionState { $0.importedReferenceListSourceName = newValue } }
    }

    var importedReferenceListImportedAt: String? {
        get { selectionState.importedReferenceListImportedAt }
        set { updateSelectionState { $0.importedReferenceListImportedAt = newValue } }
    }

    private func updateSelectionState(_ mutation: (inout KeywordSuiteSelectionState) -> Void) {
        var nextState = selectionState
        mutation(&nextState)
        selectionState = nextState
    }
}
