import Foundation

struct BatchCorpusMetadataPatch: Equatable, Sendable {
    let sourceLabel: String?
    let yearLabel: String?
    let genreLabel: String?
    let tagsToAdd: [String]

    init(
        sourceLabel: String? = nil,
        yearLabel: String? = nil,
        genreLabel: String? = nil,
        tagsToAdd: [String] = []
    ) {
        let normalizedSource = sourceLabel?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedYear = yearLabel?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedGenre = genreLabel?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.sourceLabel = normalizedSource?.isEmpty == true ? nil : normalizedSource
        self.yearLabel = normalizedYear?.isEmpty == true ? nil : normalizedYear
        self.genreLabel = normalizedGenre?.isEmpty == true ? nil : normalizedGenre
        self.tagsToAdd = tagsToAdd
            .flatMap { $0.split(separator: ",").map(String.init) }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var hasChanges: Bool {
        sourceLabel != nil || yearLabel != nil || genreLabel != nil || !tagsToAdd.isEmpty
    }

    func applying(to metadata: CorpusMetadataProfile) -> CorpusMetadataProfile {
        CorpusMetadataProfile(
            sourceLabel: sourceLabel ?? metadata.sourceLabel,
            yearLabel: yearLabel ?? metadata.yearLabel,
            genreLabel: genreLabel ?? metadata.genreLabel,
            tags: metadata.tags + tagsToAdd
        )
    }
}
