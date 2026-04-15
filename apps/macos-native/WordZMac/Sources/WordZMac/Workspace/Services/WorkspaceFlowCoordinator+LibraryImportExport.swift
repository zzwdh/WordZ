import Foundation

@MainActor
extension WorkspaceFlowCoordinator {
    func exportCurrent(
        features: WorkspaceFeatureSet,
        preferredRoute: NativeWindowRoute? = nil
    ) async {
        await exportWorkflow.exportCurrent(features: features, preferredRoute: preferredRoute)
    }

    func exportTextDocument(
        _ document: PlainTextExportDocument,
        title: String,
        successStatus: String,
        features: WorkspaceFeatureSet,
        preferredRoute: NativeWindowRoute? = nil
    ) async {
        await exportWorkflow.exportTextDocument(
            document,
            title: title,
            successStatus: successStatus,
            features: features,
            preferredRoute: preferredRoute
        )
    }

    func exportSnapshot(
        _ snapshot: NativeTableExportSnapshot,
        title: String,
        successStatus: String,
        features: WorkspaceFeatureSet,
        preferredRoute: NativeWindowRoute? = nil
    ) async {
        await exportWorkflow.exportSnapshot(
            snapshot,
            title: title,
            successStatus: successStatus,
            features: features,
            preferredRoute: preferredRoute
        )
    }

    func importCorpusFromDialog(
        features: WorkspaceFeatureSet,
        preferredRoute: NativeWindowRoute? = nil
    ) async {
        await libraryWorkflow.importCorpusFromDialog(
            features: features,
            preferredRoute: preferredRoute,
            syncFeatureContexts: syncFeatureContexts
        )
    }

    func importExternalPaths(_ paths: [String], features: WorkspaceFeatureSet) async {
        await libraryWorkflow.importExternalPaths(
            paths,
            features: features,
            syncFeatureContexts: syncFeatureContexts
        )
    }

    func handleImportedCorpora(_ result: LibraryImportResult, features: WorkspaceFeatureSet) async throws {
        try await libraryWorkflow.handleImportedCorpora(
            result,
            features: features,
            syncFeatureContexts: syncFeatureContexts
        )
    }

    func runLibraryImport(
        _ paths: [String],
        folderId: String,
        preserveHierarchy: Bool,
        features: WorkspaceFeatureSet
    ) async {
        await libraryWorkflow.runLibraryImport(
            paths,
            folderId: folderId,
            preserveHierarchy: preserveHierarchy,
            features: features,
            syncFeatureContexts: syncFeatureContexts
        )
    }

    func runCorpusCleaning(_ corpusIds: [String], features: WorkspaceFeatureSet) async {
        await libraryWorkflow.runCorpusCleaning(
            corpusIds,
            features: features,
            syncFeatureContexts: syncFeatureContexts
        )
    }
}
