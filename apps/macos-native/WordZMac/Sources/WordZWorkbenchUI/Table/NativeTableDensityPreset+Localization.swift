import WordZExport
import WordZShared

extension NativeTableDensityPreset {
    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .compact:
            return wordZText("紧凑", "Compact", mode: mode)
        case .standard:
            return wordZText("标准", "Standard", mode: mode)
        case .reading:
            return wordZText("阅读", "Reading", mode: mode)
        }
    }
}
