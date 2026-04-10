import SwiftUI

struct WelcomeSheetView: View {
    @Environment(\.wordZLanguageMode) private var languageMode
    let scene: WelcomeSceneModel
    let onDismiss: () -> Void
    let onOpenSelection: () -> Void
    let onOpenRecent: (String) -> Void
    let onOpenReleaseNotes: () -> Void
    let onOpenFeedback: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(scene.title)
                        .font(.system(size: 28, weight: .semibold))
                    Text(scene.subtitle)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text(scene.workspaceSummary)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(t("开始使用", "Get Started"), action: onDismiss)
                    .keyboardShortcut(.defaultAction)
            }

            HStack(alignment: .top, spacing: 18) {
                GroupBox(t("快速开始", "Quick Start")) {
                    VStack(alignment: .leading, spacing: 10) {
                        Button(t("打开当前选中语料", "Open Current Selection"), action: onOpenSelection)
                            .disabled(!scene.canOpenSelection)
                        Button(t("查看版本说明", "View Release Notes"), action: onOpenReleaseNotes)
                        Button(t("提交反馈", "Send Feedback"), action: onOpenFeedback)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
                }

                GroupBox(t("最近打开", "Recent")) {
                    VStack(alignment: .leading, spacing: 8) {
                        if scene.recentDocuments.isEmpty {
                            Text(t("还没有最近打开记录。", "No recent documents yet."))
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(scene.recentDocuments) { item in
                                Button {
                                    onOpenRecent(item.corpusID)
                                } label: {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.title)
                                        Text(item.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
                }
            }

            if !scene.releaseNotes.isEmpty {
                GroupBox(t("近期变化", "Recent Changes")) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(scene.releaseNotes.prefix(5).enumerated()), id: \.offset) { _, line in
                            Text("• \(line)")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
                }
            }

            if !scene.help.isEmpty {
                GroupBox(t("帮助", "Help")) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(scene.help.prefix(5).enumerated()), id: \.offset) { _, line in
                            Text("• \(line)")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
                }
            }
        }
        .padding(24)
        .frame(minWidth: 720, minHeight: 420)
    }

    private func t(_ zh: String, _ en: String) -> String {
        wordZText(zh, en, mode: languageMode)
    }
}
