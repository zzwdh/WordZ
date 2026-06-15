import Foundation
import SQLite3
import WordZStorage

extension LibraryCatalogStore {
    func metadataQueryFilter(
        folderId: String?,
        metadataFilterState: CorpusMetadataFilterState,
        searchQuery: String
    ) -> (sql: String, arguments: [String]) {
        var clauses = ["storage_status != 'quarantined'"]
        var arguments: [String] = []

        if let folderId, !folderId.isEmpty, folderId != "all" {
            clauses.append("folder_id = ?")
            arguments.append(folderId)
        }

        if !metadataFilterState.sourceQuery.isEmpty {
            clauses.append("source_label LIKE ? COLLATE NOCASE")
            arguments.append(likePattern(metadataFilterState.sourceQuery))
        }

        if let yearBounds = normalizedYearBounds(from: metadataFilterState) {
            var yearPredicates: [String] = ["corpus_year.corpus_id = corpus.id"]
            if let lower = yearBounds.lower {
                yearPredicates.append("corpus_year.year_value >= ?")
                arguments.append(String(lower))
            }
            if let upper = yearBounds.upper {
                yearPredicates.append("corpus_year.year_value <= ?")
                arguments.append(String(upper))
            }
            clauses.append(
                """
                EXISTS (
                    SELECT 1
                    FROM corpus_year
                    WHERE \(yearPredicates.joined(separator: " AND "))
                )
                """
            )
        } else if !metadataFilterState.yearQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            clauses.append("year_label LIKE ? COLLATE NOCASE")
            arguments.append(likePattern(metadataFilterState.yearQuery))
        }

        if !metadataFilterState.genreQuery.isEmpty {
            clauses.append("genre_label LIKE ? COLLATE NOCASE")
            arguments.append(likePattern(metadataFilterState.genreQuery))
        }

        for tagQuery in normalizedTagQueries(from: metadataFilterState.tagsQuery) {
            clauses.append(
                """
                EXISTS (
                    SELECT 1
                    FROM corpus_tag
                    WHERE corpus_tag.corpus_id = corpus.id
                      AND corpus_tag.normalized_tag LIKE ?
                )
                """
            )
            arguments.append(likePattern(tagQuery))
        }

        let trimmedSearchQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedSearchQuery.isEmpty {
            if let matchExpression = ftsMatchExpression(for: trimmedSearchQuery) {
                clauses.append(
                    """
                    EXISTS (
                        SELECT 1
                        FROM corpus_search_fts
                        WHERE corpus_search_fts.corpus_id = corpus.id
                          AND corpus_search_fts MATCH ?
                    )
                    """
                )
                arguments.append(matchExpression)
            } else {
                let pattern = likePattern(trimmedSearchQuery)
                clauses.append(
                    """
                    (
                        name LIKE ? COLLATE NOCASE
                        OR folder_name LIKE ? COLLATE NOCASE
                        OR source_type LIKE ? COLLATE NOCASE
                        OR source_label LIKE ? COLLATE NOCASE
                        OR year_label LIKE ? COLLATE NOCASE
                        OR genre_label LIKE ? COLLATE NOCASE
                        OR tags_text LIKE ? COLLATE NOCASE
                    )
                    """
                )
                arguments.append(contentsOf: Array(repeating: pattern, count: 7))
            }
        }

        let sql = clauses.isEmpty ? "" : "WHERE " + clauses.joined(separator: " AND ")
        return (sql, arguments)
    }

    func likePattern(_ value: String) -> String {
        "%\(value.trimmingCharacters(in: .whitespacesAndNewlines))%"
    }

    func ftsMatchExpression(for rawValue: String) -> String? {
        let terms = rawValue
            .split(whereSeparator: \.isWhitespace)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !terms.isEmpty else { return nil }

        let safeTerms = terms.compactMap { term -> String? in
            guard term.unicodeScalars.allSatisfy({
                $0.isASCII && (CharacterSet.alphanumerics.contains($0) || String($0) == "_")
            }) else {
                return nil
            }
            return "\(term)*"
        }
        guard safeTerms.count == terms.count else { return nil }
        return safeTerms.joined(separator: " ")
    }

    func normalizedTagQueries(from rawValue: String) -> [String] {
        rawValue
            .split(whereSeparator: { [",", "，", ";", "；", "\n"].contains($0) })
            .map { normalizedTag(String($0)) }
            .filter { !$0.isEmpty }
    }

    func normalizedTag(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    func extractedYears(from value: String) -> [Int] {
        Array(Set(MetadataYearSuggestionSupport.extractYears(from: value))).sorted()
    }

    func normalizedYearBounds(from state: CorpusMetadataFilterState) -> (lower: Int?, upper: Int?)? {
        let lower = parseYear(state.yearFrom)
        let upper = parseYear(state.yearTo)
        guard lower != nil || upper != nil else { return nil }
        switch (lower, upper) {
        case let (.some(lhs), .some(rhs)):
            return (min(lhs, rhs), max(lhs, rhs))
        default:
            return (lower, upper)
        }
    }

    func parseYear(_ value: String?) -> Int? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count == 4,
              trimmed.allSatisfy(\.isNumber),
              let parsed = Int(trimmed) else {
            return nil
        }
        return parsed
    }

    func rebuildCorpusSearchIndex(on db: SQLiteDatabase) throws {
        try db.execute("DELETE FROM corpus_search_fts;")
        let selectStatement = try db.prepare(
            """
            SELECT id, name, folder_name, source_type, source_label, genre_label, year_label, tags_text
            FROM corpus
            WHERE storage_status != 'quarantined'
            ORDER BY position ASC, name COLLATE NOCASE ASC;
            """
        )
        let insertStatement = try db.prepare(
            """
            INSERT INTO corpus_search_fts (
                corpus_id,
                name,
                folder_name,
                source_type,
                source_label,
                genre_label,
                year_label,
                tags
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?);
            """
        )

        while selectStatement.step() == SQLITE_ROW {
            insertStatement.reset()
            insertStatement.bind(text: selectStatement.text(at: 0), at: 1)
            insertStatement.bind(text: selectStatement.text(at: 1), at: 2)
            insertStatement.bind(text: selectStatement.text(at: 2), at: 3)
            insertStatement.bind(text: selectStatement.text(at: 3), at: 4)
            insertStatement.bind(text: selectStatement.text(at: 4), at: 5)
            insertStatement.bind(text: selectStatement.text(at: 5), at: 6)
            insertStatement.bind(text: selectStatement.text(at: 6), at: 7)
            insertStatement.bind(text: selectStatement.text(at: 7), at: 8)
            guard insertStatement.step() == SQLITE_DONE else {
                throw db.error(message: "无法重建语料搜索索引")
            }
        }
    }
}
