import Foundation

enum LocatorPageAction: Equatable {
    case run
    case saveCorpusSet
    case addCurrentRowToEvidenceWorkbench
    case setEvidenceReviewStatus(String, EvidenceReviewStatus)
    case saveSelectedEvidenceNote
    case deleteEvidenceItem(String)
    case saveCurrentHitSet
    case saveVisibleHitSet
    case saveFilteredSavedSet
    case saveSelectedSavedSetNotes
    case importSavedSetsJSON
    case refreshSavedSets
    case selectSavedSet(String?)
    case loadSelectedSavedSet
    case deleteSavedSet(String)
    case exportSelectedSavedSetJSON
    case changePageSize(LocatorPageSize)
    case toggleColumn(LocatorColumnKey)
    case selectRow(String?)
    case activateRow(String)
    case openSourceReader
    case copyCurrent(ReadingExportFormat)
    case copyVisible(ReadingExportFormat)
    case exportCurrent(ReadingExportFormat)
    case exportVisible(ReadingExportFormat)
    case previousPage
    case nextPage
}
