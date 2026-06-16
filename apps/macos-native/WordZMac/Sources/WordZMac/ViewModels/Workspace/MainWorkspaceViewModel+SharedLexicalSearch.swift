import Foundation

@MainActor
extension MainWorkspaceViewModel {
    func handleSharedLexicalSearchInputChange(from tab: WorkspaceDetailTab) {
        guard !isSynchronizingSharedLexicalSearch else { return }
        guard let query = lexicalSearchQuery(for: tab) else {
            scheduleInputStateSync()
            return
        }
        sharedLexicalSearchQuery = normalizedSharedLexicalSearchQuery(query)
        sharedLexicalSearchBaselineValues = topLevelSharedLexicalSearchValues()
        scheduleInputStateSync()
    }

    func syncSharedLexicalSearchQueryToSelectedTab() {
        let tab = selectedTab
        guard lexicalSearchQuery(for: tab) != nil else { return }
        let query = resolvedSharedLexicalSearchQuery()
        applySharedLexicalSearchQuery(query, to: tab)
    }

    private func resolvedSharedLexicalSearchQuery() -> String {
        let restoredValues = topLevelSharedLexicalSearchValues()
        if let sharedLexicalSearchQuery,
           restoredValues == sharedLexicalSearchBaselineValues {
            return sharedLexicalSearchQuery
        }

        if let commonRestoredValue = commonValue(in: restoredValues) {
            sharedLexicalSearchQuery = commonRestoredValue
            sharedLexicalSearchBaselineValues = restoredValues
            return commonRestoredValue
        }

        if let sharedLexicalSearchQuery {
            return sharedLexicalSearchQuery
        }

        if let selectedQuery = lexicalSearchQuery(for: selectedTab) {
            let normalized = normalizedSharedLexicalSearchQuery(selectedQuery)
            sharedLexicalSearchQuery = normalized
            sharedLexicalSearchBaselineValues = restoredValues
            return normalized
        }

        let fallback = restoredValues.first(where: { !$0.isEmpty }) ?? ""
        sharedLexicalSearchQuery = fallback
        sharedLexicalSearchBaselineValues = restoredValues
        return fallback
    }

    private func lexicalSearchQuery(for tab: WorkspaceDetailTab) -> String? {
        switch tab {
        case .word:
            return word.query
        case .tokenize:
            return tokenize.query
        case .topics:
            return topics.query
        case .compare:
            return compare.query
        case .plot:
            return plot.query
        case .ngram:
            return ngram.query
        case .cluster:
            return cluster.query
        case .kwic:
            return kwic.keyword
        case .collocate:
            return collocate.keyword
        default:
            return nil
        }
    }

    private func topLevelSharedLexicalSearchValues() -> [String] {
        [
            word.query,
            tokenize.query,
            topics.query,
            compare.query,
            ngram.query,
            cluster.query,
            kwic.keyword,
            collocate.keyword
        ].map(normalizedSharedLexicalSearchQuery)
    }

    private func commonValue(in values: [String]) -> String? {
        guard let first = values.first else { return nil }
        return values.allSatisfy { $0 == first } ? first : nil
    }

    private func applySharedLexicalSearchQuery(_ query: String, to tab: WorkspaceDetailTab) {
        guard lexicalSearchQuery(for: tab).map(normalizedSharedLexicalSearchQuery) != query else { return }

        isSynchronizingSharedLexicalSearch = true
        defer { isSynchronizingSharedLexicalSearch = false }

        switch tab {
        case .word:
            word.applyStateChange(rebuildScene: word.rebuildScene) {
                word.query = query
            }
        case .tokenize:
            tokenize.applyStateChange(rebuildScene: tokenize.rebuildScene) {
                tokenize.query = query
            }
        case .topics:
            topics.applyStateChange(rebuildScene: topics.rebuildScene) {
                topics.query = query
            }
        case .compare:
            compare.applyStateChange(rebuildScene: compare.rebuildScene) {
                compare.query = query
            }
        case .plot:
            plot.isApplyingInputState = true
            defer { plot.isApplyingInputState = false }
            plot.query = query
        case .ngram:
            ngram.isApplyingState = true
            defer {
                ngram.isApplyingState = false
                ngram.rebuildScene()
            }
            ngram.query = query
        case .cluster:
            cluster.isApplyingState = true
            defer {
                cluster.isApplyingState = false
                cluster.rebuildScene()
            }
            cluster.query = query
        case .kwic:
            kwic.applyStateChange {
                kwic.keyword = query
            }
        case .collocate:
            collocate.applyStateChange {
                collocate.keyword = query
            }
        default:
            break
        }
    }

    private func normalizedSharedLexicalSearchQuery(_ query: String) -> String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
