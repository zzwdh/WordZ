import Foundation

import WordZHost
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
    let analysisRuntime: String
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
    let sentimentReviewSampleCount: Int
    let corpusShardFileCount: Int
    let recycleFileCount: Int
    let libraryWALSidecarExists: Bool
    let workspaceWALSidecarExists: Bool
}

struct NativeDiagnosticsAPIRequestMetadata: Codable, Equatable, Sendable {
    let requestID: String
    let method: String
    let host: String
    let path: String
    let statusCode: Int?
    let durationMilliseconds: Int?
    let attemptCount: Int
    let headers: [String: String]
    let cacheState: String?
    let outcome: String

    init(
        requestID: String,
        method: String,
        url: URL,
        statusCode: Int? = nil,
        durationMilliseconds: Int? = nil,
        attemptCount: Int = 1,
        headers: [String: String] = [:],
        cacheState: String? = nil,
        outcome: String
    ) {
        self.requestID = requestID
        self.method = method
        self.host = url.host ?? ""
        self.path = url.path.isEmpty ? "/" : url.path
        self.statusCode = statusCode
        self.durationMilliseconds = durationMilliseconds
        self.attemptCount = attemptCount
        self.headers = headers
        self.cacheState = cacheState
        self.outcome = outcome
    }

    init(
        requestID: String,
        method: String,
        host: String,
        path: String,
        statusCode: Int? = nil,
        durationMilliseconds: Int? = nil,
        attemptCount: Int = 1,
        headers: [String: String] = [:],
        cacheState: String? = nil,
        outcome: String
    ) {
        self.requestID = requestID
        self.method = method
        self.host = host
        self.path = path.isEmpty ? "/" : path
        self.statusCode = statusCode
        self.durationMilliseconds = durationMilliseconds
        self.attemptCount = attemptCount
        self.headers = headers
        self.cacheState = cacheState
        self.outcome = outcome
    }
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
    let apiRequests: [NativeDiagnosticsAPIRequestMetadata]
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
        apiRequests: [NativeDiagnosticsAPIRequestMetadata] = [],
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
        self.apiRequests = apiRequests
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
