import Foundation
import SQLite3

extension NativeCorpusDatabaseSupport {
    static func configureDatabase(on db: OpaquePointer?) throws {
        try execute("PRAGMA journal_mode=DELETE;", on: db)
        try execute("PRAGMA synchronous=NORMAL;", on: db)
    }

    static func ensureDocumentSchema(on db: OpaquePointer?) throws {
        try execute(
            """
            CREATE TABLE IF NOT EXISTS corpus_document (
                id INTEGER PRIMARY KEY CHECK (id = 1),
                schema_version INTEGER NOT NULL,
                imported_at TEXT NOT NULL,
                source_type TEXT NOT NULL,
                represented_path TEXT NOT NULL,
                detected_encoding TEXT NOT NULL,
                source_label TEXT NOT NULL DEFAULT '',
                year_label TEXT NOT NULL DEFAULT '',
                genre_label TEXT NOT NULL DEFAULT '',
                tags_text TEXT NOT NULL DEFAULT '',
                token_count INTEGER NOT NULL,
                type_count INTEGER NOT NULL,
                sentence_count INTEGER NOT NULL,
                paragraph_count INTEGER NOT NULL,
                character_count INTEGER NOT NULL,
                ttr REAL NOT NULL DEFAULT 0,
                sttr REAL NOT NULL DEFAULT 0,
                text TEXT NOT NULL
            );
            """,
            on: db
        )
        try execute(
            """
            CREATE TABLE IF NOT EXISTS token_frequency (
                term TEXT PRIMARY KEY,
                count INTEGER NOT NULL,
                rank_index INTEGER NOT NULL,
                norm_frequency REAL NOT NULL,
                sentence_range INTEGER NOT NULL,
                paragraph_range INTEGER NOT NULL
            );
            """,
            on: db
        )
        try ensureColumn("source_label", definition: "TEXT NOT NULL DEFAULT ''", onTable: "corpus_document", db: db)
        try ensureColumn("year_label", definition: "TEXT NOT NULL DEFAULT ''", onTable: "corpus_document", db: db)
        try ensureColumn("genre_label", definition: "TEXT NOT NULL DEFAULT ''", onTable: "corpus_document", db: db)
        try ensureColumn("tags_text", definition: "TEXT NOT NULL DEFAULT ''", onTable: "corpus_document", db: db)
        try ensureColumn("ttr", definition: "REAL NOT NULL DEFAULT 0", onTable: "corpus_document", db: db)
        try ensureColumn("sttr", definition: "REAL NOT NULL DEFAULT 0", onTable: "corpus_document", db: db)
        try execute("CREATE INDEX IF NOT EXISTS idx_token_frequency_count ON token_frequency(count DESC, term ASC);", on: db)
        try execute("CREATE INDEX IF NOT EXISTS idx_token_frequency_rank ON token_frequency(rank_index ASC, term ASC);", on: db)
        try execute("CREATE INDEX IF NOT EXISTS idx_token_frequency_norm_frequency ON token_frequency(norm_frequency DESC, term ASC);", on: db)
        try execute("CREATE INDEX IF NOT EXISTS idx_token_frequency_sentence_range ON token_frequency(sentence_range DESC, term ASC);", on: db)
    }

    static func ensureColumn(
        _ column: String,
        definition: String,
        onTable tableName: String,
        db: OpaquePointer?
    ) throws {
        guard try !columnExists(column, onTable: tableName, db: db) else { return }
        try execute("ALTER TABLE \(tableName) ADD COLUMN \(column) \(definition);", on: db)
    }

    static func columnExists(_ column: String, onTable tableName: String, db: OpaquePointer?) throws -> Bool {
        let statement = try prepare("PRAGMA table_info(\(tableName));", on: db)
        defer { sqlite3_finalize(statement) }

        while sqlite3_step(statement) == SQLITE_ROW {
            if stringColumn(statement, index: 1) == column {
                return true
            }
        }
        return false
    }
}
