import Foundation

package enum EngineContracts {
    package static let jsonRpcVersion = "2.0"

    package enum Method {
        package static let appGetInfo = "app.getInfo"
        package static let libraryList = "library.list"
        package static let libraryImportPaths = "library.importPaths"
        package static let libraryOpenSaved = "library.openSaved"
        package static let libraryRenameCorpus = "library.renameCorpus"
        package static let libraryMoveCorpus = "library.moveCorpus"
        package static let libraryDeleteCorpus = "library.deleteCorpus"
        package static let libraryCreateFolder = "library.createFolder"
        package static let libraryRenameFolder = "library.renameFolder"
        package static let libraryDeleteFolder = "library.deleteFolder"
        package static let libraryListRecycleBin = "library.listRecycleBin"
        package static let libraryRestoreRecycleEntry = "library.restoreRecycleEntry"
        package static let libraryPurgeRecycleEntry = "library.purgeRecycleEntry"
        package static let libraryBackup = "library.backup"
        package static let libraryRestore = "library.restore"
        package static let libraryRepair = "library.repair"
        package static let workspaceGetState = "workspace.getState"
        package static let workspaceSaveState = "workspace.saveState"
        package static let workspaceGetUiSettings = "workspace.getUiSettings"
        package static let workspaceSaveUiSettings = "workspace.saveUiSettings"
        package static let analysisStartTask = "analysis.startTask"
        package static let engineShutdown = "engine.shutdown"
    }

    package enum TaskType {
        package static let stats = "stats"
        package static let compare = "compare"
        package static let chiSquare = "chi-square"
        package static let ngram = "ngram"
        package static let kwic = "kwic"
        package static let collocate = "collocate"
        package static let locator = "locator"
    }

    package enum Event {
        package static let engineReady = "engine.ready"
        package static let engineStartupError = "engine.startupError"
        package static let taskCompleted = "task.completed"
        package static let taskFailed = "task.failed"
        package static let taskCancelled = "task.cancelled"
    }
}
