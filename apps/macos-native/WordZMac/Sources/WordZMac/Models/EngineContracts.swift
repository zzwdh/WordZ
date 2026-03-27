import Foundation

enum EngineContracts {
    static let jsonRpcVersion = "2.0"

    enum Method {
        static let appGetInfo = "app.getInfo"
        static let libraryList = "library.list"
        static let libraryImportPaths = "library.importPaths"
        static let libraryOpenSaved = "library.openSaved"
        static let libraryRenameCorpus = "library.renameCorpus"
        static let libraryMoveCorpus = "library.moveCorpus"
        static let libraryDeleteCorpus = "library.deleteCorpus"
        static let libraryCreateFolder = "library.createFolder"
        static let libraryRenameFolder = "library.renameFolder"
        static let libraryDeleteFolder = "library.deleteFolder"
        static let libraryListRecycleBin = "library.listRecycleBin"
        static let libraryRestoreRecycleEntry = "library.restoreRecycleEntry"
        static let libraryPurgeRecycleEntry = "library.purgeRecycleEntry"
        static let libraryBackup = "library.backup"
        static let libraryRestore = "library.restore"
        static let libraryRepair = "library.repair"
        static let workspaceGetState = "workspace.getState"
        static let workspaceSaveState = "workspace.saveState"
        static let workspaceGetUiSettings = "workspace.getUiSettings"
        static let workspaceSaveUiSettings = "workspace.saveUiSettings"
        static let analysisStartTask = "analysis.startTask"
        static let engineShutdown = "engine.shutdown"
    }

    enum TaskType {
        static let stats = "stats"
        static let compare = "compare"
        static let chiSquare = "chi-square"
        static let ngram = "ngram"
        static let kwic = "kwic"
        static let collocate = "collocate"
        static let wordCloud = "word-cloud"
        static let locator = "locator"
    }

    enum Event {
        static let engineReady = "engine.ready"
        static let engineStartupError = "engine.startupError"
        static let taskCompleted = "task.completed"
        static let taskFailed = "task.failed"
        static let taskCancelled = "task.cancelled"
    }
}
