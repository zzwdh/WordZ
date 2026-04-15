import SwiftUI

extension TokenizeView {
    var tokenizeInputSection: some View {
        WorkbenchSearchToolbarSection(
            searchOptions: $viewModel.searchOptions,
            stopwordFilter: $viewModel.stopwordFilter,
            isEditingStopwords: $viewModel.isEditingStopwords
        ) {
            VStack(alignment: .leading, spacing: 12) {
                WorkbenchInlineActionStrip {
                    tokenizeSearchField
                } actions: {
                    HStack(spacing: 8) {
                        tokenizeRunButton
                        exportTextButton
                    }
                }

                WorkbenchAdaptiveControls {
                    HStack(spacing: 12) {
                        languagePresetPicker
                        lemmaStrategyPicker
                        Spacer(minLength: 0)
                    }
                } compact: {
                    VStack(alignment: .leading, spacing: 12) {
                        languagePresetPicker
                        lemmaStrategyPicker
                    }
                }

                Text(tokenizeControlSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    var tokenizeSearchField: some View {
        TextField(t("搜索 token（留空显示全部）", "Search tokens (leave blank for all)"), text: $viewModel.query)
            .textFieldStyle(.roundedBorder)
            .layoutPriority(1)
    }

    var languagePresetPicker: some View {
        WorkbenchMenuPicker(
            title: t("语言预设", "Language Preset"),
            selection: $viewModel.languagePreset,
            options: Array(TokenizeLanguagePreset.allCases)
        ) {
            $0.title(in: languageMode)
        }
    }

    var lemmaStrategyPicker: some View {
        WorkbenchMenuPicker(
            title: t("词形策略", "Lemma Strategy"),
            selection: $viewModel.lemmaStrategy,
            options: Array(TokenLemmaStrategy.allCases)
        ) {
            $0.title(in: languageMode)
        }
    }

    var tokenizeRunButton: some View {
        Button(t("开始分词", "Run Tokenize")) { onAction(.run) }
            .buttonStyle(.borderedProminent)
            .disabled(isBusy)
    }

    var exportTextButton: some View {
        Button(t("导出 TXT", "Export TXT")) { onAction(.exportText) }
            .buttonStyle(.bordered)
            .disabled(viewModel.exportDocument == nil)
    }

    var tokenizeControlSummary: String {
        "\(viewModel.languagePreset.title(in: languageMode)) · \(viewModel.lemmaStrategy.title(in: languageMode))"
    }
}
