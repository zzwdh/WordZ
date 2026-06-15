import Foundation
import SQLite3
import WordZStorage

extension LibraryCatalogStore {
    func ensureInitialized() throws {
        try fileManager.createDirectory(
            at: databaseURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )
        try withDatabase { db in
            try applySchema(on: db)
        }
    }

    func applySchema(on db: SQLiteDatabase) throws {
        try db.transaction {
            try db.execute(
                """
                CREATE TABLE IF NOT EXISTS schema_migrations (
                    version INTEGER PRIMARY KEY,
                    applied_at TEXT NOT NULL,
                    description TEXT NOT NULL
                );
                """
            )
            try db.execute(
                """
                CREATE TABLE IF NOT EXISTS storage_meta (
                    key TEXT PRIMARY KEY,
                    value TEXT NOT NULL
                );
                """
            )
            try db.execute(
                """
                CREATE TABLE IF NOT EXISTS library_folder (
                    id TEXT PRIMARY KEY,
                    name TEXT NOT NULL,
                    position INTEGER NOT NULL DEFAULT 0
                );
                """
            )
            try db.execute(
                """
                CREATE TABLE IF NOT EXISTS corpus (
                    id TEXT PRIMARY KEY,
                    name TEXT NOT NULL,
                    folder_id TEXT NOT NULL,
                    folder_name TEXT NOT NULL,
                    source_type TEXT NOT NULL,
                    represented_path TEXT NOT NULL,
                    storage_file_name TEXT NOT NULL,
                    metadata_json TEXT NOT NULL,
                    cleaning_summary_json TEXT NOT NULL DEFAULT '',
                    source_label TEXT NOT NULL DEFAULT '',
                    year_label TEXT NOT NULL DEFAULT '',
                    genre_label TEXT NOT NULL DEFAULT '',
                    tags_text TEXT NOT NULL DEFAULT '',
                    imported_at TEXT NOT NULL DEFAULT '',
                    token_count INTEGER NOT NULL DEFAULT 0,
                    type_count INTEGER NOT NULL DEFAULT 0,
                    sentence_count INTEGER NOT NULL DEFAULT 0,
                    paragraph_count INTEGER NOT NULL DEFAULT 0,
                    character_count INTEGER NOT NULL DEFAULT 0,
                    ttr REAL NOT NULL DEFAULT 0,
                    sttr REAL NOT NULL DEFAULT 0,
                    cleaned_at TEXT NOT NULL DEFAULT '',
                    cleaning_profile_version TEXT NOT NULL DEFAULT '',
                    original_character_count INTEGER NOT NULL DEFAULT 0,
                    cleaned_character_count INTEGER NOT NULL DEFAULT 0,
                    cleaned_text_digest TEXT NOT NULL DEFAULT '',
                    storage_status TEXT NOT NULL DEFAULT 'available',
                    migration_state TEXT NOT NULL DEFAULT 'current',
                    checksum_sha256 TEXT NOT NULL DEFAULT '',
                    integrity_note TEXT NOT NULL DEFAULT '',
                    schema_version INTEGER NOT NULL DEFAULT 0,
                    updated_at TEXT NOT NULL DEFAULT '',
                    position INTEGER NOT NULL DEFAULT 0
                );
                """
            )
            try db.execute(
                """
                CREATE TABLE IF NOT EXISTS corpus_tag (
                    corpus_id TEXT NOT NULL,
                    normalized_tag TEXT NOT NULL,
                    tag TEXT NOT NULL,
                    position INTEGER NOT NULL DEFAULT 0,
                    PRIMARY KEY (corpus_id, normalized_tag)
                );
                """
            )
            try db.execute(
                """
                CREATE TABLE IF NOT EXISTS corpus_year (
                    corpus_id TEXT NOT NULL,
                    year_value INTEGER NOT NULL,
                    position INTEGER NOT NULL DEFAULT 0,
                    PRIMARY KEY (corpus_id, year_value)
                );
                """
            )
            try db.execute(
                """
                CREATE TABLE IF NOT EXISTS corpus_set (
                    id TEXT PRIMARY KEY,
                    name TEXT NOT NULL,
                    metadata_filter_json TEXT NOT NULL,
                    created_at TEXT NOT NULL,
                    updated_at TEXT NOT NULL,
                    position INTEGER NOT NULL DEFAULT 0
                );
                """
            )
            try db.execute(
                """
                CREATE TABLE IF NOT EXISTS corpus_set_member (
                    corpus_set_id TEXT NOT NULL,
                    corpus_id TEXT NOT NULL,
                    corpus_name TEXT NOT NULL DEFAULT '',
                    position INTEGER NOT NULL DEFAULT 0,
                    PRIMARY KEY (corpus_set_id, corpus_id)
                );
                """
            )
            try db.execute(
                """
                CREATE TABLE IF NOT EXISTS recycle_entry (
                    id TEXT PRIMARY KEY,
                    type TEXT NOT NULL,
                    deleted_at TEXT NOT NULL,
                    name TEXT NOT NULL,
                    original_folder_name TEXT NOT NULL,
                    source_type TEXT NOT NULL,
                    item_count INTEGER NOT NULL,
                    folder_json TEXT NOT NULL DEFAULT '',
                    position INTEGER NOT NULL DEFAULT 0
                );
                """
            )
            try db.execute(
                """
                CREATE TABLE IF NOT EXISTS recycle_entry_corpus (
                    recycle_entry_id TEXT NOT NULL,
                    position INTEGER NOT NULL,
                    corpus_id TEXT NOT NULL,
                    payload_json TEXT NOT NULL,
                    PRIMARY KEY (recycle_entry_id, position)
                );
                """
            )
            try db.execute(
                """
                CREATE VIRTUAL TABLE IF NOT EXISTS corpus_search_fts USING fts5(
                    corpus_id UNINDEXED,
                    name,
                    folder_name,
                    source_type,
                    source_label,
                    genre_label,
                    year_label,
                    tags,
                    tokenize = 'unicode61 remove_diacritics 2'
                );
                """
            )
            try db.execute("CREATE INDEX IF NOT EXISTS idx_corpus_folder ON corpus(folder_id, position, name COLLATE NOCASE);")
            try db.execute("CREATE INDEX IF NOT EXISTS idx_corpus_imported_at ON corpus(imported_at DESC);")
            try db.execute("CREATE INDEX IF NOT EXISTS idx_corpus_source_label ON corpus(source_label COLLATE NOCASE);")
            try db.execute("CREATE INDEX IF NOT EXISTS idx_corpus_year_label ON corpus(year_label COLLATE NOCASE);")
            try db.execute("CREATE INDEX IF NOT EXISTS idx_corpus_genre_label ON corpus(genre_label COLLATE NOCASE);")
            try db.execute("CREATE INDEX IF NOT EXISTS idx_corpus_tags_text ON corpus(tags_text COLLATE NOCASE);")
            try db.execute("CREATE INDEX IF NOT EXISTS idx_corpus_storage_status ON corpus(storage_status, migration_state);")
            try db.execute("CREATE INDEX IF NOT EXISTS idx_corpus_tag_lookup ON corpus_tag(normalized_tag, corpus_id);")
            try db.execute("CREATE INDEX IF NOT EXISTS idx_corpus_year_lookup ON corpus_year(year_value, corpus_id);")
            try db.execute("CREATE INDEX IF NOT EXISTS idx_corpus_set_member_position ON corpus_set_member(corpus_set_id, position);")
            try db.execute("CREATE INDEX IF NOT EXISTS idx_recycle_entry_deleted_at ON recycle_entry(position, deleted_at DESC);")
            try db.execute(
                """
                INSERT OR IGNORE INTO schema_migrations(version, applied_at, description)
                VALUES (\(schemaVersion), '\(timestamp())', 'Initialize library catalog database with corpus search FTS');
                """
            )
            try rebuildCorpusSearchIndex(on: db)
        }
    }

    func metaValue(forKey key: String, on db: SQLiteDatabase) throws -> String? {
        let statement = try db.prepare("SELECT value FROM storage_meta WHERE key = ? LIMIT 1;")
        statement.bind(text: key, at: 1)
        guard statement.step() == SQLITE_ROW else { return nil }
        return statement.text(at: 0)
    }

    func setMetaValue(_ value: String, forKey key: String, on db: SQLiteDatabase) throws {
        let statement = try db.prepare(
            """
            INSERT INTO storage_meta(key, value)
            VALUES (?, ?)
            ON CONFLICT(key) DO UPDATE SET value = excluded.value;
            """
        )
        statement.bind(text: key, at: 1)
        statement.bind(text: value, at: 2)
        guard statement.step() == SQLITE_DONE else {
            throw db.error(message: "无法写入目录存储元数据")
        }
    }
}
