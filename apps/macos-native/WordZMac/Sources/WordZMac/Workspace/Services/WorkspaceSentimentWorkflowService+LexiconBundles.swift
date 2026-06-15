import Foundation

import WordZWindowing
import WordZShared
@MainActor
extension WorkspaceSentimentWorkflowService {
    func importSentimentUserLexiconBundle(
        features: WorkspaceSentimentWorkflowContext,
        preferredRoute: NativeWindowRoute? = nil,
        markWorkspaceEdited: @escaping @MainActor (WorkspaceFeatureSet) -> Void
    ) async {
        let featureSet = features.withFeatureSet { $0 }
        guard let path = await analysisWorkflow.dialogService.chooseOpenPath(
            title: wordZText("导入自定义情感词典", "Import Custom Sentiment Lexicon", mode: .system),
            message: wordZText(
                "选择自定义情感词典文件。",
                "Choose a custom sentiment lexicon file.",
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
                        "已导入自定义情感词典“%@”：接受 %d 条，跳过 %d 条。",
                        "Imported custom sentiment lexicon “%@”: accepted %d rules and skipped %d.",
                        mode: .system
                    ),
                    outcome.bundle.manifest.id,
                    outcome.acceptedEntryCount,
                    outcome.rejectedEntryCount
                )
            } else {
                status = String(
                    format: wordZText(
                        "已导入自定义情感词典“%@”：共 %d 条规则。",
                        "Imported custom sentiment lexicon “%@” with %d rules.",
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
