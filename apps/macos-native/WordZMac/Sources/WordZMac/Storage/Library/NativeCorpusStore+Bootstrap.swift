import Foundation

extension NativeCorpusStore {
    func ensureInitialized() throws {
        guard !isInitialized else { return }
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: corporaDirectoryURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: corpusSetsDirectoryURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: recycleDirectoryURL, withIntermediateDirectories: true)

        try storageMigrationCoordinator.ensureInitialized()

        _ = try loadFolders()
        _ = try loadCorpora()
        _ = try loadCorpusSets()
        _ = try loadRecycleEntries()
        _ = try loadAnalysisPresets()
        _ = try loadKeywordSavedLists()
        _ = try loadConcordanceSavedSets()
        _ = try loadSentimentReviewSamples()
        _ = try loadWorkspacePersistedSnapshot()
        _ = try loadPersistedUISettings()
        try seedBundledDefaultReferenceCorporaIfNeeded()
        isInitialized = true
    }

    func appInfo() -> AppInfoSummary {
        let bundleVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return AppInfoSummary(json: [
            "name": "WordZ",
            "version": bundleVersion ?? "native-preview",
            "help": [
                "WordZ 默认使用本机分析能力，不需要上传语料。",
                "导入文本语料后，可直接运行 Stats / Word / KWIC / Collocate / N-Gram / Compare / Locator。"
            ],
            "releaseNotes": [
                "性能基线收口：新增 1.4.0 release 基线、UI 性能门禁和 before/after 记录，覆盖 Topics、Library/import、大结果页交互和参考语料分析。",
                "高频路径优化：Library import/index、重复 Library 刷新、Topics 结果组装和 slice/embedding 分配完成实测优化，并保留质量字段对比。",
                "API 调用稳定化：更新检查和手动 API 连接检查统一走可取消、可超时、可重试、限并发和脱敏记录的 API 底座。",
                "本地优先与隐私保护：API 总开关、Keychain 凭据、连接测试、错误恢复和诊断包脱敏已落地，未配置 API 时本地语料分析仍完整可用。"
            ],
            "userDataDir": rootURL.path
        ])
    }
}
