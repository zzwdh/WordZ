import XCTest
@testable import WordZWorkspaceCore

final class ImportedDocumentReadingSupportTests: XCTestCase {
    private var temporaryFiles: [URL] = []

    override func tearDown() {
        let fileManager = FileManager.default
        temporaryFiles.forEach { try? fileManager.removeItem(at: $0) }
        temporaryFiles.removeAll()
        super.tearDown()
    }

    func testReadImportedDocumentPreservesRawDOCXTextForLaterCleaning() throws {
        let url = makeTemporaryFileURL(named: "sample.docx")
        try ImportedDocumentTestFixtures.writeDOCX(text: "Hello\u{00A0}DOCX\r\nSecond line", to: url)

        let document = try ImportedDocumentReadingSupport.readImportedDocument(at: url)

        XCTAssertEqual(
            document.text.trimmingCharacters(in: .whitespacesAndNewlines),
            "Hello\u{00A0}DOCX\nSecond line"
        )
        XCTAssertEqual(document.encodingName, "")
    }

    func testReadImportedDocumentPreservesRawTXTTextForLaterCleaning() throws {
        let url = makeTemporaryFileURL(named: "sample.txt")
        let rawText = "\u{FEFF}\nAlpha\u{00A0}Beta\t\u{200B}\r\nLine\u{0000} two  \n\n"
        try rawText.write(to: url, atomically: true, encoding: .utf8)

        let document = try ImportedDocumentReadingSupport.readImportedDocument(at: url)

        XCTAssertEqual(document.text, rawText)
        XCTAssertEqual(document.encodingName, "utf-8")
    }

    func testCorpusAutoCleaningNormalizesWhitespaceAndInvisibleCharacters() {
        let result = CorpusAutoCleaningSupport.clean("\u{FEFF}\nAlpha\u{00A0}Beta\t\u{200B}\r\nLine\u{0000} two  \n\n")

        XCTAssertEqual(result.cleanedText, "Alpha Beta\nLine two")
        XCTAssertEqual(result.ruleHits.map(\.id), [
            "compatibility-mapping",
            "line-ending-normalization",
            "space-normalization",
            "bom-removal",
            "zero-width-removal",
            "null-removal",
            "trailing-whitespace-trim",
            "outer-blank-line-trim"
        ])
    }

    func testReadImportedDocumentExtractsPDFText() throws {
        let url = makeTemporaryFileURL(named: "sample.pdf")
        try ImportedDocumentTestFixtures.writePDF(text: "Hello PDF", to: url)

        let document = try ImportedDocumentReadingSupport.readImportedDocument(at: url)

        XCTAssertEqual(document.text.trimmingCharacters(in: .whitespacesAndNewlines), "Hello PDF")
        XCTAssertEqual(document.encodingName, "")
    }

    func testReadImportedDocumentRejectsUnsupportedExtension() {
        let url = URL(fileURLWithPath: "/tmp/sample.png")

        XCTAssertThrowsError(try ImportedDocumentReadingSupport.readImportedDocument(at: url)) { error in
            XCTAssertTrue(error.localizedDescription.contains("暂不支持读取该语料文件格式"))
        }
    }

    func testReadImportedDocumentRejectsDOCXWithoutUsableText() throws {
        let url = makeTemporaryFileURL(named: "empty.docx")
        try ImportedDocumentTestFixtures.writeDOCX(text: "", to: url)

        XCTAssertThrowsError(try ImportedDocumentReadingSupport.readImportedDocument(at: url)) { error in
            XCTAssertTrue(error.localizedDescription.contains("未提取到可用文本"))
        }
    }

    func testReadImportedDocumentRejectsPDFWithoutUsableText() throws {
        let url = makeTemporaryFileURL(named: "empty.pdf")
        try ImportedDocumentTestFixtures.writePDF(text: "", to: url)

        XCTAssertThrowsError(try ImportedDocumentReadingSupport.readImportedDocument(at: url)) { error in
            XCTAssertTrue(error.localizedDescription.contains("未提取到可用文本"))
        }
    }

    private func makeTemporaryFileURL(named fileName: String) -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("wordz-imported-document-\(UUID().uuidString)-\(fileName)", isDirectory: false)
        temporaryFiles.append(url)
        return url
    }
}
