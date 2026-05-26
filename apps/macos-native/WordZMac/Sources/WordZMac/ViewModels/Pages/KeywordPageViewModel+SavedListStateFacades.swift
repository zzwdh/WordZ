import Foundation

extension KeywordPageViewModel {
    var savedListName: String {
        get { savedListState.savedListName }
        set { updateSavedListState { $0.savedListName = newValue } }
    }

    var savedListViewMode: KeywordSavedListViewMode {
        get { savedListState.savedListViewMode }
        set {
            guard savedListState.savedListViewMode != newValue else { return }
            updateSavedListState { $0.savedListViewMode = newValue }
            rebuildScene()
        }
    }

    var selectedSavedListID: String? {
        get { savedListState.selectedSavedListID }
        set {
            guard savedListState.selectedSavedListID != newValue else { return }
            updateSavedListState { $0.selectedSavedListID = newValue }
            handleSavedListSelectionChange()
        }
    }

    var comparisonSavedListID: String? {
        get { savedListState.comparisonSavedListID }
        set {
            guard savedListState.comparisonSavedListID != newValue else { return }
            updateSavedListState { $0.comparisonSavedListID = newValue }
            handleSavedListSelectionChange()
        }
    }

    var savedLists: [KeywordSavedList] {
        get { savedListState.savedLists }
        set { updateSavedListState { $0.savedLists = newValue } }
    }

    private func updateSavedListState(_ mutation: (inout KeywordSavedListState) -> Void) {
        var nextState = savedListState
        mutation(&nextState)
        savedListState = nextState
    }
}
