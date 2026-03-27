import Foundation

@MainActor
final class LibrarySidebarViewModel: ObservableObject {
    @Published var librarySnapshot = LibrarySnapshot.empty
    @Published var selectedCorpusID: String? {
        didSet {
            guard oldValue != selectedCorpusID else { return }
            syncScene()
            onSelectionChange?()
        }
    }
    @Published var engineStatus = wordZText("正在连接本地引擎...", "Connecting to local engine…", mode: .system)
    @Published var lastErrorMessage = ""
    @Published private(set) var scene = WorkspaceSidebarSceneModel.empty

    var onSelectionChange: (() -> Void)?
    private var context = WorkspaceSceneContext.empty
    private var isBusy = false
    private var engineState: WorkspaceSidebarEngineState = .connecting
    private var languageMode: AppLanguageMode {
        WordZLocalization.shared.effectiveMode
    }

    var selectedCorpus: LibraryCorpusItem? {
        guard let selectedCorpusID else { return nil }
        return librarySnapshot.corpora.first(where: { $0.id == selectedCorpusID })
    }

    func applyBootstrap(_ state: WorkspaceBootstrapState) {
        librarySnapshot = state.librarySnapshot
        engineState = .connected
        engineStatus = wordZText("本地引擎已连接", "Local engine connected", mode: languageMode)
        lastErrorMessage = ""
        syncScene()
    }

    func applyContext(_ context: WorkspaceSceneContext) {
        self.context = context
        syncScene()
    }

    func setBusy(_ isBusy: Bool) {
        self.isBusy = isBusy
        syncScene()
    }

    func setConnectionFailure(_ message: String) {
        engineState = .failed
        engineStatus = wordZText("本地引擎连接失败", "Local engine connection failed", mode: languageMode)
        lastErrorMessage = message
        syncScene()
    }

    func clearError() {
        lastErrorMessage = ""
        syncScene()
    }

    func setError(_ message: String) {
        lastErrorMessage = message
        syncScene()
    }

    private func syncScene() {
        let currentCorpus = selectedCorpus.map {
            WorkspaceCurrentCorpusSceneModel(
                title: $0.name,
                subtitle: $0.folderName
            )
        }
        let actions = [
            WorkspaceSidebarActionItem(action: .refresh, title: wordZText("刷新", "Refresh", mode: languageMode), isEnabled: !isBusy),
            WorkspaceSidebarActionItem(
                action: .openSelected,
                title: wordZText("打开选中", "Open Selected", mode: languageMode),
                isEnabled: !isBusy && selectedCorpusID != nil
            )
        ]
        let corpora = librarySnapshot.corpora.map { corpus in
            WorkspaceSidebarCorpusSceneItem(
                id: corpus.id,
                title: corpus.name,
                subtitle: corpus.folderName,
                isSelected: corpus.id == selectedCorpusID
            )
        }
        scene = WorkspaceSidebarSceneModel(
            appName: context.appName,
            versionLabel: context.versionLabel,
            engineStatus: engineStatus,
            engineState: engineState,
            actions: actions,
            currentCorpus: currentCorpus,
            corpora: corpora,
            errorMessage: lastErrorMessage
        )
    }
}
