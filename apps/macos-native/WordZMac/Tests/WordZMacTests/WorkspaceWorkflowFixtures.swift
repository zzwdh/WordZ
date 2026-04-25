import Foundation
@testable import WordZWorkspaceCore

func makeTopicsSourceReaderFixture() -> (
    openedCorpus: OpenedCorpus,
    tokenizeResult: TokenizeResult,
    topicsResult: TopicAnalysisResult
) {
    let paragraphs = [
        "Security researchers discussed hacker communities and disclosure norms.",
        "Hackers shared exploit mitigation strategies and coordinated fixes.",
        "A short unrelated paragraph about coffee and weather."
    ]
    let documentText = paragraphs.joined(separator: "\n\n")

    let openedCorpus = OpenedCorpus(json: [
        "mode": "saved",
        "filePath": "/tmp/topics-source.txt",
        "displayName": "Topics Source Corpus",
        "content": documentText,
        "sourceType": "txt"
    ])

    let tokenizeResult = TokenizeResult(
        sentences: [
            TokenizedSentence(
                sentenceId: 0,
                text: paragraphs[0],
                tokens: [
                    TokenizedToken(original: "Security", normalized: "security", sentenceId: 0, tokenIndex: 0, annotations: TokenLinguisticAnnotations(script: .latin, lemma: "security", lexicalClass: .noun)),
                    TokenizedToken(original: "researchers", normalized: "researchers", sentenceId: 0, tokenIndex: 1, annotations: TokenLinguisticAnnotations(script: .latin, lemma: "researcher", lexicalClass: .noun)),
                    TokenizedToken(original: "discussed", normalized: "discussed", sentenceId: 0, tokenIndex: 2, annotations: TokenLinguisticAnnotations(script: .latin, lemma: "discuss", lexicalClass: .verb)),
                    TokenizedToken(original: "hacker", normalized: "hacker", sentenceId: 0, tokenIndex: 3, annotations: TokenLinguisticAnnotations(script: .latin, lemma: "hacker", lexicalClass: .noun)),
                    TokenizedToken(original: "communities", normalized: "communities", sentenceId: 0, tokenIndex: 4, annotations: TokenLinguisticAnnotations(script: .latin, lemma: "community", lexicalClass: .noun)),
                    TokenizedToken(original: "and", normalized: "and", sentenceId: 0, tokenIndex: 5, annotations: TokenLinguisticAnnotations(script: .latin, lemma: "and", lexicalClass: .other)),
                    TokenizedToken(original: "disclosure", normalized: "disclosure", sentenceId: 0, tokenIndex: 6, annotations: TokenLinguisticAnnotations(script: .latin, lemma: "disclosure", lexicalClass: .noun)),
                    TokenizedToken(original: "norms", normalized: "norms", sentenceId: 0, tokenIndex: 7, annotations: TokenLinguisticAnnotations(script: .latin, lemma: "norm", lexicalClass: .noun))
                ]
            ),
            TokenizedSentence(
                sentenceId: 1,
                text: paragraphs[1],
                tokens: [
                    TokenizedToken(original: "Hackers", normalized: "hackers", sentenceId: 1, tokenIndex: 0, annotations: TokenLinguisticAnnotations(script: .latin, lemma: "hacker", lexicalClass: .noun)),
                    TokenizedToken(original: "shared", normalized: "shared", sentenceId: 1, tokenIndex: 1, annotations: TokenLinguisticAnnotations(script: .latin, lemma: "share", lexicalClass: .verb)),
                    TokenizedToken(original: "exploit", normalized: "exploit", sentenceId: 1, tokenIndex: 2, annotations: TokenLinguisticAnnotations(script: .latin, lemma: "exploit", lexicalClass: .noun)),
                    TokenizedToken(original: "mitigation", normalized: "mitigation", sentenceId: 1, tokenIndex: 3, annotations: TokenLinguisticAnnotations(script: .latin, lemma: "mitigation", lexicalClass: .noun)),
                    TokenizedToken(original: "strategies", normalized: "strategies", sentenceId: 1, tokenIndex: 4, annotations: TokenLinguisticAnnotations(script: .latin, lemma: "strategy", lexicalClass: .noun)),
                    TokenizedToken(original: "and", normalized: "and", sentenceId: 1, tokenIndex: 5, annotations: TokenLinguisticAnnotations(script: .latin, lemma: "and", lexicalClass: .other)),
                    TokenizedToken(original: "coordinated", normalized: "coordinated", sentenceId: 1, tokenIndex: 6, annotations: TokenLinguisticAnnotations(script: .latin, lemma: "coordinate", lexicalClass: .verb)),
                    TokenizedToken(original: "fixes", normalized: "fixes", sentenceId: 1, tokenIndex: 7, annotations: TokenLinguisticAnnotations(script: .latin, lemma: "fix", lexicalClass: .noun))
                ]
            ),
            TokenizedSentence(
                sentenceId: 2,
                text: paragraphs[2],
                tokens: [
                    TokenizedToken(original: "A", normalized: "a", sentenceId: 2, tokenIndex: 0, annotations: TokenLinguisticAnnotations(script: .latin, lemma: "a", lexicalClass: .other)),
                    TokenizedToken(original: "short", normalized: "short", sentenceId: 2, tokenIndex: 1, annotations: TokenLinguisticAnnotations(script: .latin, lemma: "short", lexicalClass: .adjective)),
                    TokenizedToken(original: "unrelated", normalized: "unrelated", sentenceId: 2, tokenIndex: 2, annotations: TokenLinguisticAnnotations(script: .latin, lemma: "unrelated", lexicalClass: .adjective)),
                    TokenizedToken(original: "paragraph", normalized: "paragraph", sentenceId: 2, tokenIndex: 3, annotations: TokenLinguisticAnnotations(script: .latin, lemma: "paragraph", lexicalClass: .noun)),
                    TokenizedToken(original: "about", normalized: "about", sentenceId: 2, tokenIndex: 4, annotations: TokenLinguisticAnnotations(script: .latin, lemma: "about", lexicalClass: .other)),
                    TokenizedToken(original: "coffee", normalized: "coffee", sentenceId: 2, tokenIndex: 5, annotations: TokenLinguisticAnnotations(script: .latin, lemma: "coffee", lexicalClass: .noun)),
                    TokenizedToken(original: "and", normalized: "and", sentenceId: 2, tokenIndex: 6, annotations: TokenLinguisticAnnotations(script: .latin, lemma: "and", lexicalClass: .other)),
                    TokenizedToken(original: "weather", normalized: "weather", sentenceId: 2, tokenIndex: 7, annotations: TokenLinguisticAnnotations(script: .latin, lemma: "weather", lexicalClass: .noun))
                ]
            )
        ]
    )

    let topicsResult = TopicAnalysisResult(
        modelVersion: "wordz-topics-english-1",
        modelProvider: "system-sentence-embedding",
        usesFallbackProvider: false,
        clusters: [
            TopicClusterSummary(
                id: "topic-1",
                index: 1,
                isOutlier: false,
                size: 2,
                keywordCandidates: [
                    TopicKeywordCandidate(term: "security", score: 1.42),
                    TopicKeywordCandidate(term: "hacker", score: 1.17)
                ],
                representativeSegmentIDs: ["paragraph-1"]
            ),
            TopicClusterSummary(
                id: TopicAnalysisResult.outlierTopicID,
                index: 0,
                isOutlier: true,
                size: 1,
                keywordCandidates: [
                    TopicKeywordCandidate(term: "coffee", score: 0.75)
                ],
                representativeSegmentIDs: ["paragraph-3"]
            )
        ],
        segments: [
            TopicSegmentRow(
                id: "paragraph-1",
                topicID: "topic-1",
                paragraphIndex: 1,
                text: paragraphs[0],
                similarityScore: 0.91,
                isOutlier: false
            ),
            TopicSegmentRow(
                id: "paragraph-2",
                topicID: "topic-1",
                paragraphIndex: 2,
                text: paragraphs[1],
                similarityScore: 0.88,
                isOutlier: false
            ),
            TopicSegmentRow(
                id: "paragraph-3",
                topicID: TopicAnalysisResult.outlierTopicID,
                paragraphIndex: 3,
                text: paragraphs[2],
                similarityScore: 0,
                isOutlier: true
            )
        ],
        totalSegments: 3,
        clusteredSegments: 2,
        outlierCount: 1,
        warnings: []
    )

    return (openedCorpus, tokenizeResult, topicsResult)
}

func makeTopicsSentimentResult(
    corpusID: String,
    sourceTitle: String,
    documentText: String
) -> SentimentRunResult {
    let sentences = documentText.components(separatedBy: "\n\n")
    let request = SentimentRunRequest(
        source: .topicSegments,
        unit: .sourceSentence,
        contextBasis: .fullSentenceWhenAvailable,
        thresholds: .default,
        texts: [
            SentimentInputText(
                id: "paragraph-1::sentence::0",
                sourceID: corpusID,
                sourceTitle: sourceTitle,
                text: sentences[0],
                sentenceID: 0,
                tokenIndex: 0,
                groupID: "topic-1",
                groupTitle: "Topic 1",
                documentText: documentText
            ),
            SentimentInputText(
                id: "paragraph-2::sentence::1",
                sourceID: corpusID,
                sourceTitle: sourceTitle,
                text: sentences[1],
                sentenceID: 1,
                tokenIndex: 0,
                groupID: "topic-1",
                groupTitle: "Topic 1",
                documentText: documentText
            ),
            SentimentInputText(
                id: "paragraph-3::sentence::2",
                sourceID: corpusID,
                sourceTitle: sourceTitle,
                text: sentences[2],
                sentenceID: 2,
                tokenIndex: 0,
                groupID: TopicAnalysisResult.outlierTopicID,
                groupTitle: "Outlier Topic",
                documentText: documentText
            )
        ],
        backend: .lexicon
    )

    let rows = [
        SentimentRowResult(
            id: "paragraph-1::sentence::0",
            sourceID: corpusID,
            sourceTitle: sourceTitle,
            groupID: "topic-1",
            groupTitle: "Topic 1",
            text: sentences[0],
            positivityScore: 0.68,
            negativityScore: 0.12,
            neutralityScore: 0.20,
            finalLabel: .positive,
            netScore: 0.56,
            evidence: [
                SentimentEvidenceHit(
                    id: "topic-hit-1",
                    surface: "Security",
                    lemma: "security",
                    baseScore: 0.9,
                    adjustedScore: 0.9,
                    ruleTags: ["lexicon"],
                    tokenIndex: 0,
                    tokenLength: 1
                )
            ],
            evidenceCount: 1,
            mixedEvidence: false,
            diagnostics: .empty,
            sentenceID: 0,
            tokenIndex: 0
        ),
        SentimentRowResult(
            id: "paragraph-2::sentence::1",
            sourceID: corpusID,
            sourceTitle: sourceTitle,
            groupID: "topic-1",
            groupTitle: "Topic 1",
            text: sentences[1],
            positivityScore: 0.15,
            negativityScore: 0.62,
            neutralityScore: 0.23,
            finalLabel: .negative,
            netScore: -0.47,
            evidence: [
                SentimentEvidenceHit(
                    id: "topic-hit-2",
                    surface: "exploit",
                    lemma: "exploit",
                    baseScore: -0.8,
                    adjustedScore: -0.8,
                    ruleTags: ["lexicon"],
                    tokenIndex: 2,
                    tokenLength: 1
                )
            ],
            evidenceCount: 1,
            mixedEvidence: false,
            diagnostics: .empty,
            sentenceID: 1,
            tokenIndex: 2
        ),
        SentimentRowResult(
            id: "paragraph-3::sentence::2",
            sourceID: corpusID,
            sourceTitle: sourceTitle,
            groupID: TopicAnalysisResult.outlierTopicID,
            groupTitle: "Outlier Topic",
            text: sentences[2],
            positivityScore: 0.12,
            negativityScore: 0.13,
            neutralityScore: 0.75,
            finalLabel: .neutral,
            netScore: -0.01,
            evidence: [],
            evidenceCount: 0,
            mixedEvidence: false,
            diagnostics: .empty,
            sentenceID: 2,
            tokenIndex: 0
        )
    ]

    return SentimentRunResult(
        request: request,
        backendKind: .lexicon,
        backendRevision: "lexicon-v1",
        resourceRevision: "resource-v1",
        supportsEvidenceHits: true,
        rows: rows,
        overallSummary: SentimentAggregateSummary(
            id: "overall",
            title: "Overall",
            totalTexts: 3,
            positiveCount: 1,
            neutralCount: 1,
            negativeCount: 1,
            positiveRatio: 1.0 / 3.0,
            neutralRatio: 1.0 / 3.0,
            negativeRatio: 1.0 / 3.0,
            averagePositivity: 0.316,
            averageNeutrality: 0.393,
            averageNegativity: 0.29,
            averageNetScore: 0.026
        ),
        groupSummaries: [
            SentimentAggregateSummary(
                id: "topic-1",
                title: "Topic 1",
                totalTexts: 2,
                positiveCount: 1,
                neutralCount: 0,
                negativeCount: 1,
                positiveRatio: 0.5,
                neutralRatio: 0,
                negativeRatio: 0.5,
                averagePositivity: 0.415,
                averageNeutrality: 0.215,
                averageNegativity: 0.37,
                averageNetScore: 0.045
            ),
            SentimentAggregateSummary(
                id: TopicAnalysisResult.outlierTopicID,
                title: "Outlier Topic",
                totalTexts: 1,
                positiveCount: 0,
                neutralCount: 1,
                negativeCount: 0,
                positiveRatio: 0,
                neutralRatio: 1,
                negativeRatio: 0,
                averagePositivity: 0.12,
                averageNeutrality: 0.75,
                averageNegativity: 0.13,
                averageNetScore: -0.01
            )
        ],
        lexiconVersion: "test-v1"
    )
}
