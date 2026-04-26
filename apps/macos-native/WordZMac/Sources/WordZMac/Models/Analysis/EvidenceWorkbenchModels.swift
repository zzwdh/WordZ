import Foundation

enum EvidenceSourceKind: String, CaseIterable, Identifiable, Codable, Sendable, Equatable {
    case kwic
    case locator
    case plot
    case sentiment
    case topics

    var id: String { rawValue }

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .kwic:
            return wordZText("KWIC", "KWIC", mode: mode)
        case .locator:
            return wordZText("定位器", "Locator", mode: mode)
        case .plot:
            return "Plot"
        case .sentiment:
            return wordZText("情感", "Sentiment", mode: mode)
        case .topics:
            return wordZText("主题", "Topics", mode: mode)
        }
    }
}

enum EvidenceReviewStatus: String, CaseIterable, Identifiable, Codable, Sendable, Equatable {
    case pending
    case keep
    case exclude

    var id: String { rawValue }

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .pending:
            return wordZText("待审", "Pending", mode: mode)
        case .keep:
            return wordZText("保留", "Keep", mode: mode)
        case .exclude:
            return wordZText("排除", "Exclude", mode: mode)
        }
    }
}

enum EvidenceReviewFilter: String, CaseIterable, Identifiable, Hashable {
    case all
    case pending
    case keep
    case exclude

    var id: String { rawValue }

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .all:
            return wordZText("全部", "All", mode: mode)
        case .pending:
            return wordZText("待审", "Pending", mode: mode)
        case .keep:
            return wordZText("保留", "Keep", mode: mode)
        case .exclude:
            return wordZText("排除", "Exclude", mode: mode)
        }
    }

    func includes(_ status: EvidenceReviewStatus) -> Bool {
        switch self {
        case .all:
            return true
        case .pending:
            return status == .pending
        case .keep:
            return status == .keep
        case .exclude:
            return status == .exclude
        }
    }
}

enum EvidenceCrossAnalysisOriginKind: String, CaseIterable, Codable, Sendable, Equatable {
    case sentimentDirect
    case compareSentiment
    case topicsSentiment

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .sentimentDirect:
            return wordZText("情感分析", "Sentiment", mode: mode)
        case .compareSentiment:
            return wordZText("Compare x Sentiment", "Compare x Sentiment", mode: mode)
        case .topicsSentiment:
            return wordZText("Topics x Sentiment", "Topics x Sentiment", mode: mode)
        }
    }
}

struct EvidenceSentimentMetadata: Codable, Equatable, Sendable {
    let source: SentimentInputSource
    let unit: SentimentAnalysisUnit
    let contextBasis: SentimentContextBasis
    let backendKind: SentimentBackendKind
    let backendRevision: String
    let resourceRevision: String
    let providerID: String?
    let providerFamily: SentimentModelProviderFamily?
    let domainPackID: SentimentDomainPackID
    let ruleProfileID: String
    let calibrationProfileRevision: String
    let activePackIDs: [SentimentDomainPackID]
    let rawLabel: SentimentLabel
    let rawScores: SentimentScoreTriple
    let effectiveLabel: SentimentLabel
    let effectiveScores: SentimentScoreTriple
    let reviewDecision: SentimentReviewDecision?
    let reviewStatus: SentimentReviewStatus
    let reviewNote: String?
    let reviewSampleID: String?
    let reviewedAt: String?
    let rowID: String
    let sourceID: String?
    let sentenceID: Int?
    let tokenIndex: Int?
    let ruleSummary: String?
    let topRuleTraceSteps: [SentimentRuleTraceStep]
    let inferencePath: SentimentInferencePath?
    let modelInputKind: SentimentModelInputSchemaKind?
}

struct EvidenceCrossAnalysisMetadata: Codable, Equatable, Sendable {
    let originKind: EvidenceCrossAnalysisOriginKind
    let scopeSummary: String
    let focusTerm: String?
    let focusedTopicID: String?
    let groupTitle: String?
    let compareSide: String?
    let topicTitle: String?
}

enum EvidenceCitationFormat: String, CaseIterable, Identifiable, Codable, Sendable, Hashable {
    case citationLine
    case fullSentence
    case concordance

    var id: String { rawValue }

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .citationLine:
            return wordZText("引文行", "Citation Line", mode: mode)
        case .fullSentence:
            return wordZText("完整句", "Full Sentence", mode: mode)
        case .concordance:
            return wordZText("索引行", "Concordance", mode: mode)
        }
    }

    func summary(in mode: AppLanguageMode) -> String {
        switch self {
        case .citationLine:
            return wordZText(
                "导出捕获时生成的句号 / 来源引文。",
                "Exports the sentence/source citation captured with the item.",
                mode: mode
            )
        case .fullSentence:
            return wordZText(
                "导出不带 KWIC 截断的完整句文本。",
                "Exports the full sentence without KWIC truncation.",
                mode: mode
            )
        case .concordance:
            return wordZText(
                "导出左文、关键词、右文组成的索引行。",
                "Exports the left context, keyword, and right context as a concordance line.",
                mode: mode
            )
        }
    }
}

enum EvidenceCitationStyle: String, CaseIterable, Identifiable, Codable, Sendable, Hashable {
    case plain
    case mla
    case apa

    var id: String { rawValue }

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .plain:
            return wordZText("纯文本", "Plain", mode: mode)
        case .mla:
            return wordZText("MLA-like", "MLA-like", mode: mode)
        case .apa:
            return wordZText("APA-like", "APA-like", mode: mode)
        }
    }

    func summary(in mode: AppLanguageMode) -> String {
        switch self {
        case .plain:
            return wordZText(
                "只导出所选引文内容。",
                "Exports only the selected citation content.",
                mode: mode
            )
        case .mla:
            return wordZText(
                "按 MLA 风格组织语料标题、来源、年份和句号；缺失字段会自动省略。",
                "Arranges corpus title, source, year, and sentence number in an MLA-like template; missing fields are omitted.",
                mode: mode
            )
        case .apa:
            return wordZText(
                "按 APA 风格组织语料标题、年份和句号；缺失年份使用 n.d.",
                "Arranges corpus title, year, and sentence number in an APA-like template; missing years use n.d.",
                mode: mode
            )
        }
    }
}

struct EvidenceItem: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let sourceKind: EvidenceSourceKind
    let savedSetID: String?
    let savedSetName: String?
    let corpusID: String
    let corpusName: String
    let corpusMetadata: CorpusMetadataProfile?
    let sentenceId: Int
    let sentenceTokenIndex: Int?
    let leftContext: String
    let keyword: String
    let rightContext: String
    let fullSentenceText: String
    let citationText: String
    var citationFormat: EvidenceCitationFormat
    var citationStyle: EvidenceCitationStyle
    let query: String
    let leftWindow: Int
    let rightWindow: Int
    let searchOptionsSnapshot: SearchOptionsState?
    let stopwordFilterSnapshot: StopwordFilterState?
    var reviewStatus: EvidenceReviewStatus
    var sectionTitle: String?
    var claim: String?
    var tags: [String]
    var note: String?
    var sentimentMetadata: EvidenceSentimentMetadata?
    var crossAnalysisMetadata: EvidenceCrossAnalysisMetadata?
    let createdAt: String
    var updatedAt: String

    init(
        id: String,
        sourceKind: EvidenceSourceKind,
        savedSetID: String?,
        savedSetName: String?,
        corpusID: String,
        corpusName: String,
        corpusMetadata: CorpusMetadataProfile? = nil,
        sentenceId: Int,
        sentenceTokenIndex: Int?,
        leftContext: String,
        keyword: String,
        rightContext: String,
        fullSentenceText: String,
        citationText: String,
        citationFormat: EvidenceCitationFormat = .citationLine,
        citationStyle: EvidenceCitationStyle = .plain,
        query: String,
        leftWindow: Int,
        rightWindow: Int,
        searchOptionsSnapshot: SearchOptionsState?,
        stopwordFilterSnapshot: StopwordFilterState?,
        reviewStatus: EvidenceReviewStatus,
        sectionTitle: String? = nil,
        claim: String? = nil,
        tags: [String] = [],
        note: String? = nil,
        sentimentMetadata: EvidenceSentimentMetadata? = nil,
        crossAnalysisMetadata: EvidenceCrossAnalysisMetadata? = nil,
        createdAt: String,
        updatedAt: String
    ) {
        self.id = id
        self.sourceKind = sourceKind
        self.savedSetID = savedSetID
        self.savedSetName = savedSetName
        self.corpusID = corpusID
        self.corpusName = corpusName
        self.corpusMetadata = corpusMetadata
        self.sentenceId = sentenceId
        self.sentenceTokenIndex = sentenceTokenIndex
        self.leftContext = leftContext
        self.keyword = keyword
        self.rightContext = rightContext
        self.fullSentenceText = fullSentenceText
        self.citationText = citationText
        self.citationFormat = citationFormat
        self.citationStyle = citationStyle
        self.query = query
        self.leftWindow = leftWindow
        self.rightWindow = rightWindow
        self.searchOptionsSnapshot = searchOptionsSnapshot
        self.stopwordFilterSnapshot = stopwordFilterSnapshot
        self.reviewStatus = reviewStatus
        self.sectionTitle = sectionTitle
        self.claim = claim
        self.tags = tags
        self.note = note
        self.sentimentMetadata = sentimentMetadata
        self.crossAnalysisMetadata = crossAnalysisMetadata
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var concordanceText: String {
        [leftContext, keyword, rightContext]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    var formattedCitationText: String {
        citationBody(format: citationFormat)
    }

    var styledCitationText: String {
        styledCitationText(format: citationFormat, style: citationStyle)
    }

    func styledCitationText(
        format: EvidenceCitationFormat,
        style: EvidenceCitationStyle
    ) -> String {
        let body = citationBody(format: format)
        switch style {
        case .plain:
            return body
        case .mla:
            var sourceParts = [corpusName]
            if let sourceLabel = normalizedValue(corpusMetadata?.sourceLabel) {
                sourceParts.append(sourceLabel)
            }
            if let yearLabel = normalizedValue(corpusMetadata?.yearLabel) {
                sourceParts.append(yearLabel)
            }
            sourceParts.append(sentenceReference)
            sourceParts.append("WordZ evidence export")
            return quoted(body) + ". " + sourceParts.joined(separator: ", ") + "."
        case .apa:
            let yearLabel = normalizedValue(corpusMetadata?.yearLabel) ?? "n.d."
            var bracketParts = [sentenceReference]
            if let sourceLabel = normalizedValue(corpusMetadata?.sourceLabel) {
                bracketParts.append(sourceLabel)
            }
            return "\(corpusName). (\(yearLabel)). \(body) [" + bracketParts.joined(separator: ", ") + "]. WordZ evidence export."
        }
    }

    private func citationBody(format: EvidenceCitationFormat) -> String {
        switch format {
        case .citationLine:
            return citationText
        case .fullSentence:
            return fullSentenceText
        case .concordance:
            return concordanceText
        }
    }

    private var sentenceReference: String {
        "Sentence \(sentenceId + 1)"
    }

    private func quoted(_ value: String) -> String {
        "\"" + value.replacingOccurrences(of: "\"", with: "'") + "\""
    }

    var tagSummaryText: String {
        tags.joined(separator: ", ")
    }

    var hasSavedSetProvenance: Bool {
        !(savedSetID?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }

    func parameterSummary(in mode: AppLanguageMode) -> String {
        var parts: [String] = []
        if let query = normalizedValue(query) {
            parts.append(wordZText("查询", "Query", mode: mode) + ": " + query)
        }
        if leftWindow > 0 || rightWindow > 0 {
            parts.append("L\(leftWindow) / R\(rightWindow)")
        }
        if let searchOptionsSnapshot {
            parts.append(searchOptionsSnapshot.summaryText)
        }
        if let stopwordFilterSnapshot {
            parts.append(stopwordFilterSnapshot.summaryText)
        }
        if parts.isEmpty {
            return wordZText("无额外参数", "No extra parameters", mode: mode)
        }
        return parts.joined(separator: " · ")
    }

    func dossierSummary(in mode: AppLanguageMode) -> String {
        var parts: [String] = []
        if let claim = normalizedValue(claim) {
            parts.append(wordZText("论点", "Claim", mode: mode) + ": " + claim)
        }
        if !tags.isEmpty {
            parts.append(wordZText("标签", "Tags", mode: mode) + ": " + tagSummaryText)
        }
        if let sectionTitle = normalizedValue(sectionTitle) {
            parts.append(wordZText("章节", "Section", mode: mode) + ": " + sectionTitle)
        }
        if citationFormat != .citationLine {
            parts.append(wordZText("引文格式", "Citation Format", mode: mode) + ": " + citationFormat.title(in: mode))
        }
        if citationStyle != .plain {
            parts.append(wordZText("引用样式", "Citation Style", mode: mode) + ": " + citationStyle.title(in: mode))
        }
        return parts.joined(separator: " · ")
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case sourceKind
        case savedSetID
        case savedSetName
        case corpusID
        case corpusName
        case corpusMetadata
        case sentenceId
        case sentenceTokenIndex
        case leftContext
        case keyword
        case rightContext
        case fullSentenceText
        case citationText
        case citationFormat
        case citationStyle
        case query
        case leftWindow
        case rightWindow
        case searchOptionsSnapshot
        case stopwordFilterSnapshot
        case reviewStatus
        case sectionTitle
        case claim
        case tags
        case note
        case sentimentMetadata
        case crossAnalysisMetadata
        case createdAt
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        sourceKind = try container.decode(EvidenceSourceKind.self, forKey: .sourceKind)
        savedSetID = try container.decodeIfPresent(String.self, forKey: .savedSetID)
        savedSetName = try container.decodeIfPresent(String.self, forKey: .savedSetName)
        corpusID = try container.decode(String.self, forKey: .corpusID)
        corpusName = try container.decode(String.self, forKey: .corpusName)
        corpusMetadata = try container.decodeIfPresent(CorpusMetadataProfile.self, forKey: .corpusMetadata)
        sentenceId = try container.decode(Int.self, forKey: .sentenceId)
        sentenceTokenIndex = try container.decodeIfPresent(Int.self, forKey: .sentenceTokenIndex)
        leftContext = try container.decode(String.self, forKey: .leftContext)
        keyword = try container.decode(String.self, forKey: .keyword)
        rightContext = try container.decode(String.self, forKey: .rightContext)
        fullSentenceText = try container.decode(String.self, forKey: .fullSentenceText)
        citationText = try container.decode(String.self, forKey: .citationText)
        citationFormat = try container.decodeIfPresent(EvidenceCitationFormat.self, forKey: .citationFormat) ?? .citationLine
        citationStyle = try container.decodeIfPresent(EvidenceCitationStyle.self, forKey: .citationStyle) ?? .plain
        query = try container.decode(String.self, forKey: .query)
        leftWindow = try container.decode(Int.self, forKey: .leftWindow)
        rightWindow = try container.decode(Int.self, forKey: .rightWindow)
        searchOptionsSnapshot = try container.decodeIfPresent(SearchOptionsState.self, forKey: .searchOptionsSnapshot)
        stopwordFilterSnapshot = try container.decodeIfPresent(StopwordFilterState.self, forKey: .stopwordFilterSnapshot)
        reviewStatus = try container.decode(EvidenceReviewStatus.self, forKey: .reviewStatus)
        sectionTitle = try container.decodeIfPresent(String.self, forKey: .sectionTitle)
        claim = try container.decodeIfPresent(String.self, forKey: .claim)
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        note = try container.decodeIfPresent(String.self, forKey: .note)
        sentimentMetadata = try container.decodeIfPresent(EvidenceSentimentMetadata.self, forKey: .sentimentMetadata)
        crossAnalysisMetadata = try container.decodeIfPresent(EvidenceCrossAnalysisMetadata.self, forKey: .crossAnalysisMetadata)
        createdAt = try container.decode(String.self, forKey: .createdAt)
        updatedAt = try container.decode(String.self, forKey: .updatedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(sourceKind, forKey: .sourceKind)
        try container.encodeIfPresent(savedSetID, forKey: .savedSetID)
        try container.encodeIfPresent(savedSetName, forKey: .savedSetName)
        try container.encode(corpusID, forKey: .corpusID)
        try container.encode(corpusName, forKey: .corpusName)
        try container.encodeIfPresent(corpusMetadata, forKey: .corpusMetadata)
        try container.encode(sentenceId, forKey: .sentenceId)
        try container.encodeIfPresent(sentenceTokenIndex, forKey: .sentenceTokenIndex)
        try container.encode(leftContext, forKey: .leftContext)
        try container.encode(keyword, forKey: .keyword)
        try container.encode(rightContext, forKey: .rightContext)
        try container.encode(fullSentenceText, forKey: .fullSentenceText)
        try container.encode(citationText, forKey: .citationText)
        try container.encode(citationFormat, forKey: .citationFormat)
        try container.encode(citationStyle, forKey: .citationStyle)
        try container.encode(query, forKey: .query)
        try container.encode(leftWindow, forKey: .leftWindow)
        try container.encode(rightWindow, forKey: .rightWindow)
        try container.encodeIfPresent(searchOptionsSnapshot, forKey: .searchOptionsSnapshot)
        try container.encodeIfPresent(stopwordFilterSnapshot, forKey: .stopwordFilterSnapshot)
        try container.encode(reviewStatus, forKey: .reviewStatus)
        try container.encodeIfPresent(sectionTitle, forKey: .sectionTitle)
        try container.encodeIfPresent(claim, forKey: .claim)
        try container.encode(tags, forKey: .tags)
        try container.encodeIfPresent(note, forKey: .note)
        try container.encodeIfPresent(sentimentMetadata, forKey: .sentimentMetadata)
        try container.encodeIfPresent(crossAnalysisMetadata, forKey: .crossAnalysisMetadata)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }

    private func normalizedValue(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

struct EvidenceTransferBundle: Codable, Equatable, Sendable {
    let version: Int
    let exportedAt: String
    let items: [EvidenceItem]
}

enum EvidenceTransferSupport {
    enum TransferError: LocalizedError {
        case emptySelection

        var errorDescription: String? {
            switch self {
            case .emptySelection:
                return wordZText("没有可导出的证据条目。", "There are no evidence items to export.", mode: .system)
            }
        }
    }

    static func makeBundle(
        items: [EvidenceItem],
        exportedAt: Date = Date()
    ) throws -> EvidenceTransferBundle {
        guard !items.isEmpty else {
            throw TransferError.emptySelection
        }
        return EvidenceTransferBundle(
            version: 1,
            exportedAt: ISO8601DateFormatter().string(from: exportedAt),
            items: items
        )
    }

    static func exportData(
        items: [EvidenceItem],
        exportedAt: Date = Date()
    ) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(makeBundle(items: items, exportedAt: exportedAt))
    }
}

enum EvidenceMarkdownPacketSupport {
    static func document(
        items: [EvidenceItem],
        grouping: EvidenceWorkbenchGroupingMode = .section,
        exportedAt: Date = Date()
    ) throws -> PlainTextExportDocument {
        try EvidenceMarkdownDossierSupport.document(
            items: items,
            grouping: grouping,
            exportedAt: exportedAt
        )
    }
}
