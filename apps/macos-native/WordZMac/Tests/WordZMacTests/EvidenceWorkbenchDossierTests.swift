import XCTest
@testable import WordZWorkspaceCore

final class EvidenceWorkbenchDossierTests: XCTestCase {
    func testCurrentGroupToolbarSummaryUsesSelectedGroupTitleAndCount() {
        let group = EvidenceWorkbenchGroup(
            id: "section:Methods",
            title: "Methods",
            subtitle: nil,
            assignmentValue: "Methods",
            itemCountSummary: "2 items",
            items: []
        )

        XCTAssertEqual(
            EvidenceWorkbenchGroupingMode.section.currentGroupToolbarSummary(
                group: group,
                in: .english
            ),
            "Methods · 2 items"
        )
        XCTAssertEqual(
            EvidenceWorkbenchGroupingMode.section.currentGroupToolbarSummary(
                group: nil,
                in: .english
            ),
            "No Section Selected"
        )
    }

    func testCurrentGroupWindowTitleAppendsSelectedGroupSummary() {
        let group = EvidenceWorkbenchGroup(
            id: "section:Methods",
            title: "Methods",
            subtitle: nil,
            assignmentValue: "Methods",
            itemCountSummary: "2 items",
            items: []
        )

        XCTAssertEqual(
            EvidenceWorkbenchGroupingMode.section.currentGroupWindowTitle(
                baseTitle: "Evidence Workbench",
                group: group,
                in: .english
            ),
            "Evidence Workbench · Current Section: Methods · 2 items"
        )
        XCTAssertEqual(
            EvidenceWorkbenchGroupingMode.section.currentGroupWindowTitle(
                baseTitle: "Evidence Workbench",
                group: nil,
                in: .english
            ),
            "Evidence Workbench"
        )
    }

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
        XCTAssertEqual(item.note, "legacy note")
    }

    func testMarkdownDossierGroupsKeptItemsAndIncludesDossierMetadata() throws {
        let kept = EvidenceItem(
            id: "evidence-keep-1",
            sourceKind: .kwic,
            savedSetID: "saved-kwic-1",
            savedSetName: "Lesson Set",
            corpusID: "corpus-1",
            corpusName: "Demo Corpus",
            sentenceId: 1,
            sentenceTokenIndex: 2,
            leftContext: "left",
            keyword: "keyword-a",
            rightContext: "right",
            fullSentenceText: "left keyword-a right",
            citationText: "Sentence 2: left keyword-a right",
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
        let pending = EvidenceItem(
            id: "evidence-pending-1",
            sourceKind: .locator,
            savedSetID: nil,
            savedSetName: nil,
            corpusID: "corpus-2",
            corpusName: "Locator Corpus",
            sentenceId: 3,
            sentenceTokenIndex: 4,
            leftContext: "left",
            keyword: "pending-only",
            rightContext: "right",
            fullSentenceText: "left pending-only right",
            citationText: "Sentence 4: left pending-only right",
            query: "pending-only",
            leftWindow: 5,
            rightWindow: 5,
            searchOptionsSnapshot: nil,
            stopwordFilterSnapshot: nil,
            reviewStatus: .pending,
            sectionTitle: "Section B",
            claim: "Claim Beta",
            tags: ["pending"],
            note: "Should not export to markdown.",
            createdAt: "2026-04-13T00:00:00Z",
            updatedAt: "2026-04-13T00:00:00Z"
        )

        let document = try EvidenceMarkdownDossierSupport.document(
            items: [kept, pending],
            grouping: .section
        )

        XCTAssertTrue(document.text.contains("Section A"))
        XCTAssertTrue(document.text.contains("Claim Alpha"))
        XCTAssertTrue(document.text.contains("teaching, pattern"))
        XCTAssertTrue(document.text.contains("Use this in the handout."))
        XCTAssertFalse(document.text.contains("pending-only"))
    }

    func testMarkdownDossierPreservesManualSectionOrderFromWorkbenchSequence() throws {
        let sectionB = makeEvidenceItem(
            id: "evidence-section-b",
            sourceKind: .topics,
            reviewStatus: .keep,
            sectionTitle: "Section B",
            claim: "Claim Beta"
        )
        let sectionA = makeEvidenceItem(
            id: "evidence-section-a",
            sourceKind: .kwic,
            reviewStatus: .keep,
            sectionTitle: "Section A",
            claim: "Claim Alpha"
        )

        let document = try EvidenceMarkdownDossierSupport.document(
            items: [sectionB, sectionA],
            grouping: .section
        )

        let sectionBRange = try XCTUnwrap(document.text.range(of: "## Section B"))
        let sectionARange = try XCTUnwrap(document.text.range(of: "## Section A"))
        XCTAssertLessThan(sectionBRange.lowerBound, sectionARange.lowerBound)
    }

    func testMarkdownDossierPreservesManualClaimOrderFromWorkbenchSequence() throws {
        let claimBetaPrimary = makeEvidenceItem(
            id: "evidence-claim-beta-1",
            sourceKind: .topics,
            reviewStatus: .keep,
            sectionTitle: "Section B",
            claim: "Claim Beta"
        )
        let claimBetaSecondary = makeEvidenceItem(
            id: "evidence-claim-beta-2",
            sourceKind: .plot,
            reviewStatus: .keep,
            sectionTitle: "Section B",
            claim: "Claim Beta"
        )
        let claimAlpha = makeEvidenceItem(
            id: "evidence-claim-alpha-1",
            sourceKind: .kwic,
            reviewStatus: .keep,
            sectionTitle: "Section A",
            claim: "Claim Alpha"
        )

        let document = try EvidenceMarkdownDossierSupport.document(
            items: [claimBetaPrimary, claimBetaSecondary, claimAlpha],
            grouping: .claim
        )

        let claimBetaRange = try XCTUnwrap(document.text.range(of: "## Claim Beta"))
        let claimAlphaRange = try XCTUnwrap(document.text.range(of: "## Claim Alpha"))
        XCTAssertLessThan(claimBetaRange.lowerBound, claimAlphaRange.lowerBound)
    }

    func testEvidenceItemRoundTripsStructuredSentimentMetadata() throws {
        let item = EvidenceItem(
            id: "evidence-sentiment-1",
            sourceKind: .sentiment,
            savedSetID: nil,
            savedSetName: nil,
            corpusID: "corpus-1",
            corpusName: "Demo Corpus",
            sentenceId: 1,
            sentenceTokenIndex: 2,
            leftContext: "left",
            keyword: "good",
            rightContext: "right",
            fullSentenceText: "left good right",
            citationText: "Sentence 2: left good right",
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
        XCTAssertEqual(decoded.crossAnalysisMetadata?.originKind, .compareSentiment)
        XCTAssertEqual(decoded.crossAnalysisMetadata?.focusTerm, "alpha")
    }

    func testMarkdownDossierIncludesSentimentProvenanceSections() throws {
        let item = EvidenceItem(
            id: "evidence-sentiment-2",
            sourceKind: .sentiment,
            savedSetID: nil,
            savedSetName: nil,
            corpusID: "corpus-1",
            corpusName: "Demo Corpus",
            sentenceId: 0,
            sentenceTokenIndex: 0,
            leftContext: "left",
            keyword: "good",
            rightContext: "right",
            fullSentenceText: "left good right",
            citationText: "Sentence 1: left good right",
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
                source: .openedCorpus,
                unit: .sourceSentence,
                contextBasis: .fullSentenceWhenAvailable,
                backendKind: .lexicon,
                backendRevision: "lexicon-v2",
                resourceRevision: "resource-v2",
                providerID: nil,
                providerFamily: nil,
                domainPackID: .general,
                ruleProfileID: "default",
                calibrationProfileRevision: "calibration-v2",
                activePackIDs: [.general],
                rawLabel: .positive,
                rawScores: SentimentScoreTriple(positivityScore: 0.8, neutralityScore: 0.1, negativityScore: 0.1, netScore: 0.7),
                effectiveLabel: .positive,
                effectiveScores: SentimentScoreTriple(positivityScore: 0.8, neutralityScore: 0.1, negativityScore: 0.1, netScore: 0.7),
                reviewDecision: .confirmRaw,
                reviewStatus: .confirmed,
                reviewNote: "Confirmed",
                reviewSampleID: "review-2",
                reviewedAt: "2026-04-18T08:00:00Z",
                rowID: "row-2",
                sourceID: "corpus-1",
                sentenceID: 0,
                tokenIndex: 0,
                ruleSummary: "positive lexical cue",
                topRuleTraceSteps: [
                    SentimentRuleTraceStep(tag: "lexicon", note: "good -> +1.0", multiplier: 1.0)
                ],
                inferencePath: .lexicon,
                modelInputKind: nil
            ),
            crossAnalysisMetadata: EvidenceCrossAnalysisMetadata(
                originKind: .sentimentDirect,
                scopeSummary: "Opened Corpus",
                focusTerm: nil,
                focusedTopicID: nil,
                groupTitle: "Target",
                compareSide: nil,
                topicTitle: nil
            ),
            createdAt: "2026-04-18T08:00:00Z",
            updatedAt: "2026-04-18T08:00:00Z"
        )

        let document = try EvidenceMarkdownDossierSupport.document(
            items: [item],
            grouping: .section
        )

        XCTAssertTrue(document.text.contains(wordZText("情感 Provenance", "Sentiment Provenance", mode: .system)))
        XCTAssertTrue(document.text.contains(wordZText("跨分析 Provenance", "Cross-analysis Provenance", mode: .system)))
        XCTAssertTrue(document.text.contains(wordZText("生效标签", "Effective Label", mode: .system)))
        XCTAssertTrue(document.text.contains(wordZText("原始标签", "Raw Label", mode: .system)))
    }
}
