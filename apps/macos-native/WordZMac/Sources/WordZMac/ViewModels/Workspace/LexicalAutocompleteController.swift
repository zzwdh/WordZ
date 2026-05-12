import Foundation

@MainActor
final class LexicalAutocompleteController: ObservableObject {
    @Published private(set) var activeCorpusID: String?
    @Published private(set) var loadedCorpusID: String?
    @Published private(set) var revision = 0

    private let frequencyRepository: (any StoredFrequencyArtifactReadingRepository)?
    private let tokenizedRepository: (any StoredTokenizedArtifactReadingRepository)?
    private let tokenPositionRepository: (any StoredTokenPositionIndexReadingRepository)?
    private var activeScope: LexicalSuggestionScope = .none
    private var loadedScope: LexicalSuggestionScope = .none
    private var loadingScope: LexicalSuggestionScope?
    private var service = LexicalSuggestionService.empty
    private var loadTask: Task<Void, Never>?
    private var loadGeneration = 0
    private var collocateTask: Task<Void, Never>?
    private var collocateGeneration = 0
    private var collocateSuggestionsByKey: [CollocateCacheKey: [LexicalSuggestion]] = [:]
    private var inFlightCollocateKey: CollocateCacheKey?

    init(repository: AnyObject? = nil) {
        self.frequencyRepository = repository as? any StoredFrequencyArtifactReadingRepository
        self.tokenizedRepository = repository as? any StoredTokenizedArtifactReadingRepository
        self.tokenPositionRepository = repository as? any StoredTokenPositionIndexReadingRepository
    }

    func updateSelectedCorpusID(_ corpusID: String?) {
        updateSuggestionScope(.corpusID(corpusID))
    }

    func updateSelectedCorpusIDs(_ corpusIDs: [String]) {
        updateSuggestionScope(.corpora(corpusIDs))
    }

    func suggestions(
        for query: String,
        options: SearchOptionsState,
        stopwordFilter: StopwordFilterState = .default,
        scope: LexicalSuggestionScope? = nil,
        configuration: LexicalSuggestionConfiguration = .default,
        limit: Int = 8
    ) -> [LexicalSuggestion] {
        let resolvedConfiguration = configuration.limitingSuggestions(to: limit)
        let resolvedScope = scope ?? activeScope
        guard loadedScope == resolvedScope else {
            if loadingScope != resolvedScope {
                scheduleLoad(for: resolvedScope)
            }
            return []
        }
        let request = LexicalSuggestionRequest(
            query: query,
            options: options,
            stopwordFilter: stopwordFilter,
            scope: resolvedScope,
            configuration: resolvedConfiguration
        )
        let prefixSuggestions = service.prefixSuggestions(for: request)
        let cacheKey = CollocateCacheKey(request: request, loadedScope: loadedScope)
        let cachedCollocates = collocateSuggestionsByKey[cacheKey] ?? []
        scheduleCollocateSuggestionsIfNeeded(request: request, cacheKey: cacheKey)
        return service.combinedSuggestions(
            prefixSuggestions: prefixSuggestions,
            collocateSuggestions: cachedCollocates,
            configuration: resolvedConfiguration
        )
    }

    private func updateSuggestionScope(_ scope: LexicalSuggestionScope) {
        guard activeScope != scope else { return }
        activeScope = scope
        activeCorpusID = scope.primaryCorpusID
        scheduleLoad(for: scope)
    }

    private func scheduleLoad(for scope: LexicalSuggestionScope) {
        guard loadingScope != scope, loadedScope != scope else { return }
        loadGeneration += 1
        let generation = loadGeneration
        loadingScope = scope
        cancelCollocateTask()
        loadTask?.cancel()
        loadTask = nil
        collocateSuggestionsByKey.removeAll()

        let corpusIDs = scope.corpusIDs
        guard !corpusIDs.isEmpty, let frequencyRepository else {
            applyLoadedService(.empty, for: scope, generation: generation)
            return
        }

        service = .empty
        loadedCorpusID = nil
        loadedScope = .none
        revision += 1

        let tokenizedRepository = self.tokenizedRepository
        let tokenPositionRepository = self.tokenPositionRepository
        loadTask = Task { @MainActor [weak self] in
            var frequencyArtifacts: [LexicalSuggestionCorpusFrequencyArtifact] = []
            for corpusID in corpusIDs {
                guard !Task.isCancelled else { return }
                if let artifact = try? await frequencyRepository.loadStoredFrequencyArtifact(corpusId: corpusID) {
                    frequencyArtifacts.append(
                        LexicalSuggestionCorpusFrequencyArtifact(corpusID: corpusID, artifact: artifact)
                    )
                }
            }

            var collocateArtifact: LexicalSuggestionCollocateArtifact?
            if corpusIDs.count == 1,
               let corpusID = corpusIDs.first,
               let tokenizedRepository,
               let tokenPositionRepository,
               let tokenizedArtifact = try? await tokenizedRepository.loadStoredTokenizedArtifact(corpusId: corpusID),
               let positionIndex = try? await tokenPositionRepository.loadStoredTokenPositionIndex(corpusId: corpusID) {
                collocateArtifact = LexicalSuggestionCollocateArtifact(
                    corpusID: corpusID,
                    tokenizedArtifact: tokenizedArtifact,
                    positionIndex: positionIndex
                )
            }

            guard !Task.isCancelled else { return }
            let service = await Task.detached(priority: .userInitiated) {
                LexicalSuggestionService(
                    frequencyArtifacts: frequencyArtifacts,
                    collocateArtifact: collocateArtifact
                )
            }.value
            self?.applyLoadedService(service, for: scope, generation: generation)
        }
    }

    private func applyLoadedService(
        _ nextService: LexicalSuggestionService,
        for scope: LexicalSuggestionScope,
        generation: Int
    ) {
        guard generation == loadGeneration else { return }

        service = nextService
        loadedScope = scope
        loadingScope = nil
        loadedCorpusID = nextService.isEmpty ? nil : scope.primaryCorpusID
        collocateSuggestionsByKey.removeAll()
        inFlightCollocateKey = nil
        revision += 1
    }

    private func scheduleCollocateSuggestionsIfNeeded(
        request: LexicalSuggestionRequest,
        cacheKey: CollocateCacheKey
    ) {
        guard service.canSuggestCollocates(for: request) else {
            return
        }
        guard collocateSuggestionsByKey[cacheKey] == nil else {
            return
        }
        guard inFlightCollocateKey != cacheKey else {
            return
        }

        collocateGeneration += 1
        let generation = collocateGeneration
        inFlightCollocateKey = cacheKey
        let serviceSnapshot = service
        collocateTask?.cancel()
        collocateTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: request.configuration.collocateDebounceNanoseconds)
            guard !Task.isCancelled else { return }
            let suggestions = await Task.detached(priority: .userInitiated) {
                serviceSnapshot.collocateSuggestions(for: request)
            }.value
            guard !Task.isCancelled else { return }
            self?.applyCollocateSuggestions(
                suggestions,
                for: cacheKey,
                generation: generation
            )
        }
    }

    private func applyCollocateSuggestions(
        _ suggestions: [LexicalSuggestion],
        for cacheKey: CollocateCacheKey,
        generation: Int
    ) {
        guard generation == collocateGeneration else { return }
        collocateSuggestionsByKey[cacheKey] = suggestions
        inFlightCollocateKey = nil
        revision += 1
    }

    private func cancelCollocateTask() {
        collocateGeneration += 1
        collocateTask?.cancel()
        collocateTask = nil
        inFlightCollocateKey = nil
    }
}

private struct CollocateCacheKey: Hashable {
    let scopeIDs: [String]
    let query: String
    let words: Bool
    let caseSensitive: Bool
    let regex: Bool
    let matchMode: SearchMatchMode
    let stopwordEnabled: Bool
    let stopwordMode: StopwordFilterMode
    let stopwordListText: String
    let leftWindow: Int
    let rightWindow: Int
    let minFreq: Int
    let maxCount: Int

    init(request: LexicalSuggestionRequest, loadedScope: LexicalSuggestionScope) {
        self.scopeIDs = loadedScope.corpusIDs
        self.query = AnalysisTextNormalizationSupport.normalizeToken(request.query)
        self.words = request.options.words
        self.caseSensitive = request.options.caseSensitive
        self.regex = request.options.regex
        self.matchMode = request.options.matchMode
        self.stopwordEnabled = request.stopwordFilter.enabled
        self.stopwordMode = request.stopwordFilter.mode
        self.stopwordListText = StopwordFilterState.normalizeListText(request.stopwordFilter.listText)
        self.leftWindow = request.configuration.collocateLeftWindow
        self.rightWindow = request.configuration.collocateRightWindow
        self.minFreq = request.configuration.collocateMinFrequency
        self.maxCount = request.configuration.maxCollocateSuggestions
    }
}
