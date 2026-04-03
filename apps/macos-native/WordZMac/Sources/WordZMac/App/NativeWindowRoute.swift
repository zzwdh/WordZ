import Foundation

enum NativeWindowRoute: String {
    case mainWorkspace
    case library
    case settings
    case taskCenter
    case about
    case help
    case releaseNotes

    var id: String { rawValue }

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .mainWorkspace:
            return wordZText("主窗口", "Main Window", mode: mode)
        case .library:
            return wordZText("语料库", "Library", mode: mode)
        case .settings:
            return wordZText("设置", "Settings", mode: mode)
        case .taskCenter:
            return wordZText("任务中心", "Task Center", mode: mode)
        case .about:
            return wordZText("关于", "About", mode: mode)
        case .help:
            return wordZText("使用说明", "Usage Guide", mode: mode)
        case .releaseNotes:
            return wordZText("版本说明", "Release Notes", mode: mode)
        }
    }
}
