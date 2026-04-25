import Foundation
import SQLite3

extension NativeCorpusDatabaseSupport {
    static func readStoredLocatorResult(
        at url: URL,
        sentenceId: Int,
        nodeIndex: Int,
        leftWindow: Int,
        rightWindow: Int
    ) throws -> LocatorResult? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }

        let db = try openDatabase(at: url, flags: SQLITE_OPEN_READONLY)
        defer { sqlite3_close(db) }

        try ensureDocumentSchema(on: db)

        let sentenceCount = try scalarInt("SELECT COUNT(*) FROM sentence;", on: db)
        guard sentenceCount > 0 else {
            return LocatorResult(sentenceCount: 0, rows: [])
        }

        let safeSentenceId = min(max(sentenceId, 0), sentenceCount - 1)
        let safeLeft = max(0, leftWindow)
        let safeRight = max(0, rightWindow)
        let start = max(0, safeSentenceId - safeLeft)
        let end = min(sentenceCount - 1, safeSentenceId + safeRight)
        let sourceTokens = try loadOriginalTerms(forSentenceID: safeSentenceId, on: db)
        let safeNodeIndex = min(max(nodeIndex, 0), max(sourceTokens.count - 1, 0))
        let currentLeftWords = sourceTokens.prefix(safeNodeIndex).joined(separator: " ")
        let currentNodeWord = sourceTokens.isEmpty ? "" : sourceTokens[safeNodeIndex]
        let currentRightWords = sourceTokens.dropFirst(min(safeNodeIndex + 1, sourceTokens.count)).joined(separator: " ")

        let statement = try prepare(
            """
            SELECT sentence_id,
                   text
            FROM sentence
            WHERE sentence_id BETWEEN ? AND ?
            ORDER BY sentence_id ASC;
            """,
            on: db
        )
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_int64(statement, 1, sqlite3_int64(start))
        sqlite3_bind_int64(statement, 2, sqlite3_int64(end))

        var rows: [LocatorRow] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let resolvedSentenceID = Int(sqlite3_column_int(statement, 0))
            let isCurrent = resolvedSentenceID == safeSentenceId
            let status: String
            if isCurrent {
                status = "当前"
            } else if resolvedSentenceID < safeSentenceId {
                status = "前文"
            } else {
                status = "后文"
            }

            rows.append(
                LocatorRow(
                    sentenceId: resolvedSentenceID,
                    text: stringColumn(statement, index: 1),
                    leftWords: isCurrent ? currentLeftWords : "",
                    nodeWord: isCurrent ? currentNodeWord : "",
                    rightWords: isCurrent ? currentRightWords : "",
                    status: status
                )
            )
        }

        return LocatorResult(sentenceCount: sentenceCount, rows: rows)
    }

    private static func loadOriginalTerms(
        forSentenceID sentenceID: Int,
        on db: OpaquePointer?
    ) throws -> [String] {
        let statement = try prepare(
            """
            SELECT original_term
            FROM token
            WHERE sentence_id = ?
            ORDER BY token_index ASC;
            """,
            on: db
        )
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_int64(statement, 1, sqlite3_int64(sentenceID))
        var tokens: [String] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            tokens.append(stringColumn(statement, index: 0))
        }
        return tokens
    }
}
