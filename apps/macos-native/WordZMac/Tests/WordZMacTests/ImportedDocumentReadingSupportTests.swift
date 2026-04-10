import XCTest
@testable import WordZMac

final class ImportedDocumentReadingSupportTests: XCTestCase {
    private var temporaryFiles: [URL] = []

    override func tearDown() {
        let fileManager = FileManager.default
        temporaryFiles.forEach { try? fileManager.removeItem(at: $0) }
        temporaryFiles.removeAll()
        super.tearDown()
    }

    func testReadImportedDocumentExtractsNormalizedDOCXText() throws {
        let url = makeTemporaryFileURL(named: "sample.docx")
        try ImportedDocumentTestFixtures.writeDOCX(text: "Hello\u{00A0}DOCX\r\nSecond line", to: url)

        let document = try ImportedDocumentReadingSupport.readImportedDocument(at: url)

        XCTAssertEqual(
            document.text.trimmingCharacters(in: .whitespacesAndNewlines),
            "Hello DOCX\nSecond line"
        )
        XCTAssertEqual(document.encodingName, "")
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
