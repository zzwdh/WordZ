import Foundation

@MainActor
extension WorkspaceAnalysisWorkflowService {
    func copyKWICReading(_ format: ReadingExportFormat, currentOnly: Bool, features: WorkspaceFeatureSet) async {
        guard let scene = features.kwic.scene else { return }
        let document: PlainTextExportDocument?
        if currentOnly, let row = features.kwic.selectedSceneRow {
            document = ReadingExportSupport.document(for: format, currentKWICRow: row, scene: scene)
        } else {
            document = ReadingExportSupport.document(for: format, visibleKWICRows: scene.rows, scene: scene)
        }
        copyReadingDocument(
            document,
            successStatus: wordZText("已复制 KWIC 阅读内容。", "Copied KWIC reading export.", mode: .system),
            features: features
        )
    }

    func exportKWICReading(
        _ format: ReadingExportFormat,
        currentOnly: Bool,
        features: WorkspaceFeatureSet,
        preferredRoute: NativeWindowRoute? = nil
    ) async {
        guard let scene = features.kwic.scene else { return }
        let document: PlainTextExportDocument?
        if currentOnly, let row = features.kwic.selectedSceneRow {
            document = ReadingExportSupport.document(for: format, currentKWICRow: row, scene: scene)
        } else {
            document = ReadingExportSupport.document(for: format, visibleKWICRows: scene.rows, scene: scene)
        }
        guard let document else { return }
        await exportTextDocument(
            document,
            title: wordZText("导出 KWIC 阅读内容", "Export KWIC Reading", mode: .system),
            successStatus: wordZText("已导出 KWIC 阅读内容到", "Exported KWIC reading to", mode: .system),
            features: features,
            preferredRoute: preferredRoute
        )
    }

    func copyLocatorReading(_ format: ReadingExportFormat, currentOnly: Bool, features: WorkspaceFeatureSet) async {
        guard let scene = features.locator.scene else { return }
        let document: PlainTextExportDocument?
        if currentOnly, let row = features.locator.selectedSceneRow {
            document = ReadingExportSupport.document(for: format, currentLocatorRow: row, scene: scene)
        } else {
            document = ReadingExportSupport.document(for: format, visibleLocatorRows: scene.rows, scene: scene)
        }
        copyReadingDocument(
            document,
            successStatus: wordZText("已复制定位器阅读内容。", "Copied locator reading export.", mode: .system),
            features: features
        )
    }

    func exportLocatorReading(
        _ format: ReadingExportFormat,
        currentOnly: Bool,
        features: WorkspaceFeatureSet,
        preferredRoute: NativeWindowRoute? = nil
    ) async {
        guard let scene = features.locator.scene else { return }
        let document: PlainTextExportDocument?
        if currentOnly, let row = features.locator.selectedSceneRow {
            document = ReadingExportSupport.document(for: format, currentLocatorRow: row, scene: scene)
        } else {
            document = ReadingExportSupport.document(for: format, visibleLocatorRows: scene.rows, scene: scene)
        }
        guard let document else { return }
        await exportTextDocument(
            document,
            title: wordZText("导出定位器阅读内容", "Export Locator Reading", mode: .system),
            successStatus: wordZText("已导出定位器阅读内容到", "Exported locator reading to", mode: .system),
            features: features,
            preferredRoute: preferredRoute
        )
    }

    func copyCompareReading(currentOnly: Bool, features: WorkspaceFeatureSet) async {
        guard let scene = features.compare.scene else { return }
        let document: PlainTextExportDocument?
        if currentOnly, let row = features.compare.selectedSceneRow {
            document = ReadingExportSupport.document(currentCompareRow: row, scene: scene)
        } else {
            document = ReadingExportSupport.document(visibleCompareRows: scene.rows, scene: scene)
        }
        copyReadingDocument(
            document,
            successStatus: wordZText("已复制对比研究摘要。", "Copied compare research summary.", mode: .system),
            features: features
        )
    }

    func exportCompareReading(
        currentOnly: Bool,
        features: WorkspaceFeatureSet,
        preferredRoute: NativeWindowRoute? = nil
    ) async {
        guard let scene = features.compare.scene else { return }
        let document: PlainTextExportDocument?
        if currentOnly, let row = features.compare.selectedSceneRow {
            document = ReadingExportSupport.document(currentCompareRow: row, scene: scene)
        } else {
            document = ReadingExportSupport.document(visibleCompareRows: scene.rows, scene: scene)
        }
        guard let document else { return }
        await exportTextDocument(
            document,
            title: wordZText("导出对比研究摘要", "Export Compare Summary", mode: .system),
            successStatus: wordZText("已导出对比研究摘要到", "Exported compare summary to", mode: .system),
            features: features,
            preferredRoute: preferredRoute
        )
    }

    func copyCompareMethodSummary(features: WorkspaceFeatureSet) async {
        guard let scene = features.compare.scene else { return }
        copyReadingDocument(
            ReadingExportSupport.compareMethodDocument(scene: scene),
            successStatus: wordZText("已复制对比方法摘要。", "Copied compare method summary.", mode: .system),
            features: features
        )
    }

    func copyCollocateReading(currentOnly: Bool, features: WorkspaceFeatureSet) async {
        guard let scene = features.collocate.scene else { return }
        let document: PlainTextExportDocument?
        if currentOnly, let row = features.collocate.selectedSceneRow {
            document = ReadingExportSupport.document(currentCollocateRow: row, scene: scene)
        } else {
            document = ReadingExportSupport.document(visibleCollocateRows: scene.rows, scene: scene)
        }
        copyReadingDocument(
            document,
            successStatus: wordZText("已复制搭配研究摘要。", "Copied collocate research summary.", mode: .system),
            features: features
        )
    }

    func exportCollocateReading(
        currentOnly: Bool,
        features: WorkspaceFeatureSet,
        preferredRoute: NativeWindowRoute? = nil
    ) async {
        guard let scene = features.collocate.scene else { return }
        let document: PlainTextExportDocument?
        if currentOnly, let row = features.collocate.selectedSceneRow {
            document = ReadingExportSupport.document(currentCollocateRow: row, scene: scene)
        } else {
            document = ReadingExportSupport.document(visibleCollocateRows: scene.rows, scene: scene)
        }
        guard let document else { return }
        await exportTextDocument(
            document,
            title: wordZText("导出搭配研究摘要", "Export Collocate Summary", mode: .system),
            successStatus: wordZText("已导出搭配研究摘要到", "Exported collocate summary to", mode: .system),
            features: features,
            preferredRoute: preferredRoute
        )
    }

    func copyCollocateMethodSummary(features: WorkspaceFeatureSet) async {
        guard let scene = features.collocate.scene else { return }
        copyReadingDocument(
            ReadingExportSupport.collocateMethodDocument(scene: scene),
            successStatus: wordZText("已复制搭配方法摘要。", "Copied collocate method summary.", mode: .system),
            features: features
        )
    }

    private func copyReadingDocument(
        _ document: PlainTextExportDocument?,
        successStatus: String,
        features: WorkspaceFeatureSet
    ) {
        guard let document else { return }
        hostActionService.copyTextToClipboard(document.text)
        features.library.setStatus(successStatus)
        features.sidebar.clearError()
    }
}
