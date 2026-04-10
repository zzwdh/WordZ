import AppKit
import Foundation

@MainActor
protocol WorkspaceExportCoordinating: AnyObject {
    func exportActiveScene(graph: WorkspaceSceneGraph, preferredRoute: NativeWindowRoute?) async throws -> String?
    func exportSnapshot(from graph: WorkspaceSceneGraph) -> NativeTableExportSnapshot?
    func export(snapshot: NativeTableExportSnapshot, title: String, preferredRoute: NativeWindowRoute?) async throws -> String?
    func export(textDocument: PlainTextExportDocument, title: String, preferredRoute: NativeWindowRoute?) async throws -> String?
}

@MainActor
final class WorkspaceExportCoordinator: WorkspaceExportCoordinating {
    let dialogService: NativeDialogServicing
    let tableExportService: TableExportService
    let xlsxExportService: XLSXExportService

    init(
        dialogService: NativeDialogServicing,
        tableExportService: TableExportService = TableExportService(),
        xlsxExportService: XLSXExportService = XLSXExportService()
    ) {
        self.dialogService = dialogService
        self.tableExportService = tableExportService
        self.xlsxExportService = xlsxExportService
    }
}
