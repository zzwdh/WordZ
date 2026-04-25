import Foundation
import SQLite3

extension NativeCorpusDatabaseSupport {
    static func openDatabase(at url: URL, flags: Int32) throws -> OpaquePointer? {
        var db: OpaquePointer?
        let result = sqlite3_open_v2(url.path, &db, flags, nil)
        guard result == SQLITE_OK, let db else {
            let message = db.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            sqlite3_close(db)
            throw NSError(
                domain: "WordZMac.NativeCorpusDatabaseSupport",
                code: Int(result),
                userInfo: [NSLocalizedDescriptionKey: "无法打开语料数据库：\(message)"]
            )
        }
        return db
    }

    static func prepare(_ sql: String, on db: OpaquePointer?) throws -> OpaquePointer? {
        var statement: OpaquePointer?
        let result = sqlite3_prepare_v2(db, sql, -1, &statement, nil)
        guard result == SQLITE_OK else {
            throw databaseError(on: db, message: "数据库语句准备失败")
        }
        return statement
    }

    static func execute(_ sql: String, on db: OpaquePointer?) throws {
        let result = sqlite3_exec(db, sql, nil, nil, nil)
        guard result == SQLITE_OK else {
            throw databaseError(on: db, message: "数据库执行失败")
        }
    }

    static func bindText(_ value: String, to statement: OpaquePointer?, index: Int32) {
        value.utf8CString.withUnsafeBufferPointer { buffer in
            let byteCount = max(0, buffer.count - 1)
            sqlite3_bind_text(statement, index, buffer.baseAddress, Int32(byteCount), sqliteTransient)
        }
    }

    static func stringColumn(_ statement: OpaquePointer?, index: Int32) -> String {
        let byteCount = Int(sqlite3_column_bytes(statement, index))
        guard byteCount > 0,
              let pointer = sqlite3_column_text(statement, index) else {
            return ""
        }
        let data = Data(bytes: pointer, count: byteCount)
        return String(decoding: data, as: UTF8.self)
    }

    static func doubleColumn(_ statement: OpaquePointer?, index: Int32) -> Double {
        sqlite3_column_double(statement, index)
    }

    static func scalarInt(_ sql: String, on db: OpaquePointer?) throws -> Int {
        let statement = try prepare(sql, on: db)
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int64(statement, 0))
    }

    static func scalarText(_ sql: String, on db: OpaquePointer?) throws -> String? {
        let statement = try prepare(sql, on: db)
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
        let value = stringColumn(statement, index: 0)
        return value.isEmpty ? nil : value
    }

    static func databaseError(on db: OpaquePointer?, message: String) -> NSError {
        NSError(
            domain: "WordZMac.NativeCorpusDatabaseSupport",
            code: Int(sqlite3_errcode(db)),
            userInfo: [NSLocalizedDescriptionKey: "\(message)：\(String(cString: sqlite3_errmsg(db)))"]
        )
    }
}
