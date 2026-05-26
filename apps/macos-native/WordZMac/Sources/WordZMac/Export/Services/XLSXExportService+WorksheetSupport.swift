import Foundation

struct XLSXWorksheet {
    let name: String
    let rows: [[XLSXWorksheetCell]]
    let headerRowIndex: Int?
    let autoFilter: Bool
}

enum XLSXWorksheetCell: Equatable {
    case text(String)
    case number(String)
    case boolean(Bool)

    var displayText: String {
        switch self {
        case .text(let value), .number(let value):
            return value
        case .boolean(let value):
            return value ? "TRUE" : "FALSE"
        }
    }
}

extension XLSXExportService {
    static func metadataRows(
        snapshot: NativeTableExportSnapshot,
        timestamp: String
    ) -> [[XLSXWorksheetCell]] {
        var rows: [[XLSXWorksheetCell]] = [
            [.text("Field"), .text("Value")],
            [.text("Suggested Base Name"), .text(snapshot.suggestedBaseName)],
            [.text("Exported At"), .text(timestamp)],
            [.text("Rows"), .number("\(snapshot.rows.count)")],
            [.text("Visible Columns"), .number("\(snapshot.table.visibleColumns.count)")]
        ]

        if !snapshot.metadataLines.isEmpty {
            rows.append([.text("")])
            rows.append([.text("Analysis Metadata"), .text("")])
            rows.append(
                contentsOf: snapshot.metadataLines.map { line in
                    metadataRow(from: line)
                }
            )
        }

        return rows
    }

    static func dataDictionaryRows(snapshot: NativeTableExportSnapshot) -> [[XLSXWorksheetCell]] {
        var rows: [[XLSXWorksheetCell]] = [
            [.text("Column ID"), .text("Title"), .text("Presentation"), .text("Width Policy"), .text("Pinned")]
        ]
        rows.append(
            contentsOf: snapshot.table.visibleColumns.map { column in
                [
                    .text(column.id),
                    .text(column.title),
                    .text(column.presentation.exportDescription),
                    .text(column.widthPolicy.rawValue),
                    .boolean(column.isPinned)
                ]
            }
        )
        return rows
    }

    static func writeResultsWorksheetXML(
        snapshot: NativeTableExportSnapshot,
        to url: URL
    ) throws {
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        FileManager.default.createFile(atPath: url.path, contents: nil)

        let fileHandle = try FileHandle(forWritingTo: url)
        defer { try? fileHandle.close() }

        let visibleColumns = snapshot.table.visibleColumns
        let maxColumns = max(visibleColumns.count, 1)
        let lastColumn = columnName(for: maxColumns)
        let rowCount = max(snapshot.rows.count + 1, 1)
        let dimension = "A1:\(lastColumn)\(rowCount)"
        let columns = resultColumnDefinitions(snapshot: snapshot, visibleColumns: visibleColumns)
        let freezePane = freezePaneXML(headerRowIndex: 1, rowCount: rowCount)
        let autoFilter = autoFilterXML(
            headerRowIndex: 1,
            rowCount: rowCount,
            lastColumn: lastColumn,
            enabled: true
        )

        try writeXMLFragment("""
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
          <dimension ref="\(dimension)"/>
          <sheetViews>
            <sheetView workbookViewId="0">
        """ + freezePane + """
            </sheetView>
          </sheetViews>
          <sheetFormatPr defaultRowHeight="18"/>
          <cols>\(columns)</cols>
          <sheetData>
        """, to: fileHandle)

        try writeWorksheetRow(
            visibleColumns.map { .text($0.title) },
            rowIndex: 1,
            headerRowIndex: 1,
            to: fileHandle
        )
        for (rowOffset, row) in snapshot.rows.enumerated() {
            let values = visibleColumns.map { column in
                worksheetCell(row.cell(for: column.id), column: column)
            }
            try writeWorksheetRow(
                values,
                rowIndex: rowOffset + 2,
                headerRowIndex: 1,
                to: fileHandle
            )
        }

        try writeXMLFragment("""
          </sheetData>
          \(autoFilter)
        </worksheet>
        """, to: fileHandle)
    }

    static func worksheetCell(
        _ cell: NativeTableCellValue?,
        column: NativeTableColumnDescriptor
    ) -> XLSXWorksheetCell {
        guard let cell else { return .text("") }
        switch cell {
        case .integer(let value):
            return .number("\(value)")
        case .decimal(let value):
            guard value.isFinite else { return .text(cell.stringValue) }
            return .number(String(value))
        case .boolean(let value):
            return .boolean(value)
        case .text(let value), .custom(let value, _):
            if column.isNumeric, let number = numericLiteral(from: value) {
                return .number(number)
            }
            return .text(value)
        }
    }

    static func metadataRow(from line: String) -> [XLSXWorksheetCell] {
        let separators = [": ", "：", ":"]
        for separator in separators {
            guard let range = line.range(of: separator) else { continue }
            let key = line[..<range.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
            let value = line[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
            if !key.isEmpty {
                return [.text(key), .text(value)]
            }
        }
        return [.text("Note"), .text(line)]
    }

    static func worksheetXML(_ worksheet: XLSXWorksheet) -> String {
        let allRows = worksheet.rows.isEmpty ? [[]] : worksheet.rows
        let xmlRows = allRows.enumerated().map { rowIndex, values in
            let styleIndex = rowIndex + 1 == worksheet.headerRowIndex ? 1 : 0
            let cells = values.enumerated().map { columnIndex, value in
                let cellReference = "\(columnName(for: columnIndex + 1))\(rowIndex + 1)"
                return cellXML(value, reference: cellReference, styleIndex: styleIndex)
            }.joined()
            return "<row r=\"\(rowIndex + 1)\">\(cells)</row>"
        }.joined()

        let maxColumns = max(allRows.map(\.count).max() ?? 0, 1)
        let lastColumn = columnName(for: maxColumns)
        let dimension = "A1:\(lastColumn)\(max(allRows.count, 1))"
        let columns = columnDefinitions(rows: allRows, maxColumns: maxColumns)
        let freezePane = freezePaneXML(headerRowIndex: worksheet.headerRowIndex, rowCount: allRows.count)
        let autoFilter = autoFilterXML(
            headerRowIndex: worksheet.headerRowIndex,
            rowCount: allRows.count,
            lastColumn: lastColumn,
            enabled: worksheet.autoFilter
        )

        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
          <dimension ref="\(dimension)"/>
          <sheetViews>
            <sheetView workbookViewId="0">
        """ + freezePane + """
            </sheetView>
          </sheetViews>
          <sheetFormatPr defaultRowHeight="18"/>
          <cols>\(columns)</cols>
          <sheetData>\(xmlRows)</sheetData>
          \(autoFilter)
        </worksheet>
        """
    }

    static func writeWorksheetRow(
        _ values: [XLSXWorksheetCell],
        rowIndex: Int,
        headerRowIndex: Int?,
        to fileHandle: FileHandle
    ) throws {
        let styleIndex = rowIndex == headerRowIndex ? 1 : 0
        let cells = values.enumerated().map { columnIndex, value in
            let cellReference = "\(columnName(for: columnIndex + 1))\(rowIndex)"
            return cellXML(value, reference: cellReference, styleIndex: styleIndex)
        }.joined()
        try writeXMLFragment("<row r=\"\(rowIndex)\">\(cells)</row>", to: fileHandle)
    }

    static func cellXML(
        _ value: XLSXWorksheetCell,
        reference: String,
        styleIndex: Int
    ) -> String {
        switch value {
        case .text(let text):
            return """
            <c r="\(reference)" t="inlineStr" s="\(styleIndex)"><is>\(inlineStringTextNode(text))</is></c>
            """
        case .number(let number):
            return """
            <c r="\(reference)" s="\(styleIndex)"><v>\(xmlEscaped(number))</v></c>
            """
        case .boolean(let bool):
            return """
            <c r="\(reference)" t="b" s="\(styleIndex)"><v>\(bool ? "1" : "0")</v></c>
            """
        }
    }

    static func columnDefinitions(rows: [[XLSXWorksheetCell]], maxColumns: Int) -> String {
        (0..<maxColumns).map { index in
            let sampleWidth = rows
                .prefix(256)
                .compactMap { row -> Int? in
                    guard index < row.count else { return nil }
                    return row[index].displayText.count
                }
                .max() ?? 0
            let width = min(max(sampleWidth + 4, 10), 56)
            return "<col min=\"\(index + 1)\" max=\"\(index + 1)\" width=\"\(width)\" customWidth=\"1\"/>"
        }.joined()
    }

    static func resultColumnDefinitions(
        snapshot: NativeTableExportSnapshot,
        visibleColumns: [NativeTableColumnDescriptor]
    ) -> String {
        let maxColumns = max(visibleColumns.count, 1)
        var widths = visibleColumns.map { $0.title.count }
        if widths.isEmpty {
            widths = [0]
        }

        for row in snapshot.rows.prefix(255) {
            for (index, column) in visibleColumns.enumerated() {
                let cell = worksheetCell(row.cell(for: column.id), column: column)
                widths[index] = max(widths[index], cell.displayText.count)
            }
        }

        return (0..<maxColumns).map { index in
            let sampleWidth = index < widths.count ? widths[index] : 0
            let width = min(max(sampleWidth + 4, 10), 56)
            return "<col min=\"\(index + 1)\" max=\"\(index + 1)\" width=\"\(width)\" customWidth=\"1\"/>"
        }.joined()
    }

    static func freezePaneXML(headerRowIndex: Int?, rowCount: Int) -> String {
        guard let headerRowIndex,
              rowCount > headerRowIndex
        else { return "" }
        return """
          <pane ySplit="\(headerRowIndex)" topLeftCell="A\(headerRowIndex + 1)" activePane="bottomLeft" state="frozen"/>
          <selection pane="bottomLeft"/>
        """
    }

    static func autoFilterXML(
        headerRowIndex: Int?,
        rowCount: Int,
        lastColumn: String,
        enabled: Bool
    ) -> String {
        guard enabled,
              let headerRowIndex,
              headerRowIndex <= rowCount
        else { return "" }
        return "<autoFilter ref=\"A\(headerRowIndex):\(lastColumn)\(max(headerRowIndex, rowCount))\"/>"
    }

    static func numericLiteral(from value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let normalized = trimmed.replacingOccurrences(of: ",", with: "")
        guard let number = Double(normalized),
              number.isFinite
        else { return nil }
        return normalized
    }

    static func columnName(for index: Int) -> String {
        var index = index
        var result = ""
        while index > 0 {
            let remainder = (index - 1) % 26
            let scalarValue = 65 + remainder
            guard let scalar = UnicodeScalar(scalarValue) else {
                return result.isEmpty ? "A" : result
            }
            result = String(scalar) + result
            index = (index - 1) / 26
        }
        return result.isEmpty ? "A" : result
    }

    static func inlineStringTextNode(_ value: String) -> String {
        let escaped = xmlEscaped(value)
        if escaped.hasPrefix(" ") || escaped.hasSuffix(" ") || escaped.contains("\n") {
            return "<t xml:space=\"preserve\">\(escaped)</t>"
        }
        return "<t>\(escaped)</t>"
    }
}

private extension NativeTableColumnPresentation {
    var exportDescription: String {
        switch self {
        case .label:
            return "label"
        case .numeric:
            return "numeric"
        case .keyword:
            return "keyword"
        case .contextLeading:
            return "context-leading"
        case .contextTrailing:
            return "context-trailing"
        case .contextCenter:
            return "context-center"
        case .summary:
            return "summary"
        case .custom(let custom):
            return custom.exportDescription
        }
    }
}

private extension NativeTableCustomColumnPresentation {
    var exportDescription: String {
        switch self {
        case .markerStrip:
            return "marker-strip"
        }
    }
}
