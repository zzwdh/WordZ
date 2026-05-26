import Foundation

struct KeywordSuiteSelectionState {
    var focusSelectionKind: KeywordTargetSelectionKind = .singleCorpus
    var referenceSourceKind: KeywordReferenceSourceKind = .singleCorpus
    var selectedFocusCorpusID: String?
    var selectedFocusCorpusIDs: Set<String> = []
    var selectedFocusCorpusSetID: String?
    var selectedReferenceCorpusID: String?
    var selectedReferenceCorpusSetID: String?
    var importedReferenceListText = ""
    var importedReferenceListSourceName: String?
    var importedReferenceListImportedAt: String?
}

struct KeywordSuiteFilterState {
    var annotationProfile: WorkspaceAnnotationProfile = .surface
    var unit: KeywordUnit = .normalizedSurface
    var direction: KeywordDirection = .positive
    var statistic: KeywordStatisticMethod = .logLikelihood
    var languagePreset: TokenizeLanguagePreset = .mixedChineseEnglish
    var stopwordFilter = StopwordFilterState.default
    var minFocusFrequency = "2"
    var minReferenceFrequency = "0"
    var minCombinedFrequency = "2"
    var maxPValue = "1.0"
    var minAbsLogRatio = "0.0"
    var selectedScripts: Set<TokenScript> = []
    var selectedLexicalClasses: Set<TokenLexicalClass> = []
    var isEditingStopwords = false
}

struct KeywordSavedListState {
    var savedListName = ""
    var savedListViewMode: KeywordSavedListViewMode = .pairwiseDiff
    var selectedSavedListID: String?
    var comparisonSavedListID: String?
    var savedLists: [KeywordSavedList] = []
}
