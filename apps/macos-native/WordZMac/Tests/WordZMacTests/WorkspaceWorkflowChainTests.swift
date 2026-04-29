import XCTest
@testable import WordZWorkspaceCore

@MainActor
final class WorkspaceWorkflowChainTests: XCTestCase {
    func testOpenCompareSentimentSeedsCorpusCompareScopeAndRunsSentiment() async throws {
        let referenceSet = LibraryCorpusSetItem(json: [
            "id": "set-1",
            "name": "Reference Set",
            "corpusIds": ["corpus-2"],
            "corpusNames": ["Compare Corpus"],
            "metadataFilter": [:],
            "createdAt": "today",
            "updatedAt": "today"
        ])
        let repository = FakeWorkspaceRepository(
            bootstrapState: makeBootstrapState(corpusSets: [referenceSet]),
            sentimentResult: makeCompareSentimentResult()
        )
        let workspace = makeMainWorkspaceViewModel(repository: repository)

        await workspace.initializeIfNeeded()
        workspace.compare.syncLibrarySnapshot(repository.bootstrapState.librarySnapshot)
        workspace.compare.selectedCorpusIDs = ["corpus-1"]
        workspace.compare.selectedReferenceSelection = .corpusSet("set-1")
        workspace.compare.apply(makeCompareResult())
        workspace.compare.selectedRowID = "alpha"

        await workspace.openCompareSentiment()

        let request = try XCTUnwrap(repository.lastSentimentRequest)
        XCTAssertEqual(repository.runSentimentCallCount, 1)
        XCTAssertEqual(request.source, .corpusCompare)
        XCTAssertEqual(request.unit, .sentence)
        XCTAssertEqual(request.contextBasis, .fullSentenceWhenAvailable)
        XCTAssertEqual(request.texts.count, 2)
        XCTAssertEqual(request.texts.first(where: { $0.groupID == "target" })?.sourceID, "corpus-1")
        XCTAssertEqual(request.texts.first(where: { $0.groupID == "reference" })?.sourceID, "corpus-2")
        XCTAssertEqual(workspace.sentiment.source, .corpusCompare)
        XCTAssertEqual(workspace.sentiment.selectedReferenceCorpusID, "set:set-1")
        XCTAssertEqual(workspace.sentiment.selectedReferenceCorpusSetID, "set-1")
        XCTAssertEqual(workspace.sentiment.rowFilterQuery, "alpha")
        XCTAssertEqual(workspace.compare.sentimentSummary?.focusTerm, "alpha")
        XCTAssertEqual(workspace.compare.sentimentExplainer?.focusTerm, "alpha")
        XCTAssertEqual(workspace.compare.scene?.sentimentSummary?.focusTerm, "alpha")
        XCTAssertEqual(workspace.compare.scene?.sentimentExplainer?.focusTerm, "alpha")
        XCTAssertTrue(workspace.compare.scene?.exportMetadataLines.contains(where: {
            $0.contains("Compare x Sentiment")
        }) ?? false)
        XCTAssertTrue(workspace.compare.scene?.exportMetadataLines.contains(where: {
            $0.contains(workspace.annotationSummary(in: .system))
        }) ?? false)
        XCTAssertEqual(workspace.selectedTab, .sentiment)
        XCTAssertTrue(workspace.sceneGraph.sentiment.hasResult)
    }

    func testOpenCompareTopicsSeedsCompareScopeAndRunsTopics() async throws {
        let referenceSet = LibraryCorpusSetItem(json: [
            "id": "set-1",
            "name": "Reference Set",
            "corpusIds": ["corpus-2"],
            "corpusNames": ["Compare Corpus"],
            "metadataFilter": [:],
            "createdAt": "today",
            "updatedAt": "today"
        ])
        let targetOpenedCorpus = OpenedCorpus(json: [
            "mode": "saved",
            "filePath": "/tmp/compare-target-topics.txt",
            "displayName": "Demo Corpus",
            "content": "alpha target framing keeps the comparison grounded.",
            "sourceType": "txt"
        ])
        let referenceOpenedCorpus = OpenedCorpus(json: [
            "mode": "saved",
            "filePath": "/tmp/compare-reference-topics.txt",
            "displayName": "Compare Corpus",
            "content": "alpha reference framing keeps the contrast visible.",
            "sourceType": "txt"
        ])
        let repository = FakeWorkspaceRepository(
            bootstrapState: makeBootstrapState(corpusSets: [referenceSet]),
            openedCorporaByID: [
                "corpus-1": targetOpenedCorpus,
                "corpus-2": referenceOpenedCorpus
            ],
            topicsResult: makeCompareTopicsResult()
        )
        let workspace = makeMainWorkspaceViewModel(repository: repository)

        await workspace.initializeIfNeeded()
        workspace.compare.syncLibrarySnapshot(repository.bootstrapState.librarySnapshot)
        workspace.compare.selectedCorpusIDs = ["corpus-1"]
        workspace.compare.selectedReferenceSelection = .corpusSet("set-1")
        workspace.compare.apply(makeCompareResult())
        workspace.compare.selectedRowID = "alpha"

        await workspace.openCompareTopics()

        let drilldownContext = try XCTUnwrap(workspace.topics.compareDrilldownContext)
        let topicsResult = try XCTUnwrap(workspace.topics.result)

        XCTAssertEqual(repository.runTopicsCallCount, 1)
        XCTAssertEqual(repository.lastRunTopicsOptions?.searchQuery, "alpha")
        XCTAssertTrue(repository.lastRunTopicsText?.contains(targetOpenedCorpus.content) == true)
        XCTAssertTrue(repository.lastRunTopicsText?.contains(referenceOpenedCorpus.content) == true)
        XCTAssertEqual(drilldownContext.focusTerm, "alpha")
        XCTAssertEqual(drilldownContext.targetCorpusIDs, ["corpus-1"])
        XCTAssertEqual(drilldownContext.referenceCorpusIDs, ["corpus-2"])
        XCTAssertEqual(workspace.selectedTab, .topics)
        XCTAssertTrue(workspace.sceneGraph.topics.hasResult)
        XCTAssertTrue(workspace.topics.scene?.crossAnalysisSummary?.contains("alpha") == true)
        XCTAssertEqual(workspace.compare.topicsSummary?.focusTerm, "alpha")
        XCTAssertEqual(workspace.compare.scene?.topicsSummary?.targetSegmentCount, 1)
        XCTAssertEqual(workspace.compare.scene?.topicsSummary?.referenceSegmentCount, 1)
        XCTAssertTrue(workspace.compare.scene?.exportMetadataLines.contains(where: {
            $0.contains("Compare x Topics")
        }) ?? false)
        XCTAssertEqual(topicsResult.segments.first(where: { $0.id == "compare-topic-target-1" })?.sourceID, "corpus-1")
        XCTAssertEqual(topicsResult.segments.first(where: { $0.id == "compare-topic-target-1" })?.groupID, "target")
        XCTAssertEqual(topicsResult.segments.first(where: { $0.id == "compare-topic-target-1" })?.sourceParagraphIndex, 1)
        XCTAssertEqual(topicsResult.segments.first(where: { $0.id == "compare-topic-reference-1" })?.sourceID, "corpus-2")
        XCTAssertEqual(topicsResult.segments.first(where: { $0.id == "compare-topic-reference-1" })?.groupID, "reference")
        XCTAssertEqual(topicsResult.segments.first(where: { $0.id == "compare-topic-reference-1" })?.sourceParagraphIndex, 1)

        workspace.topics.selectedRowID = "compare-topic-reference-1"

        let opened = await workspace.openCurrentSourceReader()

        XCTAssertTrue(opened)
        XCTAssertEqual(workspace.sourceReader.launchContext?.origin, .topics)
        XCTAssertEqual(workspace.sourceReader.launchContext?.corpusID, "corpus-2")
    }

    func testOpenTopicsKWICUsesSelectedTopicSegmentSourceAndKeyword() async {
        let referenceOpenedCorpus = OpenedCorpus(json: [
            "mode": "saved",
            "filePath": "/tmp/compare-reference-topics.txt",
            "displayName": "Compare Corpus",
            "content": "alpha reference framing keeps the contrast visible.",
            "sourceType": "txt"
        ])
        let repository = FakeWorkspaceRepository(
            openedCorporaByID: [
                "corpus-2": referenceOpenedCorpus
            ],
            topicsResult: makeCompareTopicsResult()
        )
        let workspace = makeMainWorkspaceViewModel(repository: repository)

        await workspace.initializeIfNeeded()
        workspace.topics.query = "alpha"
        workspace.topics.apply(makeCompareTopicsResult())
        workspace.topics.selectedClusterID = "topic-1"
        workspace.topics.selectedRowID = "compare-topic-reference-1"

        await workspace.openTopicsKWIC()

        XCTAssertEqual(repository.runKWICCallCount, 1)
        XCTAssertEqual(workspace.kwic.keyword, "alpha")
        XCTAssertEqual(workspace.sidebar.selectedCorpusID, "corpus-2")
        XCTAssertEqual(workspace.selectedTab, .kwic)
        XCTAssertTrue(workspace.sceneGraph.kwic.hasResult)
    }

    func testOpenCurrentSourceReaderFromKWICLoadsSelectedSentenceContext() async {
        let repository = FakeWorkspaceRepository(
            tokenizeResult: makeTokenizeResult(),
            kwicResult: KWICResult(rows: [
                KWICRow(id: "0-0", left: "", node: "Alpha", right: "beta gamma", sentenceId: 0, sentenceTokenIndex: 0),
                KWICRow(id: "1-1", left: "Delta", node: "alpha", right: "", sentenceId: 1, sentenceTokenIndex: 1)
            ])
        )
        let workspace = makeMainWorkspaceViewModel(repository: repository)

        await workspace.initializeIfNeeded()
        workspace.kwic.keyword = "alpha"
        await workspace.runKWIC()
        workspace.kwic.selectedRowID = "1-1"

        let opened = await workspace.openCurrentSourceReader()

        XCTAssertTrue(opened)
        XCTAssertEqual(workspace.sourceReader.launchContext?.origin, .kwic)
        XCTAssertEqual(workspace.sourceReader.scene?.selectedHitID, "1-1")
        XCTAssertEqual(workspace.sourceReader.scene?.selection?.hit.fullSentenceText, "Delta alpha.")
        XCTAssertTrue(workspace.sourceReader.scene?.originSummary.contains("KWIC") == true)
        XCTAssertEqual(workspace.sourceReader.scene?.sourceChainItems.last?.id, "current-highlight")
        XCTAssertTrue(workspace.sourceReader.scene?.sourceChainItems.last?.value.contains("2") == true)
        XCTAssertTrue(workspace.sourceReader.scene?.sourceChainItems.last?.value.contains("alpha") == true)
        XCTAssertEqual(workspace.sourceReader.scene?.sourceChainItems.last?.isCurrent, true)
    }

    func testOpenCurrentSourceReaderFromLocatorLoadsSelectedSentenceContext() async {
        let repository = FakeWorkspaceRepository(
            tokenizeResult: makeTokenizeResult(),
            locatorResult: LocatorResult(json: [
                "sentences": [
                    [
                        "sentenceId": 0,
                        "text": "Alpha beta gamma.",
                        "leftWords": "",
                        "nodeWord": "Alpha",
                        "rightWords": "beta gamma",
                        "status": "当前定位"
                    ],
                    [
                        "sentenceId": 1,
                        "text": "Delta alpha.",
                        "leftWords": "Delta",
                        "nodeWord": "alpha",
                        "rightWords": "",
                        "status": ""
                    ]
                ],
                "rows": [
                    [
                        "sentenceId": 0,
                        "text": "Alpha beta gamma.",
                        "leftWords": "",
                        "nodeWord": "Alpha",
                        "rightWords": "beta gamma",
                        "status": "当前定位"
                    ],
                    [
                        "sentenceId": 1,
                        "text": "Delta alpha.",
                        "leftWords": "Delta",
                        "nodeWord": "alpha",
                        "rightWords": "",
                        "status": ""
                    ]
                ]
            ])
        )
        let workspace = makeMainWorkspaceViewModel(repository: repository)

        await workspace.initializeIfNeeded()
        workspace.locator.apply(
            repository.locatorResult,
            source: LocatorSource(keyword: "alpha", sentenceId: 1, nodeIndex: 1)
        )
        workspace.locator.selectedRowID = "1"

        let opened = await workspace.openCurrentSourceReader()

        XCTAssertTrue(opened)
        XCTAssertEqual(workspace.sourceReader.launchContext?.origin, .locator)
        XCTAssertEqual(workspace.sourceReader.scene?.selectedHitID, "1")
        XCTAssertEqual(workspace.sourceReader.scene?.selection?.hit.fullSentenceText, "Delta alpha.")
    }

    func testOpenCurrentSourceReaderFromSentimentLoadsSelectedSentenceContext() async {
        let sentimentResult = SentimentRunResult(
            request: SentimentRunRequest(
                source: .openedCorpus,
                unit: .sentence,
                contextBasis: .visibleContext,
                thresholds: .default,
                texts: [
                    SentimentInputText(
                        id: "corpus-1",
                        sourceID: "corpus-1",
                        sourceTitle: "Demo Corpus",
                        text: "Alpha beta gamma. Delta alpha."
                    )
                ],
                backend: .lexicon
            ),
            backendKind: .lexicon,
            backendRevision: "lexicon-rules-v3",
            resourceRevision: "sentiment-pack-test-v1",
            supportsEvidenceHits: true,
            rows: [
                SentimentRowResult(
                    id: "sentiment-0",
                    sourceID: "corpus-1",
                    sourceTitle: "Demo Corpus",
                    groupID: "target",
                    groupTitle: "Target",
                    text: "Alpha beta gamma.",
                    positivityScore: 0.2,
                    negativityScore: 0.1,
                    neutralityScore: 0.7,
                    finalLabel: .neutral,
                    netScore: 0.1,
                    evidence: [
                        SentimentEvidenceHit(
                            id: "beta-hit",
                            surface: "beta",
                            lemma: "beta",
                            baseScore: 0.3,
                            adjustedScore: 0.3,
                            ruleTags: ["lexicon"],
                            tokenIndex: 1,
                            tokenLength: 1
                        )
                    ],
                    evidenceCount: 1,
                    mixedEvidence: false,
                    diagnostics: .empty,
                    sentenceID: 0,
                    tokenIndex: 1
                ),
                SentimentRowResult(
                    id: "sentiment-1",
                    sourceID: "corpus-1",
                    sourceTitle: "Demo Corpus",
                    groupID: "target",
                    groupTitle: "Target",
                    text: "Delta alpha.",
                    positivityScore: 0.6,
                    negativityScore: 0.1,
                    neutralityScore: 0.3,
                    finalLabel: .positive,
                    netScore: 0.9,
                    evidence: [
                        SentimentEvidenceHit(
                            id: "alpha-hit",
                            surface: "alpha",
                            lemma: "alpha",
                            baseScore: 1.1,
                            adjustedScore: 1.1,
                            ruleTags: ["lexicon"],
                            tokenIndex: 1,
                            tokenLength: 1
                        )
                    ],
                    evidenceCount: 1,
                    mixedEvidence: false,
                    diagnostics: .empty,
                    sentenceID: 1,
                    tokenIndex: 1
                )
            ],
            overallSummary: makeSentimentResult().overallSummary,
            groupSummaries: makeSentimentResult().groupSummaries,
            lexiconVersion: "test-v1"
        )
        let repository = FakeWorkspaceRepository(
            tokenizeResult: makeTokenizeResult(),
            sentimentResult: sentimentResult
        )
        let workspace = makeMainWorkspaceViewModel(repository: repository)

        await workspace.initializeIfNeeded()
        workspace.sentiment.apply(sentimentResult)
        workspace.sentiment.selectedRowID = "sentiment-1"
        workspace.selectedTab = .sentiment
        workspace.syncSceneGraph()

        let opened = await workspace.openCurrentSourceReader()

        XCTAssertTrue(opened)
        XCTAssertEqual(workspace.sourceReader.launchContext?.origin, .sentiment)
        XCTAssertEqual(workspace.sourceReader.scene?.selectedHitID, "sentiment-1")
        XCTAssertEqual(workspace.sourceReader.scene?.selection?.hit.fullSentenceText, "Delta alpha.")
        XCTAssertFalse(workspace.sourceReader.scene?.originSummary.isEmpty ?? true)
    }

    func testOpenCurrentSourceReaderFromTopicsLoadsSelectedSegmentContext() async {
        let fixture = makeTopicsSourceReaderFixture()
        let repository = FakeWorkspaceRepository(
            openedCorpus: fixture.openedCorpus,
            tokenizeResult: fixture.tokenizeResult,
            topicsResult: fixture.topicsResult
        )
        let workspace = makeMainWorkspaceViewModel(repository: repository)

        await workspace.initializeIfNeeded()
        workspace.topics.query = "hacker"
        await workspace.runTopics()
        workspace.topics.selectedRowID = "paragraph-2"

        let opened = await workspace.openCurrentSourceReader()

        XCTAssertTrue(opened)
        XCTAssertEqual(workspace.sourceReader.launchContext?.origin, .topics)
        XCTAssertEqual(workspace.sourceReader.scene?.selectedHitID, "paragraph-2")
        XCTAssertEqual(
            workspace.sourceReader.scene?.selection?.hit.fullSentenceText,
            "Hackers shared exploit mitigation strategies and coordinated fixes."
        )
        XCTAssertFalse(workspace.sourceReader.scene?.selection?.annotationItems.isEmpty ?? true)
    }

    func testOpenTopicsSentimentBuildsTopicGroupedRequestAndPreservesSourceReaderChain() async {
        let fixture = makeTopicsSourceReaderFixture()
        let sentimentResult = makeTopicsSentimentResult(
            corpusID: "corpus-1",
            sourceTitle: fixture.openedCorpus.displayName,
            documentText: fixture.openedCorpus.content
        )
        let repository = FakeWorkspaceRepository(
            openedCorpus: fixture.openedCorpus,
            tokenizeResult: fixture.tokenizeResult,
            topicsResult: fixture.topicsResult,
            sentimentResult: sentimentResult
        )
        let workspace = makeMainWorkspaceViewModel(repository: repository)

        await workspace.initializeIfNeeded()
        workspace.topics.query = ""
        workspace.topics.apply(fixture.topicsResult)
        workspace.selectedTab = .topics
        workspace.syncSceneGraph()
        XCTAssertNotNil(workspace.topics.scene)
        XCTAssertTrue(workspace.topics.canAnalyzeVisibleTopicsInSentiment)
        await workspace.openTopicsSentiment(scope: .visibleTopics)

        XCTAssertEqual(repository.runSentimentCallCount, 1)
        XCTAssertEqual(repository.lastSentimentRequest?.source, .topicSegments)
        XCTAssertEqual(repository.lastSentimentRequest?.unit, .sourceSentence)
        XCTAssertEqual(repository.lastSentimentRequest?.texts.map(\.sentenceID), [0, 1, 2])
        XCTAssertEqual(repository.lastSentimentRequest?.texts.map(\.groupID), ["topic-1", "topic-1", TopicAnalysisResult.outlierTopicID])
        XCTAssertTrue(repository.lastSentimentRequest?.texts.allSatisfy { !$0.text.isEmpty } ?? false)
        XCTAssertEqual(workspace.selectedTab, .sentiment)
        XCTAssertEqual(workspace.sentiment.source, .topicSegments)
        XCTAssertEqual(workspace.sentiment.unit, .sourceSentence)
        XCTAssertEqual(workspace.topics.sentimentExplainer?.clusters.count, 1)
        XCTAssertEqual(workspace.topics.scene?.sentimentExplainer?.clusters.count, 1)
        XCTAssertEqual(workspace.topics.sentimentExplainer?.clusters.first?.id, "topic-1")
        XCTAssertTrue(
            workspace.currentReadingExportDocument?.document.text.contains(
                wordZText("分组统计", "Grouped Summaries", mode: .system)
            ) == true
        )

        let opened = await workspace.openCurrentSourceReader()

        XCTAssertTrue(opened)
        XCTAssertEqual(workspace.sourceReader.launchContext?.origin, .sentiment)
        XCTAssertEqual(workspace.sourceReader.scene?.selection?.hit.fullSentenceText, fixture.openedCorpus.content.components(separatedBy: "\n\n").first)
    }

    func testCaptureCurrentSentimentEvidenceItemAddsWorkbenchEntry() async {
        let sentimentResult = SentimentRunResult(
            request: SentimentRunRequest(
                source: .openedCorpus,
                unit: .sourceSentence,
                contextBasis: .fullSentenceWhenAvailable,
                thresholds: .default,
                texts: [
                    SentimentInputText(
                        id: "sentiment-1",
                        sourceID: "corpus-1",
                        sourceTitle: "Demo Corpus",
                        text: "Delta alpha.",
                        sentenceID: 1,
                        tokenIndex: 1,
                        documentText: "Gamma beta.\n\nDelta alpha."
                    )
                ],
                backend: .lexicon
            ),
            backendKind: .lexicon,
            backendRevision: "lexicon-v1",
            resourceRevision: "resource-v1",
            supportsEvidenceHits: true,
            rows: [
                SentimentRowResult(
                    id: "sentiment-1",
                    sourceID: "corpus-1",
                    sourceTitle: "Demo Corpus",
                    groupID: "target",
                    groupTitle: "Target",
                    text: "Delta alpha.",
                    positivityScore: 0.74,
                    negativityScore: 0.06,
                    neutralityScore: 0.20,
                    finalLabel: .positive,
                    netScore: 1.25,
                    evidence: [
                        SentimentEvidenceHit(
                            id: "alpha-hit",
                            surface: "alpha",
                            lemma: "alpha",
                            baseScore: 1.1,
                            adjustedScore: 1.1,
                            ruleTags: ["lexicon"],
                            tokenIndex: 1,
                            tokenLength: 1
                        )
                    ],
                    evidenceCount: 1,
                    mixedEvidence: false,
                    diagnostics: .empty,
                    sentenceID: 1,
                    tokenIndex: 1
                )
            ],
            overallSummary: makeSentimentResult().overallSummary,
            groupSummaries: makeSentimentResult().groupSummaries,
            lexiconVersion: "test-v1"
        )
        let repository = FakeWorkspaceRepository(
            tokenizeResult: makeTokenizeResult(),
            sentimentResult: sentimentResult
        )
        let workspace = makeMainWorkspaceViewModel(repository: repository)

        await workspace.initializeIfNeeded()
        workspace.sentiment.apply(sentimentResult)
        workspace.sentiment.selectedRowID = "sentiment-1"
        workspace.selectedTab = .sentiment
        workspace.syncSceneGraph()

        await workspace.captureCurrentSentimentEvidenceItem()

        XCTAssertEqual(repository.saveEvidenceItemCallCount, 1)
        XCTAssertEqual(repository.evidenceItems.first?.sourceKind, .sentiment)
        XCTAssertEqual(repository.evidenceItems.first?.sentenceId, 1)
        XCTAssertEqual(repository.evidenceItems.first?.keyword, "alpha")
        XCTAssertEqual(repository.evidenceItems.first?.sentimentMetadata?.effectiveLabel, .positive)
        XCTAssertEqual(repository.evidenceItems.first?.crossAnalysisMetadata?.originKind, .sentimentDirect)
    }

    func testCaptureCurrentCompareSentimentEvidenceItemCarriesCrossAnalysisMetadata() async {
        let repository = FakeWorkspaceRepository(
            bootstrapState: makeBootstrapState(),
            tokenizeResult: makeTokenizeResult(),
            sentimentResult: makeCompareSentimentResult()
        )
        let workspace = makeMainWorkspaceViewModel(repository: repository)

        await workspace.initializeIfNeeded()
        workspace.sentiment.syncLibrarySnapshot(repository.bootstrapState.librarySnapshot)
        workspace.sentiment.selectedCorpusIDs = ["corpus-1"]
        workspace.sentiment.selectedReferenceSelection = .corpus("corpus-2")
        workspace.sentiment.apply(makeCompareSentimentResult())
        workspace.sentiment.rowFilterQuery = "alpha"
        workspace.sentiment.selectedRowID = "target::corpus-1::sentence::0"
        workspace.selectedTab = .sentiment
        workspace.syncSceneGraph()

        await workspace.captureCurrentSentimentEvidenceItem()

        XCTAssertEqual(repository.saveEvidenceItemCallCount, 1)
        XCTAssertEqual(repository.evidenceItems.first?.sentimentMetadata?.rawLabel, .positive)
        XCTAssertEqual(repository.evidenceItems.first?.crossAnalysisMetadata?.originKind, .compareSentiment)
        XCTAssertEqual(repository.evidenceItems.first?.crossAnalysisMetadata?.focusTerm, "alpha")
    }

    func testCaptureCurrentSourceReaderEvidenceItemFromSentimentPersistsSentimentSource() async {
        let repository = FakeWorkspaceRepository(
            tokenizeResult: makeTokenizeResult(),
            sentimentResult: makeSentimentResult()
        )
        let workspace = makeMainWorkspaceViewModel(repository: repository)

        await workspace.initializeIfNeeded()
        workspace.sentiment.apply(makeSentimentResult())
        workspace.sentiment.selectedRowID = "sentiment-negative"
        workspace.selectedTab = .sentiment
        workspace.syncSceneGraph()
        _ = await workspace.openCurrentSourceReader()

        workspace.sourceReader.captureClaim = "Negative sentence evidence."
        await workspace.captureCurrentSourceReaderEvidenceItem()

        XCTAssertEqual(repository.evidenceItems.first?.sourceKind, .sentiment)
        XCTAssertEqual(repository.evidenceItems.first?.sentenceId, 1)
        XCTAssertEqual(repository.evidenceItems.first?.claim, "Negative sentence evidence.")
        XCTAssertEqual(repository.evidenceItems.first?.keyword, "bad")
    }

    func testCaptureCurrentSourceReaderEvidenceItemFromTopicsPersistsTopicsSource() async {
        let fixture = makeTopicsSourceReaderFixture()
        let repository = FakeWorkspaceRepository(
            openedCorpus: fixture.openedCorpus,
            tokenizeResult: fixture.tokenizeResult,
            topicsResult: fixture.topicsResult
        )
        let workspace = makeMainWorkspaceViewModel(repository: repository)

        await workspace.initializeIfNeeded()
        workspace.topics.query = "hacker"
        await workspace.runTopics()
        workspace.topics.selectedRowID = "paragraph-2"
        _ = await workspace.openCurrentSourceReader()

        workspace.sourceReader.captureTagsText = "topics, security"
        await workspace.captureCurrentSourceReaderEvidenceItem()

        XCTAssertEqual(repository.evidenceItems.first?.sourceKind, .topics)
        XCTAssertEqual(repository.evidenceItems.first?.sentenceId, 1)
        XCTAssertEqual(repository.evidenceItems.first?.keyword, "hacker")
        XCTAssertEqual(
            repository.evidenceItems.first?.fullSentenceText,
            "Hackers shared exploit mitigation strategies and coordinated fixes."
        )
        XCTAssertEqual(repository.evidenceItems.first?.tags, ["topics", "security"])
    }

    func testTopicsSentimentSourceReaderCapturePreservesTopicsCrossAnalysisMetadata() async {
        let fixture = makeTopicsSourceReaderFixture()
        let repository = FakeWorkspaceRepository(
            openedCorpus: fixture.openedCorpus,
            tokenizeResult: fixture.tokenizeResult,
            topicsResult: fixture.topicsResult,
            sentimentResult: makeTopicsSentimentResult(
                corpusID: "corpus-1",
                sourceTitle: fixture.openedCorpus.displayName,
                documentText: fixture.openedCorpus.content
            )
        )
        let workspace = makeMainWorkspaceViewModel(repository: repository)

        await workspace.initializeIfNeeded()
        workspace.topics.query = ""
        workspace.topics.apply(fixture.topicsResult)
        workspace.selectedTab = .topics
        workspace.syncSceneGraph()
        XCTAssertNotNil(workspace.topics.scene)
        XCTAssertTrue(workspace.topics.canAnalyzeVisibleTopicsInSentiment)

        await workspace.openTopicsSentiment(scope: .visibleTopics)
        workspace.sentiment.selectedRowID = "paragraph-1::sentence::0"
        workspace.selectedTab = .sentiment
        workspace.syncSceneGraph()
        let opened = await workspace.openCurrentSourceReader()
        await workspace.captureCurrentSourceReaderEvidenceItem()

        XCTAssertTrue(opened)
        XCTAssertEqual(workspace.sourceReader.launchContext?.origin, .sentiment)
        XCTAssertEqual(repository.evidenceItems.first?.sourceKind, .sentiment)
        XCTAssertEqual(repository.evidenceItems.first?.crossAnalysisMetadata?.originKind, .topicsSentiment)
        XCTAssertEqual(repository.evidenceItems.first?.crossAnalysisMetadata?.topicTitle, "Topic 1")
    }
}
