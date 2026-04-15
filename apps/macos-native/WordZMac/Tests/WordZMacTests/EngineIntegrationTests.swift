import XCTest
@testable import WordZWorkspaceCore

final class EngineIntegrationTests: XCTestCase {
    @MainActor
    func testNativeWorkspaceRepositoryBootstrapsAgainstNativeUserDataDirectory() async throws {
        let repository = NativeWorkspaceRepository()
        let userDataURL = FileManager.default.temporaryDirectory.appendingPathComponent(
            ".wordz-native-user-data-test",
            isDirectory: true
        )

        try? FileManager.default.removeItem(at: userDataURL)

        do {
            try await repository.start(userDataURL: userDataURL)
            let bootstrap = try await repository.loadBootstrapState()
            XCTAssertEqual(bootstrap.appInfo.name, "WordZ")
            XCTAssertEqual(bootstrap.librarySnapshot.folders.count, 0)
            XCTAssertEqual(bootstrap.librarySnapshot.corpora.count, 0)
            XCTAssertEqual(bootstrap.workspaceSnapshot.currentTab, "stats")
        } catch {
            XCTFail("Native engine bootstrap failed: \(error.localizedDescription)")
        }

        await repository.stop()
    }

    @MainActor
    func testNativeWorkspaceRepositoryLoadsCorpusInfoFromStoredDatabaseMetadata() async throws {
        let repository = NativeWorkspaceRepository()
        let userDataURL = FileManager.default.temporaryDirectory.appendingPathComponent(
            ".wordz-native-user-data-corpus-info-test",
            isDirectory: true
        )
        let importURL = userDataURL.appendingPathComponent("sample.txt")

        try? FileManager.default.removeItem(at: userDataURL)
        try FileManager.default.createDirectory(at: userDataURL, withIntermediateDirectories: true)
        try "Alpha beta gamma.\nAlpha beta.".write(to: importURL, atomically: true, encoding: .utf8)

        do {
            try await repository.start(userDataURL: userDataURL)
            _ = try await repository.importCorpusPaths([importURL.path], folderId: "", preserveHierarchy: false)
            let library = try await repository.listLibrary(folderId: "all")
            guard let corpus = library.corpora.first else {
                XCTFail("Expected imported corpus")
                return
            }

            let info = try await repository.loadCorpusInfo(corpusId: corpus.id)

            XCTAssertEqual(info.title, corpus.name)
            XCTAssertEqual(info.detectedEncoding.uppercased(), "UTF-8")
            XCTAssertGreaterThan(info.tokenCount, 0)
            XCTAssertGreaterThan(info.typeCount, 0)
            XCTAssertGreaterThan(info.ttr, 0)
        } catch {
            XCTFail("Native corpus info failed: \(error.localizedDescription)")
        }

        await repository.stop()
    }

    @MainActor
    func testNativeWorkspaceRepositoryPreparesStoredCompareCorporaOnlyWhenContentMatchesStoredDigest() async throws {
        let repository = NativeWorkspaceRepository()
        let userDataURL = FileManager.default.temporaryDirectory.appendingPathComponent(
            ".wordz-native-user-data-compare-artifact-test",
            isDirectory: true
        )
        let importURL = userDataURL.appendingPathComponent("compare.txt")

        try? FileManager.default.removeItem(at: userDataURL)
        try FileManager.default.createDirectory(at: userDataURL, withIntermediateDirectories: true)
        try "alpha alpha beta".write(to: importURL, atomically: true, encoding: .utf8)

        do {
            try await repository.start(userDataURL: userDataURL)
            _ = try await repository.importCorpusPaths([importURL.path], folderId: "", preserveHierarchy: false)
            let library = try await repository.listLibrary(folderId: "all")
            let corpus = try XCTUnwrap(library.corpora.first)

            let matchingEntries = [
                CompareRequestEntry(
                    corpusId: corpus.id,
                    corpusName: corpus.name,
                    folderId: corpus.folderId,
                    folderName: corpus.folderName,
                    sourceType: corpus.sourceType,
                    content: "alpha alpha beta"
                )
            ]
            let prepared = try await repository.core.prepareStoredCompareCorpora(from: matchingEntries)
            let matchingPrepared = try XCTUnwrap(prepared?.first)
            XCTAssertEqual(matchingPrepared.tokenCount, 3)
            XCTAssertEqual(matchingPrepared.topWord, "alpha")
            XCTAssertEqual(matchingPrepared.frequency["beta"], 1)

            let mismatchedEntries = [
                CompareRequestEntry(
                    corpusId: corpus.id,
                    corpusName: corpus.name,
                    folderId: corpus.folderId,
                    folderName: corpus.folderName,
                    sourceType: corpus.sourceType,
                    content: "placeholder content"
                )
            ]
            let mismatchedPrepared = try await repository.core.prepareStoredCompareCorpora(from: mismatchedEntries)
            XCTAssertNil(mismatchedPrepared)
        } catch {
            XCTFail("Native compare artifact preparation failed: \(error.localizedDescription)")
        }

        await repository.stop()
    }

    @MainActor
    func testNativeWorkspaceRepositoryPreparesStoredKeywordSuiteRequestOnlyWhenContentMatchesStoredDigest() async throws {
        let repository = NativeWorkspaceRepository()
        let userDataURL = FileManager.default.temporaryDirectory.appendingPathComponent(
            ".wordz-native-user-data-keyword-artifact-test",
            isDirectory: true
        )
        let focusURL = userDataURL.appendingPathComponent("focus.txt")
        let referenceURL = userDataURL.appendingPathComponent("reference.txt")

        try? FileManager.default.removeItem(at: userDataURL)
        try FileManager.default.createDirectory(at: userDataURL, withIntermediateDirectories: true)
        try "alpha alpha beta".write(to: focusURL, atomically: true, encoding: .utf8)
        try "beta beta gamma".write(to: referenceURL, atomically: true, encoding: .utf8)

        do {
            try await repository.start(userDataURL: userDataURL)
            _ = try await repository.importCorpusPaths([focusURL.path, referenceURL.path], folderId: "", preserveHierarchy: false)
            let library = try await repository.listLibrary(folderId: "all")
            XCTAssertEqual(library.corpora.count, 2)

            let corporaByName = Dictionary(uniqueKeysWithValues: library.corpora.map { ($0.name, $0) })
            let focus = try XCTUnwrap(corporaByName["focus"])
            let reference = try XCTUnwrap(corporaByName["reference"])

            let matchingRequest = KeywordSuiteRunRequest(
                focusEntries: [
                    KeywordRequestEntry(
                        corpusId: focus.id,
                        corpusName: focus.name,
                        folderName: focus.folderName,
                        content: "alpha alpha beta"
                    )
                ],
                referenceEntries: [
                    KeywordRequestEntry(
                        corpusId: reference.id,
                        corpusName: reference.name,
                        folderName: reference.folderName,
                        content: "beta beta gamma"
                    )
                ],
                importedReferenceItems: [],
                focusLabel: focus.name,
                referenceLabel: reference.name,
                configuration: .default
            )
            let preparedMatching = try await repository.core.prepareStoredKeywordSuiteRequest(from: matchingRequest)
            XCTAssertEqual(preparedMatching?.focusCorpora.first?.tokenizedArtifact.tokenCount, 3)
            XCTAssertEqual(preparedMatching?.referenceCorpora.first?.tokenizedArtifact.frequencyMap["beta"], 2)

            let mismatchedRequest = KeywordSuiteRunRequest(
                focusEntries: [
                    KeywordRequestEntry(
                        corpusId: focus.id,
                        corpusName: focus.name,
                        folderName: focus.folderName,
                        content: "placeholder content"
                    )
                ],
                referenceEntries: matchingRequest.referenceEntries,
                importedReferenceItems: [],
                focusLabel: focus.name,
                referenceLabel: reference.name,
                configuration: .default
            )
            let preparedMismatched = try await repository.core.prepareStoredKeywordSuiteRequest(from: mismatchedRequest)
            XCTAssertNil(preparedMismatched)
        } catch {
            XCTFail("Native keyword artifact preparation failed: \(error.localizedDescription)")
        }

        await repository.stop()
    }

    @MainActor
    func testNativeWorkspaceRepositoryRunTokenizeUsesStoredTokenizedArtifactWithoutRuntimeParse() async throws {
        let repository = NativeWorkspaceRepository()
        let userDataURL = FileManager.default.temporaryDirectory.appendingPathComponent(
            ".wordz-native-user-data-tokenize-artifact-test",
            isDirectory: true
        )
        let importURL = userDataURL.appendingPathComponent("sample.txt")

        try? FileManager.default.removeItem(at: userDataURL)
        try FileManager.default.createDirectory(at: userDataURL, withIntermediateDirectories: true)
        try "Running beta.\nGAMMA delta!".write(to: importURL, atomically: true, encoding: .utf8)

        do {
            try await repository.start(userDataURL: userDataURL)
            _ = try await repository.importCorpusPaths([importURL.path], folderId: "", preserveHierarchy: false)
            let library = try await repository.listLibrary(folderId: "all")
            let corpus = try XCTUnwrap(library.corpora.first)
            let opened = try await repository.openSavedCorpus(corpusId: corpus.id)

            let beforeCachedDocuments = await repository.core.analysisRuntime.cachedDocumentCountForTesting
            XCTAssertEqual(beforeCachedDocuments, 0)

            let result = try await repository.runTokenize(text: opened.content)

            XCTAssertEqual(result.sentenceCount, 2)
            XCTAssertEqual(result.tokenCount, 4)
            XCTAssertEqual(result.sentences.last?.tokens.map(\.normalized), ["gamma", "delta"])

            let afterCachedDocuments = await repository.core.analysisRuntime.cachedDocumentCountForTesting
            XCTAssertEqual(afterCachedDocuments, 0)
        } catch {
            XCTFail("Native tokenize artifact fast path failed: \(error.localizedDescription)")
        }

        await repository.stop()
    }

    @MainActor
    func testNativeWorkspaceRepositoryRunKeywordSuiteUsesStoredTokenizedArtifactsWithoutRuntimeParse() async throws {
        let repository = NativeWorkspaceRepository()
        let userDataURL = FileManager.default.temporaryDirectory.appendingPathComponent(
            ".wordz-native-user-data-keyword-run-artifact-test",
            isDirectory: true
        )
        let focusURL = userDataURL.appendingPathComponent("focus.txt")
        let referenceURL = userDataURL.appendingPathComponent("reference.txt")

        try? FileManager.default.removeItem(at: userDataURL)
        try FileManager.default.createDirectory(at: userDataURL, withIntermediateDirectories: true)
        try "alpha alpha beta".write(to: focusURL, atomically: true, encoding: .utf8)
        try "beta beta gamma".write(to: referenceURL, atomically: true, encoding: .utf8)

        do {
            try await repository.start(userDataURL: userDataURL)
            _ = try await repository.importCorpusPaths([focusURL.path, referenceURL.path], folderId: "", preserveHierarchy: false)
            let library = try await repository.listLibrary(folderId: "all")
            let corporaByName = Dictionary(uniqueKeysWithValues: library.corpora.map { ($0.name, $0) })
            let focus = try XCTUnwrap(corporaByName["focus"])
            let reference = try XCTUnwrap(corporaByName["reference"])

            let openedFocus = try await repository.openSavedCorpus(corpusId: focus.id)
            let openedReference = try await repository.openSavedCorpus(corpusId: reference.id)
            let request = KeywordSuiteRunRequest(
                focusEntries: [
                    KeywordRequestEntry(
                        corpusId: focus.id,
                        corpusName: focus.name,
                        folderName: focus.folderName,
                        content: openedFocus.content
                    )
                ],
                referenceEntries: [
                    KeywordRequestEntry(
                        corpusId: reference.id,
                        corpusName: reference.name,
                        folderName: reference.folderName,
                        content: openedReference.content
                    )
                ],
                importedReferenceItems: [],
                focusLabel: focus.name,
                referenceLabel: reference.name,
                configuration: .default
            )

            let beforeCachedDocuments = await repository.core.analysisRuntime.cachedDocumentCountForTesting
            XCTAssertEqual(beforeCachedDocuments, 0)

            let result = try await repository.runKeywordSuite(request)

            XCTAssertEqual(result.focusSummary.tokenCount, 3)
            XCTAssertEqual(result.referenceSummary.tokenCount, 3)
            XCTAssertTrue(result.words.contains(where: { $0.item == "alpha" && $0.direction == .positive }))

            let afterCachedDocuments = await repository.core.analysisRuntime.cachedDocumentCountForTesting
            XCTAssertEqual(afterCachedDocuments, 0)
        } catch {
            XCTFail("Native keyword artifact fast path failed: \(error.localizedDescription)")
        }

        await repository.stop()
    }

    @MainActor
    func testNativeWorkspaceRepositoryRunKWICExactMatchLoadsStoredPositionIndex() async throws {
        let repository = NativeWorkspaceRepository()
        let userDataURL = FileManager.default.temporaryDirectory.appendingPathComponent(
            ".wordz-native-user-data-kwic-position-index-test",
            isDirectory: true
        )
        let importURL = userDataURL.appendingPathComponent("sample.txt")

        try? FileManager.default.removeItem(at: userDataURL)
        try FileManager.default.createDirectory(at: userDataURL, withIntermediateDirectories: true)
        try "Alpha beta alpha.\nALPHA gamma".write(to: importURL, atomically: true, encoding: .utf8)

        do {
            try await repository.start(userDataURL: userDataURL)
            _ = try await repository.importCorpusPaths([importURL.path], folderId: "", preserveHierarchy: false)
            let library = try await repository.listLibrary(folderId: "all")
            let corpus = try XCTUnwrap(library.corpora.first)
            let opened = try await repository.openSavedCorpus(corpusId: corpus.id)
            let digest = DocumentCacheKey(text: opened.content).textDigest

            let beforeCachedDocuments = await repository.core.analysisRuntime.cachedDocumentCountForTesting
            XCTAssertEqual(beforeCachedDocuments, 0)

            let result = try await repository.runKWIC(
                text: opened.content,
                keyword: "alpha",
                leftWindow: 1,
                rightWindow: 1,
                searchOptions: .default
            )

            XCTAssertEqual(result.rows.count, 3)
            let cachedPositionIndex = await repository.core.storedTokenPositionIndexesByTextDigest[digest]
            XCTAssertNotNil(cachedPositionIndex)

            let afterCachedDocuments = await repository.core.analysisRuntime.cachedDocumentCountForTesting
            XCTAssertEqual(afterCachedDocuments, 0)
        } catch {
            XCTFail("Native KWIC position index fast path failed: \(error.localizedDescription)")
        }

        await repository.stop()
    }
}
