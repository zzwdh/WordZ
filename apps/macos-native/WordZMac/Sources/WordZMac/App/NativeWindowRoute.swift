import Foundation

enum NativeWindowRoute: String {
    case taskCenter
    case about
    case help
    case releaseNotes

    var id: String { rawValue }
}
