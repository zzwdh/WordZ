import Foundation

enum LibraryManagementAction: Equatable {
    case refresh
    case importPaths
    case createFolder
    case saveCurrentCorpusSet
    case selectFolder(String?)
    case selectCorpusSet(String?)
    case selectCorpus(String?)
    case selectCorpusIDs(Set<String>)
    case selectRecycleEntry(String?)
    case openSelectedCorpus
    case quickLookSelectedCorpus
    case showSelectedCorpusInfo
    case editSelectedCorpusMetadata
    case editSelectedCorporaMetadata
    case saveSelectedCorpusMetadata(CorpusMetadataProfile)
    case applySelectedCorporaMetadataPatch(BatchCorpusMetadataPatch)
    case renameSelectedCorpus
    case moveSelectedCorpusToSelectedFolder
    case deleteSelectedCorpus
    case renameSelectedFolder
    case deleteSelectedFolder
    case deleteSelectedCorpusSet
    case backupLibrary
    case restoreLibrary
    case repairLibrary
    case restoreSelectedRecycleEntry
    case purgeSelectedRecycleEntry
}
