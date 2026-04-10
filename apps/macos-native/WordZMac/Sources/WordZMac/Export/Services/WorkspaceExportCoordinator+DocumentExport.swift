import Foundation

extension WorkspaceExportCoordinator {
    func export(
        snapshot: NativeTableExportSnapshot,
        title: String,
        preferredRoute: NativeWindowRoute? = nil
    ) async throws -> String? {
        guard let format = await dialogService.chooseExportFormat(preferredRoute: preferredRoute) else { return nil }
        let suggestedName = "\(snapshot.suggestedBaseName).\(format.allowedExtension)"
        guard let savePath = await dialogService.chooseSavePath(
            title: title,
            suggestedName: suggestedName,
            allowedExtension: format.allowedExtension,
            preferredRoute: preferredRoute
        ) else { return nil }

        switch format {
        case .csv:
            try tableExportService.writeCSV(snapshot: snapshot, to: savePath)
        case .xlsx:
            try await xlsxExportService.write(snapshot: snapshot, to: savePath)
        }
        return savePath
    }

    func export(
        textDocument: PlainTextExportDocument,
        title: String,
        preferredRoute: NativeWindowRoute? = nil
    ) async throws -> String? {
        guard let savePath = await dialogService.chooseSavePath(
            title: title,
            suggestedName: textDocument.suggestedName,
            allowedExtension: "txt",
            preferredRoute: preferredRoute
        ) else {
            return nil
        }
        try textDocument.text.write(to: URL(fileURLWithPath: savePath), atomically: true, encoding: .utf8)
        return savePath
    }
}
