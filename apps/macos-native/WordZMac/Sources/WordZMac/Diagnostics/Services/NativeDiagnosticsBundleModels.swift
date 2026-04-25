import Foundation

struct NativeDiagnosticsBundleArtifact: Equatable, Sendable {
    let archiveURL: URL
    let workingDirectoryURL: URL
}

struct NativeDiagnosticsBundleContext: Codable, Equatable, Sendable {
    let generatedAt: String
    let appName: String
    let versionLabel: String
    let buildSummary: String
    let workspaceSummary: String
    let activeTab: String
    let selectedFolderName: String
    let selectedCorpusName: String
    let engineEntryPath: String
    let runtimeWorkingDirectory: String
    let userDataDirectory: String
    let taskCenterSummary: String
    let runningTaskCount: Int
    let persistedTaskCount: Int
}

struct NativeDiagnosticsBundleSourceFile: Equatable, Sendable {
    let sourceURL: URL
    let relativePath: String
    let description: String
}

struct NativeDiagnosticsBundleGeneratedFile: Equatable, Sendable {
    let data: Data
    let relativePath: String
    let description: String
}

struct NativeDiagnosticsStorageSnapshot: Codable, Equatable, Sendable {
    let rootPath: String
    let libraryDatabaseExists: Bool
    let workspaceDatabaseExists: Bool
    let librarySchemaVersion: Int
    let workspaceSchemaVersion: Int
    let folderCount: Int
    let activeCorpusCount: Int
    let quarantinedCorpusCount: Int
    let corpusSetCount: Int
    let recycleEntryCount: Int
    let pendingShardMigrationCount: Int
    let workspaceSnapshotCount: Int
    let uiSettingsCount: Int
    let analysisPresetCount: Int
    let keywordSavedListCount: Int
    let concordanceSavedSetCount: Int
    let evidenceItemCount: Int
    let sentimentReviewSampleCount: Int
    let corpusShardFileCount: Int
    let recycleFileCount: Int
    let libraryWALSidecarExists: Bool
    let workspaceWALSidecarExists: Bool
}

struct NativeDiagnosticsBundlePayload: Sendable {
    let bundleBaseName: String
    let reportText: String
    let buildMetadata: NativeBuildMetadata
    let context: NativeDiagnosticsBundleContext
    let hostPreferences: NativeHostPreferencesSnapshot
    let taskHistory: [PersistedNativeBackgroundTaskItem]
    let workspaceDraft: WorkspaceStateDraft
    let uiSettings: UISettingsSnapshot
    let generatedFiles: [NativeDiagnosticsBundleGeneratedFile]
    let extraFiles: [NativeDiagnosticsBundleSourceFile]

    init(
        bundleBaseName: String,
        reportText: String,
        buildMetadata: NativeBuildMetadata,
        context: NativeDiagnosticsBundleContext,
        hostPreferences: NativeHostPreferencesSnapshot,
        taskHistory: [PersistedNativeBackgroundTaskItem],
        workspaceDraft: WorkspaceStateDraft,
        uiSettings: UISettingsSnapshot,
        generatedFiles: [NativeDiagnosticsBundleGeneratedFile] = [],
        extraFiles: [NativeDiagnosticsBundleSourceFile]
    ) {
        self.bundleBaseName = bundleBaseName
        self.reportText = reportText
        self.buildMetadata = buildMetadata
        self.context = context
        self.hostPreferences = hostPreferences
        self.taskHistory = taskHistory
        self.workspaceDraft = workspaceDraft
        self.uiSettings = uiSettings
        self.generatedFiles = generatedFiles
        self.extraFiles = extraFiles
    }
}

struct NativeDiagnosticsBundleManifest: Codable, Equatable {
    let generatedAt: String
    let bundleBaseName: String
    let includedFiles: [NativeDiagnosticsBundleManifestEntry]
}

struct NativeDiagnosticsBundleManifestEntry: Codable, Equatable {
    let path: String
    let description: String
}
