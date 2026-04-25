import Foundation

@MainActor
extension MainWorkspaceViewModel {
    func reloadAnalysisPresets() async {
        guard let analysisPresetRepository else {
            analysisPresets = []
            return
        }

        do {
            analysisPresets = try await analysisPresetRepository.listAnalysisPresets()
        } catch {
            presentIssue(
                error,
                titleZh: "加载分析预设失败",
                titleEn: "Unable to Load Analysis Presets"
            )
        }
    }

    func saveCurrentAnalysisPreset(preferredWindowRoute: NativeWindowRoute? = nil) async {
        guard let analysisPresetRepository else { return }

        let defaultValue = selectedTab.displayTitle(in: languageMode)
        guard let name = await dialogService.promptText(
            title: t("保存分析预设", "Save Analysis Preset"),
            message: t("保存当前标签页、搜索参数、语料选择与分析设置。", "Save the current tab, search parameters, corpus selection, and analysis settings."),
            defaultValue: defaultValue,
            confirmTitle: t("保存", "Save"),
            preferredRoute: preferredWindowRoute
        ) else {
            return
        }

        do {
            let draft = flowCoordinator.currentWorkspaceDraft(features: features)
            let preset = try await analysisPresetRepository.saveAnalysisPreset(name: name, draft: draft)
            analysisPresets = try await analysisPresetRepository.listAnalysisPresets()
            settings.setSupportStatus(
                "\(t("已保存分析预设：", "Saved analysis preset: "))\(preset.name)"
            )
            clearActiveIssue()
        } catch {
            presentIssue(
                error,
                titleZh: "保存分析预设失败",
                titleEn: "Unable to Save Analysis Preset"
            )
        }
    }

    func applyAnalysisPreset(_ presetID: String) async {
        guard let preset = analysisPresets.first(where: { $0.id == presetID }) else { return }

        cancelPendingInputStateSync()
        sessionStore.beginRestore()
        flowCoordinator.resetFeatureResults(features: features)
        flowCoordinator.applyWorkspaceSnapshot(preset.snapshot, features: features)
        restoreWorkspaceAnnotationState(from: preset.snapshot)
        flowCoordinator.applyWorkspacePresentation(features: features)
        flowCoordinator.syncWindowDocumentState(features: features)
        sessionStore.finishRestore()
        syncSceneGraph(source: .full)
        flowCoordinator.persistWorkspaceState(features: features)
        settings.setSupportStatus(
            "\(t("已应用分析预设：", "Applied analysis preset: "))\(preset.name)"
        )
        clearActiveIssue()
    }

    func deleteAnalysisPreset(
        _ presetID: String,
        preferredWindowRoute: NativeWindowRoute? = nil
    ) async {
        guard let analysisPresetRepository,
              let preset = analysisPresets.first(where: { $0.id == presetID }) else { return }

        let shouldDelete = await dialogService.confirm(
            title: t("删除分析预设", "Delete Analysis Preset"),
            message: "\(t("确定要删除分析预设“", "Delete analysis preset “"))\(preset.name)”?",
            confirmTitle: t("删除", "Delete"),
            preferredRoute: preferredWindowRoute
        )
        guard shouldDelete else { return }

        do {
            try await analysisPresetRepository.deleteAnalysisPreset(presetID: presetID)
            analysisPresets = try await analysisPresetRepository.listAnalysisPresets()
            settings.setSupportStatus(
                "\(t("已删除分析预设：", "Deleted analysis preset: "))\(preset.name)"
            )
            clearActiveIssue()
        } catch {
            presentIssue(
                error,
                titleZh: "删除分析预设失败",
                titleEn: "Unable to Delete Analysis Preset"
            )
        }
    }

    func exportCurrentReportBundle(preferredWindowRoute: NativeWindowRoute? = nil) async {
        guard canExportCurrentReportBundle else {
            presentShareUnavailableIssue()
            return
        }

        let taskID = taskCenter.beginTask(
            title: t("导出研究报告包", "Export Research Report Bundle"),
            detail: t("正在整理当前结果、方法说明和工作区状态…", "Collecting the current result, methodology notes, and workspace state…"),
            progress: 0
        )

        do {
            let payload = try makeCurrentReportBundlePayload()
            let artifact = try reportBundleService.buildBundle(payload: payload)
            defer { reportBundleService.cleanup(artifact) }

            let suggestedName = "\(payload.bundleBaseName).zip"
            if let savedPath = try await hostActionService.exportArchiveBundle(
                archivePath: artifact.archiveURL.path,
                suggestedName: suggestedName,
                title: t("导出研究报告包", "Export Research Report Bundle"),
                preferredRoute: preferredWindowRoute?.hostPresentationHint
            ) {
                settings.setSupportStatus(
                    "\(t("已导出研究报告包到", "Exported report bundle to")) \(savedPath)"
                )
                clearActiveIssue()
                taskCenter.completeTask(
                    id: taskID,
                    detail: savedPath,
                    action: .openFile(path: savedPath)
                )
            } else {
                let cancelled = t("已取消导出研究报告包。", "Report bundle export was cancelled.")
                settings.setSupportStatus(cancelled)
                taskCenter.failTask(id: taskID, detail: cancelled)
            }
        } catch {
            presentIssue(
                error,
                titleZh: "导出研究报告包失败",
                titleEn: "Report Bundle Export Failed"
            )
            taskCenter.failTask(id: taskID, detail: error.localizedDescription)
        }
    }

    private func makeCurrentReportBundlePayload() throws -> AnalysisReportBundlePayload {
        let buildMetadata = buildMetadataProvider.current()
        let workspaceDraft = flowCoordinator.currentWorkspaceDraft(features: features)
        let generatedAt = ISO8601DateFormatter().string(from: Date())
        let activeSceneNode = currentResultSceneNode
        let metadataLines = currentExportSnapshot?.metadataLines ?? []
        let generatedSceneSummary = try JSONSerialization.data(
            withJSONObject: [
                "generatedAt": generatedAt,
                "activeTab": selectedTab.snapshotValue,
                "displayTitle": selectedTab.displayTitle(in: languageMode),
                "sceneTitle": activeSceneNode?.title ?? "",
                "sceneStatus": activeSceneNode?.status ?? "",
                "metadataLines": metadataLines
            ],
            options: [.prettyPrinted, .sortedKeys]
        )

        let reportLines = [
            "WordZ Report Bundle",
            "Generated At: \(generatedAt)",
            "Analysis: \(selectedTab.displayTitle(in: languageMode))",
            "Workspace Summary: \(sceneGraph.context.workspaceSummary)",
            "Build Summary: \(buildMetadata.buildSummary)",
            "Scene Status: \(activeSceneNode?.status ?? "")",
            "Visible Rows: \(currentExportSnapshot?.rows.count ?? 0)",
            "",
            metadataLines.joined(separator: "\n")
        ]
        let reportText = reportLines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")

        let methodSummaryText = metadataLines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")

        var generatedFiles = [
            AnalysisReportBundleGeneratedFile(
                relativePath: "scene-summary.json",
                description: "Current scene metadata and export notes.",
                data: generatedSceneSummary
            )
        ]

        if !methodSummaryText.isEmpty {
            generatedFiles.append(
                AnalysisReportBundleGeneratedFile(
                    relativePath: "method-summary.txt",
                    description: "Method summary derived from the current export metadata lines.",
                    data: Data(methodSummaryText.utf8)
                )
            )
        }

        return AnalysisReportBundlePayload(
            bundleBaseName: "WordZMac-\(selectedTab.snapshotValue)-report",
            reportText: reportText,
            buildMetadata: buildMetadata,
            workspaceDraft: workspaceDraft,
            tableSnapshot: currentExportSnapshot,
            textDocuments: currentReportTextDocuments,
            generatedFiles: generatedFiles
        )
    }
}
