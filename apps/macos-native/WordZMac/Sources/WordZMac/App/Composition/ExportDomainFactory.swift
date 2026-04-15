import Foundation

@MainActor
struct ExportDomainFactory {
    func makeReportBundleService() -> any AnalysisReportBundleServicing {
        AnalysisReportBundleService()
    }

    func makeWorkspaceExportCoordinator(dialogService: NativeDialogServicing) -> any WorkspaceExportCoordinating {
        WorkspaceExportCoordinator(dialogService: dialogService)
    }
}
