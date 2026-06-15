import Foundation

package struct ResultTableSnapshot: Equatable, Sendable {
    package let version: Int
    package let rows: [NativeTableRowDescriptor]
    package let rowIndexByID: [String: Int]

    package init(
        version: Int = ResultTableSnapshotVersioning.next(),
        rows: [NativeTableRowDescriptor]
    ) {
        self.version = version
        self.rows = rows
        self.rowIndexByID = NativeTableRowIndexing.firstIndexByID(rows)
    }

    package static func stable(rows: [NativeTableRowDescriptor]) -> ResultTableSnapshot {
        ResultTableSnapshot(
            version: StableResultTableSnapshotVersioning.version(for: rows),
            rows: rows
        )
    }

    package static let empty = ResultTableSnapshot(version: 0, rows: [])
}

private enum ResultTableSnapshotVersioning {
    private static let queue = DispatchQueue(label: "WordZMac.ResultTableSnapshotVersioning")
    nonisolated(unsafe) private static var currentVersion = 0

    static func next() -> Int {
        queue.sync {
            currentVersion &+= 1
            return currentVersion
        }
    }
}

private enum StableResultTableSnapshotVersioning {
    private static let offsetBasis: UInt64 = 14_695_981_039_346_656_037
    private static let prime: UInt64 = 1_099_511_628_211

    static func version(for rows: [NativeTableRowDescriptor]) -> Int {
        guard !rows.isEmpty else { return 1 }

        var hash = offsetBasis
        for row in rows {
            mix(row.id, into: &hash)
            for key in row.cells.keys.sorted() {
                mix(key, into: &hash)
                mix(row.value(for: key), into: &hash)
            }
            mix("|", into: &hash)
        }

        let value = Int(truncatingIfNeeded: hash)
        return value == 0 ? 1 : value
    }

    private static func mix(_ string: String, into hash: inout UInt64) {
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash &*= prime
        }
    }
}

package enum NativeTableRowIndexing {
    package static func firstIndexByID(_ rows: [NativeTableRowDescriptor]) -> [String: Int] {
        var indexes: [String: Int] = [:]
        for (index, row) in rows.enumerated() where indexes[row.id] == nil {
            indexes[row.id] = index
        }
        return indexes
    }
}
