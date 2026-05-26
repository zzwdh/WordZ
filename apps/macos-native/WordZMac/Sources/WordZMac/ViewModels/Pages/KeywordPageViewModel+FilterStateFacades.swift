import Foundation

extension KeywordPageViewModel {
    var annotationProfile: WorkspaceAnnotationProfile {
        get { filterState.annotationProfile }
        set {
            guard filterState.annotationProfile != newValue else { return }
            let oldUnit = filterState.unit
            updateFilterState { $0.annotationProfile = newValue }
            let nextUnit = newValue.keywordUnit
            if oldUnit != nextUnit {
                unit = nextUnit
            } else {
                handleInputChange()
            }
        }
    }

    var unit: KeywordUnit {
        get { filterState.unit }
        set {
            guard filterState.unit != newValue else { return }
            updateFilterState { $0.unit = newValue }
            handleInputChange()
        }
    }

    var direction: KeywordDirection {
        get { filterState.direction }
        set {
            guard filterState.direction != newValue else { return }
            updateFilterState { $0.direction = newValue }
            handleInputChange()
        }
    }

    var statistic: KeywordStatisticMethod {
        get { filterState.statistic }
        set {
            guard filterState.statistic != newValue else { return }
            updateFilterState { $0.statistic = newValue }
            handleInputChange()
        }
    }

    var languagePreset: TokenizeLanguagePreset {
        get { filterState.languagePreset }
        set {
            guard filterState.languagePreset != newValue else { return }
            updateFilterState { $0.languagePreset = newValue }
            handleInputChange()
        }
    }

    var stopwordFilter: StopwordFilterState {
        get { filterState.stopwordFilter }
        set {
            guard filterState.stopwordFilter != newValue else { return }
            updateFilterState { $0.stopwordFilter = newValue }
            handleInputChange()
        }
    }

    var minFocusFrequency: String {
        get { filterState.minFocusFrequency }
        set {
            guard filterState.minFocusFrequency != newValue else { return }
            updateFilterState { $0.minFocusFrequency = newValue }
            handleInputChange()
        }
    }

    var minReferenceFrequency: String {
        get { filterState.minReferenceFrequency }
        set {
            guard filterState.minReferenceFrequency != newValue else { return }
            updateFilterState { $0.minReferenceFrequency = newValue }
            handleInputChange()
        }
    }

    var minCombinedFrequency: String {
        get { filterState.minCombinedFrequency }
        set {
            guard filterState.minCombinedFrequency != newValue else { return }
            updateFilterState { $0.minCombinedFrequency = newValue }
            handleInputChange()
        }
    }

    var maxPValue: String {
        get { filterState.maxPValue }
        set {
            guard filterState.maxPValue != newValue else { return }
            updateFilterState { $0.maxPValue = newValue }
            handleInputChange()
        }
    }

    var minAbsLogRatio: String {
        get { filterState.minAbsLogRatio }
        set {
            guard filterState.minAbsLogRatio != newValue else { return }
            updateFilterState { $0.minAbsLogRatio = newValue }
            handleInputChange()
        }
    }

    var selectedScripts: Set<TokenScript> {
        get { filterState.selectedScripts }
        set {
            guard filterState.selectedScripts != newValue else { return }
            updateFilterState { $0.selectedScripts = newValue }
            handleInputChange()
        }
    }

    var selectedLexicalClasses: Set<TokenLexicalClass> {
        get { filterState.selectedLexicalClasses }
        set {
            guard filterState.selectedLexicalClasses != newValue else { return }
            updateFilterState { $0.selectedLexicalClasses = newValue }
            handleInputChange()
        }
    }

    var isEditingStopwords: Bool {
        get { filterState.isEditingStopwords }
        set { updateFilterState { $0.isEditingStopwords = newValue } }
    }

    private func updateFilterState(_ mutation: (inout KeywordSuiteFilterState) -> Void) {
        var nextState = filterState
        mutation(&nextState)
        filterState = nextState
    }
}
