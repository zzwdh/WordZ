import AppKit
import Foundation

enum TableExportFormat: String, CaseIterable {
    case xlsx
    case csv

    var allowedExtension: String {
        switch self {
        case .xlsx:
            return "xlsx"
        case .csv:
            return "csv"
        }
    }
}

@MainActor
final class WorkspaceExportCoordinator {
    private let dialogService: NativeDialogServicing
    private let tableExportService: TableExportService
    private let xlsxExportService: XLSXExportService

    init(
        dialogService: NativeDialogServicing,
        tableExportService: TableExportService = TableExportService(),
        xlsxExportService: XLSXExportService = XLSXExportService()
    ) {
        self.dialogService = dialogService
        self.tableExportService = tableExportService
        self.xlsxExportService = xlsxExportService
    }

    func attach(window: AnyObject?) {
        dialogService.attach(window: window as? NSWindow)
    }

    func exportActiveScene(graph: WorkspaceSceneGraph) async throws -> String? {
        guard let snapshot = exportSnapshot(from: graph) else { return nil }
        return try await export(snapshot: snapshot, title: "导出当前结果")
    }

    func export(snapshot: NativeTableExportSnapshot, title: String) async throws -> String? {
        guard let format = await dialogService.chooseExportFormat() else { return nil }
        let suggestedName = "\(snapshot.suggestedBaseName).\(format.allowedExtension)"
        guard let savePath = await dialogService.chooseSavePath(
            title: title,
            suggestedName: suggestedName,
            allowedExtension: format.allowedExtension
        ) else { return nil }

        switch format {
        case .csv:
            try tableExportService.writeCSV(snapshot: snapshot, to: savePath)
        case .xlsx:
            try await xlsxExportService.write(snapshot: snapshot, to: savePath)
        }
        return savePath
    }

    func export(textDocument: PlainTextExportDocument, title: String) async throws -> String? {
        guard let savePath = await dialogService.chooseSavePath(
            title: title,
            suggestedName: textDocument.suggestedName,
            allowedExtension: "txt"
        ) else {
            return nil
        }
        try textDocument.text.write(to: URL(fileURLWithPath: savePath), atomically: true, encoding: .utf8)
        return savePath
    }

    private func exportSnapshot(from graph: WorkspaceSceneGraph) -> NativeTableExportSnapshot? {
        switch graph.activeTab {
        case .stats:
            return graph.stats.exportSnapshot
        case .word:
            return graph.word.exportSnapshot
        case .tokenize:
            return graph.tokenize.exportSnapshot
        case .topics:
            return graph.topics.exportSnapshot
        case .compare:
            return graph.compare.exportSnapshot
        case .chiSquare:
            return graph.chiSquare.exportSnapshot
        case .ngram:
            return graph.ngram.exportSnapshot
        case .wordCloud:
            return graph.wordCloud.exportSnapshot
        case .kwic:
            return graph.kwic.exportSnapshot
        case .collocate:
            return graph.collocate.exportSnapshot
        case .locator:
            return graph.locator.exportSnapshot
        case .library, .settings:
            return nil
        }
    }
}
