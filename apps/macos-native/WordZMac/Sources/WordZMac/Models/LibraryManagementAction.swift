import Foundation

enum LibraryManagementAction: Equatable {
    case refresh
    case importPaths
    case createFolder
    case selectFolder(String?)
    case selectCorpus(String?)
    case selectRecycleEntry(String?)
    case openSelectedCorpus
    case renameSelectedCorpus
    case moveSelectedCorpusToSelectedFolder
    case deleteSelectedCorpus
    case renameSelectedFolder
    case deleteSelectedFolder
    case backupLibrary
    case restoreLibrary
    case repairLibrary
    case restoreSelectedRecycleEntry
    case purgeSelectedRecycleEntry
}
