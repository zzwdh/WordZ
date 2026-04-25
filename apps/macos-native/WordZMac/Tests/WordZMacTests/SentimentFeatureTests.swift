import XCTest
@testable import WordZWorkspaceCore

final class SentimentEngineFeatureTests: XCTestCase {
    func testLexiconAnalyzerSurfacesResourceLoadFailureWithoutCrashing() throws {
        let analyzer = LexiconSentimentAnalyzer(
            indexDocument: { text, _ in ParsedDocumentIndex(text: text) },
            lexicon: SentimentLexiconStore(
                manifest: SentimentRulePackManifest(
                    version: "unavailable",
                    backendRevision: "unavailable",
                    resourceRevision: "unavailable"
                ),
                packDescriptors: [],
                coreEntries: [],
                entriesByPack: [:],
                negators: [],
                intensifiers: [:],
                contrastives: [],
                reportingVerbs: [],
                hedges: [],
                neutralShields: [:],
                loadError: .missingResource(name: "manifest")
            )
        )

        XCTAssertThrowsError(
            try analyzer.analyze(
                makeRequest(
                    texts: [
                        SentimentInputText(
                            id: "row-1",
                            sourceTitle: "Manual",
                            text: "This is excellent."
                        )
                    ]
                )
            )
        ) { error in
            XCTAssertEqual(
                error.localizedDescription,
                "Missing sentiment resource: manifest.json"
            )
        }
    }

    func testRunSentimentHandlesNegationIntensityAndExclamation() throws {
        let engine = NativeAnalysisEngine()
        let result = engine.runSentiment(
            makeRequest(texts: [
                SentimentInputText(
                    id: "negated",
                    sourceTitle: "Manual",
                    text: "This is not bad."
                ),
                SentimentInputText(
                    id: "intense",
                    sourceTitle: "Manual",
                    text: "This is very good!"
                )
            ])
        )

        let negated = try XCTUnwrap(result.rows.first(where: { $0.id == "negated" }))
        XCTAssertEqual(negated.finalLabel, .positive)
        XCTAssertTrue(negated.evidence.contains(where: { $0.ruleTags.contains("negated") }))

        let intense = try XCTUnwrap(result.rows.first(where: { $0.id == "intense" }))
        XCTAssertEqual(intense.finalLabel, .positive)
        XCTAssertTrue(intense.evidence.contains(where: { $0.ruleTags.contains("intensified") }))
        XCTAssertTrue(intense.evidence.contains(where: { $0.ruleTags.contains("exclamation") }))
        XCTAssertGreaterThan(intense.netScore, negated.netScore)
    }

    func testRunSentimentAppliesContrastiveAndQuotedEvidenceAdjustments() throws {
        let engine = NativeAnalysisEngine()
        let result = engine.runSentiment(
            makeRequest(texts: [
                SentimentInputText(
                    id: "contrast",
                    sourceTitle: "Manual",
                    text: "The movie was good but very expensive."
                ),
                SentimentInputText(
                    id: "quoted",
                    sourceTitle: "Manual",
                    text: "\"great,\" he said."
                )
            ])
        )

        let contrast = try XCTUnwrap(result.rows.first(where: { $0.id == "contrast" }))
        XCTAssertEqual(contrast.finalLabel, .negative)
        XCTAssertTrue(contrast.evidence.contains(where: { $0.ruleTags.contains("preContrast") }))
        XCTAssertTrue(contrast.evidence.contains(where: { $0.ruleTags.contains("postContrast") }))

        let quoted = try XCTUnwrap(result.rows.first(where: { $0.id == "quoted" }))
        let quotedHit = try XCTUnwrap(quoted.evidence.first)
        XCTAssertEqual(quoted.finalLabel, .positive)
        XCTAssertTrue(quotedHit.ruleTags.contains("quotedEvidence"))
        XCTAssertLessThan(quotedHit.adjustedScore, quotedHit.baseScore)
    }

    func testRunSentimentDiscountsQuotedNewsCueAtCueLevel() throws {
        let engine = NativeAnalysisEngine()
        let result = engine.runSentiment(
            makeRequest(
                texts: [
                    SentimentInputText(
                        id: "direct",
                        sourceTitle: "City Desk",
                        text: "Officials supported the plan."
                    ),
                    SentimentInputText(
                        id: "quoted",
                        sourceTitle: "City Desk",
                        text: "The filing used the word \"supported\" in one footnote."
                    )
                ],
                domainPackID: .news
            )
        )

        let direct = try XCTUnwrap(result.rows.first(where: { $0.id == "direct" }))
        let quoted = try XCTUnwrap(result.rows.first(where: { $0.id == "quoted" }))
        let directHit = try XCTUnwrap(direct.evidence.first(where: { $0.surface.localizedCaseInsensitiveContains("supported") }))
        let quotedHit = try XCTUnwrap(quoted.evidence.first(where: { $0.surface.localizedCaseInsensitiveContains("supported") }))

        XCTAssertGreaterThan(directHit.adjustedScore, quotedHit.adjustedScore)
        XCTAssertTrue(quoted.diagnostics.reviewFlags.contains(.quoted))
        XCTAssertFalse(quoted.diagnostics.reviewFlags.contains(.reported))
    }

    func testRunSentimentDoesNotMarkReporterVoiceAsReportedWithoutAttributionConnector() throws {
        let engine = NativeAnalysisEngine()
        let result = engine.runSentiment(
            makeRequest(
                texts: [
                    SentimentInputText(
                        id: "row-1",
                        sourceTitle: "Metro Desk",
                        text: "The mayor warned of a costly delay after the storm."
                    )
                ],
                domainPackID: .news
            )
        )

        let row = try XCTUnwrap(result.rows.first)
        XCTAssertEqual(row.finalLabel, .negative)
        XCTAssertFalse(row.diagnostics.reviewFlags.contains(.reported))
        XCTAssertFalse(row.evidence.contains(where: { $0.ruleTags.contains("reportedSpeech") }))
    }

    func testRunSentimentMarksReportedSpeechWhenConnectorExists() throws {
        let engine = NativeAnalysisEngine()
        let result = engine.runSentiment(
            makeRequest(
                texts: [
                    SentimentInputText(
                        id: "row-1",
                        sourceTitle: "Metro Desk",
                        text: "Officials described the repairs as costly during the afternoon briefing."
                    )
                ],
                domainPackID: .news
            )
        )

        let row = try XCTUnwrap(result.rows.first)
        let hit = try XCTUnwrap(row.evidence.first(where: { $0.surface.localizedCaseInsensitiveContains("costly") }))
        XCTAssertTrue(row.diagnostics.reviewFlags.contains(.reported))
        XCTAssertTrue(hit.ruleTags.contains("reportedSpeech"))
        XCTAssertLessThan(abs(hit.adjustedScore), abs(hit.baseScore))
        XCTAssertFalse(row.diagnostics.reviewFlags.contains(.quoted))
    }

    func testRunSentimentKeepsProceduralNewsSentenceNeutral() throws {
        let engine = NativeAnalysisEngine()
        let result = engine.runSentiment(
            makeRequest(
                texts: [
                    SentimentInputText(
                        id: "row-1",
                        sourceTitle: "Wire",
                        text: "The agency issued the notice before noon after the hearing."
                    )
                ],
                domainPackID: .news
            )
        )

        let row = try XCTUnwrap(result.rows.first)
        XCTAssertEqual(row.finalLabel, .neutral)
        XCTAssertEqual(row.evidenceCount, 0)
    }

    func testCoordinatorUsesHybridPathForNewsReportedSpeech() throws {
        let request = SentimentRunRequest(
            source: .pastedText,
            unit: .sentence,
            contextBasis: .visibleContext,
            thresholds: .default,
            texts: [
                SentimentInputText(
                    id: "row-1",
                    sourceTitle: "Wire",
                    text: "Officials described the repairs as costly during the afternoon briefing."
                )
            ],
            backend: .coreML,
            domainPackID: .mixed,
            effectiveDomainPackID: .news
        )
        let modelRow = SentimentRowResult(
            id: "row-1::sentence::0",
            sourceID: nil,
            sourceTitle: "Wire",
            groupID: nil,
            groupTitle: nil,
            text: request.texts[0].text,
            positivityScore: 0.15,
            negativityScore: 0.62,
            neutralityScore: 0.23,
            finalLabel: .negative,
            netScore: -0.47,
            evidence: [],
            evidenceCount: 0,
            mixedEvidence: false,
            diagnostics: SentimentRowDiagnostics(
                mixedEvidence: false,
                ruleSummary: nil,
                scopeNotes: [],
                confidence: 0.82,
                topMargin: 0.41,
                subunitCount: nil,
                truncated: false,
                aggregatedFrom: .direct,
                modelRevision: "stub-coreml-v1",
                providerID: "stub-coreml",
                providerFamily: .embeddingLogReg,
                inferencePath: .model,
                modelInputKind: .denseFeatures
            ),
            sentenceID: 0,
            tokenIndex: 0
        )
        let lexiconRow = SentimentRowResult(
            id: "row-1::sentence::0",
            sourceID: nil,
            sourceTitle: "Wire",
            groupID: nil,
            groupTitle: nil,
            text: request.texts[0].text,
            positivityScore: 0.18,
            negativityScore: 0.24,
            neutralityScore: 0.58,
            finalLabel: .neutral,
            netScore: -0.06,
            evidence: [
                SentimentEvidenceHit(
                    id: "hit-1",
                    surface: "costly",
                    lemma: "costly",
                    baseScore: -1.1,
                    adjustedScore: -0.83,
                    ruleTags: ["lexicon", "reportedSpeech"],
                    tokenIndex: 4,
                    tokenLength: 1
                )
            ],
            evidenceCount: 1,
            mixedEvidence: false,
            diagnostics: SentimentRowDiagnostics(
                mixedEvidence: false,
                ruleSummary: "1 cue(s) with reportedSpeech",
                scopeNotes: [],
                confidence: nil,
                topMargin: nil,
                subunitCount: nil,
                truncated: false,
                aggregatedFrom: .direct,
                modelRevision: nil,
                ruleTraces: [],
                reviewFlags: [.reported],
                activeRuleProfileID: "default",
                activePackIDs: [.news],
                calibrationProfileRevision: "benchmark"
            ),
            sentenceID: 0,
            tokenIndex: 0
        )
        let coordinator = SentimentAnalysisCoordinator(
            lexiconAnalyzer: StubSentimentAnalyzer {
                makeStubSentimentRunResult(
                    request: $0,
                    backendKind: .lexicon,
                    rows: [lexiconRow],
                    supportsEvidenceHits: true,
                    lexiconVersion: "stub-lexicon-v1"
                )
            },
            coreMLAnalyzer: StubSentimentAnalyzer {
                makeStubSentimentRunResult(
                    request: $0,
                    backendKind: .coreML,
                    rows: [modelRow],
                    supportsEvidenceHits: false,
                    providerID: "stub-coreml",
                    providerFamily: .embeddingLogReg
                )
            }
        )

        let result = coordinator.analyze(request)
        let row = try XCTUnwrap(result.rows.first)

        XCTAssertEqual(result.backendKind, .coreML)
        XCTAssertTrue(result.supportsEvidenceHits)
        XCTAssertEqual(row.finalLabel, .neutral)
        XCTAssertEqual(row.diagnostics.inferencePath, .hybrid)
        XCTAssertTrue(row.diagnostics.reviewFlags.contains(.reported))
        XCTAssertTrue(row.evidence.contains(where: { $0.ruleTags.contains("reportedSpeech") }))
        XCTAssertEqual(row.diagnostics.providerID, "stub-coreml")
        XCTAssertEqual(row.diagnostics.providerFamily, .embeddingLogReg)
    }

    func testSentimentBundleImportSupportNormalizesAndFiltersEntries() throws {
        let bundleURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("sentiment-import-bundle-\(UUID().uuidString).json")
        let bundleJSON = """
        {
          "manifest": {
            "id": "teaching-bundle",
            "version": "2.0",
            "author": "Tester"
          },
          "entries": [
            { "term": "corpus-savvy", "score": 1.4 },
            { "term": "", "score": 1.1 },
            { "term": "corpus-savvy", "score": 1.0 },
            { "term": "risk-laden", "score": -1.8, "category": "coreNegative", "domainTags": ["news"], "matchMode": "surface" }
          ]
        }
        """
        try bundleJSON.write(to: bundleURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: bundleURL) }

        let outcome = try SentimentUserLexiconBundleImportSupport.importBundle(from: bundleURL)

        XCTAssertEqual(outcome.bundle.manifest.id, "teaching-bundle")
        XCTAssertEqual(outcome.bundle.manifest.version, "2.0")
        XCTAssertEqual(outcome.acceptedEntryCount, 2)
        XCTAssertEqual(outcome.rejectedEntryCount, 2)
        XCTAssertEqual(outcome.bundle.entries.map(\.term), ["corpus-savvy", "risk-laden"])
        XCTAssertEqual(outcome.bundle.entries.first?.category, .corePositive)
        XCTAssertEqual(outcome.bundle.entries.last?.matchMode, .surface)
    }

    private func makeRequest(
        texts: [SentimentInputText],
        backend: SentimentBackendKind = .lexicon,
        domainPackID: SentimentDomainPackID = .mixed,
        effectiveDomainPackID: SentimentDomainPackID? = nil
    ) -> SentimentRunRequest {
        SentimentRunRequest(
            source: .pastedText,
            unit: .document,
            contextBasis: .visibleContext,
            thresholds: .default,
            texts: texts,
            backend: backend,
            domainPackID: domainPackID,
            effectiveDomainPackID: effectiveDomainPackID
        )
    }
}

@MainActor
final class SentimentPresentationFeatureTests: XCTestCase {
    func testSentimentReviewOverlayOverrideRecomputesEffectiveSummaryAndScene() {
        let rawResult = makeSentimentResult()
        let reviewSample = makeSentimentReviewSample(
            result: rawResult,
            rowID: "sentiment-negative",
            decision: .overridePositive,
            note: "Teaching override"
        )
        let presentation = makeSentimentPresentationResult(
            result: rawResult,
            reviewSamples: [reviewSample]
        )

        XCTAssertEqual(presentation.effectiveOverallSummary.positiveCount, 2)
        XCTAssertEqual(presentation.effectiveOverallSummary.negativeCount, 0)
        XCTAssertEqual(presentation.reviewSummary.reviewedCount, 1)
        XCTAssertEqual(presentation.reviewSummary.overriddenCount, 1)

        let effectiveRow = presentation.effectiveRows.first(where: { $0.id == "sentiment-negative" })
        XCTAssertEqual(effectiveRow?.effectiveLabel, .positive)
        XCTAssertEqual(effectiveRow?.effectiveScores, .oneHot(for: .positive))

        let scene = SentimentSceneBuilder().build(
            from: presentation,
            thresholdPreset: .conservative,
            filterQuery: "",
            labelFilter: nil,
            sortMode: .original,
            pageSize: .fifty,
            currentPage: 1,
            visibleColumns: [.text, .finalLabel, .rawLabel, .reviewStatus],
            selectedRowID: "sentiment-negative",
            chartKind: .distributionBar
        )

        let row = scene.rows.first(where: { $0.id == "sentiment-negative" })
        XCTAssertEqual(row?.finalLabel, .positive)
        XCTAssertEqual(row?.rawLabel, .negative)
        XCTAssertEqual(row?.reviewStatus, .overridden)
        XCTAssertEqual(row?.reviewNote, "Teaching override")
        XCTAssertTrue(row?.isManuallyOverridden ?? false)
    }

    func testSentimentReviewOverlayConfirmRawKeepsScoresButCountsReviewed() {
        let rawResult = makeSentimentResult()
        let reviewSample = makeSentimentReviewSample(
            result: rawResult,
            rowID: "sentiment-positive",
            decision: .confirmRaw,
            note: "Confirmed by reviewer"
        )
        let presentation = makeSentimentPresentationResult(
            result: rawResult,
            reviewSamples: [reviewSample]
        )
        let row = presentation.effectiveRows.first(where: { $0.id == "sentiment-positive" })

        XCTAssertEqual(row?.effectiveLabel, .positive)
        XCTAssertEqual(row?.effectiveScores, row?.rawScores)
        XCTAssertEqual(row?.reviewStatus, .confirmed)
        XCTAssertEqual(presentation.reviewSummary.reviewedCount, 1)
        XCTAssertEqual(presentation.reviewSummary.confirmedRawCount, 1)
        XCTAssertEqual(presentation.reviewSummary.overriddenCount, 0)
    }

    func testSentimentExportSummaryUsesEffectiveReviewedCounts() {
        let rawResult = makeCompareSentimentResult()
        let reviewSample = makeSentimentReviewSample(
            result: rawResult,
            rowID: "reference::corpus-2::sentence::0",
            decision: .overrideNeutral,
            note: "Borderline reference example"
        )
        let presentation = makeSentimentPresentationResult(
            result: rawResult,
            reviewSamples: [reviewSample]
        )
        let lines = SentimentExportSupport.summaryLines(
            presentationResult: presentation,
            languageMode: .english
        )

        XCTAssertTrue(lines.contains("Reviewed Samples: 1"))
        XCTAssertTrue(lines.contains("Overrides: 1"))
        XCTAssertTrue(lines.contains("Confirmed Raw: 0"))
        XCTAssertTrue(lines.contains("Positive: 1 (50.0%)"))
        XCTAssertTrue(lines.contains("Neutral: 1 (50.0%)"))
        XCTAssertTrue(lines.contains("Negative: 0 (0.0%)"))
    }

    func testSentimentExportSummaryIncludesModelProviderMetadata() {
        let rawResult = SentimentRunResult(
            request: SentimentRunRequest(
                source: .pastedText,
                unit: .sentence,
                contextBasis: .visibleContext,
                thresholds: .default,
                texts: [
                    SentimentInputText(
                        id: "row-1",
                        sourceTitle: "Manual",
                        text: "The workflow is very helpful."
                    )
                ],
                backend: .coreML
            ),
            backendKind: .coreML,
            backendRevision: "coreml-sentiment-v2",
            resourceRevision: "sentiment-model-pack-v2",
            providerID: "bundled-coreml-sentiment",
            providerFamily: .embeddingLogReg,
            supportsEvidenceHits: false,
            rows: [
                SentimentRowResult(
                    id: "row-1::sentence::0",
                    sourceID: nil,
                    sourceTitle: "Manual",
                    groupID: nil,
                    groupTitle: nil,
                    text: "The workflow is very helpful.",
                    positivityScore: 0.76,
                    negativityScore: 0.07,
                    neutralityScore: 0.17,
                    finalLabel: .positive,
                    netScore: 0.69,
                    evidence: [],
                    evidenceCount: 0,
                    mixedEvidence: false,
                    diagnostics: SentimentRowDiagnostics(
                        mixedEvidence: false,
                        ruleSummary: nil,
                        scopeNotes: [],
                        confidence: 0.76,
                        topMargin: 0.59,
                        subunitCount: nil,
                        truncated: false,
                        aggregatedFrom: .direct,
                        modelRevision: "coreml-sentiment-v2",
                        providerID: "bundled-coreml-sentiment",
                        providerFamily: .embeddingLogReg,
                        inferencePath: .model,
                        modelInputKind: .denseFeatures
                    ),
                    sentenceID: 0,
                    tokenIndex: 0
                )
            ],
            overallSummary: SentimentAggregateSummary(
                id: "overall",
                title: "Overall",
                totalTexts: 1,
                positiveCount: 1,
                neutralCount: 0,
                negativeCount: 0,
                positiveRatio: 1,
                neutralRatio: 0,
                negativeRatio: 0,
                averagePositivity: 0.76,
                averageNeutrality: 0.17,
                averageNegativity: 0.07,
                averageNetScore: 0.69
            ),
            groupSummaries: [],
            lexiconVersion: ""
        )
        let lines = SentimentExportSupport.summaryLines(
            presentationResult: makeSentimentPresentationResult(result: rawResult),
            languageMode: .english
        )

        XCTAssertTrue(lines.contains("Model Provider: bundled-coreml-sentiment"))
        XCTAssertTrue(lines.contains("Provider Family: Sentence Embedding + Logistic Regression"))
    }

    func testCompareSentimentExplainerUsesEffectiveRowsAndReviewImpact() throws {
        let rawResult = makeCompareSentimentResult()
        let reviewSample = makeSentimentReviewSample(
            result: rawResult,
            rowID: "reference::corpus-2::sentence::0",
            decision: .overrideNeutral,
            note: "Reviewed reference"
        )
        let presentation = makeSentimentPresentationResult(
            result: rawResult,
            reviewSamples: [reviewSample]
        )
        let librarySnapshot = makeBootstrapState().librarySnapshot
        let targetCorpus = try XCTUnwrap(librarySnapshot.corpora.first(where: { $0.id == "corpus-1" }))
        let referenceCorpus = try XCTUnwrap(librarySnapshot.corpora.first(where: { $0.id == "corpus-2" }))
        let context = CompareSentimentDrilldownContext(
            focusTerm: "alpha",
            targetCorpora: [targetCorpus],
            referenceCorpora: [referenceCorpus]
        )

        let explainer = try XCTUnwrap(
            SentimentCrossAnalysisSupport.buildCompareExplainer(
                context: context,
                presentationResult: presentation,
                languageMode: .english
            )
        )

        XCTAssertEqual(explainer.targetSummary.positiveCount, 1)
        XCTAssertEqual(explainer.referenceSummary?.neutralCount, 1)
        XCTAssertEqual(explainer.referenceReviewImpact?.overriddenCount, 1)
        XCTAssertEqual(explainer.referenceReviewImpact?.changedCount, 1)
        XCTAssertEqual(explainer.positiveDeltaPoints, 100, accuracy: 0.001)
        XCTAssertEqual(explainer.averageNetDelta, 1.1, accuracy: 0.001)
        XCTAssertEqual(explainer.targetExemplars.first?.id, "target::corpus-1::sentence::0")
    }

    func testTopicsSentimentExplainerBuildsClusterLevelEffectiveSummary() throws {
        let rawResult = SentimentRunResult(
            request: SentimentRunRequest(
                source: .topicSegments,
                unit: .sourceSentence,
                contextBasis: .fullSentenceWhenAvailable,
                thresholds: .default,
                texts: [
                    SentimentInputText(
                        id: "topic-1::row-1",
                        sourceID: "corpus-1",
                        sourceTitle: "Corpus 1",
                        text: "Helpful support arrived quickly.",
                        sentenceID: 0,
                        tokenIndex: 0,
                        groupID: "topic-1",
                        groupTitle: "Topic 1"
                    ),
                    SentimentInputText(
                        id: "topic-2::row-1",
                        sourceID: "corpus-1",
                        sourceTitle: "Corpus 1",
                        text: "The process felt risky and unstable.",
                        sentenceID: 1,
                        tokenIndex: 0,
                        groupID: "topic-2",
                        groupTitle: "Topic 2"
                    )
                ],
                backend: .lexicon
            ),
            backendKind: .lexicon,
            backendRevision: "lexicon-v2",
            resourceRevision: "resource-v2",
            supportsEvidenceHits: true,
            rows: [
                SentimentRowResult(
                    id: "topic-1::row-1",
                    sourceID: "corpus-1",
                    sourceTitle: "Corpus 1",
                    groupID: "topic-1",
                    groupTitle: "Topic 1",
                    text: "Helpful support arrived quickly.",
                    positivityScore: 0.72,
                    negativityScore: 0.08,
                    neutralityScore: 0.20,
                    finalLabel: .positive,
                    netScore: 0.64,
                    evidence: [],
                    evidenceCount: 1,
                    mixedEvidence: false,
                    diagnostics: .empty,
                    sentenceID: 0,
                    tokenIndex: 0
                ),
                SentimentRowResult(
                    id: "topic-2::row-1",
                    sourceID: "corpus-1",
                    sourceTitle: "Corpus 1",
                    groupID: "topic-2",
                    groupTitle: "Topic 2",
                    text: "The process felt risky and unstable.",
                    positivityScore: 0.08,
                    negativityScore: 0.72,
                    neutralityScore: 0.20,
                    finalLabel: .negative,
                    netScore: -0.64,
                    evidence: [],
                    evidenceCount: 1,
                    mixedEvidence: false,
                    diagnostics: .empty,
                    sentenceID: 1,
                    tokenIndex: 0
                )
            ],
            overallSummary: makeSentimentResult().overallSummary,
            groupSummaries: makeSentimentResult().groupSummaries,
            lexiconVersion: "lexicon-v2"
        )
        let reviewSample = makeSentimentReviewSample(
            result: rawResult,
            rowID: "topic-2::row-1",
            decision: .overrideNeutral,
            note: "Borderline topic"
        )
        let presentation = makeSentimentPresentationResult(
            result: rawResult,
            reviewSamples: [reviewSample]
        )

        let explainer = try XCTUnwrap(
            SentimentCrossAnalysisSupport.buildTopicsExplainer(
                presentationResult: presentation,
                focusedClusterID: nil,
                languageMode: .english
            )
        )

        XCTAssertEqual(explainer.clusters.count, 2)
        XCTAssertEqual(explainer.cluster(id: "topic-1")?.dominantLabel, .positive)
        XCTAssertEqual(explainer.cluster(id: "topic-2")?.dominantLabel, .neutral)
        XCTAssertEqual(explainer.cluster(id: "topic-2")?.reviewImpact.overriddenCount, 1)
        XCTAssertEqual(explainer.overallReviewImpact.reviewedCount, 1)
        XCTAssertEqual(explainer.overallReviewImpact.changedCount, 1)
    }

    func testSentimentSceneBuilderAppliesFilteringSortingAndVisibleColumns() {
        let scene = SentimentSceneBuilder().build(
            from: makeSentimentResult(),
            thresholdPreset: .conservative,
            filterQuery: "bad",
            labelFilter: .negative,
            sortMode: .negativityDescending,
            pageSize: .fifty,
            currentPage: 1,
            visibleColumns: [.text, .negativity, .finalLabel, .evidence],
            selectedRowID: "sentiment-negative",
            chartKind: .distributionBar
        )

        XCTAssertEqual(scene.filteredRows, 1)
        XCTAssertEqual(scene.rows.count, 1)
        XCTAssertEqual(scene.rows.first?.text, "This is bad.")
        XCTAssertEqual(scene.selectedRowID, "sentiment-negative")
        XCTAssertTrue(scene.column(for: .evidence)?.isVisible ?? false)
        XCTAssertFalse(scene.column(for: .source)?.isVisible ?? true)
        XCTAssertTrue(scene.exportMetadataLines.contains(where: { $0.contains("Backend") || $0.contains("后端") }))
    }

    func testSentimentPageViewModelExportsCompareCrossAnalysisAndAnnotationMetadata() {
        let viewModel = SentimentPageViewModel()
        viewModel.syncLibrarySnapshot(makeBootstrapState().librarySnapshot)
        viewModel.selectedCorpusIDs = ["corpus-1"]
        viewModel.selectedReferenceSelection = .corpus("corpus-2")
        viewModel.rowFilterQuery = "alpha"
        viewModel.applyWorkspaceAnnotationState(
            WorkspaceAnnotationState(
                profile: .lemmaPreferred,
                lexicalClasses: [.noun],
                scripts: [.latin]
            )
        )
        viewModel.apply(makeCompareSentimentResult())

        let exportLines = viewModel.exportMetadataLines(
            annotationSummary: viewModel.annotationState.summary(in: .english),
            languageMode: .english
        )

        XCTAssertTrue(exportLines.contains(where: { $0.contains("Compare x Sentiment") }))
        XCTAssertTrue(exportLines.contains(where: { $0.contains("Focus Term: alpha") }))
        XCTAssertTrue(exportLines.contains(where: { $0.contains("Annotation: Lemma Preferred") }))
        XCTAssertTrue(viewModel.scene?.exportMetadataLines.contains(where: {
            $0.contains("Compare x Sentiment")
        }) ?? false)
    }

    func testSentimentPageViewModelExportsTopicsCrossAnalysisMetadata() {
        let viewModel = SentimentPageViewModel()
        let baseResult = makeCompareSentimentResult()
        viewModel.applyWorkspaceAnnotationState(
            WorkspaceAnnotationState(
                profile: .surfaceWithLemmaFallback,
                lexicalClasses: [.verb],
                scripts: [.latin]
            )
        )
        viewModel.topicSegmentsFocusClusterID = "topic-1"
        viewModel.apply(
            SentimentRunResult(
                request: SentimentRunRequest(
                    source: .topicSegments,
                    unit: .sourceSentence,
                    contextBasis: .fullSentenceWhenAvailable,
                    thresholds: .default,
                    texts: [
                        SentimentInputText(
                            id: "topic-1::1",
                            sourceID: "corpus-1",
                            sourceTitle: "Demo Corpus",
                            text: "alpha topic sentence",
                            groupID: "topic-1",
                            groupTitle: "Topic 1"
                        )
                    ],
                    backend: .lexicon
                ),
                backendKind: .lexicon,
                backendRevision: "lexicon-r1",
                resourceRevision: "sentiment-lexicon-2026-04",
                supportsEvidenceHits: true,
                rows: baseResult.rows,
                overallSummary: baseResult.overallSummary,
                groupSummaries: baseResult.groupSummaries,
                lexiconVersion: "lexicon-r1"
            )
        )

        let exportLines = viewModel.exportMetadataLines(
            annotationSummary: viewModel.annotationState.summary(in: .english),
            languageMode: .english
        )

        XCTAssertTrue(exportLines.contains(where: { $0.contains("Topics x Sentiment") }))
        XCTAssertTrue(exportLines.contains(where: { $0.contains("Focused Topic: topic-1") }))
        XCTAssertTrue(exportLines.contains(where: { $0.contains("Topic Scope: Topic 1") }))
        XCTAssertTrue(exportLines.contains(where: { $0.contains("Annotation: Surface with Lemma Fallback") }))
    }

    func testSentimentPageViewModelTracksFilteringColumnsAndCompareSelection() {
        let viewModel = SentimentPageViewModel()
        viewModel.syncLibrarySnapshot(makeBootstrapState().librarySnapshot)
        viewModel.apply(makeSentimentResult())

        XCTAssertEqual(viewModel.scene?.rows.count, 2)
        XCTAssertEqual(viewModel.selectedSceneRow?.id, "sentiment-positive")

        viewModel.handle(.changeLabelFilter(.negative))
        XCTAssertEqual(viewModel.scene?.rows.count, 1)
        XCTAssertEqual(viewModel.selectedSceneRow?.finalLabel, .negative)

        viewModel.handle(.toggleColumn(.evidence))
        XCTAssertTrue(viewModel.scene?.column(for: .evidence)?.isVisible ?? false)

        viewModel.handle(.changeSource(.kwicVisible))
        XCTAssertEqual(viewModel.unit, .concordanceLine)

        viewModel.handle(.changeSource(.corpusCompare))
        viewModel.handle(.toggleCorpusSelection("corpus-2"))
        viewModel.handle(.changeReferenceCorpus("corpus-2"))

        XCTAssertEqual(viewModel.unit, .document)
        XCTAssertEqual(Set(viewModel.selectedTargetCorpusItems().map(\.id)), Set(["corpus-1"]))
        XCTAssertEqual(viewModel.selectedReferenceCorpusItem()?.id, "corpus-2")
    }

    func testSentimentPageViewModelFallsBackWhenCoreMLBackendIsUnavailable() {
        let viewModel = SentimentPageViewModel(
            availableBackendProvider: { [.lexicon] }
        )
        viewModel.syncLibrarySnapshot(makeBootstrapState().librarySnapshot)

        viewModel.apply(
            makeWorkspaceSnapshot(
                currentTab: WorkspaceDetailTab.sentiment.snapshotValue,
                sentimentBackend: .coreML
            )
        )

        XCTAssertEqual(viewModel.backend, .lexicon)
        XCTAssertNotNil(viewModel.backendNotice)
    }

    func testSentimentPageViewModelShowsBackendPickerWhenMultipleBackendsExist() {
        let viewModel = SentimentPageViewModel(
            availableBackendProvider: { [.lexicon, .coreML] }
        )

        XCTAssertTrue(viewModel.showsBackendPicker)

        viewModel.handle(.changeBackend(.coreML))
        XCTAssertEqual(viewModel.backend, .coreML)
    }

    func testSentimentPageViewModelSupportsTopicSegmentCrossAnalysisSource() {
        let viewModel = SentimentPageViewModel()
        viewModel.syncLibrarySnapshot(makeBootstrapState().librarySnapshot)

        viewModel.handle(.changeSource(.topicSegments))

        XCTAssertEqual(viewModel.unit, .sourceSentence)
        XCTAssertEqual(viewModel.supportedUnits, [.sourceSentence])
        XCTAssertFalse(
            viewModel.canRun(
                hasOpenedCorpus: true,
                hasKWICRows: true,
                hasTopicRows: false
            )
        )
        XCTAssertTrue(
            viewModel.canRun(
                hasOpenedCorpus: false,
                hasKWICRows: false,
                hasTopicRows: true
            )
        )
    }

    func testSentimentPageViewModelUsesImportedBundleProfileInRequestsAndMetadata() {
        let viewModel = SentimentPageViewModel()
        viewModel.syncLibrarySnapshot(makeBootstrapState().librarySnapshot)
        let bundle = makeSentimentUserLexiconBundle()

        viewModel.importUserLexiconBundle(bundle)
        let request = viewModel.currentRunRequest(
            texts: [
                SentimentInputText(
                    id: "manual-1",
                    sourceTitle: "Manual",
                    text: "The explanation feels corpus-savvy."
                )
            ]
        )
        let exportLines = viewModel.exportMetadataLines(
            annotationSummary: "",
            languageMode: .english
        )

        XCTAssertEqual(viewModel.selectedRuleProfileID, "bundle:\(bundle.id)")
        XCTAssertEqual(viewModel.selectedRuleProfile.sourceKind, .importedBundle)
        XCTAssertEqual(request.userLexiconBundleIDs, [bundle.id])
        XCTAssertEqual(request.ruleProfile.customEntries.map(\.term), ["corpus-savvy"])
        XCTAssertTrue(exportLines.contains(where: { $0.contains(bundle.id) }))
    }

    func testSentimentPageViewModelAppliesWorkspaceCalibrationBiasToRequests() {
        let viewModel = SentimentPageViewModel()
        viewModel.syncLibrarySnapshot(makeBootstrapState().librarySnapshot)

        viewModel.handle(.changeCalibrationProfile(SentimentCalibrationProfile.workspaceDefault.id))
        viewModel.handle(.changeDomainPack(.news))
        viewModel.currentPackCalibrationBias = 0.18

        let request = viewModel.currentRunRequest(
            texts: [
                SentimentInputText(
                    id: "manual-1",
                    sourceTitle: "Manual",
                    text: "The coverage feels controversial."
                )
            ]
        )

        XCTAssertEqual(request.calibrationProfile.id, SentimentCalibrationProfile.workspaceDefault.id)
        XCTAssertEqual(
            request.calibrationProfile.domainBiasAdjustments[SentimentDomainPackID.news.rawValue] ?? 0,
            0.18,
            accuracy: 0.0001
        )
        XCTAssertEqual(viewModel.selectedCalibrationProfileID, SentimentCalibrationProfile.workspaceDefault.id)
    }

    func testDispatcherSentimentRunActionRunsAnalysisAndBuildsSceneGraph() async {
        let repository = FakeWorkspaceRepository()
        let workspace = makeMainWorkspaceViewModel(repository: repository)
        let dispatcher = WorkspaceActionDispatcher(workspace: workspace)

        await workspace.initializeIfNeeded()
        dispatcher.handleSentimentAction(.run)
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(repository.runSentimentCallCount, 1)
        XCTAssertEqual(workspace.selectedTab, .sentiment)
        XCTAssertEqual(workspace.sentiment.scene?.summary.totalTexts, 2)
        XCTAssertEqual(workspace.sceneGraph.activeTab, .sentiment)
    }

    func testWorkspaceSentimentOverrideUpdatesEffectivePresentationImmediately() async {
        let repository = FakeWorkspaceRepository()
        let workspace = makeMainWorkspaceViewModel(repository: repository)

        await workspace.initializeIfNeeded()
        workspace.sentiment.apply(makeSentimentResult())
        workspace.sentiment.selectedRowID = "sentiment-negative"
        workspace.sentiment.selectedReviewNoteDraft = "Manual override in tests"

        await workspace.overrideSelectedSentimentRow(.positive)

        XCTAssertEqual(repository.saveSentimentReviewSampleCallCount, 1)
        XCTAssertEqual(workspace.sentiment.presentationResult?.effectiveOverallSummary.positiveCount, 2)
        XCTAssertEqual(workspace.sentiment.presentationResult?.effectiveOverallSummary.negativeCount, 0)
        XCTAssertEqual(workspace.sentiment.presentationResult?.reviewSummary.overriddenCount, 1)
        XCTAssertEqual(workspace.sentiment.selectedSceneRow?.finalLabel, .positive)
        XCTAssertEqual(workspace.sentiment.selectedSceneRow?.rawLabel, .negative)
        XCTAssertEqual(workspace.sentiment.selectedSceneRow?.reviewStatus, .overridden)
        XCTAssertEqual(workspace.sentiment.reviewSamples.count, 1)
    }

    func testWorkspaceBootstrapRefreshesSentimentReviewSamples() async {
        let repository = FakeWorkspaceRepository()
        repository.sentimentReviewSamples = [
            makeSentimentReviewSample(
                decision: .overrideNegative,
                note: "Loaded from workspace store"
            )
        ]
        let workspace = makeMainWorkspaceViewModel(repository: repository)

        await workspace.initializeIfNeeded()

        XCTAssertEqual(repository.listSentimentReviewSamplesCallCount, 1)
        XCTAssertEqual(workspace.sentiment.reviewSamples.count, 1)
        XCTAssertEqual(workspace.sentiment.reviewSamples.first?.decision, .overrideNegative)
    }
}

private struct StubSentimentAnalyzer: SentimentAnalyzing {
    let handler: (SentimentRunRequest) throws -> SentimentRunResult

    func analyze(_ request: SentimentRunRequest) throws -> SentimentRunResult {
        try handler(request)
    }
}

private func makeStubSentimentRunResult(
    request: SentimentRunRequest,
    backendKind: SentimentBackendKind,
    rows: [SentimentRowResult],
    supportsEvidenceHits: Bool,
    providerID: String? = nil,
    providerFamily: SentimentModelProviderFamily? = nil,
    lexiconVersion: String = ""
) -> SentimentRunResult {
    SentimentResultAggregation.makeRunResult(
        request: request,
        backendKind: backendKind,
        backendRevision: backendKind == .coreML ? "stub-coreml-v1" : "stub-lexicon-v1",
        resourceRevision: "stub-resource-v1",
        providerID: providerID,
        providerFamily: providerFamily,
        supportsEvidenceHits: supportsEvidenceHits,
        rows: rows,
        lexiconVersion: lexiconVersion
    )
}
