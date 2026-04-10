import Foundation

extension XLSXExportService {
    static func worksheetRows(snapshot: NativeTableExportSnapshot) -> [[String]] {
        var rows = snapshot.metadataLines.map { [$0] }
        if !snapshot.metadataLines.isEmpty {
            rows.append([])
        }
        rows.append(snapshot.table.csvHeaderRow())
        rows.append(contentsOf: snapshot.table.csvRows(from: snapshot.rows))
        return rows
    }

    static func worksheetXML(rows: [[String]], headerRowIndex: Int) -> String {
        let allRows = rows.isEmpty ? [[]] : rows
        let xmlRows = allRows.enumerated().map { rowIndex, values in
            let styleIndex = rowIndex + 1 == headerRowIndex ? 1 : 0
            let cells = values.enumerated().map { columnIndex, value in
                let cellReference = "\(columnName(for: columnIndex + 1))\(rowIndex + 1)"
                return """
                <c r="\(cellReference)" t="inlineStr" s="\(styleIndex)"><is>\(inlineStringTextNode(value))</is></c>
                """
            }.joined()
            return "<row r=\"\(rowIndex + 1)\">\(cells)</row>"
        }.joined()

        let maxColumns = max(allRows.map(\.count).max() ?? 0, 1)
        let lastColumn = columnName(for: maxColumns)
        let dimension = "A1:\(lastColumn)\(max(allRows.count, 1))"
        let columns = (0..<maxColumns).map { index in
            let sampleWidth = allRows
                .prefix(256)
                .compactMap { row -> Int? in
                    guard index < row.count else { return nil }
                    return row[index].count
                }
                .max() ?? 0
            let width = min(max(sampleWidth + 4, 10), 48)
            return "<col min=\"\(index + 1)\" max=\"\(index + 1)\" width=\"\(width)\" customWidth=\"1\"/>"
        }.joined()
        let freezePane = """
          <pane ySplit="\(headerRowIndex)" topLeftCell="A\(headerRowIndex + 1)" activePane="bottomLeft" state="frozen"/>
          <selection pane="bottomLeft"/>
        """
        let autoFilter = headerRowIndex <= allRows.count
            ? "<autoFilter ref=\"A\(headerRowIndex):\(lastColumn)\(headerRowIndex)\"/>"
            : ""

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

    static func xmlEscaped(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
        return escaped
    }
}
