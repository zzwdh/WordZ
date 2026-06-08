import Foundation

@MainActor
extension LibraryManagementViewModel {
    func makeImportPreflightScene(
        paths: [String],
        preserveHierarchy: Bool,
        languageMode: AppLanguageMode = WordZLocalization.shared.effectiveMode
    ) -> LibraryImportPreflightSceneModel {
        let scanner = LibraryImportPreflightScanner(
            paths: paths,
            existingCorpora: librarySnapshot.corpora,
            preserveHierarchy: preserveHierarchy,
            languageMode: languageMode
        )
        let result = scanner.scan()

        return LibraryImportPreflightSceneModel(
            id: UUID().uuidString,
            title: wordZText("导入语料", "Import Corpus", mode: languageMode),
            subtitle: String(
                format: wordZText("将检查 %d 个入口，并把可导入文本合并为一个可分析语料（.db 格式）。", "Checking %d selected entries and merging importable text into one analyzable corpus (.db format).", mode: languageMode),
                paths.count
            ),
            paths: paths,
            defaultCorpusName: wordZText("我的语料库", "My Corpus Library", mode: languageMode),
            fileCountText: "\(result.fileCount)",
            folderCountText: "\(result.folderCount)",
            supportedCountText: "\(result.supportedCount)",
            unsupportedCountText: "\(result.unsupportedCount)",
            duplicateRiskCountText: "\(result.duplicateRiskCount)",
            preserveHierarchyText: wordZText("可导入文件会合并为一个可分析语料", "Importable files will be merged into one analyzable corpus", mode: languageMode),
            warnings: result.warnings,
            previewItems: result.previewItems
        )
    }

    func presentImportPreflight(paths: [String], preserveHierarchy: Bool) {
        importPreflightSheet = makeImportPreflightScene(
            paths: paths,
            preserveHierarchy: preserveHierarchy
        )
    }

    func dismissImportPreflight() {
        importPreflightSheet = nil
    }
}

private struct LibraryImportPreflightScanner {
    let paths: [String]
    let existingCorpora: [LibraryCorpusItem]
    let preserveHierarchy: Bool
    let languageMode: AppLanguageMode

    private let fileManager = FileManager.default
    private let previewLimit = 10

    func scan() -> LibraryImportPreflightResult {
        let existingNames = Set(
            existingCorpora.flatMap { corpus in
                [
                    corpus.name.lowercased(),
                    URL(fileURLWithPath: corpus.representedPath).deletingPathExtension().lastPathComponent.lowercased(),
                    URL(fileURLWithPath: corpus.representedPath).lastPathComponent.lowercased()
                ]
            }
            .filter { !$0.isEmpty }
        )

        var fileURLs: [URL] = []
        var folderCount = 0
        var previewItems: [LibraryImportPreflightPreviewItem] = []

        for path in paths {
            let url = URL(fileURLWithPath: path).standardizedFileURL
            if isDirectory(url) {
                folderCount += 1
                appendPreview(
                    url: url,
                    detail: wordZText("文件夹 · 将递归扫描", "Folder · scanned recursively", mode: languageMode),
                    isSupported: true,
                    previewItems: &previewItems
                )
                fileURLs.append(contentsOf: importCandidateFiles(in: url))
            } else {
                fileURLs.append(url)
                appendPreview(
                    url: url,
                    detail: fileDetail(for: url),
                    isSupported: ImportedDocumentReadingSupport.canImport(url: url),
                    previewItems: &previewItems
                )
            }
        }

        let supportedURLs = fileURLs.filter { ImportedDocumentReadingSupport.canImport(url: $0) }
        let unsupportedCount = max(0, fileURLs.count - supportedURLs.count)
        let duplicateRiskCount = supportedURLs.filter { url in
            let baseName = url.deletingPathExtension().lastPathComponent.lowercased()
            return existingNames.contains(baseName) || existingNames.contains(url.lastPathComponent.lowercased())
        }.count

        return LibraryImportPreflightResult(
            fileCount: fileURLs.count,
            folderCount: folderCount,
            supportedCount: supportedURLs.count,
            unsupportedCount: unsupportedCount,
            duplicateRiskCount: duplicateRiskCount,
            warnings: warnings(
                supportedCount: supportedURLs.count,
                unsupportedCount: unsupportedCount,
                duplicateRiskCount: duplicateRiskCount,
                folderCount: folderCount
            ),
            previewItems: previewItems
        )
    }

    private func importCandidateFiles(in folderURL: URL) -> [URL] {
        guard let enumerator = fileManager.enumerator(
            at: folderURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var urls: [URL] = []
        for case let url as URL in enumerator {
            guard !isDirectory(url) else { continue }
            urls.append(url)
        }
        return urls
    }

    private func appendPreview(
        url: URL,
        detail: String,
        isSupported: Bool,
        previewItems: inout [LibraryImportPreflightPreviewItem]
    ) {
        guard previewItems.count < previewLimit else { return }
        previewItems.append(
            LibraryImportPreflightPreviewItem(
                id: url.path,
                title: url.lastPathComponent,
                detail: detail,
                isSupported: isSupported
            )
        )
    }

    private func fileDetail(for url: URL) -> String {
        let ext = url.pathExtension.isEmpty ? "—" : url.pathExtension.uppercased()
        return ImportedDocumentReadingSupport.canImport(url: url)
            ? "\(ext) · \(wordZText("可导入", "Importable", mode: languageMode))"
            : "\(ext) · \(wordZText("会跳过", "Skipped", mode: languageMode))"
    }

    private func isDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else { return false }
        return isDirectory.boolValue
    }

    private func warnings(
        supportedCount: Int,
        unsupportedCount: Int,
        duplicateRiskCount: Int,
        folderCount: Int
    ) -> [LibraryImportPreflightWarningSceneItem] {
        var warnings: [LibraryImportPreflightWarningSceneItem] = []

        if supportedCount == 0 {
            warnings.append(
                .init(
                    id: "no-supported-files",
                    title: wordZText("没有可导入文件", "No importable files", mode: languageMode),
                    detail: wordZText("请选择 TXT、DOCX 或 PDF 文件，或包含这些文件的文件夹。", "Choose TXT, DOCX, or PDF files, or folders containing them.", mode: languageMode),
                    systemImage: "exclamationmark.triangle"
                )
            )
        }
        if unsupportedCount > 0 {
            warnings.append(
                .init(
                    id: "unsupported-files",
                    title: String(format: wordZText("%d 个文件会被跳过", "%d files will be skipped", mode: languageMode), unsupportedCount),
                    detail: wordZText("当前导入器只读取 TXT、DOCX、PDF，其他格式不会写入语料库。", "The importer only reads TXT, DOCX, and PDF; other formats are not added.", mode: languageMode),
                    systemImage: "doc.badge.ellipsis"
                )
            )
        }
        if duplicateRiskCount > 0 {
            warnings.append(
                .init(
                    id: "duplicate-risk",
                    title: String(format: wordZText("%d 个文件可能同名", "%d files may duplicate existing names", mode: languageMode), duplicateRiskCount),
                    detail: wordZText("这不会阻止导入，但建议导入后检查命名和元数据。", "This does not block import, but review names and metadata afterwards.", mode: languageMode),
                    systemImage: "exclamationmark.arrow.triangle.2.circlepath"
                )
            )
        }
        if folderCount > 0 {
            warnings.append(
                .init(
                    id: "preserve-hierarchy",
                    title: wordZText("文件夹会递归读取", "Folders will be scanned recursively", mode: languageMode),
                    detail: wordZText("找到的可导入文件会进入同一个 DB 语料库。", "Importable files found inside folders are added to the same DB corpus.", mode: languageMode),
                    systemImage: "folder.badge.gearshape"
                )
            )
        }

        return warnings
    }
}

private struct LibraryImportPreflightResult {
    let fileCount: Int
    let folderCount: Int
    let supportedCount: Int
    let unsupportedCount: Int
    let duplicateRiskCount: Int
    let warnings: [LibraryImportPreflightWarningSceneItem]
    let previewItems: [LibraryImportPreflightPreviewItem]
}
