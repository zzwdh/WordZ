import Foundation

extension NativeWindowRoute {
    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .mainWorkspace:
            return l10n("主窗口", table: "Windows", mode: mode, fallback: "Main Window")
        case .library:
            return l10n("语料库", table: "Windows", mode: mode, fallback: "Library")
        case .evidenceWorkbench:
            return l10n("摘录", table: "Windows", mode: mode, fallback: "Clips")
        case .sourceReader:
            return l10n("原文阅读器", table: "Windows", mode: mode, fallback: "Source Reader")
        case .settings:
            return l10n("设置", table: "Windows", mode: mode, fallback: "Settings")
        case .taskCenter:
            return l10n("任务中心", table: "Windows", mode: mode, fallback: "Task Center")
        case .updatePrompt:
            return l10n("更新", table: "Windows", mode: mode, fallback: "Update")
        case .about:
            return l10n("关于", table: "Windows", mode: mode, fallback: "About")
        case .help:
            return l10n("使用说明", table: "Windows", mode: mode, fallback: "Usage Guide")
        case .releaseNotes:
            return l10n("版本说明", table: "Windows", mode: mode, fallback: "Release Notes")
        }
    }
}
