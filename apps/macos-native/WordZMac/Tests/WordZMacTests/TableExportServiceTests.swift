import XCTest
@testable import WordZWorkspaceCore
import WordZExport

final class TableExportServiceTests: XCTestCase {
    func testMakeTSVUsesTabsAndProtectsFormulaLikeTextCells() {
        let snapshot = NativeTableExportSnapshot(
            suggestedBaseName: "paste-safe",
            table: NativeTableDescriptor(columns: [
                NativeTableColumnDescriptor(id: "label", title: "Label", isVisible: true, sortIndicator: nil),
                NativeTableColumnDescriptor(id: "count", title: "Count", isVisible: true, sortIndicator: nil, presentation: .numeric())
            ]),
            rows: [
                NativeTableRowDescriptor(id: "row-1", cells: [
                    "label": .text("=SUM(A1:A2)\nnext"),
                    "count": .integer(-2)
                ])
            ]
        )

        let payload = TableExportService().makeTSV(snapshot: snapshot)

        XCTAssertEqual(payload, "Label\tCount\n'=SUM(A1:A2) next\t-2")
    }

    func testWriteCSVUsesUTF8BOMAndProtectsFormulaLikeTextCells() throws {
        let outputURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("wordz-table-export-\(UUID().uuidString).csv")
        defer { try? FileManager.default.removeItem(at: outputURL) }

        let snapshot = NativeTableExportSnapshot(
            suggestedBaseName: "formula-safe",
            table: NativeTableDescriptor(columns: [
                NativeTableColumnDescriptor(id: "label", title: "Label", isVisible: true, sortIndicator: nil),
                NativeTableColumnDescriptor(id: "count", title: "Count", isVisible: true, sortIndicator: nil, presentation: .numeric())
            ]),
            rows: [
                NativeTableRowDescriptor(id: "row-1", cells: [
                    "label": .text("=SUM(A1:A2)"),
                    "count": .integer(-2)
                ])
            ]
        )

        try TableExportService().writeCSV(snapshot: snapshot, to: outputURL.path)

        let data = try Data(contentsOf: outputURL)
        XCTAssertEqual(Array(data.prefix(3)), [0xEF, 0xBB, 0xBF])

        let text = String(data: data, encoding: .utf8) ?? ""
        XCTAssertTrue(text.contains("\"'=SUM(A1:A2)\""))
        XCTAssertTrue(text.contains("\"-2\""))
        XCTAssertFalse(text.contains("\"'-2\""))
    }

    func testWriteCSVMetadataSidecarKeepsAnalysisMetadataOutOfDataTable() throws {
        let outputURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("wordz-table-sidecar-\(UUID().uuidString).csv")
        let sidecarURL = outputURL
            .deletingPathExtension()
            .deletingLastPathComponent()
            .appendingPathComponent("\(outputURL.deletingPathExtension().lastPathComponent)-metadata.txt")
        defer {
            try? FileManager.default.removeItem(at: outputURL)
            try? FileManager.default.removeItem(at: sidecarURL)
        }

        let snapshot = NativeTableExportSnapshot(
            suggestedBaseName: "sidecar",
            table: NativeTableDescriptor(columns: [
                NativeTableColumnDescriptor(id: "word", title: "Word", isVisible: true, sortIndicator: nil),
                NativeTableColumnDescriptor(id: "count", title: "Count", isVisible: true, sortIndicator: nil, presentation: .numeric())
            ]),
            rows: [
                NativeTableRowDescriptor(id: "row-1", values: ["word": "alpha", "count": "2"])
            ],
            metadataLines: ["Visible Rows: 1"]
        )

        let service = TableExportService()
        try service.writeCSV(snapshot: snapshot, to: outputURL.path)
        let writtenSidecarPath = try service.writeMetadataSidecar(snapshot: snapshot, forCSVPath: outputURL.path)

        XCTAssertEqual(writtenSidecarPath, sidecarURL.path)

        let csvText = try String(contentsOf: outputURL, encoding: .utf8)
        XCTAssertTrue(csvText.contains("\"alpha\""))
        XCTAssertFalse(csvText.contains("Visible Rows: 1"))

        let sidecarText = try String(contentsOf: sidecarURL, encoding: .utf8)
        XCTAssertTrue(sidecarText.contains("Visible Rows: 1"))
        XCTAssertTrue(sidecarText.contains("Column ID\tTitle\tPresentation"))
        XCTAssertTrue(sidecarText.contains("count\tCount\tnumeric"))
    }
}
