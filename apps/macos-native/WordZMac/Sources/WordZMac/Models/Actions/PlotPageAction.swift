import Foundation

enum PlotPageAction {
    case run
    case selectRow(String?)
    case selectMarker(rowID: String, markerID: String?)
    case openKWIC
    case openSourceReader
}
