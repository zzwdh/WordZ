import XCTest
@testable import WordZWorkspaceCore

@MainActor
final class LexicalAutocompleteTests: XCTestCase {
    func testLexicalAutocompleteControllerUsesCurrentCorpusFrequencyOrder() async {
        let repository = FakeWorkspaceRepository()
        repository.storedFrequencyArtifactsByCorpusID["corpus-1"] = makeFrequencyArtifact(rows: [
            FrequencyRow(word: "hesitant", count: 9, rank: 3),
            FrequencyRow(word: "hesitation", count: 18, rank: 2),
            FrequencyRow(word: "hesitancy", count: 18, rank: 4),
            FrequencyRow(word: "hero", count: 40, rank: 1),
            FrequencyRow(word: "hexagon", count: 7, rank: 5)
        ])

        let controller = LexicalAutocompleteController(repository: repository)
        controller.updateSelectedCorpusID("corpus-1")
        await waitForAutocompleteLoad(controller, corpusID: "corpus-1")

        let suggestions = controller.suggestions(for: "hesi", options: .default)
        XCTAssertEqual(suggestions.map(\.term), ["hesitancy", "hesitation", "hesitant"])
        XCTAssertEqual(suggestions.map(\.count), [18, 18, 9])
    }

    func testLexicalAutocompleteControllerSwitchesToNewCorpusAndDisablesAdvancedModes() async {
        let repository = FakeWorkspaceRepository()
        repository.storedFrequencyArtifactsByCorpusID["corpus-1"] = makeFrequencyArtifact(rows: [
            FrequencyRow(word: "hesitation", count: 12, rank: 1),
            FrequencyRow(word: "hesitate", count: 8, rank: 2)
        ])
        repository.storedFrequencyArtifactsByCorpusID["corpus-2"] = makeFrequencyArtifact(rows: [
            FrequencyRow(word: "history", count: 14, rank: 1),
            FrequencyRow(word: "historic", count: 11, rank: 2)
        ])

        let controller = LexicalAutocompleteController(repository: repository)
        controller.updateSelectedCorpusID("corpus-1")
        await waitForAutocompleteLoad(controller, corpusID: "corpus-1")
        XCTAssertEqual(
            controller.suggestions(for: "hesi", options: .default).map(\.term),
            ["hesitation", "hesitate"]
        )

        controller.updateSelectedCorpusID("corpus-2")
        await waitForAutocompleteLoad(controller, corpusID: "corpus-2")
        XCTAssertEqual(
            controller.suggestions(for: "hist", options: .default).map(\.term),
            ["history", "historic"]
        )
        XCTAssertTrue(
            controller.suggestions(
                for: "hist",
                options: SearchOptionsState(regex: true)
            ).isEmpty
        )
        XCTAssertTrue(
            controller.suggestions(
                for: "hist",
                options: SearchOptionsState(matchMode: .phraseExact)
            ).isEmpty
        )
    }

    func testLexicalAutocompleteControllerClearsForMissingCorpusArtifact() async {
        let repository = FakeWorkspaceRepository()
        repository.storedFrequencyArtifactsByCorpusID["corpus-1"] = makeFrequencyArtifact(rows: [
            FrequencyRow(word: "hesitation", count: 12, rank: 1)
        ])

        let controller = LexicalAutocompleteController(repository: repository)
        controller.updateSelectedCorpusID("corpus-1")
        await waitForAutocompleteLoad(controller, corpusID: "corpus-1")
        XCTAssertFalse(controller.suggestions(for: "hes", options: .default).isEmpty)

        controller.updateSelectedCorpusID("missing")
        await waitForAutocompleteRevision(controller, minimumRevision: 3)
        XCTAssertTrue(controller.suggestions(for: "hes", options: .default).isEmpty)

        controller.updateSelectedCorpusID(nil)
        await waitForAutocompleteRevision(controller, minimumRevision: 4)
        XCTAssertNil(controller.activeCorpusID)
        XCTAssertNil(controller.loadedCorpusID)
        XCTAssertTrue(controller.suggestions(for: "hes", options: .default).isEmpty)
    }

    func testLexicalAutocompleteControllerFiltersPrefixSuggestionsWithStopwords() async {
        let repository = FakeWorkspaceRepository()
        repository.storedFrequencyArtifactsByCorpusID["corpus-1"] = makeFrequencyArtifact(rows: [
            FrequencyRow(word: "alpha", count: 20, rank: 1),
            FrequencyRow(word: "alpine", count: 10, rank: 2)
        ])

        let controller = LexicalAutocompleteController(repository: repository)
        controller.updateSelectedCorpusID("corpus-1")
        await waitForAutocompleteLoad(controller, corpusID: "corpus-1")

        let suggestions = controller.suggestions(
            for: "al",
            options: .default,
            stopwordFilter: StopwordFilterState(enabled: true, listText: "alpha")
        )
        XCTAssertEqual(suggestions.map(\.term), ["alpine"])
    }

    func testLexicalAutocompleteControllerMergesMultiCorpusFrequencySuggestions() async {
        let repository = FakeWorkspaceRepository()
        repository.storedFrequencyArtifactsByCorpusID["corpus-1"] = makeFrequencyArtifact(rows: [
            FrequencyRow(word: "history", count: 7, rank: 2),
            FrequencyRow(word: "historic", count: 4, rank: 4)
        ])
        repository.storedFrequencyArtifactsByCorpusID["corpus-2"] = makeFrequencyArtifact(rows: [
            FrequencyRow(word: "history", count: 11, rank: 1),
            FrequencyRow(word: "histogram", count: 9, rank: 3)
        ])

        let controller = LexicalAutocompleteController(repository: repository)
        controller.updateSelectedCorpusIDs(["corpus-1", "corpus-2"])
        await waitForAutocompleteLoad(controller, corpusID: "corpus-1")

        let suggestions = controller.suggestions(for: "hist", options: .default)
        XCTAssertEqual(suggestions.map(\.term), ["history", "histogram", "historic"])
        XCTAssertEqual(suggestions.map(\.count), [18, 9, 4])
    }

    func testLexicalAutocompleteControllerAddsCollocateSuggestionsForExactTerm() async {
        let repository = FakeWorkspaceRepository()
        repository.storedFrequencyArtifactsByCorpusID["corpus-1"] = makeFrequencyArtifact(rows: [
            FrequencyRow(word: "alpha", count: 3, rank: 1),
            FrequencyRow(word: "beta", count: 4, rank: 2),
            FrequencyRow(word: "gamma", count: 1, rank: 3)
        ])
        repository.storedTokenizedArtifactsByCorpusID["corpus-1"] = makeTokenizedArtifact()
        repository.storedTokenPositionIndexesByCorpusID["corpus-1"] = makeTokenPositionIndex()

        let controller = LexicalAutocompleteController(repository: repository)
        controller.updateSelectedCorpusID("corpus-1")
        await waitForAutocompleteLoad(controller, corpusID: "corpus-1")

        let configuration = LexicalSuggestionConfiguration(
            maxSuggestions: 5,
            maxPrefixSuggestions: 2,
            maxCollocateSuggestions: 3,
            collocateLeftWindow: 1,
            collocateRightWindow: 1,
            collocateMinFrequency: 1,
            collocateDebounceNanoseconds: 1_000_000
        )
        _ = controller.suggestions(
            for: "alpha",
            options: .default,
            configuration: configuration
        )
        await waitForAutocompleteSuggestion(controller) {
            controller.suggestions(
                for: "alpha",
                options: .default,
                configuration: configuration
            )
            .contains { $0.source == .collocate && $0.term == "beta" }
        }

        let suggestions = controller.suggestions(
            for: "alpha",
            options: .default,
            configuration: configuration
        )
        XCTAssertTrue(suggestions.contains { $0.term == "alpha" && $0.source == .prefix })
        XCTAssertTrue(suggestions.contains { $0.term == "beta" && $0.source == .collocate && $0.cooccurrence == 4 })
        XCTAssertFalse(suggestions.contains { $0.term == "alpha" && $0.source == .collocate })
    }

    func testLexicalAutocompleteControllerFallsBackToPrefixWithoutPositionIndex() async {
        let repository = FakeWorkspaceRepository()
        repository.storedFrequencyArtifactsByCorpusID["corpus-1"] = makeFrequencyArtifact(rows: [
            FrequencyRow(word: "alpha", count: 3, rank: 1),
            FrequencyRow(word: "beta", count: 4, rank: 2)
        ])
        repository.storedTokenizedArtifactsByCorpusID["corpus-1"] = makeTokenizedArtifact()

        let controller = LexicalAutocompleteController(repository: repository)
        controller.updateSelectedCorpusID("corpus-1")
        await waitForAutocompleteLoad(controller, corpusID: "corpus-1")

        let suggestions = controller.suggestions(for: "alpha", options: .default)
        XCTAssertEqual(suggestions.map(\.source), [.prefix])
        XCTAssertEqual(suggestions.map(\.term), ["alpha"])
    }

    func testLexicalAutocompleteInteractionStateSupportsMoveAcceptAndDismiss() {
        let suggestions = [
            LexicalAutocompleteSuggestion(term: "hesitation", count: 12, rank: 1),
            LexicalAutocompleteSuggestion(term: "hesitate", count: 8, rank: 2),
            LexicalAutocompleteSuggestion(term: "hesitant", count: 6, rank: 3)
        ]
        var state = LexicalAutocompleteInteractionState()

        state.updateSuggestions(suggestions, for: "hesi")
        XCTAssertTrue(state.isPresented)
        XCTAssertEqual(state.highlightedIndex, 0)

        XCTAssertTrue(state.moveSelection(by: 1, suggestionCount: suggestions.count))
        XCTAssertEqual(state.highlightedIndex, 1)
        XCTAssertEqual(state.acceptHighlightedSuggestion(from: suggestions)?.term, "hesitate")

        XCTAssertTrue(state.moveSelection(by: -1, suggestionCount: suggestions.count))
        XCTAssertEqual(state.highlightedIndex, 0)

        state.dismiss()
        XCTAssertFalse(state.isPresented)
        XCTAssertNil(state.highlightedIndex)
        XCTAssertNil(state.acceptHighlightedSuggestion(from: suggestions))
    }

    func testLexicalAutocompleteInteractionStateSuppressesAcceptedSuggestionWhileEditingAcceptedText() {
        let suggestions = [
            LexicalAutocompleteSuggestion(term: "hesitation", count: 12, rank: 1),
            LexicalAutocompleteSuggestion(term: "hesitate", count: 8, rank: 2)
        ]
        var state = LexicalAutocompleteInteractionState()

        state.updateSuggestions(suggestions, for: "hesi")
        XCTAssertTrue(state.isPresented)

        state.markAcceptedSuggestion("hesitation")
        XCTAssertFalse(state.isPresented)
        XCTAssertNil(state.highlightedIndex)

        state.updateSuggestions(suggestions, for: "hesitation")
        XCTAssertFalse(state.isPresented)
        XCTAssertNil(state.highlightedIndex)

        state.updateSuggestions(suggestions, for: "hesitatio")
        XCTAssertFalse(state.isPresented)
        XCTAssertNil(state.highlightedIndex)

        state.updateSuggestions(suggestions, for: "hesitationx")
        XCTAssertTrue(state.isPresented)
        XCTAssertEqual(state.highlightedIndex, 0)
    }

    func testLexicalAutocompleteInteractionStateCanForcePresentationAfterAcceptedText() {
        let suggestions = [
            LexicalAutocompleteSuggestion(term: "hesitation", count: 12, rank: 1),
            LexicalAutocompleteSuggestion(term: "hesitate", count: 8, rank: 2)
        ]
        var state = LexicalAutocompleteInteractionState()

        state.markAcceptedSuggestion("hesitation")
        state.updateSuggestions(suggestions, for: "hesitatio")
        XCTAssertFalse(state.isPresented)

        state.updateSuggestions(suggestions, for: "hesitatio", forcePresentation: true)
        XCTAssertTrue(state.isPresented)
        XCTAssertEqual(state.highlightedIndex, 0)
    }

    func testMainWorkspaceLexicalAutocompleteTracksSidebarSelectionAndMetadataFilterFallback() async {
        let corpusOne = LibraryCorpusItem(json: [
            "id": "corpus-1",
            "name": "Corpus 1",
            "folderId": "folder-1",
            "folderName": "Default",
            "sourceType": "txt",
            "metadata": [
                "sourceLabel": "alpha-source"
            ]
        ])
        let corpusTwo = LibraryCorpusItem(json: [
            "id": "corpus-2",
            "name": "Corpus 2",
            "folderId": "folder-1",
            "folderName": "Default",
            "sourceType": "txt",
            "metadata": [
                "sourceLabel": "beta-source"
            ]
        ])
        let repository = FakeWorkspaceRepository(
            bootstrapState: WorkspaceBootstrapState(
                appInfo: makeBootstrapState().appInfo,
                librarySnapshot: LibrarySnapshot(
                    folders: [LibraryFolderItem(json: ["id": "folder-1", "name": "Default"])],
                    corpora: [corpusOne, corpusTwo],
                    corpusSets: []
                ),
                workspaceSnapshot: makeBootstrapState().workspaceSnapshot,
                uiSettings: makeBootstrapState().uiSettings
            )
        )
        repository.storedFrequencyArtifactsByCorpusID["corpus-1"] = makeFrequencyArtifact(rows: [
            FrequencyRow(word: "hesitation", count: 12, rank: 1)
        ])
        repository.storedFrequencyArtifactsByCorpusID["corpus-2"] = makeFrequencyArtifact(rows: [
            FrequencyRow(word: "history", count: 7, rank: 1)
        ])

        let workspace = makeMainWorkspaceViewModel(repository: repository)
        workspace.sidebar.librarySnapshot = repository.librarySnapshot
        workspace.sidebar.selectedCorpusID = "corpus-1"
        await waitForAutocompleteLoad(workspace.lexicalAutocomplete, corpusID: "corpus-1")

        XCTAssertEqual(
            workspace.lexicalAutocomplete.suggestions(for: "hes", options: .default).map(\.term),
            ["hesitation"]
        )

        workspace.sidebar.applyMetadataFilterState(
            CorpusMetadataFilterState(
                sourceQuery: "beta-source",
                genreQuery: "",
                tagsQuery: ""
            )
        )
        await waitForAutocompleteLoad(workspace.lexicalAutocomplete, corpusID: "corpus-2")

        XCTAssertEqual(workspace.sidebar.selectedCorpusID, "corpus-2")
        XCTAssertEqual(
            workspace.lexicalAutocomplete.suggestions(for: "hist", options: .default).map(\.term),
            ["history"]
        )
    }
}

@MainActor
private func waitForAutocompleteLoad(
    _ controller: LexicalAutocompleteController,
    corpusID: String?,
    timeoutNanoseconds: UInt64 = 1_000_000_000
) async {
    let started = Date().timeIntervalSinceReferenceDate
    while controller.loadedCorpusID != corpusID {
        let elapsedNanoseconds = UInt64((Date().timeIntervalSinceReferenceDate - started) * 1_000_000_000)
        if elapsedNanoseconds > timeoutNanoseconds {
            break
        }
        await Task.yield()
        try? await Task.sleep(nanoseconds: 10_000_000)
    }
}

@MainActor
private func waitForAutocompleteRevision(
    _ controller: LexicalAutocompleteController,
    minimumRevision: Int,
    timeoutNanoseconds: UInt64 = 1_000_000_000
) async {
    let started = Date().timeIntervalSinceReferenceDate
    while controller.revision < minimumRevision {
        let elapsedNanoseconds = UInt64((Date().timeIntervalSinceReferenceDate - started) * 1_000_000_000)
        if elapsedNanoseconds > timeoutNanoseconds {
            break
        }
        await Task.yield()
        try? await Task.sleep(nanoseconds: 10_000_000)
    }
}

@MainActor
private func waitForAutocompleteSuggestion(
    _ controller: LexicalAutocompleteController,
    timeoutNanoseconds: UInt64 = 1_000_000_000,
    condition: () -> Bool
) async {
    let started = Date().timeIntervalSinceReferenceDate
    while !condition() {
        let elapsedNanoseconds = UInt64((Date().timeIntervalSinceReferenceDate - started) * 1_000_000_000)
        if elapsedNanoseconds > timeoutNanoseconds {
            break
        }
        await Task.yield()
        try? await Task.sleep(nanoseconds: 10_000_000)
    }
}

private func makeFrequencyArtifact(rows: [FrequencyRow]) -> StoredFrequencyArtifact {
    StoredFrequencyArtifact(
        textDigest: "digest",
        tokenCount: rows.reduce(0) { $0 + $1.count },
        typeCount: rows.count,
        sentenceCount: max(1, rows.count),
        paragraphCount: 1,
        ttr: rows.isEmpty ? 0 : Double(rows.count) / Double(rows.reduce(0) { $0 + $1.count }),
        sttr: 0,
        frequencyRows: rows
    )
}

private func makeTokenizedArtifact() -> StoredTokenizedArtifact {
    StoredTokenizedArtifact(
        textDigest: "digest",
        sentences: [
            TokenizedSentence(sentenceId: 0, text: "alpha beta alpha gamma", tokens: [
                TokenizedToken(original: "alpha", normalized: "alpha", sentenceId: 0, tokenIndex: 0),
                TokenizedToken(original: "beta", normalized: "beta", sentenceId: 0, tokenIndex: 1),
                TokenizedToken(original: "alpha", normalized: "alpha", sentenceId: 0, tokenIndex: 2),
                TokenizedToken(original: "gamma", normalized: "gamma", sentenceId: 0, tokenIndex: 3)
            ]),
            TokenizedSentence(sentenceId: 1, text: "beta alpha beta", tokens: [
                TokenizedToken(original: "beta", normalized: "beta", sentenceId: 1, tokenIndex: 0),
                TokenizedToken(original: "alpha", normalized: "alpha", sentenceId: 1, tokenIndex: 1),
                TokenizedToken(original: "beta", normalized: "beta", sentenceId: 1, tokenIndex: 2)
            ])
        ]
    )
}

private func makeTokenPositionIndex() -> StoredTokenPositionIndexArtifact {
    StoredTokenPositionIndexArtifact(
        textDigest: "digest",
        exactPositions: [
            "alpha": [
                StoredTokenPosition(sentenceId: 0, tokenIndex: 0),
                StoredTokenPosition(sentenceId: 0, tokenIndex: 2),
                StoredTokenPosition(sentenceId: 1, tokenIndex: 1)
            ]
        ],
        normalizedPositions: [
            "alpha": [
                StoredTokenPosition(sentenceId: 0, tokenIndex: 0),
                StoredTokenPosition(sentenceId: 0, tokenIndex: 2),
                StoredTokenPosition(sentenceId: 1, tokenIndex: 1)
            ]
        ]
    )
}
