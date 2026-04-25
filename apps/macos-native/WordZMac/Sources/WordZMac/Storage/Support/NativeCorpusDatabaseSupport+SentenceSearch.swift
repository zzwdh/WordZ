import Foundation
import SQLite3

extension NativeCorpusDatabaseSupport {
    static func loadCandidateSentenceIDs(
        at url: URL,
        phraseTokens: [String]
    ) throws -> [Int] {
        let normalizedTokens = phraseTokens
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !normalizedTokens.isEmpty else { return [] }
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }

        let db = try openDatabase(at: url, flags: SQLITE_OPEN_READWRITE)
        defer { sqlite3_close(db) }

        try ensureDocumentSchema(on: db)

        if let matchExpression = sentenceSearchMatchExpression(for: normalizedTokens) {
            let statement = try prepare(
                """
                SELECT rowid
                FROM sentence_fts
                WHERE sentence_fts MATCH ?
                ORDER BY rowid ASC;
                """,
                on: db
            )
            defer { sqlite3_finalize(statement) }

            bindText(matchExpression, to: statement, index: 1)
            return collectSentenceIDs(from: statement)
        }

        let predicates = Array(repeating: "text LIKE ? COLLATE NOCASE", count: normalizedTokens.count)
            .joined(separator: " AND ")
        let statement = try prepare(
            """
            SELECT sentence_id
            FROM sentence
            WHERE \(predicates)
            ORDER BY sentence_id ASC;
            """,
            on: db
        )
        defer { sqlite3_finalize(statement) }

        for (index, token) in normalizedTokens.enumerated() {
            bindText("%\(token)%", to: statement, index: Int32(index + 1))
        }
        return collectSentenceIDs(from: statement)
    }

    private static func collectSentenceIDs(from statement: OpaquePointer?) -> [Int] {
        var sentenceIDs: [Int] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            sentenceIDs.append(Int(sqlite3_column_int(statement, 0)))
        }
        return sentenceIDs
    }

    private static func sentenceSearchMatchExpression(for tokens: [String]) -> String? {
        let safeTerms = tokens.compactMap { token -> String? in
            guard token.unicodeScalars.allSatisfy({
                $0.isASCII && (CharacterSet.alphanumerics.contains($0) || String($0) == "_")
            }) else {
                return nil
            }
            return "\(token)*"
        }
        guard safeTerms.count == tokens.count else { return nil }
        return safeTerms.joined(separator: " ")
    }
}
