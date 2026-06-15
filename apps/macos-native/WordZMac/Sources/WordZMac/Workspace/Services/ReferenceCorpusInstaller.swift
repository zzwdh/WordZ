import Foundation
import WordZEngine

package struct ReferenceCorpusInstallSummary: Equatable, Sendable {
    package let userDataPath: String
    package let corpusSetID: String
    package let corpusSetName: String
    package let corpusIDs: [String]
    package let importedCount: Int
    package let skippedCount: Int
    package let sourceFileCount: Int
    package let failureMessages: [String]
}

package enum ReferenceCorpusInstaller {
    @MainActor
    package static func installPreparedTextDirectory(
        sourceDirectory: URL,
        corpusSetName: String,
        userDataURL: URL? = nil,
        mergeIntoSingleCorpus: Bool = true,
        seedBundledDefaultReferenceCorpora: Bool = true,
        progress: (@Sendable (String) -> Void)? = nil
    ) async throws -> ReferenceCorpusInstallSummary {
        let normalizedName = corpusSetName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedName.isEmpty else {
            throw NSError(
                domain: "WordZMac.ReferenceCorpusInstaller",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "语料集名称不能为空。"]
            )
        }

        let textURLs = try preparedTextURLs(in: sourceDirectory)
        guard !textURLs.isEmpty else {
            throw NSError(
                domain: "WordZMac.ReferenceCorpusInstaller",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "未找到可导入的 .txt 文件：\(sourceDirectory.path)"]
            )
        }

        let resolvedUserDataURL = userDataURL ?? EnginePaths.defaultUserDataURL()
        let repository = NativeWorkspaceRepository(
            rootURL: resolvedUserDataURL,
            seedBundledDefaultReferenceCorpora: seedBundledDefaultReferenceCorpora
        )
        try await repository.start(userDataURL: resolvedUserDataURL)

        progress?("Importing \(textURLs.count) text files into WordZ Library...")
        let result: LibraryImportResult
        if mergeIntoSingleCorpus {
            result = try await repository.importMergedCorpusPaths(
                textURLs.map(\.path),
                name: normalizedName,
                folderId: "",
                progress: { snapshot in
                    progress?(progressMessage(from: snapshot))
                }
            )
        } else {
            result = try await repository.importCorpusPaths(
                textURLs.map(\.path),
                folderId: "",
                preserveHierarchy: true,
                progress: { snapshot in
                    progress?(progressMessage(from: snapshot))
                }
            )
        }

        let corpusIDs = result.importedItems.map(\.id)
        guard !corpusIDs.isEmpty else {
            throw NSError(
                domain: "WordZMac.ReferenceCorpusInstaller",
                code: 3,
                userInfo: [
                    NSLocalizedDescriptionKey: "没有成功导入任何语料。",
                    "failures": result.failureItems.map { "\($0.fileName): \($0.reason)" }
                ]
            )
        }

        let savedSet = try await repository.saveCorpusSet(
            name: normalizedName,
            corpusIDs: corpusIDs,
            metadataFilterState: .empty
        )
        progress?("Saved reference corpus set: \(savedSet.name)")

        return ReferenceCorpusInstallSummary(
            userDataPath: resolvedUserDataURL.path,
            corpusSetID: savedSet.id,
            corpusSetName: savedSet.name,
            corpusIDs: savedSet.corpusIDs,
            importedCount: result.importedCount,
            skippedCount: result.skippedCount,
            sourceFileCount: textURLs.count,
            failureMessages: result.failureItems.map { "\($0.fileName): \($0.reason)" }
        )
    }

    private static func preparedTextURLs(in sourceDirectory: URL) throws -> [URL] {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: sourceDirectory.path, isDirectory: &isDirectory),
              isDirectory.boolValue
        else {
            throw NSError(
                domain: "WordZMac.ReferenceCorpusInstaller",
                code: 4,
                userInfo: [NSLocalizedDescriptionKey: "输入路径不是文件夹：\(sourceDirectory.path)"]
            )
        }

        guard let enumerator = FileManager.default.enumerator(
            at: sourceDirectory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return try enumerator.compactMap { item -> URL? in
            guard let url = item as? URL else { return nil }
            guard url.pathExtension.lowercased() == "txt" else { return nil }
            let values = try url.resourceValues(forKeys: [.isRegularFileKey])
            return values.isRegularFile == true ? url : nil
        }
        .sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
    }

    private static func progressMessage(from snapshot: LibraryImportProgressSnapshot) -> String {
        let percent = Int((snapshot.progress * 100).rounded())
        let currentName = snapshot.currentName.trimmingCharacters(in: .whitespacesAndNewlines)
        if currentName.isEmpty {
            return "\(snapshot.phase.rawValue) \(percent)%"
        }
        return "\(snapshot.phase.rawValue) \(percent)% - \(currentName)"
    }
}
