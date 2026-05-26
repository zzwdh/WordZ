import XCTest
@testable import WordZWorkspaceCore

final class EvidenceWorkbenchDossierTests: XCTestCase {
    func testLegacyEvidenceItemDecodeDefaultsDossierFields() throws {
        let legacyJSON = """
        {
          "id": "evidence-legacy-1",
          "sourceKind": "kwic",
          "savedSetID": "saved-1",
          "savedSetName": "Legacy Set",
          "corpusID": "corpus-1",
          "corpusName": "Demo Corpus",
          "sentenceId": 2,
          "sentenceTokenIndex": 3,
          "leftContext": "left",
          "keyword": "node",
          "rightContext": "right",
          "fullSentenceText": "left node right",
          "citationText": "Sentence 3: left node right",
          "query": "node",
          "leftWindow": 5,
          "rightWindow": 5,
          "searchOptionsSnapshot": null,
          "stopwordFilterSnapshot": null,
          "reviewStatus": "keep",
          "note": "legacy note",
          "createdAt": "2026-04-13T00:00:00Z",
          "updatedAt": "2026-04-13T00:00:00Z"
        }
        """

        let item = try JSONDecoder().decode(EvidenceItem.self, from: Data(legacyJSON.utf8))

        XCTAssertNil(item.sectionTitle)
        XCTAssertNil(item.claim)
        XCTAssertTrue(item.tags.isEmpty)
        XCTAssertEqual(item.citationFormat, .citationLine)
        XCTAssertEqual(item.citationStyle, .plain)
        XCTAssertNil(item.corpusMetadata)
        XCTAssertEqual(item.note, "legacy note")
    }

    func testExcerptExportKeepsOnlyKeptItemsAndReadableCopyText() throws {
        let kept = EvidenceItem(
            id: "evidence-keep-1",
            sourceKind: .kwic,
            savedSetID: "saved-kwic-1",
            savedSetName: "Lesson Set",
            corpusID: "corpus-1",
            corpusName: "Demo Corpus",
            corpusMetadata: CorpusMetadataProfile(
                sourceLabel: "Course Reader",
                yearLabel: "2024"
            ),
            sentenceId: 1,
            sentenceTokenIndex: 2,
            leftContext: "left",
            keyword: "keyword-a",
            rightContext: "right",
            fullSentenceText: "left keyword-a right",
            citationText: "Sentence 2: left keyword-a right",
            citationFormat: .fullSentence,
            citationStyle: .apa,
            query: "keyword-a",
            leftWindow: 5,
            rightWindow: 5,
            searchOptionsSnapshot: .default,
            stopwordFilterSnapshot: .default,
            reviewStatus: .keep,
            sectionTitle: "Section A",
            claim: "Claim Alpha",
            tags: ["teaching", "pattern"],
            note: "Use this in the handout.",
            createdAt: "2026-04-13T00:00:00Z",
            updatedAt: "2026-04-13T00:00:00Z"
        )
        let pending = makeEvidenceItem(
            id: "evidence-pending-1",
            sourceKind: .locator,
            reviewStatus: .pending,
            note: "Should not export."
        )

        let document = try EvidenceMarkdownDossierSupport.document(
            items: [kept, pending]
        )

        XCTAssertEqual(document.suggestedName, "wordz-excerpts.txt")
        XCTAssertTrue(document.text.contains(wordZText("摘录文本", "Excerpt Text", mode: .system)))
        XCTAssertTrue(document.text.contains("[1] keyword-a"))
        XCTAssertTrue(document.text.contains(wordZText("命中集", "Hit Set", mode: .system) + ": Lesson Set"))
        XCTAssertTrue(document.text.contains("left keyword-a right"))
        XCTAssertTrue(document.text.contains("Demo Corpus. (2024). left keyword-a right [Sentence 2, Course Reader]. WordZ evidence export."))
        XCTAssertTrue(document.text.contains("Use this in the handout."))
        XCTAssertFalse(document.text.contains("locator-node"))
        XCTAssertFalse(document.text.contains("Claim Alpha"))
        XCTAssertFalse(document.text.contains("teaching, pattern"))
        XCTAssertFalse(document.text.contains(wordZText("证据索引", "Evidence Index", mode: .system)))
    }

    func testExcerptExportRecordsFilterScopeWhenProvided() throws {
        let item = makeEvidenceItem(id: "evidence-filter-scope", reviewStatus: .keep)
        let filterSummary = wordZText("审阅", "Review", mode: .system) + ": " + EvidenceReviewFilter.keep.title(in: .system)

        let document = try EvidenceMarkdownDossierSupport.document(
            items: [item],
            filterSummary: filterSummary
        )

        XCTAssertTrue(document.text.contains(wordZText("保存范围", "Save Scope", mode: .system) + ": " + filterSummary))
    }

    func testExcerptExportPreservesCaptureOrder() throws {
        let second = makeEvidenceItem(
            id: "evidence-second",
            sourceKind: .locator,
            reviewStatus: .keep
        )
        let first = makeEvidenceItem(
            id: "evidence-first",
            sourceKind: .topics,
            reviewStatus: .keep
        )

        let document = try EvidenceMarkdownDossierSupport.document(
            items: [second, first]
        )

        let secondRange = try XCTUnwrap(document.text.range(of: "[1] locator-node"))
        let firstRange = try XCTUnwrap(document.text.range(of: "[2] topic-hit"))
        XCTAssertLessThan(secondRange.lowerBound, firstRange.lowerBound)
    }

    func testEvidenceItemRoundTripsStructuredSentimentMetadata() throws {
        let item = EvidenceItem(
            id: "evidence-sentiment-1",
            sourceKind: .sentiment,
            savedSetID: nil,
            savedSetName: nil,
            corpusID: "corpus-1",
            corpusName: "Demo Corpus",
            corpusMetadata: CorpusMetadataProfile(
                sourceLabel: "Research Archive",
                yearLabel: "2026"
            ),
            sentenceId: 1,
            sentenceTokenIndex: 2,
            leftContext: "left",
            keyword: "good",
            rightContext: "right",
            fullSentenceText: "left good right",
            citationText: "Sentence 2: left good right",
            citationFormat: .concordance,
            citationStyle: .mla,
            query: "good",
            leftWindow: 0,
            rightWindow: 0,
            searchOptionsSnapshot: nil,
            stopwordFilterSnapshot: nil,
            reviewStatus: .keep,
            sectionTitle: "Section A",
            claim: "Positive example",
            tags: ["positive"],
            note: "Reviewed",
            sentimentMetadata: EvidenceSentimentMetadata(
                source: .corpusCompare,
                unit: .sentence,
                contextBasis: .fullSentenceWhenAvailable,
                backendKind: .lexicon,
                backendRevision: "lexicon-v2",
                resourceRevision: "resource-v2",
                providerID: nil,
                providerFamily: nil,
                domainPackID: .mixed,
                ruleProfileID: "default",
                calibrationProfileRevision: "calibration-v2",
                activePackIDs: [.mixed, .news],
                rawLabel: .positive,
                rawScores: SentimentScoreTriple(positivityScore: 0.7, neutralityScore: 0.2, negativityScore: 0.1, netScore: 0.6),
                effectiveLabel: .neutral,
                effectiveScores: .oneHot(for: .neutral),
                reviewDecision: .overrideNeutral,
                reviewStatus: .overridden,
                reviewNote: "Pedagogical override",
                reviewSampleID: "review-1",
                reviewedAt: "2026-04-18T08:00:00Z",
                rowID: "row-1",
                sourceID: "corpus-1",
                sentenceID: 1,
                tokenIndex: 2,
                ruleSummary: "quoted evidence discounted",
                topRuleTraceSteps: [
                    SentimentRuleTraceStep(tag: "quotedEvidence", note: "discounted", multiplier: 0.85)
                ],
                inferencePath: .lexicon,
                modelInputKind: nil
            ),
            crossAnalysisMetadata: EvidenceCrossAnalysisMetadata(
                originKind: .compareSentiment,
                scopeSummary: "Target: Demo Corpus · Reference: Compare Corpus",
                focusTerm: "alpha",
                focusedTopicID: nil,
                groupTitle: "Target",
                compareSide: "target",
                topicTitle: nil
            ),
            createdAt: "2026-04-18T08:00:00Z",
            updatedAt: "2026-04-18T08:00:00Z"
        )

        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(EvidenceItem.self, from: data)

        XCTAssertEqual(decoded.sentimentMetadata?.effectiveLabel, .neutral)
        XCTAssertEqual(decoded.sentimentMetadata?.reviewStatus, .overridden)
        XCTAssertEqual(decoded.citationFormat, EvidenceCitationFormat.concordance)
        XCTAssertEqual(decoded.citationStyle, EvidenceCitationStyle.mla)
        XCTAssertEqual(decoded.corpusMetadata?.sourceLabel, "Research Archive")
        XCTAssertEqual(decoded.crossAnalysisMetadata?.originKind, .compareSentiment)
        XCTAssertEqual(decoded.crossAnalysisMetadata?.focusTerm, "alpha")
    }
}
