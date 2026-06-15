import Foundation
import SQLite3
import WordZStorage

extension LibraryCatalogStore {
    func loadFolders() throws -> [NativeFolderRecord] {
        try withDatabase { db in
            let statement = try db.prepare(
                """
                SELECT id, name
                FROM library_folder
                ORDER BY position ASC, name COLLATE NOCASE ASC;
                """
            )
            var folders: [NativeFolderRecord] = []
            while statement.step() == SQLITE_ROW {
                folders.append(NativeFolderRecord(id: statement.text(at: 0), name: statement.text(at: 1)))
            }
            return folders
        }
    }

    func saveFolders(_ folders: [NativeFolderRecord]) throws {
        try withDatabase { db in
            try replaceFolders(folders, on: db)
        }
    }

    func replaceFolders(_ folders: [NativeFolderRecord], on db: SQLiteDatabase) throws {
        try db.transaction {
            try db.execute("DELETE FROM library_folder;")
            let statement = try db.prepare(
                """
                INSERT INTO library_folder (id, name, position)
                VALUES (?, ?, ?);
                """
            )
            for (position, folder) in folders.enumerated() {
                statement.reset()
                statement.bind(text: folder.id, at: 1)
                statement.bind(text: folder.name, at: 2)
                statement.bind(int: position, at: 3)
                guard statement.step() == SQLITE_DONE else {
                    throw db.error(message: "无法写入文件夹目录")
                }
            }
        }
    }
}
