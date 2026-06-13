import SwiftUI

extension KeywordView {
    var keywordInputSection: some View {
        WorkbenchToolbarSection {
            VStack(alignment: .leading, spacing: 12) {
                Picker("", selection: Binding(
                    get: { viewModel.activeTab },
                    set: { onAction(.changeTab($0)) }
                )) {
                    ForEach(KeywordSuiteTab.allCases) { tab in
                        Text(tab.title(in: languageMode)).tag(tab)
                    }
                }
                .pickerStyle(.segmented)

                Text(keywordHeaderSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let runAvailabilityMessage = keywordRunAvailabilityMessage {
                    Label(runAvailabilityMessage, systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if viewModel.activeTab == .lists {
                    keywordListsControls
                } else {
                    keywordSuiteControls
                }
            }
        }
    }

    var runButton: some View {
        Button(t("运行关键词计算", "Run Keyword Analysis")) {
            onAction(.run)
        }
        .buttonStyle(.borderedProminent)
        .disabled(isBusy || !viewModel.canRun)
    }

    var keywordRunAvailabilityMessage: String? {
        if isBusy {
            return t("当前正在处理任务，完成后可运行关键词计算。", "A task is running. Keyword analysis will be available when it finishes.")
        }
        if viewModel.canRun {
            return nil
        }
        if !viewModel.canResolveFocusSelection {
            return t("请选择要分析的目标语料或语料集。", "Choose the focus corpus or corpus set to analyze.")
        }
        if !viewModel.canResolveReferenceSelection {
            return t("请选择参照语料，或导入参照词表。", "Choose a reference corpus, or import a reference word list.")
        }
        return t("补齐目标语料和参照语料后即可运行关键词计算。", "Complete the focus and reference selections to run keyword analysis.")
    }

    var keywordHeaderSummary: String {
        [
            "\(viewModel.focusSelectionSummary) → \(viewModel.referenceSelectionSummary)",
            viewModel.annotationSummary(in: languageMode)
        ].joined(separator: "\n")
    }
}
