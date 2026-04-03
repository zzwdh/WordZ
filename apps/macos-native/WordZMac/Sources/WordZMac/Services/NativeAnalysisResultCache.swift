import CryptoKit
import Foundation

final class NativeAnalysisResultCache {
    private let maxEntries: Int
    private let maxEntriesByKind: [String: Int]
    private var storage: [NativeAnalysisResultCacheKey: Any] = [:]
    private var order: [NativeAnalysisResultCacheKey] = []
    private var orderByKind: [String: [NativeAnalysisResultCacheKey]] = [:]

    init(maxEntries: Int = 24, maxEntriesByKind: [String: Int] = [:]) {
        self.maxEntries = max(4, maxEntries)
        self.maxEntriesByKind = maxEntriesByKind.mapValues { max(2, $0) }
    }

    func value<T>(for key: NativeAnalysisResultCacheKey) -> T? {
        guard let value = storage[key] as? T else { return nil }
        touch(key)
        return value
    }

    func store<T>(_ value: T, for key: NativeAnalysisResultCacheKey) {
        storage[key] = value
        touch(key)
        trimIfNeeded()
    }

    func removeAll() {
        storage.removeAll()
        order.removeAll()
        orderByKind.removeAll()
    }

    func remove(kind: String) {
        let keys = orderByKind.removeValue(forKey: kind) ?? []
        for key in keys {
            storage.removeValue(forKey: key)
            order.removeAll { $0 == key }
        }
    }

    var cachedKeyCountForTesting: Int {
        storage.count
    }

    private func touch(_ key: NativeAnalysisResultCacheKey) {
        order.removeAll { $0 == key }
        order.append(key)
        var kindOrder = orderByKind[key.kind] ?? []
        kindOrder.removeAll { $0 == key }
        kindOrder.append(key)
        orderByKind[key.kind] = kindOrder
    }

    private func trimIfNeeded() {
        for (kind, kindMaxEntries) in maxEntriesByKind {
            while (orderByKind[kind]?.count ?? 0) > kindMaxEntries {
                guard let evicted = orderByKind[kind]?.first else { break }
                remove(evicted)
            }
        }
        while order.count > maxEntries {
            let evicted = order.removeFirst()
            remove(evicted)
        }
    }

    private func remove(_ key: NativeAnalysisResultCacheKey) {
        storage.removeValue(forKey: key)
        order.removeAll { $0 == key }
        orderByKind[key.kind]?.removeAll { $0 == key }
        if orderByKind[key.kind]?.isEmpty == true {
            orderByKind[key.kind] = nil
        }
    }
}

struct NativeAnalysisResultCacheKey: Hashable {
    let kind: String
    let signature: String

    static func stats(text: String) -> Self {
        Self(kind: "stats", signature: hash(text))
    }

    static func tokenize(text: String) -> Self {
        Self(kind: "tokenize", signature: hash(text))
    }

    static func ngram(text: String, n: Int) -> Self {
        Self(kind: "ngram", signature: "\(n)|\(hash(text))")
    }

    static func wordCloud(text: String) -> Self {
        Self(kind: "wordCloud", signature: hash(text))
    }

    static func kwic(
        text: String,
        keyword: String,
        leftWindow: Int,
        rightWindow: Int,
        searchOptions: SearchOptionsState
    ) -> Self {
        Self(
            kind: "kwic",
            signature: "\(hash(text))|\(keyword)|\(leftWindow)|\(rightWindow)|\(searchOptions.words)|\(searchOptions.caseSensitive)|\(searchOptions.regex)"
        )
    }

    static func collocate(
        text: String,
        keyword: String,
        leftWindow: Int,
        rightWindow: Int,
        minFreq: Int,
        searchOptions: SearchOptionsState
    ) -> Self {
        Self(
            kind: "collocate",
            signature: "\(hash(text))|\(keyword)|\(leftWindow)|\(rightWindow)|\(minFreq)|\(searchOptions.words)|\(searchOptions.caseSensitive)|\(searchOptions.regex)"
        )
    }

    static func locator(
        text: String,
        sentenceId: Int,
        nodeIndex: Int,
        leftWindow: Int,
        rightWindow: Int
    ) -> Self {
        Self(
            kind: "locator",
            signature: "\(hash(text))|\(sentenceId)|\(nodeIndex)|\(leftWindow)|\(rightWindow)"
        )
    }

    static func compare(entries: [CompareRequestEntry]) -> Self {
        let signature = entries
            .map {
                [
                    $0.corpusId,
                    $0.corpusName,
                    $0.folderId,
                    $0.folderName,
                    $0.sourceType,
                    hash($0.content)
                ].joined(separator: "|")
            }
            .joined(separator: "||")
        return Self(kind: "compare", signature: signature)
    }

    private static func hash(_ value: String) -> String {
        let digest = SHA256.hash(data: Data(value.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
