import XCTest
@testable import WordZWorkspaceCore

final class AnalysisPresetStoreTests: XCTestCase {
    func testNativeCorpusStorePersistsAnalysisPresetRoundTrip() throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("wordz-analysis-preset-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let store = NativeCorpusStore(rootURL: rootURL)
        try store.ensureInitialized()

        let initialDraft = makeDraft(
            currentTab: WorkspaceDetailTab.kwic.snapshotValue,
            searchQuery: "node"
        )
        let saved = try store.saveAnalysisPreset(name: "KWIC Drilldown", draft: initialDraft)

        XCTAssertEqual(saved.name, "KWIC Drilldown")
        XCTAssertEqual(saved.activeTab, .kwic)

        let updatedDraft = makeDraft(
            currentTab: WorkspaceDetailTab.compare.snapshotValue,
            searchQuery: "rose",
            compareSelectedCorpusIDs: ["corpus-1", "corpus-2"],
            compareReferenceCorpusID: "set:reference"
        )
        let updated = try store.saveAnalysisPreset(name: "KWIC Drilldown", draft: updatedDraft)
        let presets = try store.listAnalysisPresets()

        XCTAssertEqual(updated.id, saved.id)
        XCTAssertEqual(presets.count, 1)
        XCTAssertEqual(presets.first?.activeTab, .compare)
        XCTAssertEqual(presets.first?.snapshot.searchQuery, "rose")

        try store.deleteAnalysisPreset(presetID: saved.id)
        XCTAssertTrue(try store.listAnalysisPresets().isEmpty)
    }

    func testNativeCorpusStorePersistsAnalysisPresetAnnotationRoundTrip() throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("wordz-analysis-preset-annotation-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let store = NativeCorpusStore(rootURL: rootURL)
        try store.ensureInitialized()

        _ = try store.saveAnalysisPreset(
            name: "Lemma Keyword",
            draft: makeDraft(
                currentTab: WorkspaceDetailTab.keyword.snapshotValue,
                searchQuery: "alpha",
                annotationProfile: .lemmaPreferred,
                annotationLexicalClasses: [.noun],
                annotationScripts: [.latin]
            )
        )

        let presets = try store.listAnalysisPresets()
        let snapshot = try XCTUnwrap(presets.first?.snapshot)

        XCTAssertEqual(snapshot.annotationProfile, .lemmaPreferred)
        XCTAssertEqual(snapshot.annotationLexicalClasses, [.noun])
        XCTAssertEqual(snapshot.annotationScripts, [.latin])
    }

    private func makeDraft(
        currentTab: String,
        searchQuery: String,
        compareSelectedCorpusIDs: [String] = [],
        compareReferenceCorpusID: String = "",
        annotationProfile: WorkspaceAnnotationProfile = .surface,
        annotationLexicalClasses: [TokenLexicalClass] = [],
        annotationScripts: [TokenScript] = []
    ) -> WorkspaceStateDraft {
        WorkspaceStateDraft(
            currentTab: currentTab,
            currentLibraryFolderId: "all",
            selectedCorpusSetID: "",
            corpusIds: ["corpus-1"],
            corpusNames: ["Demo Corpus"],
            searchQuery: searchQuery,
            searchOptions: .default,
            stopwordFilter: .default,
            annotationProfile: annotationProfile,
            annotationLexicalClasses: annotationLexicalClasses,
            annotationScripts: annotationScripts,
            compareReferenceCorpusID: compareReferenceCorpusID,
            compareSelectedCorpusIDs: compareSelectedCorpusIDs,
            ngramSize: "2",
            ngramPageSize: "10",
            kwicLeftWindow: "3",
            kwicRightWindow: "4",
            collocateLeftWindow: "5",
            collocateRightWindow: "6",
            collocateMinFreq: "2",
            topicsMinTopicSize: "2",
            topicsIncludeOutliers: true,
            topicsPageSize: "50",
            topicsActiveTopicID: "",
            chiSquareA: "",
            chiSquareB: "",
            chiSquareC: "",
            chiSquareD: "",
            chiSquareUseYates: false
        )
    }
}
