import Foundation

enum EngineContracts {
    static let jsonRpcVersion = "2.0"

    enum Method {
        static let appGetInfo = "app.getInfo"
        static let libraryList = "library.list"
        static let libraryOpenSaved = "library.openSaved"
        static let workspaceGetState = "workspace.getState"
        static let analysisStartTask = "analysis.startTask"
        static let engineShutdown = "engine.shutdown"
    }

    enum TaskType {
        static let stats = "stats"
        static let kwic = "kwic"
    }

    enum Event {
        static let taskCompleted = "task.completed"
        static let taskFailed = "task.failed"
        static let taskCancelled = "task.cancelled"
    }
}
