import Foundation

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

        let generatedFiles = [
            try makeJSONObjectDiagnosticsFile(
                workspaceDraft.asJSONObject(),
                relativePath: "persisted/workspace-state.json",
                description: "Sanitized persisted workspace state."
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
                hostPreferences: redactedHostPreferences
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
        hostPreferences: NativeHostPreferencesSnapshot
    ) -> String {
        [
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
        .joined(separator: "\n")
    }
}
