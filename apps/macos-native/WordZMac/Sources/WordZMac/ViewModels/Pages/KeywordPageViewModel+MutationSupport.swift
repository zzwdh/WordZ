import Foundation

extension KeywordPageViewModel {
    func handleSelectionConfigurationChange() {
        guard !isApplyingState else { return }
        applyStateChange {
            normalizeSelections()
        }
        handleInputChange()
    }

    func performSelectionMutation(_ mutation: () -> Void) {
        applyStateChange {
            mutation()
            normalizeSelections()
        }
        handleInputChange()
    }

    func handleSavedListSelectionChange() {
        guard !isApplyingState else { return }
        applyStateChange {
            normalizeSavedListSelections()
        }
        rebuildScene()
    }

    func performSavedListSelectionMutation(_ mutation: () -> Void) {
        applyStateChange {
            mutation()
            normalizeSavedListSelections()
        }
        rebuildScene()
    }
}
