import Foundation
import WordZAnalysis

extension NativeCorpusStore {
    private static let torchReferenceCorpusID = "wordz-reference-zh-torch2014"
    private static let torchReferenceCorpusSetID = "wordz-reference-set-zh-torch2014"
    private static let torchReferenceCorpusName = "ToRCH2014 中文默认参照语料库"
    private static let torchReferenceCorpusSetName = "ToRCH2014 中文默认参照语料库"
    private static let torchReferenceStorageFileName = "wordz-reference-zh-torch2014.db"
    private static let torchReferenceBundleSubdirectory = "ReferenceCorpora/ToRCH2014_SEG_UTF-8"
    private static let torchReferenceRepresentedPath = "bundle://WordZAnalysis/ReferenceCorpora/ToRCH2014_SEG_UTF-8"

    func seedBundledDefaultReferenceCorporaIfNeeded() throws {
        guard seedBundledDefaultReferenceCorpora else { return }
        guard let corpus = try ensureBundledToRCH2014ReferenceCorpus() else { return }
        try ensureBundledToRCH2014ReferenceCorpusSet(corpus: corpus)
    }

    private func ensureBundledToRCH2014ReferenceCorpus() throws -> NativeCorpusRecord? {
        let corpora = try loadCorpora()
        let existing = corpora.first {
            $0.id == Self.torchReferenceCorpusID || $0.name == Self.torchReferenceCorpusName
        }
        let metadata = CorpusMetadataProfile(
            sourceLabel: "ToRCH2014",
            yearLabel: "2014",
            genreLabel: "中文参照语料库",
            tags: ["中文", "默认参照语料库", "ToRCH2014"]
        )
        let record = NativeCorpusRecord(
            id: existing?.id ?? Self.torchReferenceCorpusID,
            name: existing?.name ?? Self.torchReferenceCorpusName,
            folderId: existing?.folderId ?? "",
            folderName: existing?.folderName ?? "未分类",
            sourceType: "db",
            representedPath: existing?.representedPath.isEmpty == false
                ? existing?.representedPath ?? Self.torchReferenceRepresentedPath
                : Self.torchReferenceRepresentedPath,
            storageFileName: existing?.storageFileName.isEmpty == false
                ? existing?.storageFileName ?? Self.torchReferenceStorageFileName
                : Self.torchReferenceStorageFileName,
            metadata: existing?.metadata.hasContent == true ? existing?.metadata ?? metadata : metadata,
            cleaningSummary: existing?.cleaningSummary
        )
        let storageURL = corporaDirectoryURL.appendingPathComponent(record.storageFileName)

        if existing == nil || !fileManager.fileExists(atPath: storageURL.path) {
            let seededRecord = try writeBundledToRCH2014ReferenceCorpus(record: record, storageURL: storageURL)
            var nextCorpora = corpora.filter {
                $0.id != seededRecord.id && $0.name != Self.torchReferenceCorpusName
            }
            nextCorpora.append(seededRecord)
            try saveCorpora(nextCorpora)
            return seededRecord
        }

        return record
    }

    private func writeBundledToRCH2014ReferenceCorpus(
        record: NativeCorpusRecord,
        storageURL: URL
    ) throws -> NativeCorpusRecord {
        guard let sourceURLs = WordZAnalysisResources.bundle.urls(
            forResourcesWithExtension: "txt",
            subdirectory: Self.torchReferenceBundleSubdirectory
        )?.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }),
              !sourceURLs.isEmpty else {
            throw NSError(
                domain: "WordZMac.NativeCorpusStore",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "未找到内置 ToRCH2014 中文参照语料资源。"]
            )
        }

        let rawText = try sourceURLs
            .map { try String(contentsOf: $0, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
        let cleaned = CorpusAutoCleaningSupport.clean(rawText)
        let importedAt = timestamp()
        let cleaningSummary = CorpusAutoCleaningSupport.makeReportSummary(
            from: cleaned,
            cleanedAt: importedAt
        )
        try NativeCorpusDatabaseSupport.writeDocument(
            at: storageURL,
            document: DecodedTextDocument(
                text: cleaned.cleanedText,
                encodingName: "UTF-8"
            ),
            sourceType: "db",
            representedPath: Self.torchReferenceRepresentedPath,
            importedAt: importedAt,
            metadataProfile: record.metadata,
            rawText: cleaned.rawText,
            cleaningSummary: cleaningSummary,
            sourceFileCount: sourceURLs.count
        )

        return NativeCorpusRecord(
            id: record.id,
            name: record.name,
            folderId: record.folderId,
            folderName: record.folderName,
            sourceType: record.sourceType,
            representedPath: Self.torchReferenceRepresentedPath,
            storageFileName: record.storageFileName,
            metadata: record.metadata,
            cleaningSummary: cleaningSummary
        )
    }

    private func ensureBundledToRCH2014ReferenceCorpusSet(corpus: NativeCorpusRecord) throws {
        var corpusSets = try loadCorpusSets()
        let now = timestamp()
        let record = NativeCorpusSetRecord(
            id: Self.torchReferenceCorpusSetID,
            name: Self.torchReferenceCorpusSetName,
            corpusIDs: [corpus.id],
            corpusNames: [corpus.name],
            metadataFilterState: .empty,
            createdAt: corpusSets.first {
                $0.id == Self.torchReferenceCorpusSetID || $0.name == Self.torchReferenceCorpusSetName
            }?.createdAt ?? now,
            updatedAt: now
        )

        if let existingIndex = corpusSets.firstIndex(where: {
            $0.id == Self.torchReferenceCorpusSetID || $0.name == Self.torchReferenceCorpusSetName
        }) {
            corpusSets[existingIndex] = record
        } else {
            corpusSets.append(record)
        }
        try saveCorpusSets(corpusSets)
    }
}
