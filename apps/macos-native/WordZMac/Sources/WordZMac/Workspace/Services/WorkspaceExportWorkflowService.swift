import Foundation

@MainActor
final class WorkspaceExportWorkflowService {
    private let sceneStore: WorkspaceSceneStore
    private let exportCoordinator: any WorkspaceExportCoordinating

    init(
        sceneStore: WorkspaceSceneStore,
        exportCoordinator: any WorkspaceExportCoordinating
    ) {
        self.sceneStore = sceneStore
        self.exportCoordinator = exportCoordinator
    }

    func exportCurrent(
        features: WorkspaceFeatureSet,
        preferredRoute: NativeWindowRoute? = nil
    ) async {
        do {
            let savedPath: String?
            if features.shell.selectedTab == .tokenize,
               let document = features.tokenize.exportDocument {
                savedPath = try await exportCoordinator.export(
                    textDocument: document,
                    title: wordZText("导出分词结果", "Export Tokenized Text", mode: .system),
                    preferredRoute: preferredRoute
                )
            } else {
                savedPath = try await exportCoordinator.exportActiveScene(
                    graph: buildSceneGraph(features: features),
                    preferredRoute: preferredRoute
                )
            }

            if let savedPath {
                features.library.setStatus("已导出到 \(savedPath)")
                features.sidebar.clearError()
            }
        } catch {
            features.sidebar.setError(error.localizedDescription)
        }
    }

    func exportTextDocument(
        _ document: PlainTextExportDocument,
        title: String,
        successStatus: String,
        features: WorkspaceFeatureSet,
        preferredRoute: NativeWindowRoute? = nil
    ) async {
        do {
            if let savedPath = try await exportCoordinator.export(
                textDocument: document,
                title: title,
                preferredRoute: preferredRoute
            ) {
                features.library.setStatus("\(successStatus) \(savedPath)")
                features.sidebar.clearError()
            }
        } catch {
            features.sidebar.setError(error.localizedDescription)
        }
    }

    func exportSnapshot(
        _ snapshot: NativeTableExportSnapshot,
        title: String,
        successStatus: String,
        features: WorkspaceFeatureSet,
        preferredRoute: NativeWindowRoute? = nil
    ) async {
        do {
            if let savedPath = try await exportCoordinator.export(
                snapshot: snapshot,
                title: title,
                preferredRoute: preferredRoute
            ) {
                features.library.setStatus("\(successStatus) \(savedPath)")
                features.sidebar.clearError()
            }
        } catch {
            features.sidebar.setError(error.localizedDescription)
        }
    }

    private func buildSceneGraph(features: WorkspaceFeatureSet) -> WorkspaceSceneGraph {
        let graphStore = WorkspaceSceneGraphStore()
        graphStore.sync(
            context: sceneStore.context,
            sidebar: features.sidebar.scene,
            shell: features.shell.scene,
            library: features.library.scene,
            settings: features.settings.scene,
            activeTab: features.shell.selectedTab,
            word: features.word.scene,
            tokenize: features.tokenize.scene,
            stats: features.stats.scene,
            topics: features.topics.scene,
            compare: features.compare.scene,
            keyword: features.keyword.scene,
            chiSquare: features.chiSquare.scene,
            ngram: features.ngram.scene,
            kwic: features.kwic.scene,
            collocate: features.collocate.scene,
            locator: features.locator.scene
        )
        return graphStore.graph
    }
}
