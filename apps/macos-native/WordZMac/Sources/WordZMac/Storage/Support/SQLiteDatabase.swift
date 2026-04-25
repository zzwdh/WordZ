import Foundation
import SQLite3

enum SQLiteJournalMode: String {
    case delete = "DELETE"
    case wal = "WAL"
}

enum SQLiteTransactionMode {
    case deferred
    case immediate
    case exclusive

    var beginSQL: String {
        switch self {
        case .deferred:
            return "BEGIN DEFERRED TRANSACTION;"
        case .immediate:
            return "BEGIN IMMEDIATE TRANSACTION;"
        case .exclusive:
            return "BEGIN EXCLUSIVE TRANSACTION;"
        }
    }
}

struct SQLiteDatabaseConfiguration {
    let journalMode: SQLiteJournalMode
    let synchronousMode: String
    let foreignKeysEnabled: Bool
    let busyTimeoutMS: Int32

    static let libraryCatalog = SQLiteDatabaseConfiguration(
        journalMode: .wal,
        synchronousMode: "NORMAL",
        foreignKeysEnabled: true,
        busyTimeoutMS: 5_000
    )

    static let workspaceState = SQLiteDatabaseConfiguration(
        journalMode: .wal,
        synchronousMode: "NORMAL",
        foreignKeysEnabled: true,
        busyTimeoutMS: 5_000
    )

    static let corpusShard = SQLiteDatabaseConfiguration(
        journalMode: .delete,
        synchronousMode: "NORMAL",
        foreignKeysEnabled: false,
        busyTimeoutMS: 5_000
    )
}

final class SQLiteDatabase {
    static let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    let url: URL
    private let handle: OpaquePointer?

    init(
        url: URL,
        flags: Int32 = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE,
        configuration: SQLiteDatabaseConfiguration,
        skipConfiguration: Bool = false
    ) throws {
        self.url = url
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )

        var db: OpaquePointer?
        let result = sqlite3_open_v2(url.path, &db, flags, nil)
        guard result == SQLITE_OK, let db else {
            let message = db.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            sqlite3_close(db)
            throw NSError(
                domain: "WordZMac.SQLiteDatabase",
                code: Int(result),
                userInfo: [NSLocalizedDescriptionKey: "无法打开数据库：\(message)"]
            )
        }

        self.handle = db
        if !skipConfiguration {
            try configure(with: configuration)
        }
    }

    deinit {
        sqlite3_close(handle)
    }

    func execute(_ sql: String) throws {
        let result = sqlite3_exec(handle, sql, nil, nil, nil)
        guard result == SQLITE_OK else {
            throw error(message: "数据库执行失败")
        }
    }

    func prepare(_ sql: String) throws -> SQLiteStatement {
        try SQLiteStatement(database: self, sql: sql)
    }

    func transaction<T>(
        mode: SQLiteTransactionMode = .immediate,
        _ body: () throws -> T
    ) throws -> T {
        try execute(mode.beginSQL)
        do {
            let result = try body()
            try execute("COMMIT;")
            return result
        } catch {
            try? execute("ROLLBACK;")
            throw error
        }
    }

    func tableExists(_ tableName: String) throws -> Bool {
        let statement = try prepare(
            """
            SELECT 1
            FROM sqlite_master
            WHERE type = 'table' AND name = ?
            LIMIT 1;
            """
        )
        statement.bind(text: tableName, at: 1)
        return statement.step() == SQLITE_ROW
    }

    func columnExists(_ columnName: String, onTable tableName: String) throws -> Bool {
        let statement = try prepare("PRAGMA table_info(\(tableName));")
        while statement.step() == SQLITE_ROW {
            if statement.text(at: 1) == columnName {
                return true
            }
        }
        return false
    }

    func scalarInt(_ sql: String) throws -> Int {
        let statement = try prepare(sql)
        guard statement.step() == SQLITE_ROW else {
            return 0
        }
        return statement.int(at: 0)
    }

    func scalarText(_ sql: String) throws -> String? {
        let statement = try prepare(sql)
        guard statement.step() == SQLITE_ROW else {
            return nil
        }
        let value = statement.text(at: 0)
        return value.isEmpty ? nil : value
    }

    func checkpointIfNeeded() {
        sqlite3_wal_checkpoint_v2(handle, nil, SQLITE_CHECKPOINT_TRUNCATE, nil, nil)
    }

    fileprivate var rawHandle: OpaquePointer? {
        handle
    }

    func error(message: String) -> NSError {
        NSError(
            domain: "WordZMac.SQLiteDatabase",
            code: Int(sqlite3_errcode(handle)),
            userInfo: [NSLocalizedDescriptionKey: "\(message)：\(String(cString: sqlite3_errmsg(handle)))"]
        )
    }

    private func configure(with configuration: SQLiteDatabaseConfiguration) throws {
        try execute("PRAGMA journal_mode=\(configuration.journalMode.rawValue);")
        try execute("PRAGMA synchronous=\(configuration.synchronousMode);")
        try execute("PRAGMA foreign_keys=\(configuration.foreignKeysEnabled ? "ON" : "OFF");")
        sqlite3_busy_timeout(handle, configuration.busyTimeoutMS)
    }

    static func atomicReplaceItem(
        at destinationURL: URL,
        with stagedURL: URL,
        fileManager: FileManager = .default
    ) throws {
        guard fileManager.fileExists(atPath: stagedURL.path) else { return }
        if fileManager.fileExists(atPath: destinationURL.path) {
            _ = try fileManager.replaceItemAt(destinationURL, withItemAt: stagedURL)
        } else {
            try fileManager.copyItem(at: stagedURL, to: destinationURL)
            try? fileManager.removeItem(at: stagedURL)
        }
    }

    static func databaseSidecarURLs(for databaseURL: URL) -> [URL] {
        [
            URL(fileURLWithPath: databaseURL.path + "-wal"),
            URL(fileURLWithPath: databaseURL.path + "-shm"),
            URL(fileURLWithPath: databaseURL.path + "-journal")
        ]
    }

    static func removeDatabaseSidecars(
        for databaseURL: URL,
        fileManager: FileManager = .default
    ) {
        for sidecarURL in databaseSidecarURLs(for: databaseURL)
        where fileManager.fileExists(atPath: sidecarURL.path) {
            try? fileManager.removeItem(at: sidecarURL)
        }
    }

    static func backupDatabase(
        from sourceURL: URL,
        to destinationURL: URL,
        configuration: SQLiteDatabaseConfiguration,
        fileManager: FileManager = .default
    ) throws {
        guard fileManager.fileExists(atPath: sourceURL.path) else { return }
        try fileManager.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )

        let stagingDirectoryURL = destinationURL.deletingLastPathComponent()
            .appendingPathComponent("sqlite-backup-staging-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(
            at: stagingDirectoryURL,
            withIntermediateDirectories: true,
            attributes: nil
        )
        let stagedURL = stagingDirectoryURL.appendingPathComponent(destinationURL.lastPathComponent)
        try? fileManager.removeItem(at: stagedURL)
        removeDatabaseSidecars(for: stagedURL, fileManager: fileManager)
        defer {
            try? fileManager.removeItem(at: stagedURL)
            removeDatabaseSidecars(for: stagedURL, fileManager: fileManager)
            try? fileManager.removeItem(at: stagingDirectoryURL)
        }

        var source: SQLiteDatabase?
        var destination: SQLiteDatabase?
        do {
            source = try SQLiteDatabase(
                url: sourceURL,
                flags: SQLITE_OPEN_READONLY,
                configuration: configuration,
                skipConfiguration: true
            )
            destination = try SQLiteDatabase(
                url: stagedURL,
                flags: SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE,
                configuration: configuration
            )
            let backup = sqlite3_backup_init(destination?.rawHandle, "main", source?.rawHandle, "main")
            guard let backup, let destination else {
                throw destination?.error(message: "无法初始化数据库备份")
                    ?? NSError(
                        domain: "WordZMac.SQLiteDatabase",
                        code: Int(SQLITE_ERROR),
                        userInfo: [NSLocalizedDescriptionKey: "无法初始化数据库备份"]
                    )
            }
            defer { sqlite3_backup_finish(backup) }

            var stepResult = SQLITE_OK
            repeat {
                stepResult = sqlite3_backup_step(backup, 256)
                if stepResult == SQLITE_BUSY || stepResult == SQLITE_LOCKED {
                    sqlite3_sleep(10)
                }
            } while stepResult == SQLITE_OK || stepResult == SQLITE_BUSY || stepResult == SQLITE_LOCKED
            guard stepResult == SQLITE_DONE else {
                throw destination.error(message: "数据库备份失败")
            }
            destination.checkpointIfNeeded()
        }
        destination = nil
        source = nil

        removeDatabaseSidecars(for: stagedURL, fileManager: fileManager)
        removeDatabaseSidecars(for: destinationURL, fileManager: fileManager)
        try atomicReplaceItem(at: destinationURL, with: stagedURL, fileManager: fileManager)
        removeDatabaseSidecars(for: destinationURL, fileManager: fileManager)
    }
}

final class SQLiteStatement {
    private let database: SQLiteDatabase
    private let statement: OpaquePointer?

    init(database: SQLiteDatabase, sql: String) throws {
        self.database = database
        var statement: OpaquePointer?
        let result = sqlite3_prepare_v2(database.rawHandle, sql, -1, &statement, nil)
        guard result == SQLITE_OK else {
            throw database.error(message: "数据库语句准备失败")
        }
        self.statement = statement
    }

    deinit {
        sqlite3_finalize(statement)
    }

    func reset() {
        sqlite3_reset(statement)
        sqlite3_clear_bindings(statement)
    }

    @discardableResult
    func step() -> Int32 {
        sqlite3_step(statement)
    }

    func bind(text value: String, at index: Int32) {
        value.utf8CString.withUnsafeBufferPointer { buffer in
            let count = max(0, buffer.count - 1)
            sqlite3_bind_text(statement, index, buffer.baseAddress, Int32(count), SQLiteDatabase.sqliteTransient)
        }
    }

    func bind(optionalText value: String?, at index: Int32) {
        if let value {
            bind(text: value, at: index)
        } else {
            bindNull(at: index)
        }
    }

    func bind(int value: Int, at index: Int32) {
        sqlite3_bind_int64(statement, index, sqlite3_int64(value))
    }

    func bind(double value: Double, at index: Int32) {
        sqlite3_bind_double(statement, index, value)
    }

    func bind(bool value: Bool, at index: Int32) {
        bind(int: value ? 1 : 0, at: index)
    }

    func bindNull(at index: Int32) {
        sqlite3_bind_null(statement, index)
    }

    func int(at index: Int32) -> Int {
        Int(sqlite3_column_int64(statement, index))
    }

    func double(at index: Int32) -> Double {
        sqlite3_column_double(statement, index)
    }

    func bool(at index: Int32) -> Bool {
        int(at: index) != 0
    }

    func text(at index: Int32) -> String {
        let byteCount = Int(sqlite3_column_bytes(statement, index))
        guard byteCount > 0, let pointer = sqlite3_column_text(statement, index) else {
            return ""
        }
        let data = Data(bytes: pointer, count: byteCount)
        return String(decoding: data, as: UTF8.self)
    }
}
