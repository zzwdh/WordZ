import Foundation

extension NativeWindowRoute {
    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .mainWorkspace:
            return l10n("主窗口", table: "Windows", mode: mode, fallback: "Main Window")
        case .library:
            return l10n("语料库", table: "Windows", mode: mode, fallback: "Library")
        case .sourceReader:
            return l10n("来源文本", table: "Windows", mode: mode, fallback: "Source Text")
        case .settings:
            return l10n("设置", table: "Windows", mode: mode, fallback: "Settings")
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
