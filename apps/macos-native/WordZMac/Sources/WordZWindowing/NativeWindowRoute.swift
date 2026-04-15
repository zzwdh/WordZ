import Foundation

package enum NativeWindowRoute: String, Hashable, Sendable {
    case mainWorkspace
    case library
    case evidenceWorkbench
    case sourceReader
    case settings
    case taskCenter
    case updatePrompt
    case about
    case help
    case releaseNotes

    package var id: String { rawValue }
}
