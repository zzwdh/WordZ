import Foundation

@MainActor
extension WorkspaceSentimentWorkflowService {
    func importSentimentUserLexiconBundle(
        features: WorkspaceSentimentWorkflowContext,
        preferredRoute: NativeWindowRoute? = nil,
        markWorkspaceEdited: @escaping @MainActor (WorkspaceFeatureSet) -> Void
    ) async {
        let featureSet = features.withFeatureSet { $0 }
        guard let path = await analysisWorkflow.dialogService.chooseOpenPath(
            title: wordZText("导入 Sentiment Bundle", "Import Sentiment Bundle", mode: .system),
            message: wordZText(
                "选择包含 manifest 和 entries 的 JSON bundle 文件。",
                "Choose a JSON bundle file containing a manifest and entries.",
                mode: .system
            ),
            allowedExtensions: ["json"],
            preferredRoute: preferredRoute
        ) else {
            return
        }

        do {
            let outcome = try SentimentUserLexiconBundleImportSupport.importBundle(
                from: URL(fileURLWithPath: path)
            )
            features.sentiment.importUserLexiconBundle(outcome.bundle)
            markWorkspaceEdited(featureSet)

            let status: String
            if outcome.rejectedEntryCount > 0 {
                status = String(
                    format: wordZText(
                        "已导入用户词典 bundle“%@”：接受 %d 条，跳过 %d 条。",
                        "Imported user lexicon bundle “%@”: accepted %d rules and skipped %d.",
                        mode: .system
                    ),
                    outcome.bundle.manifest.id,
                    outcome.acceptedEntryCount,
                    outcome.rejectedEntryCount
                )
            } else {
                status = String(
                    format: wordZText(
                        "已导入用户词典 bundle“%@”：共 %d 条规则。",
                        "Imported user lexicon bundle “%@” with %d rules.",
                        mode: .system
                    ),
                    outcome.bundle.manifest.id,
                    outcome.acceptedEntryCount
                )
            }

            features.library.setStatus(status)
            features.sidebar.clearError()
        } catch {
            features.sidebar.setError(error.localizedDescription)
        }
    }
}
