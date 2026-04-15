import Foundation
import WordZHost

package typealias QuickLookPreviewFilePreparing = WordZHost.QuickLookPreviewFilePreparing
package typealias QuickLookPreviewFileService = WordZHost.QuickLookPreviewFileService
package typealias QuickLookPreviewTableSnapshot = WordZHost.QuickLookPreviewTableSnapshot
package typealias QuickLookPreviewTextDocument = WordZHost.QuickLookPreviewTextDocument

extension QuickLookPreviewTableSnapshot {
    init(snapshot: NativeTableExportSnapshot) {
        self.init(
            suggestedBaseName: snapshot.suggestedBaseName,
            headerRow: snapshot.table.csvHeaderRow(),
            rows: snapshot.table.csvRows(from: snapshot.rows),
            metadataLines: snapshot.metadataLines
        )
    }
}

extension QuickLookPreviewTextDocument {
    init(document: PlainTextExportDocument) {
        self.init(
            suggestedName: document.suggestedName,
            text: document.text,
            allowedExtension: document.allowedExtension
        )
    }
}

extension QuickLookPreviewFilePreparing {
    func prepare(snapshot: NativeTableExportSnapshot) throws -> String {
        try prepare(tableSnapshot: QuickLookPreviewTableSnapshot(snapshot: snapshot))
    }

    func prepare(textDocument: PlainTextExportDocument) throws -> String {
        try prepare(textDocument: QuickLookPreviewTextDocument(document: textDocument))
    }
}
