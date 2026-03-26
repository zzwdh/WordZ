import Foundation
import SwiftUI

@MainActor
final class MainWorkspaceViewModel: ObservableObject {
    enum DetailTab: String, CaseIterable, Identifiable {
        case stats = "Stats"
        case kwic = "KWIC"
        case settings = "Settings"

        var id: String { rawValue }
    }

    @Published var appInfo: AppInfoSummary?
    @Published var librarySnapshot = LibrarySnapshot(folders: [], corpora: [])
    @Published var workspaceSnapshot: WorkspaceSnapshotSummary?
    @Published var selectedCorpusID: String?
    @Published var openedCorpus: OpenedCorpus?
    @Published var selectedTab: DetailTab = .stats
    @Published var statsResult: StatsResult?
    @Published var kwicResult: KWICResult?
    @Published var kwicKeyword = ""
    @Published var kwicLeftWindow = "5"
    @Published var kwicRightWindow = "5"
    @Published var engineStatus = "正在连接本地引擎..."
    @Published var workspaceSummary = "等待载入本地语料库"
    @Published var buildSummary = "SwiftUI + Node.js sidecar"
    @Published var isBusy = false
    @Published var lastErrorMessage = ""

    private let engineClient = EngineClient()
    private var initialized = false

    var selectedCorpus: LibraryCorpusItem? {
        guard let selectedCorpusID else { return nil }
        return librarySnapshot.corpora.first(where: { $0.id == selectedCorpusID })
    }

    func initializeIfNeeded() async {
        guard !initialized else { return }
        initialized = true
        await refreshAll()
    }

    func refreshAll() async {
        isBusy = true
        defer { isBusy = false }

        do {
            try await engineClient.start(userDataURL: EnginePaths.defaultUserDataURL())
            async let nextAppInfo = engineClient.fetchAppInfo()
            async let nextLibrary = engineClient.listLibrary()
            async let nextWorkspace = engineClient.fetchWorkspaceState()

            appInfo = try await nextAppInfo
            librarySnapshot = try await nextLibrary
            workspaceSnapshot = try await nextWorkspace
            restoreSelectionFromWorkspace()

            engineStatus = "本地引擎已连接"
            workspaceSummary = buildWorkspaceSummary()
            buildSummary = "SwiftUI + Node.js sidecar（mac native preview）"
            lastErrorMessage = ""
        } catch {
            engineStatus = "本地引擎连接失败"
            lastErrorMessage = error.localizedDescription
        }
    }

    func openSelectedCorpus() async {
        guard let selectedCorpusID else { return }
        isBusy = true
        defer { isBusy = false }

        do {
            let corpus = try await engineClient.openSavedCorpus(corpusId: selectedCorpusID)
            openedCorpus = corpus
            workspaceSummary = buildWorkspaceSummary()
            lastErrorMessage = ""
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func runStats() async {
        do {
            let corpus = try await ensureOpenedCorpus()
            isBusy = true
            defer { isBusy = false }

            statsResult = try await engineClient.runStats(text: corpus.content)
            selectedTab = .stats
            workspaceSummary = buildWorkspaceSummary()
            lastErrorMessage = ""
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func runKWIC() async {
        let keyword = kwicKeyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else {
            lastErrorMessage = "请输入 KWIC 关键词。"
            return
        }

        do {
            let corpus = try await ensureOpenedCorpus()
            isBusy = true
            defer { isBusy = false }

            let leftWindow = Int(kwicLeftWindow) ?? 5
            let rightWindow = Int(kwicRightWindow) ?? 5
            kwicResult = try await engineClient.runKWIC(
                text: corpus.content,
                keyword: keyword,
                leftWindow: leftWindow,
                rightWindow: rightWindow
            )
            selectedTab = .kwic
            workspaceSummary = buildWorkspaceSummary()
            lastErrorMessage = ""
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func shutdown() async {
        await engineClient.stop()
    }

    private func ensureOpenedCorpus() async throws -> OpenedCorpus {
        if let openedCorpus {
            return openedCorpus
        }
        try await openSelectedCorpus()
        if let openedCorpus {
            return openedCorpus
        }
        throw NSError(
            domain: "WordZMac.Workspace",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "请先从左侧选择一条已保存语料。"]
        )
    }

    private func restoreSelectionFromWorkspace() {
        if let currentSelection = selectedCorpusID,
           librarySnapshot.corpora.contains(where: { $0.id == currentSelection }) {
            return
        }

        let preferredName = workspaceSnapshot?.corpusNames.first
        if let preferredName,
           let matchingCorpus = librarySnapshot.corpora.first(where: { $0.name == preferredName }) {
            selectedCorpusID = matchingCorpus.id
            return
        }

        selectedCorpusID = librarySnapshot.corpora.first?.id
    }

    private func buildWorkspaceSummary() -> String {
        let corpusLabel = openedCorpus?.displayName ?? selectedCorpus?.name ?? "未打开语料"
        let workspaceLabel = workspaceSnapshot?.corpusNames.isEmpty == false
            ? "工作区：\(workspaceSnapshot?.corpusNames.joined(separator: "、") ?? "")"
            : "工作区：空"
        return "\(workspaceLabel) ｜ 当前语料：\(corpusLabel)"
    }
}
