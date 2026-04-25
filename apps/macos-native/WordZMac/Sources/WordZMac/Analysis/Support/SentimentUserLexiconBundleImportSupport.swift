import Foundation

struct SentimentUserLexiconBundleImportOutcome: Equatable {
    let bundle: SentimentUserLexiconBundle
    let acceptedEntryCount: Int
    let rejectedEntryCount: Int
}

enum SentimentUserLexiconBundleImportError: LocalizedError {
    case emptyFile
    case invalidBundle
    case noUsableEntries

    var errorDescription: String? {
        switch self {
        case .emptyFile:
            return wordZText(
                "导入失败：文件为空。",
                "Import failed because the selected file is empty.",
                mode: .system
            )
        case .invalidBundle:
            return wordZText(
                "导入失败：文件不是有效的情感词典 bundle JSON。",
                "Import failed because the selected file is not a valid sentiment bundle JSON.",
                mode: .system
            )
        case .noUsableEntries:
            return wordZText(
                "导入失败：bundle 中没有可用的词条。",
                "Import failed because the bundle does not contain any usable entries.",
                mode: .system
            )
        }
    }
}

enum SentimentUserLexiconBundleImportSupport {
    static func importBundle(from url: URL) throws -> SentimentUserLexiconBundleImportOutcome {
        let data = try Data(contentsOf: url)
        guard !data.isEmpty else {
            throw SentimentUserLexiconBundleImportError.emptyFile
        }

        let decodedBundle: SentimentUserLexiconBundle
        do {
            decodedBundle = try JSONDecoder().decode(SentimentUserLexiconBundle.self, from: data)
        } catch {
            throw SentimentUserLexiconBundleImportError.invalidBundle
        }

        let normalizedEntries = normalizeEntries(decodedBundle.entries)
        guard !normalizedEntries.accepted.isEmpty else {
            throw SentimentUserLexiconBundleImportError.noUsableEntries
        }

        let bundle = SentimentUserLexiconBundle(
            manifest: normalizedManifest(decodedBundle.manifest, fallbackID: fallbackBundleID(from: url)),
            entries: normalizedEntries.accepted
        )

        return SentimentUserLexiconBundleImportOutcome(
            bundle: bundle,
            acceptedEntryCount: normalizedEntries.accepted.count,
            rejectedEntryCount: normalizedEntries.rejectedCount
        )
    }

    private static func normalizeEntries(
        _ entries: [SentimentUserLexiconEntry]
    ) -> (accepted: [SentimentUserLexiconEntry], rejectedCount: Int) {
        var accepted: [SentimentUserLexiconEntry] = []
        var rejectedCount = 0
        var seen: Set<String> = []

        for entry in entries {
            let trimmedTerm = entry.term.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedTerm.isEmpty,
                  entry.score.isFinite,
                  abs(entry.score) >= 0.01
            else {
                rejectedCount += 1
                continue
            }

            let dedupeKey = "\(trimmedTerm.lowercased())::\(entry.matchMode.rawValue)"
            guard seen.insert(dedupeKey).inserted else {
                rejectedCount += 1
                continue
            }

            let clippedScore = min(max(entry.score, -4.0), 4.0)
            let normalizedCategory = normalizedCategory(for: entry.category, score: clippedScore)
            let normalizedTags = entry.domainTags.isEmpty ? [.general] : entry.domainTags

            accepted.append(
                SentimentUserLexiconEntry(
                    id: entry.id,
                    term: trimmedTerm,
                    score: clippedScore,
                    category: normalizedCategory,
                    domainTags: normalizedTags,
                    matchMode: entry.matchMode
                )
            )
        }

        return (accepted, rejectedCount)
    }

    private static func normalizedManifest(
        _ manifest: SentimentUserLexiconBundleManifest,
        fallbackID: String
    ) -> SentimentUserLexiconBundleManifest {
        let trimmedID = manifest.id.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedVersion = manifest.version.trimmingCharacters(in: .whitespacesAndNewlines)
        return SentimentUserLexiconBundleManifest(
            id: trimmedID.isEmpty ? fallbackID : trimmedID,
            version: trimmedVersion.isEmpty ? "1" : trimmedVersion,
            author: manifest.author.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: manifest.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private static func normalizedCategory(
        for category: SentimentCueCategory,
        score: Double
    ) -> SentimentCueCategory {
        switch category {
        case .hedge, .neutralShield, .academicCaution:
            return score >= 0 ? .corePositive : .coreNegative
        case .corePositive, .coreNegative, .weakEvaluative, .newsEvaluative:
            return category
        }
    }

    private static func fallbackBundleID(from url: URL) -> String {
        let candidate = url.deletingPathExtension().lastPathComponent
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if candidate.isEmpty {
            return "imported-bundle"
        }
        return candidate
    }
}
