import Foundation

enum SettingsPaneAction {
    case save
    case checkForUpdatesNow
    case downloadUpdate
    case installDownloadedUpdate
    case revealDownloadedUpdate
    case showTaskCenter
    case showHelpWindow
    case showAboutWindow
    case showReleaseNotesWindow
    case exportDiagnostics
    case openUserDataDirectory
    case openFeedback
    case openProjectHome
    case openReleaseNotes
    case clearRecentDocuments
    case reopenRecent(String)
}
