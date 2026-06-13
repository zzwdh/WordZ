import Foundation

enum WorkspaceResultArtifactCapability: String, Hashable, Sendable {
    case copy
    case preview
    case export
    case share
    case openSourceReader
}

enum WorkspaceResultArtifactAction: Hashable, Sendable {
    case copy
    case preview
    case export
    case share
    case openSourceReader
}

struct WorkspaceResultArtifactActionDescriptor: Identifiable, Equatable, Sendable {
    let action: WorkspaceResultArtifactAction
    let title: String
    let help: String
    let systemImage: String
    let isProminent: Bool

    var id: WorkspaceResultArtifactAction { action }
}

struct WorkspaceResultArtifact: Equatable, Sendable {
    enum Payload: Equatable, Sendable {
        case table(NativeTableExportSnapshot)
        case textDocument(PlainTextExportDocument)
    }

    let sourceTab: WorkspaceDetailTab
    let title: String
    let status: String
    let totalRows: Int
    let visibleRows: Int
    let payload: Payload
    let capabilities: Set<WorkspaceResultArtifactCapability>

    init(
        sourceTab: WorkspaceDetailTab,
        title: String,
        status: String,
        totalRows: Int,
        visibleRows: Int,
        payload: Payload,
        capabilities: Set<WorkspaceResultArtifactCapability> = [.copy, .preview, .export, .share]
    ) {
        self.sourceTab = sourceTab
        self.title = title
        self.status = status
        self.totalRows = totalRows
        self.visibleRows = visibleRows
        self.payload = payload
        self.capabilities = capabilities
    }

    var exportSnapshot: NativeTableExportSnapshot? {
        guard case .table(let snapshot) = payload else { return nil }
        return snapshot
    }

    var textDocument: PlainTextExportDocument? {
        guard case .textDocument(let document) = payload else { return nil }
        return document
    }

    func supports(_ capability: WorkspaceResultArtifactCapability) -> Bool {
        capabilities.contains(capability)
    }

    func addingCapabilities(_ extraCapabilities: Set<WorkspaceResultArtifactCapability>) -> WorkspaceResultArtifact {
        WorkspaceResultArtifact(
            sourceTab: sourceTab,
            title: title,
            status: status,
            totalRows: totalRows,
            visibleRows: visibleRows,
            payload: payload,
            capabilities: capabilities.union(extraCapabilities)
        )
    }

    func actionDescriptors(in languageMode: AppLanguageMode) -> [WorkspaceResultArtifactActionDescriptor] {
        WorkspaceResultArtifactAction.defaultOrder.compactMap { action in
            guard supports(action.requiredCapability) else { return nil }
            return action.descriptor(for: payload, languageMode: languageMode)
        }
    }
}

extension WorkspaceResultArtifactAction {
    static let defaultOrder: [WorkspaceResultArtifactAction] = [
        .copy,
        .preview,
        .export,
        .share,
        .openSourceReader
    ]

    var requiredCapability: WorkspaceResultArtifactCapability {
        switch self {
        case .copy:
            return .copy
        case .preview:
            return .preview
        case .export:
            return .export
        case .share:
            return .share
        case .openSourceReader:
            return .openSourceReader
        }
    }

    func descriptor(
        for payload: WorkspaceResultArtifact.Payload,
        languageMode: AppLanguageMode
    ) -> WorkspaceResultArtifactActionDescriptor {
        switch self {
        case .copy:
            return WorkspaceResultArtifactActionDescriptor(
                action: self,
                title: copyTitle(for: payload, languageMode: languageMode),
                help: copyHelp(for: payload, languageMode: languageMode),
                systemImage: copySystemImage(for: payload),
                isProminent: true
            )
        case .preview:
            return WorkspaceResultArtifactActionDescriptor(
                action: self,
                title: wordZText("预览", "Preview", mode: languageMode),
                help: wordZText("预览当前结果", "Preview current result", mode: languageMode),
                systemImage: "eye",
                isProminent: false
            )
        case .export:
            return WorkspaceResultArtifactActionDescriptor(
                action: self,
                title: wordZText("导出", "Export", mode: languageMode),
                help: wordZText("导出当前结果", "Export current result", mode: languageMode),
                systemImage: "square.and.arrow.down",
                isProminent: false
            )
        case .share:
            return WorkspaceResultArtifactActionDescriptor(
                action: self,
                title: wordZText("分享", "Share", mode: languageMode),
                help: wordZText("分享当前结果", "Share current result", mode: languageMode),
                systemImage: "square.and.arrow.up",
                isProminent: false
            )
        case .openSourceReader:
            return WorkspaceResultArtifactActionDescriptor(
                action: self,
                title: wordZText("来源", "Source", mode: languageMode),
                help: wordZText("打开当前证据的来源文本", "Open the source text for current evidence", mode: languageMode),
                systemImage: "doc.text.magnifyingglass",
                isProminent: false
            )
        }
    }

    private func copyTitle(
        for payload: WorkspaceResultArtifact.Payload,
        languageMode: AppLanguageMode
    ) -> String {
        switch payload {
        case .table:
            return wordZText("复制表格", "Copy Table", mode: languageMode)
        case .textDocument:
            return wordZText("复制文本", "Copy Text", mode: languageMode)
        }
    }

    private func copyHelp(
        for payload: WorkspaceResultArtifact.Payload,
        languageMode: AppLanguageMode
    ) -> String {
        switch payload {
        case .table:
            return wordZText("复制为 TSV，可直接粘贴到 Excel", "Copy as TSV for pasting into Excel", mode: languageMode)
        case .textDocument:
            return wordZText("复制当前结果文本", "Copy current result text", mode: languageMode)
        }
    }

    private func copySystemImage(for payload: WorkspaceResultArtifact.Payload) -> String {
        switch payload {
        case .table:
            return "tablecells"
        case .textDocument:
            return "doc.on.clipboard"
        }
    }
}
