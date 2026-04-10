import XCTest
@testable import WordZMac

final class NativeAnalysisResultCacheTests: XCTestCase {
    func testCacheReturnsStoredValueForEquivalentKey() {
        let cache = NativeAnalysisResultCache(maxEntries: 4)
        let key = NativeAnalysisResultCacheKey.kwic(
            text: "alpha beta",
            keyword: "alpha",
            leftWindow: 2,
            rightWindow: 3,
            searchOptions: .default
        )

        cache.store("cached-value", for: key)

        let cached: String? = cache.value(for: key)
        XCTAssertEqual(cached, "cached-value")
    }

    func testCacheEvictsOldestEntriesWhenCapacityIsExceeded() {
        let cache = NativeAnalysisResultCache(maxEntries: 4)
        let baseText = "alpha beta gamma"

        cache.store("stats", for: .stats(text: baseText))
        cache.store("tokenize", for: .tokenize(text: baseText))
        cache.store("ngram", for: .ngram(text: baseText, n: 2))
        cache.store("locator", for: .locator(text: baseText, sentenceId: 0, nodeIndex: 0, leftWindow: 1, rightWindow: 1))
        cache.store("compare", for: .compare(entries: [CompareRequestEntry(
            corpusId: "c1",
            corpusName: "Corpus 1",
            folderId: "f1",
            folderName: "Folder",
            sourceType: "txt",
            content: baseText
        )]))

        let evicted: String? = cache.value(for: .stats(text: baseText))
        let retained: String? = cache.value(for: .locator(text: baseText, sentenceId: 0, nodeIndex: 0, leftWindow: 1, rightWindow: 1))

        XCTAssertNil(evicted)
        XCTAssertEqual(retained, "locator")
        XCTAssertEqual(cache.cachedKeyCountForTesting, 4)
    }

    func testCacheAppliesPerKindCapacityBeforeGlobalCapacity() {
        let cache = NativeAnalysisResultCache(
            maxEntries: 10,
            maxEntriesByKind: ["kwic": 2]
        )

        cache.store("first", for: .kwic(text: "alpha", keyword: "a", leftWindow: 2, rightWindow: 2, searchOptions: .default))
        cache.store("second", for: .kwic(text: "beta", keyword: "b", leftWindow: 2, rightWindow: 2, searchOptions: .default))
        cache.store("third", for: .kwic(text: "gamma", keyword: "g", leftWindow: 2, rightWindow: 2, searchOptions: .default))

        let first: String? = cache.value(for: .kwic(text: "alpha", keyword: "a", leftWindow: 2, rightWindow: 2, searchOptions: .default))
        let third: String? = cache.value(for: .kwic(text: "gamma", keyword: "g", leftWindow: 2, rightWindow: 2, searchOptions: .default))

        XCTAssertNil(first)
        XCTAssertEqual(third, "third")
    }

    func testCacheCanClearSpecificKindWithoutRemovingOtherResults() {
        let cache = NativeAnalysisResultCache(maxEntries: 8)
        let statsKey = NativeAnalysisResultCacheKey.stats(text: "alpha beta")
        let compareKey = NativeAnalysisResultCacheKey.compare(entries: [CompareRequestEntry(
            corpusId: "c1",
            corpusName: "Corpus 1",
            folderId: "f1",
            folderName: "Folder",
            sourceType: "txt",
            content: "alpha beta"
        )])

        cache.store("stats", for: statsKey)
        cache.store("compare", for: compareKey)
        cache.remove(kind: "compare")

        let stats: String? = cache.value(for: statsKey)
        let compare: String? = cache.value(for: compareKey)

        XCTAssertEqual(stats, "stats")
        XCTAssertNil(compare)
    }

    func testCompareCacheKeyIgnoresEntryOrdering() {
        let first = CompareRequestEntry(
            corpusId: "c1",
            corpusName: "Corpus 1",
            folderId: "f1",
            folderName: "Folder",
            sourceType: "txt",
            content: "alpha beta"
        )
        let second = CompareRequestEntry(
            corpusId: "c2",
            corpusName: "Corpus 2",
            folderId: "f1",
            folderName: "Folder",
            sourceType: "txt",
            content: "gamma delta"
        )

        let keyA = NativeAnalysisResultCacheKey.compare(entries: [first, second])
        let keyB = NativeAnalysisResultCacheKey.compare(entries: [second, first])

        XCTAssertEqual(keyA, keyB)
    }
}
