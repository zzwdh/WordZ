import Foundation
import WordZEngine

package enum EnglishReferenceCorpusDownloadInstaller {
    @MainActor
    package static func downloadAndInstall(
        _ kind: EnglishReferenceCorpusKind,
        userDataURL: URL? = nil,
        seedBundledDefaultReferenceCorpora: Bool = true,
        progress: (@Sendable (String) -> Void)? = nil
    ) async throws -> ReferenceCorpusInstallSummary {
        let descriptor = EnglishReferenceCorpusCatalog.descriptor(for: kind)
        let resolvedUserDataURL = userDataURL ?? EnginePaths.defaultUserDataURL()
        let downloadRoot = resolvedUserDataURL
            .appendingPathComponent("reference-corpus-downloads", isDirectory: true)
            .appendingPathComponent(kind.rawValue, isDirectory: true)
        let preparedRoot = resolvedUserDataURL
            .appendingPathComponent("reference-corpus-prepared", isDirectory: true)
            .appendingPathComponent(kind.rawValue, isDirectory: true)
        let archiveURL = downloadRoot.appendingPathComponent(descriptor.packageFileName)
        let extractionRoot = downloadRoot.appendingPathComponent("extracted", isDirectory: true)

        try FileManager.default.createDirectory(at: downloadRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: preparedRoot, withIntermediateDirectories: true)

        if !FileManager.default.fileExists(atPath: archiveURL.path) {
            progress?("Downloading \(descriptor.shortName)...")
            try await downloadPackage(descriptor: descriptor, destinationURL: archiveURL)
        } else {
            progress?("Using downloaded \(descriptor.shortName) package.")
        }

        progress?("Extracting \(descriptor.shortName)...")
        try? FileManager.default.removeItem(at: extractionRoot)
        try FileManager.default.createDirectory(at: extractionRoot, withIntermediateDirectories: true)
        try extractZipArchive(archiveURL, to: extractionRoot)

        progress?("Preparing \(descriptor.shortName) text...")
        try? FileManager.default.removeItem(at: preparedRoot)
        try FileManager.default.createDirectory(at: preparedRoot, withIntermediateDirectories: true)
        try prepareExtractedCorpus(kind, from: extractionRoot, to: preparedRoot)

        progress?("Installing \(descriptor.shortName) into WordZ...")
        return try await ReferenceCorpusInstaller.installPreparedTextDirectory(
            sourceDirectory: preparedRoot,
            corpusSetName: descriptor.name,
            userDataURL: resolvedUserDataURL,
            mergeIntoSingleCorpus: true,
            seedBundledDefaultReferenceCorpora: seedBundledDefaultReferenceCorpora,
            progress: progress
        )
    }

    package static func prepareExtractedCorpus(
        _ kind: EnglishReferenceCorpusKind,
        from sourceRoot: URL,
        to outputRoot: URL,
        minimumCharacterCount: Int = 80
    ) throws {
        try FileManager.default.createDirectory(at: outputRoot, withIntermediateDirectories: true)
        switch kind {
        case .bnc1994:
            try prepareBNCXML(
                from: sourceRoot,
                to: outputRoot,
                minimumCharacterCount: minimumCharacterCount
            )
        case .oanc:
            try preparePlainTextCorpus(
                from: sourceRoot,
                to: outputRoot,
                minimumCharacterCount: minimumCharacterCount
            )
        }
    }

    private static func downloadPackage(
        descriptor: EnglishReferenceCorpusDescriptor,
        destinationURL: URL
    ) async throws {
        let (temporaryURL, response) = try await URLSession.shared.download(from: descriptor.downloadURL)
        if let httpResponse = response as? HTTPURLResponse,
           !(200..<300).contains(httpResponse.statusCode) {
            throw NSError(
                domain: "WordZMac.EnglishReferenceCorpusDownloadInstaller",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "下载失败：\(descriptor.shortName)"]
            )
        }
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        try FileManager.default.moveItem(at: temporaryURL, to: destinationURL)
    }

    private static func extractZipArchive(_ archiveURL: URL, to destinationURL: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-x", "-k", archiveURL.path, destinationURL.path]

        let errorPipe = Pipe()
        process.standardError = errorPipe
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: data, encoding: .utf8) ?? "无法解压下载文件。"
            throw NSError(
                domain: "WordZMac.EnglishReferenceCorpusDownloadInstaller",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: message]
            )
        }
    }

    private static func prepareBNCXML(
        from sourceRoot: URL,
        to outputRoot: URL,
        minimumCharacterCount: Int
    ) throws {
        let xmlURLs = try sourceFiles(in: sourceRoot, extensions: ["xml"]).filter { url in
            url.path.contains("/Texts/") || url.deletingLastPathComponent().lastPathComponent == "Texts"
        }
        try writePreparedDocuments(
            xmlURLs,
            to: outputRoot,
            minimumCharacterCount: minimumCharacterCount
        ) { url in
            try BNCXMLTextExtractor.extractText(from: url)
        }
    }

    private static func preparePlainTextCorpus(
        from sourceRoot: URL,
        to outputRoot: URL,
        minimumCharacterCount: Int
    ) throws {
        let textURLs = try sourceFiles(in: sourceRoot, extensions: ["txt", "text"]).filter { url in
            let name = url.lastPathComponent.lowercased()
            return !["readme", "license", "licence", "copying", "manifest"].contains { name.contains($0) }
        }
        try writePreparedDocuments(
            textURLs,
            to: outputRoot,
            minimumCharacterCount: minimumCharacterCount
        ) { url in
            try normalizeText(String(contentsOf: url, encoding: .utf8))
        }
    }

    private static func writePreparedDocuments(
        _ urls: [URL],
        to outputRoot: URL,
        minimumCharacterCount: Int,
        transform: (URL) throws -> String
    ) throws {
        var writtenCount = 0
        for url in urls.sorted(by: { $0.path.localizedStandardCompare($1.path) == .orderedAscending }) {
            let text = try transform(url)
            guard text.count >= minimumCharacterCount else { continue }
            let outputURL = outputRoot.appendingPathComponent(preparedFileName(for: url))
            try text.write(to: outputURL, atomically: true, encoding: .utf8)
            writtenCount += 1
        }
        guard writtenCount > 0 else {
            throw NSError(
                domain: "WordZMac.EnglishReferenceCorpusDownloadInstaller",
                code: 10,
                userInfo: [NSLocalizedDescriptionKey: "没有找到可导入的正文文件。"]
            )
        }
    }

    private static func sourceFiles(in root: URL, extensions allowedExtensions: Set<String>) throws -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        return try enumerator.compactMap { item -> URL? in
            guard let url = item as? URL,
                  allowedExtensions.contains(url.pathExtension.lowercased())
            else { return nil }
            let values = try url.resourceValues(forKeys: [.isRegularFileKey])
            return values.isRegularFile == true ? url : nil
        }
    }

    private static func preparedFileName(for url: URL) -> String {
        let baseName = url.deletingPathExtension().lastPathComponent
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "/", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(baseName.isEmpty ? UUID().uuidString : baseName).txt"
    }

    private static func normalizeText(_ value: String) -> String {
        let normalizedNewlines = value
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let collapsedSpaces = normalizedNewlines
            .replacingOccurrences(of: #"[ \t\f\v]+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return collapsedSpaces.isEmpty ? "" : collapsedSpaces + "\n"
    }
}

private final class BNCXMLTextExtractor: NSObject, XMLParserDelegate {
    private var tokens: [String] = []
    private var capturesToken = false

    static func extractText(from url: URL) throws -> String {
        guard let parser = XMLParser(contentsOf: url) else {
            throw NSError(
                domain: "WordZMac.BNCXMLTextExtractor",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "无法读取 BNC XML：\(url.lastPathComponent)"]
            )
        }
        let extractor = BNCXMLTextExtractor()
        parser.delegate = extractor
        guard parser.parse() else {
            throw parser.parserError ?? NSError(
                domain: "WordZMac.BNCXMLTextExtractor",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "无法解析 BNC XML：\(url.lastPathComponent)"]
            )
        }
        return EnglishReferenceCorpusDownloadInstaller.normalizeForBNC(tokens: extractor.tokens)
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        capturesToken = elementName == "w" || elementName == "c"
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard capturesToken else { return }
        let token = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if !token.isEmpty {
            tokens.append(token)
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        capturesToken = false
    }
}

private extension EnglishReferenceCorpusDownloadInstaller {
    static func normalizeForBNC(tokens: [String]) -> String {
        let noSpaceBefore = Set(".,;:!?%)]}’”".map(String.init))
        let noSpaceAfter = Set("([{£$#“‘".map(String.init))
        var output: [String] = []
        var previous = ""

        for token in tokens {
            if output.isEmpty {
                output.append(token)
            } else if noSpaceBefore.contains(token) || token.hasPrefix("'") {
                output[output.count - 1] += token
            } else if noSpaceAfter.contains(previous) {
                output[output.count - 1] += token
            } else {
                output.append(token)
            }
            previous = token
        }

        return normalizeText(output.joined(separator: " "))
    }
}
