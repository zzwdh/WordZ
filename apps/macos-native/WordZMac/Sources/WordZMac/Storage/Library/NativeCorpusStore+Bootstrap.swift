import Foundation

extension NativeCorpusStore {
    func ensureInitialized() throws {
        guard !isInitialized else { return }
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: corporaDirectoryURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: recycleDirectoryURL, withIntermediateDirectories: true)

        if !fileManager.fileExists(atPath: foldersURL.path) {
            try saveFolders([])
        }
        if !fileManager.fileExists(atPath: corporaURL.path) {
            try saveCorpora([])
        }
        if !fileManager.fileExists(atPath: corpusSetsURL.path) {
            try saveCorpusSets([])
        }
        if !fileManager.fileExists(atPath: recycleURL.path) {
            try saveRecycleEntries([])
        }
        if !fileManager.fileExists(atPath: analysisPresetsURL.path) {
            try saveAnalysisPresets([])
        }
        if !fileManager.fileExists(atPath: workspaceURL.path) {
            try saveWorkspaceSnapshot(.empty)
        }
        if !fileManager.fileExists(atPath: uiSettingsURL.path) {
            try saveUISettings(.default)
        }

        _ = try loadFolders()
        _ = try loadCorpora()
        _ = try loadCorpusSets()
        _ = try loadRecycleEntries()
        _ = try loadAnalysisPresets()
        _ = try loadWorkspacePersistedSnapshot()
        _ = try loadPersistedUISettings()
        isInitialized = true
    }

    func appInfo() -> AppInfoSummary {
        let bundleVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return AppInfoSummary(json: [
            "name": "WordZ",
            "version": bundleVersion ?? "native-preview",
            "help": [
                "原生版当前默认使用 Swift 本地引擎。",
                "导入文本语料后，可直接运行 Stats / Word / KWIC / Collocate / N-Gram / Compare / Locator。"
            ],
            "releaseNotes": [
                "语料库工作流升级：支持命名语料集、元数据筛选、完整性提示，以及多语料批量元数据编辑。",
                "研究工作流升级：新增分析预设保存/应用/删除，并支持导出附带结果、方法摘要、构建信息和 workspace 草稿的研究报告包。",
                "更新体验原生化：支持检查 GitHub Releases、展示版本亮点、下载更新并在安装前通过统一更新窗口管理流程。",
                "架构与回归继续硬化：源码按领域重组，窗口/菜单/场景同步链路更稳，相关测试覆盖进一步补齐。"
            ],
            "userDataDir": rootURL.path
        ])
    }
}
