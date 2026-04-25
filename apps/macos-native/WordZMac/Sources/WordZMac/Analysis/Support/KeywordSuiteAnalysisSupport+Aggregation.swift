import Foundation

extension KeywordSuiteAnalyzer {
    static func aggregate(
        corpora: [KeywordPreparedCorpus],
        fallbackLabel: String,
        isWordList: Bool
    ) -> KeywordPreparedSideAggregate {
        let label: String
        let names = corpora.map { $0.entry.corpusName }
        if !fallbackLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            label = fallbackLabel
        } else if names.count == 1 {
            label = names[0]
        } else if names.isEmpty {
            label = ""
        } else {
            label = names.joined(separator: " · ")
        }

        return KeywordPreparedSideAggregate(
            summary: KeywordSuiteScopeSummary(
                label: label,
                corpusCount: corpora.count,
                corpusIDs: corpora.map { $0.entry.corpusId },
                corpusNames: names,
                tokenCount: corpora.reduce(0) { $0 + $1.words.totalCount },
                typeCount: Set(corpora.flatMap { $0.words.counts.keys }).count,
                isWordList: isWordList
            ),
            groups: [
                .words: merge(group: \.words, from: corpora),
                .terms: merge(group: \.terms, from: corpora),
                .ngrams: merge(group: \.ngrams, from: corpora)
            ]
        )
    }

    static func aggregateImportedReference(
        items: [KeywordReferenceWordListItem],
        fallbackLabel: String
    ) -> KeywordPreparedSideAggregate {
        let groups = Dictionary(uniqueKeysWithValues: KeywordResultGroup.allCases.map { group in
            (group, aggregateImportedReference(items: items, for: group))
        })
        let total = items.reduce(0) { $0 + $1.frequency }
        return KeywordPreparedSideAggregate(
            summary: KeywordSuiteScopeSummary(
                label: fallbackLabel.isEmpty ? wordZText("导入词表", "Imported Word List", mode: .system) : fallbackLabel,
                corpusCount: 1,
                corpusIDs: [importedReferenceCorpusID],
                corpusNames: [fallbackLabel.isEmpty ? "Imported Word List" : fallbackLabel],
                tokenCount: total,
                typeCount: items.count,
                isWordList: true
            ),
            groups: groups
        )
    }

    static func aggregateImportedReference(
        items: [KeywordReferenceWordListItem],
        for group: KeywordResultGroup
    ) -> KeywordPreparedGroupAggregate {
        var counts: [String: Int] = [:]
        var ranges: [String: Set<String>] = [:]
        var examples: [String: KeywordExampleHit] = [:]
        var total = 0

        for item in items where importedReferenceItemBelongsToGroup(item, group: group) {
            counts[item.term, default: 0] += item.frequency
            ranges[item.term, default: []].insert(importedReferenceCorpusID)
            examples[item.term] = KeywordExampleHit(text: item.term, corpusID: importedReferenceCorpusID)
            total += item.frequency
        }

        return KeywordPreparedGroupAggregate(
            counts: counts,
            corpusRanges: ranges,
            examples: examples,
            totalCount: total
        )
    }

    static func merge(
        group keyPath: KeyPath<KeywordPreparedCorpus, KeywordPreparedGroupAggregate>,
        from corpora: [KeywordPreparedCorpus]
    ) -> KeywordPreparedGroupAggregate {
        var counts: [String: Int] = [:]
        var ranges: [String: Set<String>] = [:]
        var examples: [String: KeywordExampleHit] = [:]
        var totalCount = 0

        for corpus in corpora {
            let group = corpus[keyPath: keyPath]
            totalCount += group.totalCount
            for (item, count) in group.counts {
                counts[item, default: 0] += count
            }
            for (item, corpusIDs) in group.corpusRanges {
                ranges[item, default: []].formUnion(corpusIDs)
            }
            for (item, example) in group.examples where examples[item] == nil {
                examples[item] = example
            }
        }

        return KeywordPreparedGroupAggregate(
            counts: counts,
            corpusRanges: ranges,
            examples: examples,
            totalCount: totalCount
        )
    }
}
