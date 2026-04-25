import Foundation
import WordZEngine

@MainActor
extension MainWorkspaceViewModel {
    func exportDiagnostics(preferredWindowRoute: NativeWindowRoute? = nil) async {
        let taskID = taskCenter.beginTask(
            title: t("导出诊断包", "Export Diagnostics Bundle"),
            detail: t("正在整理运行状态与工作区快照…", "Collecting runtime state and workspace snapshots…"),
            progress: 0
        )

        do {
            let payload = try makeDiagnosticsPayload()
            let artifact = try diagnosticsBundleService.buildBundle(payload: payload)
            defer { diagnosticsBundleService.cleanup(artifact) }

            let suggestedName = "\(payload.bundleBaseName).zip"
            if let savedPath = try await hostActionService.exportDiagnosticBundle(
                archivePath: artifact.archiveURL.path,
                suggestedName: suggestedName,
                preferredRoute: preferredWindowRoute?.hostPresentationHint
            ) {
                settings.setSupportStatus("\(t("已导出诊断包到", "Exported diagnostics bundle to")) \(savedPath)")
                clearActiveIssue()
                taskCenter.completeTask(
                    id: taskID,
                    detail: savedPath,
                    action: .openFile(path: savedPath)
                )
            } else {
                let cancelled = t("已取消导出诊断包。", "Diagnostics export was cancelled.")
                settings.setSupportStatus(cancelled)
                taskCenter.failTask(id: taskID, detail: cancelled)
            }
        } catch {
            presentIssue(
                error,
                titleZh: "导出诊断包失败",
                titleEn: "Diagnostics Export Failed",
                recoveryAction: .exportDiagnostics
            )
            taskCenter.failTask(id: taskID, detail: error.localizedDescription)
        }
    }

    private func makeDiagnosticsPayload() throws -> NativeDiagnosticsBundlePayload {
        let generatedAt = ISO8601DateFormatter().string(from: Date())
        let hostPreferences = hostPreferencesStore.load()
        let redactedHostPreferences = hostPreferences.redactedForDiagnostics()
        let buildMetadata = buildMetadataProvider.current().redactedForDiagnostics()
        let workspaceDraft = flowCoordinator.currentWorkspaceDraft(features: features)
        let uiSettings = settings.exportSnapshot()
        let redactedTaskHistory = taskCenter.persistedHistory().map { $0.redactedForDiagnostics() }
        let engineEntryPath = (try? EnginePaths.engineEntryURL().path) ?? ""
        let startupCrashLogURL = EnginePaths.startupCrashLogURL()
        let storageSnapshot = makeDiagnosticsStorageSnapshot(userDataDirectory: settings.scene.userDataDirectory)?
            .redactedForDiagnostics()

        let context = NativeDiagnosticsBundleContext(
            generatedAt: generatedAt,
            appName: sceneGraph.context.appName,
            versionLabel: sceneGraph.context.versionLabel,
            buildSummary: sceneGraph.context.buildSummary,
            workspaceSummary: sceneGraph.context.workspaceSummary,
            activeTab: selectedTab.snapshotValue,
            selectedFolderName: library.selectedFolder?.name ?? t("全部语料", "All Corpora"),
            selectedCorpusName: library.selectedCorpus?.name ?? sidebar.selectedCorpus?.name ?? "",
            engineEntryPath: engineEntryPath,
            runtimeWorkingDirectory: EnginePaths.runtimeWorkingDirectoryURL().path,
            userDataDirectory: settings.scene.userDataDirectory,
            taskCenterSummary: taskCenter.scene.summary,
            runningTaskCount: taskCenter.scene.runningCount,
            persistedTaskCount: redactedTaskHistory.count
        ).redactedForDiagnostics()

        var generatedFiles = [
            try makeJSONObjectDiagnosticsFile(
                workspaceDraft.asJSONObject(),
                relativePath: "persisted/workspace-snapshot.json",
                description: "Sanitized persisted workspace snapshot."
            ),
            try makeJSONObjectDiagnosticsFile(
                uiSettings.asJSONObject(),
                relativePath: "persisted/ui-settings.json",
                description: "Sanitized persisted UI settings."
            ),
            try makeJSONDiagnosticsFile(
                redactedHostPreferences,
                relativePath: "persisted/native-host-preferences.json",
                description: "Sanitized persisted host preferences."
            )
        ]
        if let storageSnapshot {
            generatedFiles.append(
                try makeJSONDiagnosticsFile(
                    storageSnapshot,
                    relativePath: "storage-snapshot.json",
                    description: "Current local storage topology and migration summary."
                )
            )
        }

        let extraFiles: [NativeDiagnosticsBundleSourceFile] = FileManager.default.fileExists(atPath: startupCrashLogURL.path)
            ? [
                NativeDiagnosticsBundleSourceFile(
                    sourceURL: startupCrashLogURL,
                    relativePath: "logs/startup-crash.log",
                    description: "Captured startup crash log."
                )
            ]
            : []

        return NativeDiagnosticsBundlePayload(
            bundleBaseName: "WordZMac-diagnostics",
            reportText: makeDiagnosticsReport(
                generatedAt: generatedAt,
                buildMetadata: buildMetadata,
                context: context,
                hostPreferences: redactedHostPreferences,
                storageSnapshot: storageSnapshot
            ),
            buildMetadata: buildMetadata,
            context: context,
            hostPreferences: redactedHostPreferences,
            taskHistory: redactedTaskHistory,
            workspaceDraft: workspaceDraft,
            uiSettings: uiSettings,
            generatedFiles: generatedFiles,
            extraFiles: extraFiles
        )
    }

    private func makeJSONDiagnosticsFile<Value: Encodable>(
        _ value: Value,
        relativePath: String,
        description: String
    ) throws -> NativeDiagnosticsBundleGeneratedFile {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return NativeDiagnosticsBundleGeneratedFile(
            data: try encoder.encode(value),
            relativePath: relativePath,
            description: description
        )
    }

    private func makeJSONObjectDiagnosticsFile(
        _ object: JSONObject,
        relativePath: String,
        description: String
    ) throws -> NativeDiagnosticsBundleGeneratedFile {
        NativeDiagnosticsBundleGeneratedFile(
            data: try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
            relativePath: relativePath,
            description: description
        )
    }

    private func makeDiagnosticsReport(
        generatedAt: String,
        buildMetadata: NativeBuildMetadata,
        context: NativeDiagnosticsBundleContext,
        hostPreferences: NativeHostPreferencesSnapshot,
        storageSnapshot: NativeDiagnosticsStorageSnapshot?
    ) -> String {
        var lines = [
            "WordZMac Diagnostics",
            "Generated At: \(generatedAt)",
            "App: \(context.appName)",
            "Version: \(context.versionLabel)",
            "Build Summary: \(context.buildSummary)",
            "Bundle Identifier: \(buildMetadata.bundleIdentifier)",
            "Bundle ID: \(buildMetadata.bundleIdentifier)",
            "Workspace Summary: \(context.workspaceSummary)",
            "Active Tab: \(context.activeTab)",
            "Selected Folder: \(context.selectedFolderName)",
            "Selected Corpus: \(context.selectedCorpusName)",
            "Engine Entry: \(context.engineEntryPath)",
            "Task Center Summary: \(context.taskCenterSummary)",
            "Recent Documents: \(hostPreferences.recentDocuments.count)",
            "Downloaded Update Path: \(hostPreferences.downloadedUpdatePath)"
        ]
        if let storageSnapshot {
            lines.append("Library DB Present: \(storageSnapshot.libraryDatabaseExists)")
            lines.append("Workspace DB Present: \(storageSnapshot.workspaceDatabaseExists)")
            lines.append("Library DB Schema: \(storageSnapshot.librarySchemaVersion)")
            lines.append("Workspace DB Schema: \(storageSnapshot.workspaceSchemaVersion)")
            lines.append("Pending Shard Migrations: \(storageSnapshot.pendingShardMigrationCount)")
            lines.append("Quarantined Corpora: \(storageSnapshot.quarantinedCorpusCount)")
            lines.append("Corpus Shard Files: \(storageSnapshot.corpusShardFileCount)")
        }
        return lines.joined(separator: "\n")
    }

    private func makeDiagnosticsStorageSnapshot(userDataDirectory: String) -> NativeDiagnosticsStorageSnapshot? {
        let trimmed = userDataDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let fileManager = FileManager.default
        let rootURL = URL(fileURLWithPath: trimmed, isDirectory: true)
        let libraryDatabaseURL = rootURL.appendingPathComponent("library.db")
        let workspaceDatabaseURL = rootURL.appendingPathComponent("workspace.db")
        let corporaDirectoryURL = rootURL.appendingPathComponent("corpora", isDirectory: true)
        let recycleDirectoryURL = rootURL.appendingPathComponent("recycle", isDirectory: true)

        let librarySummary: LibraryCatalogStore.StorageSummary?
        if fileManager.fileExists(atPath: libraryDatabaseURL.path) {
            librarySummary = try? LibraryCatalogStore(
                fileManager: fileManager,
                encoder: JSONEncoder(),
                decoder: JSONDecoder(),
                databaseURL: libraryDatabaseURL,
                corporaDirectoryURL: corporaDirectoryURL
            ).storageSummary()
        } else {
            librarySummary = nil
        }

        let workspaceSummary: WorkspaceStateStore.StorageSummary?
        if fileManager.fileExists(atPath: workspaceDatabaseURL.path) {
            workspaceSummary = try? WorkspaceStateStore(
                fileManager: fileManager,
                encoder: JSONEncoder(),
                decoder: JSONDecoder(),
                databaseURL: workspaceDatabaseURL
            ).storageSummary()
        } else {
            workspaceSummary = nil
        }

        return NativeDiagnosticsStorageSnapshot(
            rootPath: rootURL.path,
            libraryDatabaseExists: fileManager.fileExists(atPath: libraryDatabaseURL.path),
            workspaceDatabaseExists: fileManager.fileExists(atPath: workspaceDatabaseURL.path),
            librarySchemaVersion: librarySummary?.schemaVersion ?? 0,
            workspaceSchemaVersion: workspaceSummary?.schemaVersion ?? 0,
            folderCount: librarySummary?.folderCount ?? 0,
            activeCorpusCount: librarySummary?.activeCorpusCount ?? 0,
            quarantinedCorpusCount: librarySummary?.quarantinedCorpusCount ?? 0,
            corpusSetCount: librarySummary?.corpusSetCount ?? 0,
            recycleEntryCount: librarySummary?.recycleEntryCount ?? 0,
            pendingShardMigrationCount: librarySummary?.pendingShardMigrationCount ?? 0,
            workspaceSnapshotCount: workspaceSummary?.workspaceSnapshotCount ?? 0,
            uiSettingsCount: workspaceSummary?.uiSettingsCount ?? 0,
            analysisPresetCount: workspaceSummary?.analysisPresetCount ?? 0,
            keywordSavedListCount: workspaceSummary?.keywordSavedListCount ?? 0,
            concordanceSavedSetCount: workspaceSummary?.concordanceSavedSetCount ?? 0,
            evidenceItemCount: workspaceSummary?.evidenceItemCount ?? 0,
            sentimentReviewSampleCount: workspaceSummary?.sentimentReviewSampleCount ?? 0,
            corpusShardFileCount: regularFileCount(in: corporaDirectoryURL),
            recycleFileCount: regularFileCount(in: recycleDirectoryURL),
            libraryWALSidecarExists: FileManager.default.fileExists(atPath: libraryDatabaseURL.path + "-wal"),
            workspaceWALSidecarExists: FileManager.default.fileExists(atPath: workspaceDatabaseURL.path + "-wal")
        )
    }

    private func regularFileCount(in directoryURL: URL) -> Int {
        let enumerator = FileManager.default.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        var count = 0
        while let nextURL = enumerator?.nextObject() as? URL {
            guard let values = try? nextURL.resourceValues(forKeys: [.isRegularFileKey]),
                  values.isRegularFile == true else {
                continue
            }
            count += 1
        }
        return count
    }
}
