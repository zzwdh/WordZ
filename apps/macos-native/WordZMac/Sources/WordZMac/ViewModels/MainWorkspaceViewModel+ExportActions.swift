import Foundation

@MainActor
extension MainWorkspaceViewModel {
    func exportCurrent(preferredWindowRoute: NativeWindowRoute? = nil) async {
        await flowCoordinator.exportCurrent(
            features: features,
            preferredRoute: preferredWindowRoute
        )
        syncSceneGraph(source: .resultContent)
    }

    func exportTokenizedText(preferredWindowRoute: NativeWindowRoute? = nil) async {
        guard let document = tokenize.exportDocument else { return }
        await flowCoordinator.exportTextDocument(
            document,
            title: t("导出分词结果", "Export Tokenized Text"),
            successStatus: t("已导出分词结果。", "Exported tokenized text."),
            features: features,
            preferredRoute: preferredWindowRoute
        )
        syncSceneGraph(source: .resultContent)
    }

    func exportTopicsSummary(preferredWindowRoute: NativeWindowRoute? = nil) async {
        guard let snapshot = topics.exportSummarySnapshot else { return }
        await flowCoordinator.exportSnapshot(
            snapshot,
            title: t("导出主题摘要", "Export Topics Summary"),
            successStatus: t("已导出主题摘要。", "Exported topics summary."),
            features: features,
            preferredRoute: preferredWindowRoute
        )
        syncSceneGraph(source: .resultContent)
    }

    func exportTopicsSegments(preferredWindowRoute: NativeWindowRoute? = nil) async {
        guard let snapshot = topics.exportSegmentsSnapshot else { return }
        await flowCoordinator.exportSnapshot(
            snapshot,
            title: t("导出主题片段", "Export Topic Segments"),
            successStatus: t("已导出主题片段。", "Exported topic segments."),
            features: features,
            preferredRoute: preferredWindowRoute
        )
        syncSceneGraph(source: .resultContent)
    }
}
