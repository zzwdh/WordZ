import Foundation
import SQLite3

struct WorkspaceStateStore {
    struct StorageSummary: Equatable {
        let schemaVersion: Int
        let workspaceSnapshotCount: Int
        let uiSettingsCount: Int
        let analysisPresetCount: Int
        let keywordSavedListCount: Int
        let concordanceSavedSetCount: Int
        let evidenceItemCount: Int
        let sentimentReviewSampleCount: Int
    }

    let fileManager: FileManager
    let encoder: JSONEncoder
    let decoder: JSONDecoder
    let databaseURL: URL

    private let configuration = SQLiteDatabaseConfiguration.workspaceState
    private let schemaVersion = 1

    func ensureInitialized() throws {
        try fileManager.createDirectory(
            at: databaseURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )
        try withDatabase { db in
            try applySchema(on: db)
            try seedDefaultStateIfNeeded(on: db)
        }
    }

    func loadWorkspaceSnapshot() throws -> NativePersistedWorkspaceSnapshot {
        try withDatabase { db in
            let statement = try db.prepare(
                """
                SELECT payload_json
                FROM workspace_snapshot
                WHERE id = 1
                LIMIT 1;
                """
            )
            guard statement.step() == SQLITE_ROW,
                  let snapshot = decodeJSON(NativePersistedWorkspaceSnapshot.self, from: statement.text(at: 0)) else {
                return .empty
            }
            return snapshot
        }
    }

    func saveWorkspaceSnapshot(_ snapshot: NativePersistedWorkspaceSnapshot) throws {
        try withDatabase { db in
            try replaceWorkspaceSnapshot(snapshot, on: db)
        }
    }

    func loadUISettings() throws -> NativePersistedUISettings {
        try withDatabase { db in
            let statement = try db.prepare(
                """
                SELECT payload_json
                FROM ui_settings
                WHERE id = 1
                LIMIT 1;
                """
            )
            guard statement.step() == SQLITE_ROW,
                  let settings = decodeJSON(NativePersistedUISettings.self, from: statement.text(at: 0)) else {
                return .default
            }
            return settings
        }
    }

    func saveUISettings(_ settings: NativePersistedUISettings) throws {
        try withDatabase { db in
            try replaceUISettings(settings, on: db)
        }
    }

    func loadAnalysisPresets() throws -> [NativeAnalysisPresetRecord] {
        try loadRecords(
            sql: """
            SELECT payload_json
            FROM analysis_preset
            ORDER BY updated_at DESC, position ASC;
            """,
            type: NativeAnalysisPresetRecord.self
        )
    }

    func saveAnalysisPresets(_ presets: [NativeAnalysisPresetRecord]) throws {
        try withDatabase { db in
            try replaceAnalysisPresets(presets, on: db)
        }
    }

    func loadKeywordSavedLists() throws -> [KeywordSavedList] {
        try loadRecords(
            sql: """
            SELECT payload_json
            FROM keyword_saved_list
            ORDER BY updated_at DESC, position ASC;
            """,
            type: KeywordSavedList.self
        )
    }

    func saveKeywordSavedLists(_ lists: [KeywordSavedList]) throws {
        try withDatabase { db in
            try replaceKeywordSavedLists(lists, on: db)
        }
    }

    func loadConcordanceSavedSets() throws -> [ConcordanceSavedSet] {
        try loadRecords(
            sql: """
            SELECT payload_json
            FROM concordance_saved_set
            ORDER BY updated_at DESC, position ASC;
            """,
            type: ConcordanceSavedSet.self
        )
    }

    func saveConcordanceSavedSets(_ sets: [ConcordanceSavedSet]) throws {
        try withDatabase { db in
            try replaceConcordanceSavedSets(sets, on: db)
        }
    }

    func loadEvidenceItems() throws -> [EvidenceItem] {
        try loadRecords(
            sql: """
            SELECT payload_json
            FROM evidence_item
            ORDER BY position ASC, updated_at DESC;
            """,
            type: EvidenceItem.self
        )
    }

    func saveEvidenceItems(_ items: [EvidenceItem]) throws {
        try withDatabase { db in
            try replaceEvidenceItems(items, on: db)
        }
    }

    func loadSentimentReviewSamples() throws -> [SentimentReviewSample] {
        try loadRecords(
            sql: """
            SELECT payload_json
            FROM sentiment_review_sample
            ORDER BY position ASC, updated_at DESC;
            """,
            type: SentimentReviewSample.self
        )
    }

    func saveSentimentReviewSamples(_ samples: [SentimentReviewSample]) throws {
        try withDatabase { db in
            try replaceSentimentReviewSamples(samples, on: db)
        }
    }

    func backupDatabase(to destinationURL: URL) throws {
        try SQLiteDatabase.backupDatabase(
            from: databaseURL,
            to: destinationURL,
            configuration: configuration,
            fileManager: fileManager
        )
    }

    func storageSummary() throws -> StorageSummary {
        try withDatabase { db in
            StorageSummary(
                schemaVersion: try db.scalarInt("SELECT COALESCE(MAX(version), 0) FROM schema_migrations;"),
                workspaceSnapshotCount: try db.scalarInt("SELECT COUNT(*) FROM workspace_snapshot;"),
                uiSettingsCount: try db.scalarInt("SELECT COUNT(*) FROM ui_settings;"),
                analysisPresetCount: try db.scalarInt("SELECT COUNT(*) FROM analysis_preset;"),
                keywordSavedListCount: try db.scalarInt("SELECT COUNT(*) FROM keyword_saved_list;"),
                concordanceSavedSetCount: try db.scalarInt("SELECT COUNT(*) FROM concordance_saved_set;"),
                evidenceItemCount: try db.scalarInt("SELECT COUNT(*) FROM evidence_item;"),
                sentimentReviewSampleCount: try db.scalarInt("SELECT COUNT(*) FROM sentiment_review_sample;")
            )
        }
    }

    func schemaVersionSummary() -> Int {
        schemaVersion
    }

    private func withDatabase<T>(_ body: (SQLiteDatabase) throws -> T) throws -> T {
        let database = try SQLiteDatabase(url: databaseURL, configuration: configuration)
        return try body(database)
    }

    private func loadRecords<T: Decodable>(sql: String, type: T.Type) throws -> [T] {
        try withDatabase { db in
            let statement = try db.prepare(sql)
            var items: [T] = []
            while statement.step() == SQLITE_ROW {
                if let item = decodeJSON(T.self, from: statement.text(at: 0)) {
                    items.append(item)
                }
            }
            return items
        }
    }

    private func seedDefaultStateIfNeeded(on db: SQLiteDatabase) throws {
        if try db.scalarInt("SELECT COUNT(*) FROM workspace_snapshot;") == 0 {
            try replaceWorkspaceSnapshot(.empty, on: db)
        }
        if try db.scalarInt("SELECT COUNT(*) FROM ui_settings;") == 0 {
            try replaceUISettings(.default, on: db)
        }
    }

    private func applySchema(on db: SQLiteDatabase) throws {
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
                CREATE TABLE IF NOT EXISTS workspace_snapshot (
                    id INTEGER PRIMARY KEY CHECK (id = 1),
                    payload_json TEXT NOT NULL,
                    updated_at TEXT NOT NULL
                );
                """
            )
            try db.execute(
                """
                CREATE TABLE IF NOT EXISTS ui_settings (
                    id INTEGER PRIMARY KEY CHECK (id = 1),
                    payload_json TEXT NOT NULL,
                    updated_at TEXT NOT NULL
                );
                """
            )
            try db.execute(
                """
                CREATE TABLE IF NOT EXISTS analysis_preset (
                    id TEXT PRIMARY KEY,
                    name TEXT NOT NULL,
                    created_at TEXT NOT NULL,
                    updated_at TEXT NOT NULL,
                    position INTEGER NOT NULL DEFAULT 0,
                    payload_json TEXT NOT NULL
                );
                """
            )
            try db.execute(
                """
                CREATE TABLE IF NOT EXISTS keyword_saved_list (
                    id TEXT PRIMARY KEY,
                    name TEXT NOT NULL,
                    updated_at TEXT NOT NULL,
                    position INTEGER NOT NULL DEFAULT 0,
                    payload_json TEXT NOT NULL
                );
                """
            )
            try db.execute(
                """
                CREATE TABLE IF NOT EXISTS concordance_saved_set (
                    id TEXT PRIMARY KEY,
                    name TEXT NOT NULL,
                    kind TEXT NOT NULL,
                    updated_at TEXT NOT NULL,
                    position INTEGER NOT NULL DEFAULT 0,
                    payload_json TEXT NOT NULL
                );
                """
            )
            try db.execute(
                """
                CREATE TABLE IF NOT EXISTS evidence_item (
                    id TEXT PRIMARY KEY,
                    corpus_id TEXT NOT NULL,
                    sentence_id INTEGER NOT NULL,
                    updated_at TEXT NOT NULL,
                    position INTEGER NOT NULL DEFAULT 0,
                    payload_json TEXT NOT NULL
                );
                """
            )
            try db.execute(
                """
                CREATE TABLE IF NOT EXISTS sentiment_review_sample (
                    id TEXT PRIMARY KEY,
                    match_key TEXT NOT NULL,
                    updated_at TEXT NOT NULL,
                    backend_kind TEXT NOT NULL,
                    domain_pack_id TEXT NOT NULL,
                    position INTEGER NOT NULL DEFAULT 0,
                    payload_json TEXT NOT NULL
                );
                """
            )
            try db.execute("CREATE UNIQUE INDEX IF NOT EXISTS uq_sentiment_review_match_key ON sentiment_review_sample(match_key);")
            try db.execute("CREATE INDEX IF NOT EXISTS idx_analysis_preset_updated_at ON analysis_preset(updated_at DESC);")
            try db.execute("CREATE INDEX IF NOT EXISTS idx_keyword_saved_list_updated_at ON keyword_saved_list(updated_at DESC);")
            try db.execute("CREATE INDEX IF NOT EXISTS idx_concordance_saved_set_updated_at ON concordance_saved_set(updated_at DESC);")
            try db.execute("CREATE INDEX IF NOT EXISTS idx_evidence_item_corpus ON evidence_item(corpus_id, sentence_id);")
            try db.execute("CREATE INDEX IF NOT EXISTS idx_sentiment_review_updated_at ON sentiment_review_sample(updated_at DESC);")
            try db.execute(
                """
                INSERT OR IGNORE INTO schema_migrations(version, applied_at, description)
                VALUES (\(schemaVersion), '\(timestamp())', 'Initialize workspace state database');
                """
            )
        }
    }

    private func replaceWorkspaceSnapshot(_ snapshot: NativePersistedWorkspaceSnapshot, on db: SQLiteDatabase) throws {
        let statement = try db.prepare(
            """
            INSERT INTO workspace_snapshot(id, payload_json, updated_at)
            VALUES (1, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                payload_json = excluded.payload_json,
                updated_at = excluded.updated_at;
            """
        )
        statement.bind(text: encodeJSON(snapshot), at: 1)
        statement.bind(text: timestamp(), at: 2)
        guard statement.step() == SQLITE_DONE else {
            throw db.error(message: "无法写入工作区快照")
        }
    }

    private func replaceUISettings(_ settings: NativePersistedUISettings, on db: SQLiteDatabase) throws {
        let statement = try db.prepare(
            """
            INSERT INTO ui_settings(id, payload_json, updated_at)
            VALUES (1, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                payload_json = excluded.payload_json,
                updated_at = excluded.updated_at;
            """
        )
        statement.bind(text: encodeJSON(settings), at: 1)
        statement.bind(text: timestamp(), at: 2)
        guard statement.step() == SQLITE_DONE else {
            throw db.error(message: "无法写入界面设置")
        }
    }

    private func replaceAnalysisPresets(_ presets: [NativeAnalysisPresetRecord], on db: SQLiteDatabase) throws {
        try replaceOrderedPayloadTable(
            name: "analysis_preset",
            rows: presets.enumerated().map { index, preset in
                [
                    preset.id,
                    preset.name,
                    preset.createdAt,
                    preset.updatedAt,
                    "\(index)",
                    encodeJSON(preset)
                ]
            },
            sql: """
            INSERT INTO analysis_preset(id, name, created_at, updated_at, position, payload_json)
            VALUES (?, ?, ?, ?, ?, ?);
            """,
            on: db
        )
    }

    private func replaceKeywordSavedLists(_ lists: [KeywordSavedList], on db: SQLiteDatabase) throws {
        try replaceOrderedPayloadTable(
            name: "keyword_saved_list",
            rows: lists.enumerated().map { index, list in
                [
                    list.id,
                    list.name,
                    list.updatedAt,
                    "\(index)",
                    encodeJSON(list)
                ]
            },
            sql: """
            INSERT INTO keyword_saved_list(id, name, updated_at, position, payload_json)
            VALUES (?, ?, ?, ?, ?);
            """,
            on: db
        )
    }

    private func replaceConcordanceSavedSets(_ sets: [ConcordanceSavedSet], on db: SQLiteDatabase) throws {
        try replaceOrderedPayloadTable(
            name: "concordance_saved_set",
            rows: sets.enumerated().map { index, set in
                [
                    set.id,
                    set.name,
                    set.kind.rawValue,
                    set.updatedAt,
                    "\(index)",
                    encodeJSON(set)
                ]
            },
            sql: """
            INSERT INTO concordance_saved_set(id, name, kind, updated_at, position, payload_json)
            VALUES (?, ?, ?, ?, ?, ?);
            """,
            on: db
        )
    }

    private func replaceEvidenceItems(_ items: [EvidenceItem], on db: SQLiteDatabase) throws {
        try replaceOrderedPayloadTable(
            name: "evidence_item",
            rows: items.enumerated().map { index, item in
                [
                    item.id,
                    item.corpusID,
                    "\(item.sentenceId)",
                    item.updatedAt,
                    "\(index)",
                    encodeJSON(item)
                ]
            },
            sql: """
            INSERT INTO evidence_item(id, corpus_id, sentence_id, updated_at, position, payload_json)
            VALUES (?, ?, ?, ?, ?, ?);
            """,
            on: db
        )
    }

    private func replaceSentimentReviewSamples(_ samples: [SentimentReviewSample], on db: SQLiteDatabase) throws {
        try replaceOrderedPayloadTable(
            name: "sentiment_review_sample",
            rows: samples.enumerated().map { index, sample in
                [
                    sample.id,
                    sample.matchKey.storageKey,
                    sample.updatedAt,
                    sample.backendKind.rawValue,
                    sample.domainPackID.rawValue,
                    "\(index)",
                    encodeJSON(sample)
                ]
            },
            sql: """
            INSERT INTO sentiment_review_sample(id, match_key, updated_at, backend_kind, domain_pack_id, position, payload_json)
            VALUES (?, ?, ?, ?, ?, ?, ?);
            """,
            on: db
        )
    }

    private func replaceOrderedPayloadTable(
        name: String,
        rows: [[String]],
        sql: String,
        on db: SQLiteDatabase
    ) throws {
        try db.transaction {
            try db.execute("DELETE FROM \(name);")
            let statement = try db.prepare(sql)
            for row in rows {
                statement.reset()
                for (index, value) in row.enumerated() {
                    statement.bind(text: value, at: Int32(index + 1))
                }
                guard statement.step() == SQLITE_DONE else {
                    throw db.error(message: "无法写入 \(name) 数据")
                }
            }
        }
    }

    private func metaValue(forKey key: String, on db: SQLiteDatabase) throws -> String? {
        let statement = try db.prepare("SELECT value FROM storage_meta WHERE key = ? LIMIT 1;")
        statement.bind(text: key, at: 1)
        guard statement.step() == SQLITE_ROW else { return nil }
        return statement.text(at: 0)
    }

    private func setMetaValue(_ value: String, forKey key: String, on db: SQLiteDatabase) throws {
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
            throw db.error(message: "无法写入工作区存储元数据")
        }
    }

    private func encodeJSON<T: Encodable>(_ value: T) -> String {
        guard let data = try? encoder.encode(value),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }

    private func decodeJSON<T: Decodable>(_ type: T.Type, from string: String) -> T? {
        guard let data = string.data(using: .utf8), !data.isEmpty else { return nil }
        return try? decoder.decode(type, from: data)
    }

    private func timestamp() -> String {
        NativeDateFormatting.iso8601String(from: Date())
    }
}
