import Foundation

enum KeywordSuiteAnalyzer {
    static let normalizationBase = 1_000_000.0
    private static let importedReferenceCorpusID = "__imported_word_list__"

    static func analyze(_ request: KeywordSuiteRunRequest) -> KeywordSuiteResult {
        let preparedFocus = request.focusEntries.map {
            prepareCorpus(
                entry: $0,
                configuration: request.configuration
            )
        }
        let preparedReference = request.referenceEntries.map {
            prepareCorpus(
                entry: $0,
                configuration: request.configuration
            )
        }

        return analyzePreparedCorpora(
            focusCorpora: preparedFocus,
            referenceCorpora: preparedReference,
            importedReferenceItems: request.importedReferenceItems,
            focusLabel: request.focusLabel,
            referenceLabel: request.referenceLabel,
            configuration: request.configuration
        )
    }

    static func analyzePrepared(_ request: PreparedKeywordSuiteRequest) -> KeywordSuiteResult {
        let preparedFocus = request.focusCorpora.map {
            prepareCorpus(
                entry: $0.entry,
                tokenizedArtifact: $0.tokenizedArtifact,
                configuration: request.configuration
            )
        }
        let preparedReference = request.referenceCorpora.map {
            prepareCorpus(
                entry: $0.entry,
                tokenizedArtifact: $0.tokenizedArtifact,
                configuration: request.configuration
            )
        }

        return analyzePreparedCorpora(
            focusCorpora: preparedFocus,
            referenceCorpora: preparedReference,
            importedReferenceItems: request.importedReferenceItems,
            focusLabel: request.focusLabel,
            referenceLabel: request.referenceLabel,
            configuration: request.configuration
        )
    }

    private static func analyzePreparedCorpora(
        focusCorpora: [KeywordPreparedCorpus],
        referenceCorpora: [KeywordPreparedCorpus],
        importedReferenceItems: [KeywordReferenceWordListItem],
        focusLabel: String,
        referenceLabel: String,
        configuration: KeywordSuiteConfiguration
    ) -> KeywordSuiteResult {
        let focusAggregate = aggregate(
            corpora: focusCorpora,
            fallbackLabel: focusLabel,
            isWordList: false
        )
        let referenceAggregate: KeywordPreparedSideAggregate
        if !importedReferenceItems.isEmpty {
            referenceAggregate = aggregateImportedReference(
                items: importedReferenceItems,
                fallbackLabel: referenceLabel
            )
        } else {
            referenceAggregate = aggregate(
                corpora: referenceCorpora,
                fallbackLabel: referenceLabel,
                isWordList: false
            )
        }

        return KeywordSuiteResult(
            configuration: configuration,
            focusSummary: focusAggregate.summary,
            referenceSummary: referenceAggregate.summary,
            words: buildRows(
                group: .words,
                focus: focusAggregate,
                reference: referenceAggregate,
                configuration: configuration
            ),
            terms: buildRows(
                group: .terms,
                focus: focusAggregate,
                reference: referenceAggregate,
                configuration: configuration
            ),
            ngrams: buildRows(
                group: .ngrams,
                focus: focusAggregate,
                reference: referenceAggregate,
                configuration: configuration
            )
        )
    }

    static func legacyAnalyze(
        target: KeywordRequestEntry,
        reference: KeywordRequestEntry,
        options: KeywordPreprocessingOptions
    ) -> KeywordResult {
        let configuration = KeywordSuiteConfiguration.legacy(
            targetCorpusID: target.corpusId,
            referenceCorpusID: reference.corpusId,
            options: options
        )
        let suiteResult = analyze(
            KeywordSuiteRunRequest(
                focusEntries: [target],
                referenceEntries: [reference],
                importedReferenceItems: [],
                focusLabel: target.corpusName,
                referenceLabel: reference.corpusName,
                configuration: configuration
            )
        )
        return KeywordResult(suiteResult: suiteResult)
    }

    static func parseImportedReference(_ text: String) -> KeywordImportedReferenceParseResult {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        guard !normalized.isEmpty else { return .empty }

        var lines = normalized.components(separatedBy: "\n")
        if lines.last == "" {
            lines.removeLast()
        }
        guard !lines.isEmpty else { return .empty }

        var merged: [String: Int] = [:]
        var acceptedLineCount = 0

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let parts = trimmed.components(separatedBy: "\t")
            let rawTerm = parts.first ?? trimmed
            let normalizedTerm = normalizeImportedItem(rawTerm)
            guard !normalizedTerm.isEmpty else { continue }

            let frequency: Int
            if parts.count >= 2 {
                guard let parsedFrequency = Int(parts[1].trimmingCharacters(in: .whitespacesAndNewlines)),
                      parsedFrequency > 0 else {
                    continue
                }
                frequency = parsedFrequency
            } else {
                frequency = 1
            }

            merged[normalizedTerm, default: 0] += frequency
            acceptedLineCount += 1
        }

        let items = merged.keys.sorted().map {
            KeywordReferenceWordListItem(term: $0, frequency: merged[$0, default: 1])
        }
        let rejectedLineCount = max(0, lines.count - acceptedLineCount)
        return KeywordImportedReferenceParseResult(
            items: items,
            totalLineCount: lines.count,
            acceptedLineCount: acceptedLineCount,
            rejectedLineCount: rejectedLineCount
        )
    }

    static func parseImportedReferenceItems(_ text: String) -> [KeywordReferenceWordListItem] {
        parseImportedReference(text).items
    }

    private static func prepareCorpus(
        entry: KeywordRequestEntry,
        configuration: KeywordSuiteConfiguration
    ) -> KeywordPreparedCorpus {
        let index = ParsedDocumentIndex(text: entry.content)
        return prepareCorpus(
            entry: entry,
            tokenCount: index.tokenCount,
            typeCount: index.typeCount,
            sentences: index.document.sentences.map { sentence in
                TokenizedSentence(
                    sentenceId: sentence.sentenceId,
                    text: sentence.text,
                    tokens: sentence.tokens.map { token in
                        TokenizedToken(
                            original: token.original,
                            normalized: token.normalized,
                            sentenceId: token.sentenceId,
                            tokenIndex: token.tokenIndex,
                            annotations: token.annotations
                        )
                    }
                )
            },
            configuration: configuration
        )
    }

    private static func prepareCorpus(
        entry: KeywordRequestEntry,
        tokenizedArtifact: StoredTokenizedArtifact,
        configuration: KeywordSuiteConfiguration
    ) -> KeywordPreparedCorpus {
        prepareCorpus(
            entry: entry,
            tokenCount: tokenizedArtifact.tokenCount,
            typeCount: Set(tokenizedArtifact.frequencyMap.keys).count,
            sentences: tokenizedArtifact.sentences,
            configuration: configuration
        )
    }

    private static func prepareCorpus(
        entry: KeywordRequestEntry,
        tokenCount: Int,
        typeCount: Int,
        sentences: [TokenizedSentence],
        configuration: KeywordSuiteConfiguration
    ) -> KeywordPreparedCorpus {
        let resolver = configuration.unit.lemmaStrategy
        let stopwordFilter = configuration.tokenFilters.stopwordFilter
        let stopwordSet = Set(stopwordFilter.parsedWords)
        let scriptFilter = configuration.tokenFilters.scriptFilterSet
        let lexicalClassFilter = configuration.tokenFilters.lexicalClassFilterSet

        var words = KeywordPreparedGroupAccumulator()
        var terms = KeywordPreparedGroupAccumulator()
        var ngrams = KeywordPreparedGroupAccumulator()

        for sentence in sentences {
            let resolvedTokens = sentence.tokens.compactMap { token -> KeywordResolvedToken? in
                guard configuration.tokenFilters.languagePreset.keeps(token.annotations) else { return nil }
                if !scriptFilter.isEmpty, !scriptFilter.contains(token.annotations.script) {
                    return nil
                }
                if !lexicalClassFilter.isEmpty {
                    guard let lexicalClass = token.annotations.lexicalClass, lexicalClassFilter.contains(lexicalClass) else {
                        return nil
                    }
                }

                let value = resolver.resolvedToken(
                    normalized: token.normalized,
                    annotations: token.annotations
                ).trimmingCharacters(in: .whitespacesAndNewlines)
                guard !value.isEmpty else { return nil }
                guard matchesStopwordPolicy(value, filter: stopwordFilter, stopwordSet: stopwordSet) else {
                    return nil
                }
                return KeywordResolvedToken(value: value, token: token)
            }

            for token in resolvedTokens {
                words.add(
                    item: token.value,
                    corpusID: entry.corpusId,
                    example: sentence.text
                )
            }

            for n in 2...5 {
                guard resolvedTokens.count >= n else { continue }
                for start in 0...(resolvedTokens.count - n) {
                    let slice = Array(resolvedTokens[start..<(start + n)])
                    let phrase = slice.map(\.value).joined(separator: " ")
                    ngrams.add(
                        item: phrase,
                        corpusID: entry.corpusId,
                        example: sentence.text
                    )
                    if matchesTermGrammar(tokens: slice, languagePreset: configuration.tokenFilters.languagePreset) {
                        terms.add(
                            item: phrase,
                            corpusID: entry.corpusId,
                            example: sentence.text
                        )
                    }
                }
            }
        }

        return KeywordPreparedCorpus(
            entry: entry,
            tokenCount: tokenCount,
            typeCount: typeCount,
            words: words.materialize(),
            terms: terms.materialize(),
            ngrams: ngrams.materialize()
        )
    }

    private static func aggregate(
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

    private static func aggregateImportedReference(
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

    private static func aggregateImportedReference(
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

    private static func merge(
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

    private static func buildRows(
        group: KeywordResultGroup,
        focus: KeywordPreparedSideAggregate,
        reference: KeywordPreparedSideAggregate,
        configuration: KeywordSuiteConfiguration
    ) -> [KeywordSuiteRow] {
        let focusGroup = focus.groups[group] ?? .empty
        let referenceGroup = reference.groups[group] ?? .empty
        let allItems = Set(focusGroup.counts.keys).union(referenceGroup.counts.keys)
        let thresholds = configuration.thresholds

        return allItems.compactMap { item in
            let focusFrequency = focusGroup.counts[item, default: 0]
            let referenceFrequency = referenceGroup.counts[item, default: 0]
            guard focusFrequency >= thresholds.minFocusFreq else { return nil }
            guard referenceFrequency >= thresholds.minReferenceFreq else { return nil }
            guard focusFrequency + referenceFrequency >= thresholds.minCombinedFreq else { return nil }

            let focusNorm = normalizedFrequency(
                count: focusFrequency,
                totalCount: focusGroup.totalCount
            )
            let referenceNorm = normalizedFrequency(
                count: referenceFrequency,
                totalCount: referenceGroup.totalCount
            )
            let score: Double
            switch configuration.statistic {
            case .logLikelihood:
                score = signedLogLikelihood(
                    focusCount: focusFrequency,
                    focusTotalCount: focusGroup.totalCount,
                    referenceCount: referenceFrequency,
                    referenceTotalCount: referenceGroup.totalCount
                )
            case .chiSquare:
                score = signedChiSquare(
                    focusCount: focusFrequency,
                    focusTotalCount: focusGroup.totalCount,
                    referenceCount: referenceFrequency,
                    referenceTotalCount: referenceGroup.totalCount
                )
            }
            guard score != 0 else { return nil }

            let rowDirection: KeywordRowDirection = score > 0 ? .positive : .negative
            if configuration.direction == .positive, rowDirection != .positive {
                return nil
            }
            if configuration.direction == .negative, rowDirection != .negative {
                return nil
            }

            let logRatio = logRatio(
                focusCount: focusFrequency,
                focusTotalCount: focusGroup.totalCount,
                referenceCount: referenceFrequency,
                referenceTotalCount: referenceGroup.totalCount
            )
            let pValue = erfc(sqrt(abs(score) / 2))
            guard pValue <= thresholds.maxPValue else { return nil }
            guard abs(logRatio) >= thresholds.minAbsLogRatio else { return nil }

            let preferredExample = focusGroup.examples[item] ?? referenceGroup.examples[item]
            return KeywordSuiteRow(
                group: group,
                item: item,
                direction: rowDirection,
                focusFrequency: focusFrequency,
                referenceFrequency: referenceFrequency,
                focusNormalizedFrequency: focusNorm,
                referenceNormalizedFrequency: referenceNorm,
                keynessScore: score,
                logRatio: logRatio,
                pValue: pValue,
                focusRange: focusGroup.corpusRanges[item]?.count ?? 0,
                referenceRange: referenceGroup.corpusRanges[item]?.count ?? 0,
                example: preferredExample?.text ?? "",
                focusExampleCorpusID: focusGroup.examples[item]?.corpusID,
                referenceExampleCorpusID: referenceGroup.examples[item]?.corpusID
            )
        }
        .sorted(by: compareRows)
    }

    private static func compareRows(_ lhs: KeywordSuiteRow, _ rhs: KeywordSuiteRow) -> Bool {
        let lhsAbs = abs(lhs.keynessScore)
        let rhsAbs = abs(rhs.keynessScore)
        if lhsAbs != rhsAbs {
            return lhsAbs > rhsAbs
        }
        if lhs.direction != rhs.direction {
            return lhs.direction == .positive
        }
        if lhs.focusFrequency != rhs.focusFrequency {
            return lhs.focusFrequency > rhs.focusFrequency
        }
        return lhs.item.localizedCaseInsensitiveCompare(rhs.item) == .orderedAscending
    }

    private static func normalizedFrequency(count: Int, totalCount: Int) -> Double {
        guard totalCount > 0 else { return 0 }
        return (Double(count) / Double(totalCount)) * normalizationBase
    }

    private static func signedLogLikelihood(
        focusCount: Int,
        focusTotalCount: Int,
        referenceCount: Int,
        referenceTotalCount: Int
    ) -> Double {
        let focus = Double(max(0, focusCount))
        let reference = Double(max(0, referenceCount))
        let focusTokens = Double(max(0, focusTotalCount))
        let referenceTokens = Double(max(0, referenceTotalCount))
        guard focusTokens > 0, referenceTokens > 0 else { return 0 }

        let observedTotal = focus + reference
        let tokenTotal = focusTokens + referenceTokens
        guard observedTotal > 0, tokenTotal > 0 else { return 0 }

        let expectedFocus = observedTotal * (focusTokens / tokenTotal)
        let expectedReference = observedTotal * (referenceTokens / tokenTotal)
        let focusTerm = focus > 0 && expectedFocus > 0 ? focus * Foundation.log(focus / expectedFocus) : 0
        let referenceTerm = reference > 0 && expectedReference > 0 ? reference * Foundation.log(reference / expectedReference) : 0
        let value = 2 * (focusTerm + referenceTerm)

        let focusNorm = focus / focusTokens
        let referenceNorm = reference / referenceTokens
        return focusNorm >= referenceNorm ? value : -value
    }

    private static func signedChiSquare(
        focusCount: Int,
        focusTotalCount: Int,
        referenceCount: Int,
        referenceTotalCount: Int
    ) -> Double {
        let a = Double(max(0, focusCount))
        let b = Double(max(0, focusTotalCount - focusCount))
        let c = Double(max(0, referenceCount))
        let d = Double(max(0, referenceTotalCount - referenceCount))
        let total = a + b + c + d
        guard total > 0 else { return 0 }

        let rowTotals = [a + b, c + d]
        let columnTotals = [a + c, b + d]
        let expected = [
            [rowTotals[0] * columnTotals[0] / total, rowTotals[0] * columnTotals[1] / total],
            [rowTotals[1] * columnTotals[0] / total, rowTotals[1] * columnTotals[1] / total]
        ]
        let observed = [[a, b], [c, d]]
        var statistic = 0.0

        for rowIndex in 0..<2 {
            for columnIndex in 0..<2 {
                let exp = expected[rowIndex][columnIndex]
                guard exp > 0 else { continue }
                let delta = observed[rowIndex][columnIndex] - exp
                statistic += (delta * delta) / exp
            }
        }

        let focusNorm = rowTotals[0] > 0 ? a / rowTotals[0] : 0
        let referenceNorm = rowTotals[1] > 0 ? c / rowTotals[1] : 0
        return focusNorm >= referenceNorm ? statistic : -statistic
    }

    private static func logRatio(
        focusCount: Int,
        focusTotalCount: Int,
        referenceCount: Int,
        referenceTotalCount: Int
    ) -> Double {
        let smoothing = 0.5
        let focusRate = (Double(focusCount) + smoothing) / (Double(max(focusTotalCount, 0)) + smoothing)
        let referenceRate = (Double(referenceCount) + smoothing) / (Double(max(referenceTotalCount, 0)) + smoothing)
        guard focusRate > 0, referenceRate > 0 else { return 0 }
        return Foundation.log2(focusRate / referenceRate)
    }

    private static func matchesStopwordPolicy(
        _ token: String,
        filter: StopwordFilterState,
        stopwordSet: Set<String>
    ) -> Bool {
        guard filter.enabled, !stopwordSet.isEmpty else { return true }
        let contains = stopwordSet.contains(token)
        switch filter.mode {
        case .exclude:
            return !contains
        case .include:
            return contains
        }
    }

    private static func matchesTermGrammar(
        tokens: [KeywordResolvedToken],
        languagePreset: TokenizeLanguagePreset
    ) -> Bool {
        guard let last = tokens.last?.token.annotations.lexicalClass else { return false }
        let preceding = tokens.dropLast()
        let lexicalClasses = tokens.compactMap(\.token.annotations.lexicalClass)
        guard lexicalClasses.count == tokens.count else { return false }

        switch languagePreset {
        case .latinFocused:
            let allowedFinal: Set<TokenLexicalClass> = [.noun, .idiom]
            let allowedPrefix: Set<TokenLexicalClass> = [.adjective, .noun, .classifier, .idiom]
            guard allowedFinal.contains(last) else { return false }
            guard preceding.allSatisfy({ token in
                guard let lexicalClass = token.token.annotations.lexicalClass else { return false }
                return allowedPrefix.contains(lexicalClass)
            }) else {
                return false
            }
            return lexicalClasses.contains(where: { [.noun, .idiom].contains($0) })
        case .mixedChineseEnglish, .cjkFocused:
            let allowedFinal: Set<TokenLexicalClass> = [.noun, .classifier, .idiom, .other]
            let allowedPrefix: Set<TokenLexicalClass> = [.noun, .adjective, .classifier, .idiom, .other]
            guard allowedFinal.contains(last) else { return false }
            guard preceding.allSatisfy({ token in
                guard let lexicalClass = token.token.annotations.lexicalClass else { return false }
                return allowedPrefix.contains(lexicalClass)
            }) else {
                return false
            }
            return lexicalClasses.contains(where: { [.noun, .adjective, .classifier, .idiom].contains($0) })
        }
    }

    private static func normalizeImportedItem(_ value: String) -> String {
        let normalized = AnalysisTextNormalizationSupport.normalizeSearchText(value, caseSensitive: false)
        guard !normalized.isEmpty else { return "" }
        return normalized
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static func importedReferenceItemBelongsToGroup(
        _ item: KeywordReferenceWordListItem,
        group: KeywordResultGroup
    ) -> Bool {
        let tokenCount = importedReferenceTokenCount(item.term)
        switch group {
        case .words:
            return tokenCount == 1
        case .terms, .ngrams:
            return (2...5).contains(tokenCount)
        }
    }

    private static func importedReferenceTokenCount(_ term: String) -> Int {
        max(1, term.split(separator: " ", omittingEmptySubsequences: true).count)
    }
}

private struct KeywordPreparedCorpus {
    let entry: KeywordRequestEntry
    let tokenCount: Int
    let typeCount: Int
    let words: KeywordPreparedGroupAggregate
    let terms: KeywordPreparedGroupAggregate
    let ngrams: KeywordPreparedGroupAggregate
}

private struct KeywordPreparedSideAggregate {
    let summary: KeywordSuiteScopeSummary
    let groups: [KeywordResultGroup: KeywordPreparedGroupAggregate]
}

private struct KeywordPreparedGroupAggregate {
    let counts: [String: Int]
    let corpusRanges: [String: Set<String>]
    let examples: [String: KeywordExampleHit]
    let totalCount: Int

    static let empty = KeywordPreparedGroupAggregate(
        counts: [:],
        corpusRanges: [:],
        examples: [:],
        totalCount: 0
    )
}

private struct KeywordPreparedGroupAccumulator {
    var counts: [String: Int] = [:]
    var ranges: [String: Set<String>] = [:]
    var examples: [String: KeywordExampleHit] = [:]
    var totalCount = 0

    mutating func add(item: String, corpusID: String, example: String) {
        counts[item, default: 0] += 1
        ranges[item, default: []].insert(corpusID)
        if examples[item] == nil {
            examples[item] = KeywordExampleHit(text: example, corpusID: corpusID)
        }
        totalCount += 1
    }

    func materialize() -> KeywordPreparedGroupAggregate {
        KeywordPreparedGroupAggregate(
            counts: counts,
            corpusRanges: ranges,
            examples: examples,
            totalCount: totalCount
        )
    }
}

private struct KeywordResolvedToken {
    let value: String
    let token: TokenizedToken
}

private struct KeywordExampleHit {
    let text: String
    let corpusID: String
}
