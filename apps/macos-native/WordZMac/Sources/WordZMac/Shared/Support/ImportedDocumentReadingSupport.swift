import AppKit
import Foundation
import PDFKit

enum ImportedDocumentReadingSupport {
    static let supportedImportExtensions = ["txt", "docx", "pdf"]

    static func canImport(url: URL) -> Bool {
        supportedImportExtensions.contains(url.pathExtension.lowercased())
    }

    static func readImportedDocument(at url: URL) throws -> DecodedTextDocument {
        let pathExtension = url.pathExtension.lowercased()

        switch pathExtension {
        case "txt":
            return try TextFileDecodingSupport.readTextDocument(at: url)
        case "docx":
            return try readDOCXDocument(at: url)
        case "pdf":
            return try readPDFDocument(at: url)
        default:
            throw unsupportedFormatError(fileName: url.lastPathComponent)
        }
    }

    static func unsupportedFormatError(fileName: String) -> NSError {
        NSError(
            domain: "WordZMac.ImportedDocumentReadingSupport",
            code: 415,
            userInfo: [NSLocalizedDescriptionKey: "暂不支持读取该语料文件格式：\(fileName)"]
        )
    }

    private static func readDOCXDocument(at url: URL) throws -> DecodedTextDocument {
        let attributedString: NSAttributedString
        do {
            attributedString = try NSAttributedString(
                url: url,
                options: [.documentType: NSAttributedString.DocumentType.officeOpenXML],
                documentAttributes: nil
            )
        } catch {
            throw wrappedReadError(fileName: url.lastPathComponent, formatName: "DOCX", underlyingError: error)
        }

        return try finalizedDocument(
            text: attributedString.string,
            encodingName: "",
            fileName: url.lastPathComponent
        )
    }

    private static func readPDFDocument(at url: URL) throws -> DecodedTextDocument {
        guard let document = PDFDocument(url: url) else {
            throw wrappedReadError(fileName: url.lastPathComponent, formatName: "PDF", underlyingError: nil)
        }

        var pageTexts: [String] = []
        pageTexts.reserveCapacity(document.pageCount)

        for pageIndex in 0..<document.pageCount {
            if let pageText = document.page(at: pageIndex)?.string {
                pageTexts.append(pageText)
            }
        }

        return try finalizedDocument(
            text: pageTexts.joined(separator: "\n\n"),
            encodingName: "",
            fileName: url.lastPathComponent
        )
    }

    private static func finalizedDocument(
        text: String,
        encodingName: String,
        fileName: String
    ) throws -> DecodedTextDocument {
        let normalizedText = normalizeImportedText(text)
        guard !normalizedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw emptyDocumentError(fileName: fileName)
        }
        return DecodedTextDocument(text: normalizedText, encodingName: encodingName)
    }

    private static func normalizeImportedText(_ text: String) -> String {
        text
            .precomposedStringWithCompatibilityMapping
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\u{000C}", with: "\n")
            .replacingOccurrences(of: "\u{2028}", with: "\n")
            .replacingOccurrences(of: "\u{2029}", with: "\n")
            .replacingOccurrences(of: "\u{00A0}", with: " ")
    }

    private static func emptyDocumentError(fileName: String) -> NSError {
        NSError(
            domain: "WordZMac.ImportedDocumentReadingSupport",
            code: 422,
            userInfo: [NSLocalizedDescriptionKey: "未提取到可用文本：\(fileName)。可能是空文档或扫描版 PDF。"]
        )
    }

    private static func wrappedReadError(
        fileName: String,
        formatName: String,
        underlyingError: Error?
    ) -> NSError {
        var userInfo: [String: Any] = [
            NSLocalizedDescriptionKey: "无法读取 \(formatName) 文档：\(fileName)"
        ]
        if let underlyingError {
            userInfo[NSUnderlyingErrorKey] = underlyingError
        }
        return NSError(
            domain: "WordZMac.ImportedDocumentReadingSupport",
            code: 500,
            userInfo: userInfo
        )
    }
}
