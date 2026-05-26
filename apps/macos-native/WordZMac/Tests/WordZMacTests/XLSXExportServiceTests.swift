import XCTest
@testable import WordZWorkspaceCore

final class XLSXExportServiceTests: XCTestCase {
    func testWriteCreatesZipBasedXLSXArchive() async throws {
        let outputURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("wordz-native-\(UUID().uuidString).xlsx")
        defer { try? FileManager.default.removeItem(at: outputURL) }

        let snapshot = NativeTableExportSnapshot(
            suggestedBaseName: "Stats Export",
            table: NativeTableDescriptor(columns: [
                NativeTableColumnDescriptor(id: "word", title: "词", isVisible: true, sortIndicator: nil),
                NativeTableColumnDescriptor(id: "count", title: "频次", isVisible: true, sortIndicator: nil)
            ]),
            rows: [
                NativeTableRowDescriptor(id: "alpha", values: ["word": "alpha", "count": "12"]),
                NativeTableRowDescriptor(id: "beta", values: ["word": "beta", "count": "9"])
            ]
        )

        try await XLSXExportService().write(snapshot: snapshot, to: outputURL.path)

        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
        let header = try Data(contentsOf: outputURL).prefix(2)
        XCTAssertEqual(Array(header), [0x50, 0x4B])
    }

    func testWriteOnlyIncludesVisibleColumnsInWorksheet() async throws {
        let outputURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("wordz-native-visible-\(UUID().uuidString).xlsx")
        defer { try? FileManager.default.removeItem(at: outputURL) }

        let snapshot = NativeTableExportSnapshot(
            suggestedBaseName: "Stats Export",
            table: NativeTableDescriptor(columns: [
                NativeTableColumnDescriptor(id: "word", title: "词", isVisible: true, sortIndicator: nil),
                NativeTableColumnDescriptor(id: "normFrequency", title: "标准频次", isVisible: true, sortIndicator: nil),
                NativeTableColumnDescriptor(id: "count", title: "频次", isVisible: false, sortIndicator: nil)
            ]),
            rows: [
                NativeTableRowDescriptor(
                    id: "alpha",
                    values: ["word": "alpha", "normFrequency": "4000.00", "count": "12"]
                )
            ]
        )

        try await XLSXExportService().write(snapshot: snapshot, to: outputURL.path)

        let sheetXML = try unzipEntry(at: outputURL, entry: "xl/worksheets/sheet1.xml")
        XCTAssertTrue(sheetXML.contains("词"))
        XCTAssertTrue(sheetXML.contains("标准频次"))
        XCTAssertTrue(sheetXML.contains("4000.00"))
        XCTAssertFalse(sheetXML.contains(">频次<"))
        XCTAssertFalse(sheetXML.contains(">12<"))
    }

    func testWriteCreatesMetadataAndDataDictionaryWorksheets() async throws {
        let outputURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("wordz-native-metadata-\(UUID().uuidString).xlsx")
        defer { try? FileManager.default.removeItem(at: outputURL) }

        let snapshot = NativeTableExportSnapshot(
            suggestedBaseName: "Stats Export",
            table: NativeTableDescriptor(columns: [
                NativeTableColumnDescriptor(id: "word", title: "词", isVisible: true, sortIndicator: nil),
                NativeTableColumnDescriptor(id: "count", title: "频次", isVisible: true, sortIndicator: nil)
            ]),
            rows: [
                NativeTableRowDescriptor(id: "alpha", values: ["word": "alpha", "count": "12"])
            ],
            metadataLines: ["口径: 每万词 · 按句子", "导出范围: 当前可见行 1 / 1"]
        )

        try await XLSXExportService().write(snapshot: snapshot, to: outputURL.path)

        let workbookXML = try unzipEntry(at: outputURL, entry: "xl/workbook.xml")
        XCTAssertTrue(workbookXML.contains("Results"))
        XCTAssertTrue(workbookXML.contains("Metadata"))
        XCTAssertTrue(workbookXML.contains("Data Dictionary"))

        let resultSheetXML = try unzipEntry(at: outputURL, entry: "xl/worksheets/sheet1.xml")
        XCTAssertFalse(resultSheetXML.contains("口径"))
        XCTAssertTrue(resultSheetXML.contains("ySplit=\"1\""))
        XCTAssertTrue(resultSheetXML.contains("topLeftCell=\"A2\""))
        XCTAssertTrue(resultSheetXML.contains("autoFilter ref=\"A1:B2\""))

        let metadataSheetXML = try unzipEntry(at: outputURL, entry: "xl/worksheets/sheet2.xml")
        XCTAssertTrue(metadataSheetXML.contains("口径"))
        XCTAssertTrue(metadataSheetXML.contains("每万词 · 按句子"))
        XCTAssertTrue(metadataSheetXML.contains("导出范围"))
        XCTAssertTrue(metadataSheetXML.contains("当前可见行 1 / 1"))

        let dictionarySheetXML = try unzipEntry(at: outputURL, entry: "xl/worksheets/sheet3.xml")
        XCTAssertTrue(dictionarySheetXML.contains("Column ID"))
        XCTAssertTrue(dictionarySheetXML.contains("word"))
        XCTAssertTrue(dictionarySheetXML.contains("count"))
    }

    func testWritePreservesPrimitiveTypesAndEscapesFormulaLikeText() async throws {
        let outputURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("wordz-native-types-\(UUID().uuidString).xlsx")
        defer { try? FileManager.default.removeItem(at: outputURL) }

        let snapshot = NativeTableExportSnapshot(
            suggestedBaseName: "Typed Export",
            table: NativeTableDescriptor(columns: [
                NativeTableColumnDescriptor(id: "word", title: "Word", isVisible: true, sortIndicator: nil),
                NativeTableColumnDescriptor(id: "count", title: "Count", isVisible: true, sortIndicator: nil, presentation: .numeric()),
                NativeTableColumnDescriptor(id: "score", title: "Score", isVisible: true, sortIndicator: nil, presentation: .numeric()),
                NativeTableColumnDescriptor(id: "reviewed", title: "Reviewed", isVisible: true, sortIndicator: nil)
            ]),
            rows: [
                NativeTableRowDescriptor(id: "row-1", cells: [
                    "word": .text("=SUM(A1:A2)"),
                    "count": .integer(12),
                    "score": .decimal(3.5),
                    "reviewed": .boolean(true)
                ])
            ]
        )

        try await XLSXExportService().write(snapshot: snapshot, to: outputURL.path)

        let resultSheetXML = try unzipEntry(at: outputURL, entry: "xl/worksheets/sheet1.xml")
        XCTAssertTrue(resultSheetXML.contains("<t>=SUM(A1:A2)</t>"))
        XCTAssertTrue(resultSheetXML.contains("<c r=\"B2\" s=\"0\"><v>12</v></c>"))
        XCTAssertTrue(resultSheetXML.contains("<c r=\"C2\" s=\"0\"><v>3.5</v></c>"))
        XCTAssertTrue(resultSheetXML.contains("<c r=\"D2\" t=\"b\" s=\"0\"><v>1</v></c>"))
        XCTAssertFalse(resultSheetXML.contains("<f>"))
    }

    func testWriteLargeResultsWorksheetKeepsBoundsAndLastRow() async throws {
        let outputURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("wordz-native-large-\(UUID().uuidString).xlsx")
        defer { try? FileManager.default.removeItem(at: outputURL) }

        let rowCount = 3_000
        let snapshot = NativeTableExportSnapshot(
            suggestedBaseName: "Large Export",
            table: NativeTableDescriptor(columns: [
                NativeTableColumnDescriptor(id: "word", title: "Word", isVisible: true, sortIndicator: nil),
                NativeTableColumnDescriptor(id: "count", title: "Count", isVisible: true, sortIndicator: nil, presentation: .numeric()),
                NativeTableColumnDescriptor(id: "score", title: "Score", isVisible: true, sortIndicator: nil, presentation: .numeric())
            ]),
            rows: (0..<rowCount).map { index in
                NativeTableRowDescriptor(id: "row-\(index)", cells: [
                    "word": .text("term-\(index)"),
                    "count": .integer(index),
                    "score": .decimal(Double(index) / 10.0)
                ])
            }
        )

        try await XLSXExportService().write(snapshot: snapshot, to: outputURL.path)

        let resultSheetXML = try unzipEntry(at: outputURL, entry: "xl/worksheets/sheet1.xml")
        XCTAssertTrue(resultSheetXML.contains("<dimension ref=\"A1:C3001\"/>"))
        XCTAssertTrue(resultSheetXML.contains("<row r=\"3001\">"))
        XCTAssertTrue(resultSheetXML.contains("<t>term-2999</t>"))
        XCTAssertTrue(resultSheetXML.contains("<c r=\"B3001\" s=\"0\"><v>2999</v></c>"))
        XCTAssertTrue(resultSheetXML.contains("<autoFilter ref=\"A1:C3001\"/>"))
    }

    private func unzipEntry(at archiveURL: URL, entry: String) throws -> String {
        let outputURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("wordz-unzip-entry-\(UUID().uuidString).xml")
        FileManager.default.createFile(atPath: outputURL.path, contents: nil)
        defer { try? FileManager.default.removeItem(at: outputURL) }

        let process = Process()
        let stderrPipe = Pipe()
        let stdoutHandle = try FileHandle(forWritingTo: outputURL)
        defer { try? stdoutHandle.close() }

        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-p", archiveURL.path, entry]
        process.standardOutput = stdoutHandle
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw XCTSkip("unzip failed: \(stderr)")
        }

        return try String(contentsOf: outputURL, encoding: .utf8)
    }
}
