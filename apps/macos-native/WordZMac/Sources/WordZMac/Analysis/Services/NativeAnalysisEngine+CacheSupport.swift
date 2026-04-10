import Foundation

extension NativeAnalysisEngine {
    func indexedDocument(for text: String, documentKey: DocumentCacheKey? = nil) -> ParsedDocumentIndex {
        let key = documentKey ?? DocumentCacheKey(text: text)
        if let entry = documentCache[key] {
            touchCacheKey(key)
            return entry
        }

        let index = ParsedDocumentIndex(text: text)
        documentCache[key] = index
        touchCacheKey(key)
        trimCacheIfNeeded()
        return index
    }

    func touchCacheKey(_ key: DocumentCacheKey) {
        cacheOrder.removeAll { $0 == key }
        cacheOrder.append(key)
    }

    func trimCacheIfNeeded() {
        while cacheOrder.count > maxCachedDocuments {
            let evicted = cacheOrder.removeFirst()
            documentCache.removeValue(forKey: evicted)
        }
    }

    static func buildFrequencyMap(for tokens: [ParsedToken]) -> [String: Int] {
        var counts: [String: Int] = [:]
        for token in tokens {
            counts[token.normalized, default: 0] += 1
        }
        return counts
    }

    static func buildStandardizedTypeTokenRatio(tokens: [ParsedToken], chunkSize: Int = 1000) -> Double {
        guard !tokens.isEmpty else { return 0 }
        guard tokens.count > chunkSize else {
            let unique = Set(tokens.map(\.normalized)).count
            return Double(unique) / Double(tokens.count)
        }

        var ratios: [Double] = []
        var index = 0
        while index < tokens.count {
            let end = min(index + chunkSize, tokens.count)
            let chunk = tokens[index..<end]
            let unique = Set(chunk.map(\.normalized)).count
            ratios.append(Double(unique) / Double(chunk.count))
            index += chunkSize
        }
        return ratios.reduce(0, +) / Double(ratios.count)
    }

    static func signedLogLikelihood(
        targetCount: Int,
        targetTokenCount: Int,
        referenceCount: Int,
        referenceTokenCount: Int
    ) -> Double {
        let target = Double(max(0, targetCount))
        let reference = Double(max(0, referenceCount))
        let targetTotal = Double(max(0, targetTokenCount))
        let referenceTotal = Double(max(0, referenceTokenCount))
        let grandTotal = targetTotal + referenceTotal
        let observedTotal = target + reference

        guard targetTotal > 0, referenceTotal > 0, grandTotal > 0, observedTotal > 0 else {
            return 0
        }

        let pooledRate = observedTotal / grandTotal
        let expectedTarget = targetTotal * pooledRate
        let expectedReference = referenceTotal * pooledRate
        let targetTerm = target > 0 && expectedTarget > 0 ? target * log(target / expectedTarget) : 0
        let referenceTerm = reference > 0 && expectedReference > 0 ? reference * log(reference / expectedReference) : 0
        let statistic = 2 * (targetTerm + referenceTerm)

        let targetRate = target / targetTotal
        let referenceRate = reference / referenceTotal
        let sign = targetRate >= referenceRate ? 1.0 : -1.0
        return statistic * sign
    }

    static func logRatio(
        targetCount: Int,
        targetTokenCount: Int,
        referenceCount: Int,
        referenceTokenCount: Int
    ) -> Double {
        let targetRate = (Double(max(0, targetCount)) + 0.5) / (Double(max(0, targetTokenCount)) + 1)
        let referenceRate = (Double(max(0, referenceCount)) + 0.5) / (Double(max(0, referenceTokenCount)) + 1)
        guard targetRate > 0, referenceRate > 0 else { return 0 }
        return log2(targetRate / referenceRate)
    }
}
