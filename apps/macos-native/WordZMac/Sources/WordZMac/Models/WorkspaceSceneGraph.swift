import Foundation

struct WorkspaceResultSceneNode: Equatable {
    let title: String
    let status: String
    let totalRows: Int
    let visibleRows: Int
    let hasResult: Bool
    let table: NativeTableDescriptor
    let tableRows: [NativeTableRowDescriptor]

    static func empty(title: String, status: String) -> WorkspaceResultSceneNode {
        WorkspaceResultSceneNode(
            title: title,
            status: status,
            totalRows: 0,
            visibleRows: 0,
            hasResult: false,
            table: .empty,
            tableRows: []
        )
    }

    var exportSnapshot: NativeTableExportSnapshot? {
        guard hasResult, !table.visibleColumns.isEmpty, !tableRows.isEmpty else { return nil }
        return NativeTableExportSnapshot(
            suggestedBaseName: title.lowercased().replacingOccurrences(of: " ", with: "-"),
            table: table,
            rows: tableRows
        )
    }
}

struct WorkspaceSceneGraph: Equatable {
    let context: WorkspaceSceneContext
    let sidebar: WorkspaceSidebarSceneModel
    let shell: WorkspaceShellSceneModel
    let library: LibraryManagementSceneModel
    let settings: SettingsPaneSceneModel
    let activeTab: WorkspaceDetailTab
    let word: WorkspaceResultSceneNode
    let wordCloud: WorkspaceResultSceneNode
    let stats: WorkspaceResultSceneNode
    let compare: WorkspaceResultSceneNode
    let chiSquare: WorkspaceResultSceneNode
    let ngram: WorkspaceResultSceneNode
    let kwic: WorkspaceResultSceneNode
    let collocate: WorkspaceResultSceneNode
    let locator: WorkspaceResultSceneNode

    init(
        context: WorkspaceSceneContext,
        sidebar: WorkspaceSidebarSceneModel,
        shell: WorkspaceShellSceneModel,
        library: LibraryManagementSceneModel,
        settings: SettingsPaneSceneModel,
        activeTab: WorkspaceDetailTab,
        word: WorkspaceResultSceneNode = .empty(title: "Word", status: "尚未生成 Word 结果"),
        wordCloud: WorkspaceResultSceneNode,
        stats: WorkspaceResultSceneNode,
        compare: WorkspaceResultSceneNode,
        chiSquare: WorkspaceResultSceneNode,
        ngram: WorkspaceResultSceneNode,
        kwic: WorkspaceResultSceneNode,
        collocate: WorkspaceResultSceneNode,
        locator: WorkspaceResultSceneNode
    ) {
        self.context = context
        self.sidebar = sidebar
        self.shell = shell
        self.library = library
        self.settings = settings
        self.activeTab = activeTab
        self.word = word
        self.wordCloud = wordCloud
        self.stats = stats
        self.compare = compare
        self.chiSquare = chiSquare
        self.ngram = ngram
        self.kwic = kwic
        self.collocate = collocate
        self.locator = locator
    }

    static let empty = WorkspaceSceneGraph(
        context: .empty,
        sidebar: .empty,
        shell: WorkspaceShellSceneModel(
            workspaceSummary: WorkspaceSceneContext.empty.workspaceSummary,
            buildSummary: WorkspaceSceneContext.empty.buildSummary,
            toolbar: WorkspaceToolbarSceneModel(items: [])
        ),
        library: .empty,
        settings: .empty,
        activeTab: .library,
        word: .empty(title: "Word", status: "尚未生成 Word 结果"),
        wordCloud: .empty(title: "Word Cloud", status: "尚未生成词云结果"),
        stats: .empty(title: "Stats", status: "尚未生成统计结果"),
        compare: .empty(title: "Compare", status: "尚未生成 Compare 结果"),
        chiSquare: .empty(title: "Chi-Square", status: "尚未生成 Chi-Square 结果"),
        ngram: .empty(title: "N-Gram", status: "尚未生成 N-Gram 结果"),
        kwic: .empty(title: "KWIC", status: "尚未生成 KWIC 结果"),
        collocate: .empty(title: "Collocate", status: "尚未生成 Collocate 结果"),
        locator: .empty(title: "Locator", status: "尚未生成 Locator 结果")
    )
}
