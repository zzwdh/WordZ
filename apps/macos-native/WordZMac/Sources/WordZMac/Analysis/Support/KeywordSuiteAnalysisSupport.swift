import Foundation

enum KeywordSuiteAnalyzer {
    static let normalizationBase = 1_000_000.0
    static let importedReferenceCorpusID = "__imported_word_list__"

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

    static func analyzePreparedCorpora(
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
}
