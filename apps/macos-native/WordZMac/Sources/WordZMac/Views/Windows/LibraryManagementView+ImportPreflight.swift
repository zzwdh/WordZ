import SwiftUI
import WordZShared

struct LibraryImportPreflightSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.wordZLanguageMode) private var languageMode
    let scene: LibraryImportPreflightSceneModel
    let onConfirm: ([String], String) -> Void
    let onDismiss: () -> Void
    @State private var corpusName: String

    init(
        scene: LibraryImportPreflightSceneModel,
        onConfirm: @escaping ([String], String) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.scene = scene
        self.onConfirm = onConfirm
        self.onDismiss = onDismiss
        _corpusName = State(initialValue: scene.defaultCorpusName)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            NativeWindowHeader(title: scene.title, subtitle: scene.subtitle) {
                Button(t("取消", "Cancel")) {
                    onDismiss()
                    dismiss()
                }
                Button(t("导入", "Import")) {
                    onConfirm(scene.paths, normalizedCorpusName)
                    dismiss()
                }
                .adaptiveGlassButtonStyle(prominent: true)
                .disabled(scene.supportedCountText == "0")
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 118), spacing: 10)], spacing: 10) {
                NativeMetricTile(title: t("文件", "Files"), value: scene.fileCountText)
                NativeMetricTile(title: t("文件夹", "Folders"), value: scene.folderCountText)
                NativeMetricTile(title: t("可导入", "Importable"), value: scene.supportedCountText)
                NativeMetricTile(title: t("会跳过", "Skipped"), value: scene.unsupportedCountText)
                NativeMetricTile(title: t("同名风险", "Name Risks"), value: scene.duplicateRiskCountText)
            }

            NativeWindowSection(
                title: t("导入设置", "Import Settings"),
                subtitle: scene.preserveHierarchyText
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(t("语料名称", "Corpus Name"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        TextField(scene.defaultCorpusName, text: $corpusName)
                            .textFieldStyle(.roundedBorder)
                    }

                    if scene.warnings.isEmpty {
                        Label(t("没有发现明显风险", "No obvious risks found"), systemImage: "checkmark.circle")
                            .foregroundStyle(.green)
                    } else {
                        ForEach(scene.warnings) { warning in
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(warning.title)
                                        .font(.callout.weight(.semibold))
                                    Text(warning.detail)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: warning.systemImage)
                            }
                        }
                    }
                }
            }

            NativeWindowSection(
                title: t("预览", "Preview"),
                subtitle: t("显示前几项选择和扫描结果", "Showing the first selected or scanned items")
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(scene.previewItems) { item in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Image(systemName: item.isSupported ? "doc.text" : "doc.badge.ellipsis")
                                .foregroundStyle(item.isSupported ? .green : .secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.callout)
                                    .lineLimit(1)
                                Text(item.detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(minWidth: 560, minHeight: 460, alignment: .topLeading)
        .librarySheetSurface()
    }

    private func t(_ zh: String, _ en: String) -> String {
        wordZText(zh, en, mode: languageMode)
    }

    private var normalizedCorpusName: String {
        let trimmed = corpusName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? scene.defaultCorpusName : trimmed
    }
}
