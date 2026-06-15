import Foundation
import SQLite3
import WordZStorage

extension LibraryCatalogStore {
    func loadRecycleEntries() throws -> [NativeRecycleRecord] {
        try withDatabase { db in
            let corpusStatement = try db.prepare(
                """
                SELECT recycle_entry_id, payload_json
                FROM recycle_entry_corpus
                ORDER BY recycle_entry_id ASC, position ASC;
                """
            )
            var corporaByEntryID: [String: [NativeCorpusRecord]] = [:]
            while corpusStatement.step() == SQLITE_ROW {
                let entryID = corpusStatement.text(at: 0)
                if let record = decodeJSON(NativeCorpusRecord.self, from: corpusStatement.text(at: 1)) {
                    corporaByEntryID[entryID, default: []].append(record)
                }
            }

            let statement = try db.prepare(
                """
                SELECT id, type, deleted_at, name, original_folder_name, source_type, item_count, folder_json
                FROM recycle_entry
                ORDER BY position ASC, deleted_at DESC;
                """
            )
            var entries: [NativeRecycleRecord] = []
            while statement.step() == SQLITE_ROW {
                let entryID = statement.text(at: 0)
                entries.append(
                    NativeRecycleRecord(
                        recycleEntryId: entryID,
                        type: statement.text(at: 1),
                        deletedAt: statement.text(at: 2),
                        name: statement.text(at: 3),
                        originalFolderName: statement.text(at: 4),
                        sourceType: statement.text(at: 5),
                        itemCount: statement.int(at: 6),
                        folder: decodeJSON(NativeFolderRecord.self, from: statement.text(at: 7)),
                        corpora: corporaByEntryID[entryID, default: []]
                    )
                )
            }
            return entries
        }
    }

    func saveRecycleEntries(_ entries: [NativeRecycleRecord]) throws {
        try withDatabase { db in
            try replaceRecycleEntries(entries, on: db)
        }
    }

    func replaceRecycleEntries(_ entries: [NativeRecycleRecord], on db: SQLiteDatabase) throws {
        try db.transaction {
            try db.execute("DELETE FROM recycle_entry_corpus;")
            try db.execute("DELETE FROM recycle_entry;")

            let statement = try db.prepare(
                """
                INSERT INTO recycle_entry (
                    id, type, deleted_at, name, original_folder_name, source_type, item_count, folder_json, position
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
                """
            )
            let corpusStatement = try db.prepare(
                """
                INSERT INTO recycle_entry_corpus (recycle_entry_id, position, corpus_id, payload_json)
                VALUES (?, ?, ?, ?);
                """
            )

            for (position, entry) in entries.enumerated() {
                statement.reset()
                statement.bind(text: entry.recycleEntryId, at: 1)
                statement.bind(text: entry.type, at: 2)
                statement.bind(text: entry.deletedAt, at: 3)
                statement.bind(text: entry.name, at: 4)
                statement.bind(text: entry.originalFolderName, at: 5)
                statement.bind(text: entry.sourceType, at: 6)
                statement.bind(int: entry.itemCount, at: 7)
                statement.bind(text: encodeJSON(entry.folder), at: 8)
                statement.bind(int: position, at: 9)
                guard statement.step() == SQLITE_DONE else {
                    throw db.error(message: "无法写入回收站条目")
                }

                for (corpusPosition, corpus) in entry.corpora.enumerated() {
                    corpusStatement.reset()
                    corpusStatement.bind(text: entry.recycleEntryId, at: 1)
                    corpusStatement.bind(int: corpusPosition, at: 2)
                    corpusStatement.bind(text: corpus.id, at: 3)
                    corpusStatement.bind(text: encodeJSON(corpus), at: 4)
                    guard corpusStatement.step() == SQLITE_DONE else {
                        throw db.error(message: "无法写入回收站语料快照")
                    }
                }
            }
        }
    }
}
