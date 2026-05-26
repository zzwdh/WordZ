import Foundation
import SQLite3

extension LibraryCatalogStore {
    func loadCorpusSets() throws -> [NativeCorpusSetRecord] {
        try withDatabase { db in
            let memberStatement = try db.prepare(
                """
                SELECT corpus_set_id, corpus_id, corpus_name
                FROM corpus_set_member
                ORDER BY corpus_set_id ASC, position ASC;
                """
            )
            var membersBySetID: [String: [(String, String)]] = [:]
            while memberStatement.step() == SQLITE_ROW {
                membersBySetID[memberStatement.text(at: 0), default: []].append(
                    (memberStatement.text(at: 1), memberStatement.text(at: 2))
                )
            }

            let statement = try db.prepare(
                """
                SELECT id, name, metadata_filter_json, created_at, updated_at
                FROM corpus_set
                ORDER BY position ASC, updated_at DESC;
                """
            )
            var sets: [NativeCorpusSetRecord] = []
            while statement.step() == SQLITE_ROW {
                let id = statement.text(at: 0)
                let members = membersBySetID[id, default: []]
                sets.append(
                    NativeCorpusSetRecord(
                        id: id,
                        name: statement.text(at: 1),
                        corpusIDs: members.map(\.0),
                        corpusNames: members.map(\.1),
                        metadataFilterState: decodeJSON(CorpusMetadataFilterState.self, from: statement.text(at: 2)) ?? .empty,
                        createdAt: statement.text(at: 3),
                        updatedAt: statement.text(at: 4)
                    )
                )
            }
            return sets
        }
    }

    func saveCorpusSets(_ corpusSets: [NativeCorpusSetRecord]) throws {
        try withDatabase { db in
            try replaceCorpusSets(corpusSets, on: db)
        }
    }

    func replaceCorpusSets(_ corpusSets: [NativeCorpusSetRecord], on db: SQLiteDatabase) throws {
        try db.transaction {
            try db.execute("DELETE FROM corpus_set_member;")
            try db.execute("DELETE FROM corpus_set;")

            let statement = try db.prepare(
                """
                INSERT INTO corpus_set (id, name, metadata_filter_json, created_at, updated_at, position)
                VALUES (?, ?, ?, ?, ?, ?);
                """
            )
            let memberStatement = try db.prepare(
                """
                INSERT INTO corpus_set_member (corpus_set_id, corpus_id, corpus_name, position)
                VALUES (?, ?, ?, ?);
                """
            )
            for (position, corpusSet) in corpusSets.enumerated() {
                statement.reset()
                statement.bind(text: corpusSet.id, at: 1)
                statement.bind(text: corpusSet.name, at: 2)
                statement.bind(text: encodeJSON(corpusSet.metadataFilterState), at: 3)
                statement.bind(text: corpusSet.createdAt, at: 4)
                statement.bind(text: corpusSet.updatedAt, at: 5)
                statement.bind(int: position, at: 6)
                guard statement.step() == SQLITE_DONE else {
                    throw db.error(message: "无法写入语料集目录")
                }

                for (memberPosition, corpusID) in corpusSet.corpusIDs.enumerated() {
                    memberStatement.reset()
                    memberStatement.bind(text: corpusSet.id, at: 1)
                    memberStatement.bind(text: corpusID, at: 2)
                    memberStatement.bind(text: corpusSet.corpusNames[safe: memberPosition] ?? "", at: 3)
                    memberStatement.bind(int: memberPosition, at: 4)
                    guard memberStatement.step() == SQLITE_DONE else {
                        throw db.error(message: "无法写入语料集成员")
                    }
                }
            }
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
