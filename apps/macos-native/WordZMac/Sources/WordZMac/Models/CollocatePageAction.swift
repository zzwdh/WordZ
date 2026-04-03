import Foundation

enum CollocatePageAction {
    case run
    case applyPreset(CollocatePreset)
    case changeFocusMetric(CollocateAssociationMetric)
    case changeSort(CollocateSortMode)
    case sortByColumn(CollocateColumnKey)
    case changePageSize(CollocatePageSize)
    case toggleColumn(CollocateColumnKey)
    case selectRow(String?)
    case previousPage
    case nextPage
}
