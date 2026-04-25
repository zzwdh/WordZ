import Foundation

@MainActor
final class LexicalAutocompleteController: ObservableObject {
    @Published private(set) var activeCorpusID: String?
    @Published private(set) var loadedCorpusID: String?
    @Published private(set) var revision = 0

    private let repository: (any StoredFrequencyArtifactReadingRepository)?
    private var entries: [Entry] = []
    private var loadTask: Task<Void, Never>?
    private var loadGeneration = 0

    init(repository: (any StoredFrequencyArtifactReadingRepository)? = nil) {
        self.repository = repository
    }

    func updateSelectedCorpusID(_ corpusID: String?) {
        guard activeCorpusID != corpusID else { return }
        activeCorpusID = corpusID
        scheduleLoad(for: corpusID)
    }

    func suggestions(
        for query: String,
        options: SearchOptionsState,
        limit: Int = 8
    ) -> [LexicalAutocompleteSuggestion] {
        guard options.regex == false, options.matchMode == .token else {
            return []
        }

        let normalizedPrefix = normalizedPrefix(from: query)
        guard !normalizedPrefix.isEmpty else {
            return []
        }

        let safeLimit = max(1, limit)
        return Array(
            entries.lazy
                .filter { $0.normalizedTerm.hasPrefix(normalizedPrefix) }
                .prefix(safeLimit)
                .map(\.suggestion)
        )
    }

    private func scheduleLoad(for corpusID: String?) {
        loadGeneration += 1
        let generation = loadGeneration
        loadTask?.cancel()
        loadTask = nil

        guard let corpusID, let repository else {
            applyLoadedArtifact(nil, for: corpusID, generation: generation)
            return
        }

        entries = []
        loadedCorpusID = nil
        revision += 1

        loadTask = Task { @MainActor [weak self] in
            let artifact: StoredFrequencyArtifact?
            do {
                artifact = try await repository.loadStoredFrequencyArtifact(corpusId: corpusID)
            } catch {
                artifact = nil
            }

            guard !Task.isCancelled else { return }
            self?.applyLoadedArtifact(artifact, for: corpusID, generation: generation)
        }
    }

    private func applyLoadedArtifact(
        _ artifact: StoredFrequencyArtifact?,
        for corpusID: String?,
        generation: Int
    ) {
        guard generation == loadGeneration else { return }
        guard activeCorpusID == corpusID else { return }

        if let artifact {
            entries = artifact.frequencyRows
                .enumerated()
                .compactMap(Entry.init)
                .sorted(by: Entry.areInSuggestionOrder)
            loadedCorpusID = entries.isEmpty ? nil : corpusID
        } else {
            entries = []
            loadedCorpusID = nil
        }

        revision += 1
    }

    private func normalizedPrefix(from query: String) -> String {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        guard trimmed.contains("*") == false, trimmed.contains("?") == false else {
            return ""
        }

        let tokens = AnalysisTextNormalizationSupport.tokenizeWordLikeSegments(in: trimmed)
        guard tokens.count == 1, let token = tokens.first else {
            return ""
        }

        return token
    }
}

private extension LexicalAutocompleteController {
    struct Entry: Sendable {
        let sourceIndex: Int
        let normalizedTerm: String
        let suggestion: LexicalAutocompleteSuggestion

        init?(indexedRow: (offset: Int, element: FrequencyRow)) {
            let row = indexedRow.element
            let normalizedTerm = AnalysisTextNormalizationSupport.normalizeToken(row.word)
            guard !normalizedTerm.isEmpty else { return nil }

            sourceIndex = indexedRow.offset
            self.normalizedTerm = normalizedTerm
            self.suggestion = LexicalAutocompleteSuggestion(
                term: row.word,
                count: row.count,
                rank: row.rank > 0 ? row.rank : nil
            )
        }

        static func areInSuggestionOrder(_ lhs: Entry, _ rhs: Entry) -> Bool {
            if lhs.suggestion.count != rhs.suggestion.count {
                return lhs.suggestion.count > rhs.suggestion.count
            }

            if lhs.normalizedTerm != rhs.normalizedTerm {
                return lhs.normalizedTerm < rhs.normalizedTerm
            }

            if lhs.suggestion.term != rhs.suggestion.term {
                return lhs.suggestion.term < rhs.suggestion.term
            }

            return lhs.sourceIndex < rhs.sourceIndex
        }
    }
}
