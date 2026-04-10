import SQLite3
import XCTest
@testable import WordZMac

final class NativeCorpusDatabaseSupportTests: XCTestCase {
    func testWriteDocumentCreatesPerformanceIndexesForTokenFrequencyTable() throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("wordz-frequency-indexes-\(UUID().uuidString).db")
        defer { try? FileManager.default.removeItem(at: databaseURL) }

        try NativeCorpusDatabaseSupport.writeDocument(
            at: databaseURL,
            document: DecodedTextDocument(text: "rose rose rose bloom bloom field", encodingName: "utf-8"),
            sourceType: "txt",
            representedPath: "/tmp/demo.txt",
            importedAt: "2026-04-08T00:00:00Z"
        )

        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(databaseURL.path, &db), SQLITE_OK)
        defer { sqlite3_close(db) }

        let names = try indexNames(in: db)
        XCTAssertTrue(names.contains("idx_token_frequency_count"))
        XCTAssertTrue(names.contains("idx_token_frequency_rank"))
        XCTAssertTrue(names.contains("idx_token_frequency_norm_frequency"))
        XCTAssertTrue(names.contains("idx_token_frequency_sentence_range"))
    }

    private func indexNames(in db: OpaquePointer?) throws -> Set<String> {
        var statement: OpaquePointer?
        let sql = "SELECT name FROM sqlite_master WHERE type = 'index' AND tbl_name = 'token_frequency';"
        XCTAssertEqual(sqlite3_prepare_v2(db, sql, -1, &statement, nil), SQLITE_OK)
        defer { sqlite3_finalize(statement) }

        var names: Set<String> = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let rawName = sqlite3_column_text(statement, 0) {
                names.insert(String(cString: rawName))
            }
        }
        return names
    }
}
