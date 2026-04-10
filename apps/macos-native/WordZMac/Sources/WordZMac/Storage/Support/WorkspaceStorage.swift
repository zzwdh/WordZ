import Foundation

protocol StorageAppInfoProviding: AnyObject {
    func appInfo() -> AppInfoSummary
}

typealias WorkspaceStorage = LibraryStore & WorkspaceSnapshotStore & StorageAppInfoProviding
