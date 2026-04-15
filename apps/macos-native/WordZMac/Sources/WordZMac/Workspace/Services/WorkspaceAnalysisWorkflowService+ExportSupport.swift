import Foundation

@MainActor
extension WorkspaceAnalysisWorkflowService {
    func exportTextDocument(
        _ document: PlainTextExportDocument,
        title: String,
        successStatus: String,
        features: WorkspaceFeatureSet,
        preferredRoute: NativeWindowRoute?
    ) async {
        do {
            if let savedPath = try await exportCoordinator.export(
                textDocument: document,
                title: title,
                preferredRoute: preferredRoute
            ) {
                features.library.setStatus("\(successStatus) \(savedPath)")
                features.sidebar.clearError()
            }
        } catch {
            features.sidebar.setError(error.localizedDescription)
        }
    }
}
