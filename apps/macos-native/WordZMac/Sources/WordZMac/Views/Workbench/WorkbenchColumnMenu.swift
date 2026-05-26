import SwiftUI

struct WorkbenchColumnMenu<Key: Identifiable>: View {
    @Environment(\.wordZLanguageMode) private var languageMode
    let title: String
    let keys: [Key]
    let label: (Key) -> String
    let isVisible: (Key) -> Bool
    let onToggle: (Key) -> Void

    var body: some View {
        Menu(title) {
            ForEach(keys) { key in
                Toggle(
                    isOn: Binding(
                        get: { isVisible(key) },
                        set: { newValue in
                            guard newValue != isVisible(key),
                                  Self.canToggle(key, keys: keys, isVisible: isVisible)
                            else { return }
                            onToggle(key)
                        }
                    )
                ) {
                    Text(label(key))
                }
                .disabled(!Self.canToggle(key, keys: keys, isVisible: isVisible))
                .help(toggleHelp(for: key))
            }
        }
    }

    static func canToggle(
        _ key: Key,
        keys: [Key],
        isVisible: (Key) -> Bool
    ) -> Bool {
        !isVisible(key) || visibleCount(keys: keys, isVisible: isVisible) > 1
    }

    static func visibleCount(
        keys: [Key],
        isVisible: (Key) -> Bool
    ) -> Int {
        keys.filter(isVisible).count
    }

    private func toggleHelp(for key: Key) -> String {
        guard !Self.canToggle(key, keys: keys, isVisible: isVisible) else { return "" }
        return wordZText("至少保留一列可见。", "Keep at least one column visible.", mode: languageMode)
    }
}
