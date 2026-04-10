import Foundation

@MainActor
struct ExportDomainFactory {
    func makeQuickLookPreviewFileService() -> any QuickLookPreviewFilePreparing {
        QuickLookPreviewFileService()
    }

    func makeReportBundleService() -> any AnalysisReportBundleServicing {
        AnalysisReportBundleService()
    }

    func makeWorkspaceExportCoordinator(dialogService: NativeDialogServicing) -> any WorkspaceExportCoordinating {
        WorkspaceExportCoordinator(dialogService: dialogService)
    }
}

