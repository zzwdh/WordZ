import Foundation

struct StorageMutationCoordinator {
    let fileManager: FileManager
    let stagingRootURL: URL

    func perform<T>(_ body: (StorageMutationTransaction) throws -> T) throws -> T {
        let transaction = try StorageMutationTransaction(
            fileManager: fileManager,
            stagingRootURL: stagingRootURL
        )
        do {
            let result = try body(transaction)
            transaction.commit()
            return result
        } catch {
            transaction.rollback()
            throw error
        }
    }
}

final class StorageMutationTransaction {
    private struct DatabaseSnapshot {
        let databaseURL: URL
        let snapshotURL: URL?
        let existed: Bool
    }

    private let fileManager: FileManager
    private let stagingDirectoryURL: URL
    private var fileRollbackActions: [() -> Void] = []
    private var rollbackActions: [() -> Void] = []
    private var databaseSnapshotsByPath: [String: DatabaseSnapshot] = [:]
    private var isFinalized = false

    init(fileManager: FileManager, stagingRootURL: URL) throws {
        self.fileManager = fileManager
        self.stagingDirectoryURL = stagingRootURL
            .appendingPathComponent("mutation-staging-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(
            at: stagingDirectoryURL,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }

    func moveItem(at sourceURL: URL, to destinationURL: URL) throws {
        guard standardizedURL(sourceURL) != standardizedURL(destinationURL) else { return }
        guard fileManager.fileExists(atPath: sourceURL.path) else { return }

        try fileManager.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )

        let displacedDestinationURL: URL?
        if fileManager.fileExists(atPath: destinationURL.path) {
            let stagedDestinationURL = makeStagedURL(for: destinationURL)
            try fileManager.moveItem(at: destinationURL, to: stagedDestinationURL)
            displacedDestinationURL = stagedDestinationURL
        } else {
            displacedDestinationURL = nil
        }

        do {
            try fileManager.moveItem(at: sourceURL, to: destinationURL)
        } catch {
            if let displacedDestinationURL {
                try? fileManager.moveItem(at: displacedDestinationURL, to: destinationURL)
            }
            throw error
        }

        registerFileRollback { [fileManager] in
            if fileManager.fileExists(atPath: destinationURL.path) {
                try? fileManager.moveItem(at: destinationURL, to: sourceURL)
            }
            if let displacedDestinationURL,
               fileManager.fileExists(atPath: displacedDestinationURL.path) {
                try? fileManager.moveItem(at: displacedDestinationURL, to: destinationURL)
            }
        }
    }

    func removeItem(at url: URL) throws {
        guard fileManager.fileExists(atPath: url.path) else { return }
        let stagedURL = makeStagedURL(for: url)
        try fileManager.moveItem(at: url, to: stagedURL)
        registerFileRollback { [fileManager] in
            if fileManager.fileExists(atPath: stagedURL.path) {
                try? fileManager.moveItem(at: stagedURL, to: url)
            }
        }
    }

    func snapshotDatabase(at databaseURL: URL, configuration: SQLiteDatabaseConfiguration) throws {
        let standardizedDatabaseURL = standardizedURL(databaseURL)
        let snapshotKey = standardizedDatabaseURL.path
        guard databaseSnapshotsByPath[snapshotKey] == nil else { return }

        let existed = fileManager.fileExists(atPath: standardizedDatabaseURL.path)
        let snapshotURL: URL?
        if existed {
            let stagedSnapshotURL = makeStagedURL(for: standardizedDatabaseURL)
            try SQLiteDatabase.backupDatabase(
                from: standardizedDatabaseURL,
                to: stagedSnapshotURL,
                configuration: configuration,
                fileManager: fileManager
            )
            snapshotURL = stagedSnapshotURL
        } else {
            snapshotURL = nil
        }

        let snapshot = DatabaseSnapshot(
            databaseURL: standardizedDatabaseURL,
            snapshotURL: snapshotURL,
            existed: existed
        )
        databaseSnapshotsByPath[snapshotKey] = snapshot

        registerRollback { [fileManager] in
            if fileManager.fileExists(atPath: snapshot.databaseURL.path) {
                try? fileManager.removeItem(at: snapshot.databaseURL)
            }
            SQLiteDatabase.removeDatabaseSidecars(for: snapshot.databaseURL, fileManager: fileManager)

            guard snapshot.existed,
                  let snapshotURL = snapshot.snapshotURL,
                  fileManager.fileExists(atPath: snapshotURL.path) else {
                return
            }

            try? fileManager.createDirectory(
                at: snapshot.databaseURL.deletingLastPathComponent(),
                withIntermediateDirectories: true,
                attributes: nil
            )
            try? fileManager.copyItem(at: snapshotURL, to: snapshot.databaseURL)
            SQLiteDatabase.removeDatabaseSidecars(for: snapshot.databaseURL, fileManager: fileManager)
        }
    }

    func registerRollback(_ action: @escaping () -> Void) {
        rollbackActions.append(action)
    }

    private func registerFileRollback(_ action: @escaping () -> Void) {
        fileRollbackActions.append(action)
    }

    func commit() {
        guard !isFinalized else { return }
        isFinalized = true
        fileRollbackActions.removeAll()
        rollbackActions.removeAll()
        databaseSnapshotsByPath.removeAll()
        try? fileManager.removeItem(at: stagingDirectoryURL)
    }

    func rollback() {
        guard !isFinalized else { return }
        isFinalized = true
        for action in fileRollbackActions.reversed() {
            action()
        }
        fileRollbackActions.removeAll()
        for action in rollbackActions.reversed() {
            action()
        }
        rollbackActions.removeAll()
        databaseSnapshotsByPath.removeAll()
        try? fileManager.removeItem(at: stagingDirectoryURL)
    }

    private func makeStagedURL(for url: URL) -> URL {
        stagingDirectoryURL.appendingPathComponent(
            "\(UUID().uuidString)-\(url.lastPathComponent)",
            isDirectory: false
        )
    }

    private func standardizedURL(_ url: URL) -> URL {
        url.standardizedFileURL
    }
}
