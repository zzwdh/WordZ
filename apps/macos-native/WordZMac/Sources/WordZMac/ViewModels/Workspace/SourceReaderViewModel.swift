import Foundation

@MainActor
final class SourceReaderViewModel: ObservableObject {
    @Published private(set) var scene: SourceReaderSceneModel?
    @Published private(set) var launchContext: SourceReaderLaunchContext?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published var captureSectionTitle = ""
    @Published var captureClaim = ""
    @Published var captureTagsText = ""
    @Published var captureCitationFormat: EvidenceCitationFormat = .citationLine
    @Published var captureCitationStyle: EvidenceCitationStyle = .plain
    @Published var captureNote = ""

    private var tokenizedSentences: [TokenizedSentence] = []
    private var selectedHitID: String?
    private var annotationState = WorkspaceAnnotationState.default

    var canAddEvidence: Bool {
        guard let origin = launchContext?.origin else { return false }
        return origin == .kwic || origin == .locator || origin == .plot || origin == .sentiment || origin == .topics
    }

    var canSelectPreviousHit: Bool {
        guard let selectedHitID,
              let hitItems = scene?.hitItems,
              let index = hitItems.firstIndex(where: { $0.id == selectedHitID })
        else { return false }
        return index > 0
    }

    var canSelectNextHit: Bool {
        guard let selectedHitID,
              let hitItems = scene?.hitItems,
              let index = hitItems.firstIndex(where: { $0.id == selectedHitID })
        else { return false }
        return index < hitItems.count - 1
    }

    var currentFilePath: String? {
        normalizedValue(launchContext?.filePath)
    }

    var currentCitationText: String? {
        scene?.selection?.hit.citationText
    }

    var currentReadingExportDocument: PlainTextExportDocument? {
        guard let context = launchContext,
              let selection = scene?.selection
        else { return nil }

        var metadataLines = [
            "Source Reader",
            "Origin: \(context.origin.title(in: .system))",
            "Corpus: \(context.corpusName)"
        ]

        if let filePath = normalizedValue(context.filePath) {
            metadataLines.append("Source File: \(filePath)")
        }
        if let query = normalizedValue(context.query) {
            metadataLines.append("Query: \(query)")
        }
        if let searchOptionsSummary = normalizedValue(context.searchOptionsSummary) {
            metadataLines.append("Search: \(searchOptionsSummary)")
        }
        metadataLines.append("Annotation: \(annotationState.summary(in: .system))")

        let text = [
            metadataLines.joined(separator: "\n"),
            selection.hit.citationText,
            "Full Sentence\n\(selection.hit.fullSentenceText)"
        ]
        .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        .joined(separator: "\n\n")

        return PlainTextExportDocument(
            suggestedName: "source-reader-current.txt",
            text: text
        )
    }

    var currentEvidenceCaptureDraft: EvidenceCaptureDraft {
        EvidenceCaptureDraft(
            sectionTitle: captureSectionTitle,
            claim: captureClaim,
            tagsText: captureTagsText,
            citationFormat: captureCitationFormat,
            citationStyle: captureCitationStyle,
            note: captureNote
        )
    }

    var captureDraftSummary: String? {
        let summary = currentEvidenceCaptureDraft.summary(in: WordZLocalization.shared.effectiveMode)
        return summary.isEmpty ? nil : summary
    }

    func load(
        context: SourceReaderLaunchContext,
        repository: any WorkspaceRepository
    ) async throws {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        launchContext = context
        tokenizedSentences = try await resolvedTokenizedSentences(
            for: context,
            repository: repository
        )
        selectedHitID = context.selectedHitID ?? context.hitAnchors.first?.id
        rebuildScene()

        if scene == nil {
            throw NSError(
                domain: "WordZMac.SourceReaderViewModel",
                code: 2,
                userInfo: [
                    NSLocalizedDescriptionKey: wordZText(
                        "当前没有可阅读的原文上下文。",
                        "There is no readable source context available right now.",
                        mode: .system
                    )
                ]
            )
        }
    }

    func selectHit(_ hitID: String?) {
        guard let context = launchContext else { return }
        let availableIDs = Set(context.hitAnchors.map(\.id))
        guard let hitID else {
            selectedHitID = context.hitAnchors.first?.id
            rebuildScene()
            return
        }
        guard availableIDs.contains(hitID) else { return }
        selectedHitID = hitID
        rebuildScene()
    }

    func selectAdjacentHit(offset: Int) {
        guard let hitItems = scene?.hitItems, !hitItems.isEmpty else { return }
        guard let selectedHitID,
              let index = hitItems.firstIndex(where: { $0.id == selectedHitID })
        else {
            selectHit(hitItems.first?.id)
            return
        }
        let nextIndex = min(max(index + offset, 0), hitItems.count - 1)
        selectHit(hitItems[nextIndex].id)
    }

    func applyAnnotationState(_ annotationState: WorkspaceAnnotationState) {
        guard self.annotationState != annotationState else { return }
        self.annotationState = annotationState
        if launchContext != nil {
            rebuildScene()
        }
    }

    private func resolvedTokenizedSentences(
        for context: SourceReaderLaunchContext,
        repository: any WorkspaceRepository
    ) async throws -> [TokenizedSentence] {
        if let corpusID = normalizedValue(context.corpusID),
           let artifactRepository = repository as? any StoredTokenizedArtifactReadingRepository {
            do {
                if let storedArtifact = try await artifactRepository.loadStoredTokenizedArtifact(corpusId: corpusID) {
                    return storedArtifact.sentences
                }
            } catch {
                // Fall back to live tokenization so Source Reader stays available
                // even when the saved shard artifact cannot be reused.
            }
        }

        let documentText = try resolvedDocumentText(for: context)
        let tokenized = try await repository.runTokenize(text: documentText)
        return tokenized.sentences
    }

    private func rebuildScene() {
        guard let context = launchContext else {
            scene = nil
            return
        }

        let sentencesByID = Dictionary(uniqueKeysWithValues: tokenizedSentences.map { ($0.sentenceId, $0) })
        let effectiveSelectedHitID = context.hitAnchors.contains(where: { $0.id == selectedHitID })
            ? selectedHitID
            : context.hitAnchors.first?.id
        let selectedAnchor = context.hitAnchors.first(where: { $0.id == effectiveSelectedHitID })

        let hitItems = context.hitAnchors.map { anchor in
            makeHitSceneItem(anchor: anchor, context: context, sentence: sentencesByID[anchor.sentenceId])
        }

        let selection = selectedAnchor.flatMap { anchor -> SourceReaderSelection? in
            let sentence = sentencesByID[anchor.sentenceId]
            let resolved = resolveConcordance(anchor: anchor, context: context, sentence: sentence)
            let hit = makeHitSceneItem(anchor: anchor, context: context, sentence: sentence)
            let annotationItems = buildAnnotationItems(anchor: anchor, sentence: sentence, languageMode: WordZLocalization.shared.effectiveMode)
            return SourceReaderSelection(
                hit: hit,
                leftContext: resolved.leftContext,
                keyword: resolved.keyword,
                rightContext: resolved.rightContext,
                annotationItems: annotationItems
            )
        }

        let selectedSentenceID = selectedAnchor?.sentenceId
        let hitSentenceIDs = Set(context.hitAnchors.map(\.sentenceId))
        let sentences = tokenizedSentences.map { sentence in
            SourceReaderSentenceSceneItem(
                id: sentence.id,
                sentenceId: sentence.sentenceId,
                sentenceLabel: "\(sentence.sentenceId + 1)",
                text: sentence.text,
                containsHit: hitSentenceIDs.contains(sentence.sentenceId),
                isSelected: sentence.sentenceId == selectedSentenceID
            )
        }

        let languageMode = WordZLocalization.shared.effectiveMode
        let resolvedTitle = normalizedValue(context.displayName)
            ?? normalizedValue((context.filePath as NSString).lastPathComponent)
            ?? context.corpusName
        let subtitleParts = [
            normalizedValue(context.corpusName),
            normalizedValue(context.filePath)
        ].compactMap { $0 }
        let originParts = [
            context.origin.title(in: languageMode),
            normalizedValue(context.query).map { "\(wordZText("查询", "Query", mode: languageMode)): \($0)" },
            {
                guard let leftWindow = context.leftWindow, let rightWindow = context.rightWindow else { return nil }
                return "L\(leftWindow) / R\(rightWindow)"
            }(),
            normalizedValue(context.searchOptionsSummary)
        ].compactMap { $0 }

        scene = SourceReaderSceneModel(
            title: resolvedTitle,
            subtitle: subtitleParts.joined(separator: " · "),
            filePath: context.filePath,
            originSummary: originParts.joined(separator: " · "),
            annotationSummary: annotationState.summary(in: languageMode),
            hitCountSummary: String(
                format: wordZText("共 %d 条命中", "%d hits", mode: languageMode),
                hitItems.count
            ),
            sourceChainItems: SourceReaderSourceChainBuilder.build(
                context: context,
                selectedAnchor: selectedAnchor,
                selection: selection,
                hitCount: hitItems.count,
                mode: languageMode
            ),
            hitItems: hitItems,
            selectedHitID: effectiveSelectedHitID,
            sentences: sentences,
            selection: selection
        )
    }

    private func buildAnnotationItems(
        anchor: SourceReaderHitAnchor,
        sentence: TokenizedSentence?,
        languageMode: AppLanguageMode
    ) -> [SourceReaderAnnotationSceneItem] {
        guard let sentence,
              let tokenIndex = anchor.tokenIndex,
              !sentence.tokens.isEmpty
        else {
            return []
        }

        let safeIndex = min(max(tokenIndex, 0), sentence.tokens.count - 1)
        let token = sentence.tokens[safeIndex]

        return [
            SourceReaderAnnotationSceneItem(
                id: "lemma",
                title: wordZText("Lemma", "Lemma", mode: languageMode),
                value: normalizedValue(token.annotations.lemma) ?? "—"
            ),
            SourceReaderAnnotationSceneItem(
                id: "lexical-class",
                title: wordZText("词类", "Lexical Class", mode: languageMode),
                value: token.annotations.lexicalClass?.title(in: languageMode)
                    ?? wordZText("未标注", "Unlabeled", mode: languageMode)
            ),
            SourceReaderAnnotationSceneItem(
                id: "script",
                title: wordZText("脚本", "Script", mode: languageMode),
                value: token.annotations.script.title(in: languageMode)
            )
        ]
    }

    private func makeHitSceneItem(
        anchor: SourceReaderHitAnchor,
        context: SourceReaderLaunchContext,
        sentence: TokenizedSentence?
    ) -> SourceReaderHitSceneItem {
        let resolved = resolveConcordance(anchor: anchor, context: context, sentence: sentence)
        return SourceReaderHitSceneItem(
            id: anchor.id,
            sentenceId: anchor.sentenceId,
            sentenceLabel: "\(anchor.sentenceId + 1)",
            keyword: resolved.keyword,
            concordanceText: resolved.concordanceText,
            citationText: resolved.citationText,
            fullSentenceText: resolved.fullSentenceText
        )
    }

    private func resolveConcordance(
        anchor: SourceReaderHitAnchor,
        context: SourceReaderLaunchContext,
        sentence: TokenizedSentence?
    ) -> (
        leftContext: String,
        keyword: String,
        rightContext: String,
        concordanceText: String,
        citationText: String,
        fullSentenceText: String
    ) {
        let fullSentenceText: String
        if context.origin == .topics {
            fullSentenceText = normalizedValue(anchor.fullSentenceText)
                ?? normalizedValue(sentence?.text)
                ?? ""
        } else {
            fullSentenceText = normalizedValue(sentence?.text)
                ?? normalizedValue(anchor.fullSentenceText)
                ?? ""
        }

        let computedContexts = computedContexts(
            for: anchor,
            context: context,
            sentence: sentence
        )
        let leftContext = normalizedValue(anchor.leftContext) ?? computedContexts.left
        let rightContext = normalizedValue(anchor.rightContext) ?? computedContexts.right
        let keyword = normalizedValue(anchor.keyword) ?? computedContexts.keyword
        let concordanceText = normalizedValue(anchor.concordanceText)
            ?? ConcordancePresentationSupport.annotatedLine(
                normalizedLeft: leftContext,
                normalizedKeyword: keyword,
                normalizedRight: rightContext
            )
        let citationText = normalizedValue(anchor.citationText)
            ?? ConcordancePresentationSupport.citationText(
                sentenceNumber: anchor.sentenceId + 1,
                normalizedKeyword: keyword,
                normalizedLeft: leftContext,
                normalizedRight: rightContext,
                normalizedFullText: fullSentenceText
            )

        return (
            leftContext,
            keyword,
            rightContext,
            concordanceText,
            citationText,
            fullSentenceText
        )
    }

    private func computedContexts(
        for anchor: SourceReaderHitAnchor,
        context: SourceReaderLaunchContext,
        sentence: TokenizedSentence?
    ) -> (left: String, keyword: String, right: String) {
        guard let sentence,
              let tokenIndex = anchor.tokenIndex,
              !sentence.tokens.isEmpty
        else {
            return ("", normalizedValue(anchor.keyword) ?? normalizedValue(context.query) ?? "", "")
        }

        let safeIndex = min(max(tokenIndex, 0), sentence.tokens.count - 1)
        let leftWindow = max(0, context.leftWindow ?? 5)
        let rightWindow = max(0, context.rightWindow ?? 5)

        let leftStart = max(0, safeIndex - leftWindow)
        let leftTokens = sentence.tokens[leftStart..<safeIndex].map(\.original)
        let rightEnd = min(sentence.tokens.count, safeIndex + rightWindow + 1)
        let rightTokens = sentence.tokens[(safeIndex + 1)..<rightEnd].map(\.original)
        let keyword = normalizedValue(anchor.keyword) ?? sentence.tokens[safeIndex].original

        return (
            ConcordancePresentationSupport.normalizedContext(leftTokens.joined(separator: " ")),
            ConcordancePresentationSupport.normalizedContext(keyword),
            ConcordancePresentationSupport.normalizedContext(rightTokens.joined(separator: " "))
        )
    }

    private func resolvedDocumentText(for context: SourceReaderLaunchContext) throws -> String {
        if let filePath = normalizedValue(context.filePath),
           FileManager.default.fileExists(atPath: filePath) {
            let url = URL(fileURLWithPath: filePath)

            if ImportedDocumentReadingSupport.canImport(url: url),
               let document = try? ImportedDocumentReadingSupport.readImportedDocument(at: url),
               let text = normalizedValue(document.text) {
                return text
            }

            if let text = try? String(contentsOf: url),
               let normalizedText = normalizedValue(text) {
                return normalizedText
            }
        }

        if let fallbackText = normalizedValue(context.fallbackText) {
            return fallbackText
        }

        throw NSError(
            domain: "WordZMac.SourceReaderViewModel",
            code: 1,
            userInfo: [
                NSLocalizedDescriptionKey: wordZText(
                    "无法读取原始文件内容。",
                    "Unable to read the source file content.",
                    mode: .system
                )
            ]
        )
    }

    private func normalizedValue(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
