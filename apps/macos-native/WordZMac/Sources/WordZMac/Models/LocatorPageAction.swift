import Foundation

enum LocatorPageAction: Equatable {
    case run
    case changePageSize(LocatorPageSize)
    case toggleColumn(LocatorColumnKey)
    case selectRow(String?)
    case activateRow(String)
    case previousPage
    case nextPage
}
