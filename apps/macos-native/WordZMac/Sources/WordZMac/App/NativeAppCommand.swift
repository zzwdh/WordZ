import Foundation

enum NativeAppCommand: String {
    case importCorpora
    case newWorkspace
    case restoreWorkspace
    case showWelcome
    case showLibrary
    case showSettings
    case showTaskCenterWindow
    case showUpdateWindow
    case showAboutWindow
    case showHelpWindow
    case showReleaseNotesWindow
    case toggleInspector
    case refreshWorkspace
    case openSelectedCorpus
    case openSourceReader
    case quickLookCurrentCorpus
    case shareCurrentContent
    case runStats
    case runWord
    case runTokenize
    case runTopics
    case runCompare
    case runSentiment
    case runKeyword
    case runChiSquare
    case runPlot
    case runNgram
    case runCluster
    case runKWIC
    case runCollocate
    case runLocator
    case exportCurrent
    case checkForUpdates
    case downloadUpdate
    case installDownloadedUpdate
    case exportDiagnostics
    case openProjectHome
    case openReleaseNotes
    case openFeedback
    case clearRecentDocuments
}

extension Notification.Name {
    static let wordZMacCommandTriggered = Notification.Name("WordZMac.commandTriggered")
}

enum NativeAppCommandCenter {
    static func post(_ command: NativeAppCommand) {
        NotificationCenter.default.post(
            name: .wordZMacCommandTriggered,
            object: nil,
            userInfo: ["command": command.rawValue]
        )
    }

    static func parse(_ notification: Notification) -> NativeAppCommand? {
        guard let rawValue = notification.userInfo?["command"] as? String else { return nil }
        return NativeAppCommand(rawValue: rawValue)
    }
}
