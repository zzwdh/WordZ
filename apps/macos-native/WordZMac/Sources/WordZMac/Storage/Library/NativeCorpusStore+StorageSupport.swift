import Foundation

extension NativeCorpusStore {
    func expandImportRequests(
        paths: [String],
        preserveHierarchy: Bool,
        folders: inout [NativeFolderRecord]
    ) throws -> NativeExpandedImportRequests {
        var requests: [NativeImportRequest] = []
        var skippedItems: [LibraryImportFailureItem] = []
        for rawPath in paths {
            let sourceURL = URL(fileURLWithPath: rawPath)
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: sourceURL.path, isDirectory: &isDirectory) else { continue }
            if isDirectory.boolValue {
                let baseFolder = preserveHierarchy
                    ? ensureFolder(named: sourceURL.lastPathComponent, folders: &folders)
                    : nil
                let enumerator = fileManager.enumerator(
                    at: sourceURL,
                    includingPropertiesForKeys: [.isRegularFileKey],
                    options: [.skipsHiddenFiles]
                )
                while let nextURL = enumerator?.nextObject() as? URL {
                    let values = try nextURL.resourceValues(forKeys: [.isRegularFileKey])
                    guard values.isRegularFile == true else { continue }
                    if ImportedDocumentReadingSupport.canImport(url: nextURL) {
                        requests.append(NativeImportRequest(sourceURL: nextURL, folder: baseFolder))
                    } else {
                        skippedItems.append(
                            LibraryImportFailureItem(
                                path: nextURL.path,
                                fileName: nextURL.lastPathComponent,
                                reason: ImportedDocumentReadingSupport.unsupportedFormatError(
                                    fileName: nextURL.lastPathComponent
                                ).localizedDescription
                            )
                        )
                    }
                }
            } else {
                requests.append(NativeImportRequest(sourceURL: sourceURL, folder: nil))
            }
        }
        return NativeExpandedImportRequests(requests: requests, skippedItems: skippedItems)
    }

    func ensureFolder(named name: String, folders: inout [NativeFolderRecord]) -> NativeFolderRecord {
        if let existing = folders.first(where: { $0.name == name }) {
            return existing
        }
        let created = NativeFolderRecord(id: UUID().uuidString, name: name)
        folders.append(created)
        return created
    }

    func resolvedFolder(for folderId: String, folders: [NativeFolderRecord]) -> NativeFolderRecord? {
        guard !folderId.isEmpty else { return nil }
        return folders.first(where: { $0.id == folderId })
    }

    func moveStorageToRecycle(for record: NativeCorpusRecord) throws {
        let sourceURL = corporaDirectoryURL.appendingPathComponent(record.storageFileName)
        let recycleURL = recycleDirectoryURL.appendingPathComponent(record.storageFileName)
        if fileManager.fileExists(atPath: sourceURL.path) {
            try? fileManager.removeItem(at: recycleURL)
            try fileManager.moveItem(at: sourceURL, to: recycleURL)
        }
    }

    func restoreStorageFromRecycle(for record: NativeCorpusRecord) throws {
        let recycleURL = recycleDirectoryURL.appendingPathComponent(record.storageFileName)
        let storageURL = corporaDirectoryURL.appendingPathComponent(record.storageFileName)
        if fileManager.fileExists(atPath: recycleURL.path) {
            try? fileManager.removeItem(at: storageURL)
            try fileManager.moveItem(at: recycleURL, to: storageURL)
        }
    }

    func copyDirectoryContents(from source: URL, to destination: URL) throws {
        if isSameOrDescendant(destination, of: source) {
            throw missingItemError("目标目录不能位于源目录内部。")
        }
        try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
        let contents = try fileManager.contentsOfDirectory(at: source, includingPropertiesForKeys: nil)
        for item in contents {
            let target = destination.appendingPathComponent(item.lastPathComponent)
            try? fileManager.removeItem(at: target)
            try fileManager.copyItem(at: item, to: target)
        }
    }

    func removeDirectoryContents(at url: URL) throws {
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
        for item in contents {
            try fileManager.removeItem(at: item)
        }
    }

    func missingItemError(_ message: String) -> NSError {
        NSError(
            domain: "WordZMac.NativeCorpusStore",
            code: 404,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }

    func timestamp() -> String {
        NativeDateFormatting.iso8601String(from: Date())
    }

    func compactTimestamp() -> String {
        NativeDateFormatting.compactTimestampString(from: Date())
    }

    func standardizedDirectoryURL(_ url: URL) -> URL {
        let standardized = url.standardizedFileURL
        guard standardized.hasDirectoryPath else {
            return standardized.deletingLastPathComponent()
        }
        return standardized
    }

    func isSameOrDescendant(_ candidate: URL, of parent: URL) -> Bool {
        let normalizedCandidate = standardizedDirectoryURL(candidate)
        let normalizedParent = standardizedDirectoryURL(parent)
        return normalizedCandidate.path == normalizedParent.path
            || normalizedCandidate.path.hasPrefix(normalizedParent.path + "/")
    }

    func readStoredCorpusText(at url: URL, record: NativeCorpusRecord) throws -> String {
        if let document = try NativeCorpusDatabaseSupport.readDocument(at: url) {
            return document.text
        }

        if let document = try readStoredCorpusDocumentIfPresent(at: url) {
            let decoded = DecodedTextDocument(text: document.text, encodingName: document.detectedEncoding)
            try NativeCorpusDatabaseSupport.writeDocument(
                at: url,
                document: decoded,
                sourceType: document.sourceType,
                representedPath: document.representedPath,
                importedAt: document.importedAt,
                metadataProfile: record.metadata
            )
            return document.text
        }

        let decoded = try TextFileDecodingSupport.readTextDocument(at: url)
        try NativeCorpusDatabaseSupport.writeDocument(
            at: url,
            document: decoded,
            sourceType: record.sourceType,
            representedPath: record.representedPath,
            importedAt: timestamp(),
            metadataProfile: record.metadata
        )
        return decoded.text
    }

    func readStoredCorpusDocumentIfPresent(at url: URL) throws -> NativeStoredCorpusDocument? {
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        return try? decoder.decode(NativeStoredCorpusDocument.self, from: data)
    }

    func shouldRefreshCorpusMetadata(_ metadata: NativeStoredCorpusMetadata) -> Bool {
        metadata.ttr == 0 && metadata.tokenCount > 0
    }

    func corpusInfoSummary(
        from record: NativeCorpusRecord,
        metadata: NativeStoredCorpusMetadata,
        fallbackPath: String
    ) -> CorpusInfoSummary {
        CorpusInfoSummary(json: [
            "corpusId": record.id,
            "title": record.name,
            "folderName": record.folderName,
            "sourceType": metadata.sourceType.isEmpty ? record.sourceType : metadata.sourceType,
            "representedPath": metadata.representedPath.isEmpty ? (record.representedPath.isEmpty ? fallbackPath : record.representedPath) : metadata.representedPath,
            "detectedEncoding": metadata.detectedEncoding,
            "importedAt": metadata.importedAt,
            "tokenCount": metadata.tokenCount,
            "typeCount": metadata.typeCount,
            "sentenceCount": metadata.sentenceCount,
            "paragraphCount": metadata.paragraphCount,
            "characterCount": metadata.characterCount,
            "ttr": metadata.ttr > 0 ? metadata.ttr : fallbackTTR(typeCount: metadata.typeCount, tokenCount: metadata.tokenCount),
            "sttr": metadata.sttr,
            "metadata": metadata.metadataProfile.merged(over: record.metadata).jsonObject
        ])
    }

    func fallbackTTR(typeCount: Int, tokenCount: Int) -> Double {
        guard tokenCount > 0 else { return 0 }
        return Double(typeCount) / Double(tokenCount)
    }

    func isStoredCorpusReadable(at url: URL) -> Bool {
        if let databaseDocument = try? NativeCorpusDatabaseSupport.readDocument(at: url) {
            return !databaseDocument.text.isEmpty || databaseDocument.metadata.characterCount == 0
        }
        if (try? readStoredCorpusDocumentIfPresent(at: url)) != nil {
            return true
        }
        return (try? TextFileDecodingSupport.readTextDocument(at: url)) != nil
    }
}
