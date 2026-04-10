import SwiftUI

extension KeywordView {
    var keywordHeaderActions: some View {
        WorkbenchPageHeaderActions(summary: keywordHeaderSummary, layout: .trailingStack) {
            runButton
        }
    }

    var keywordInputSection: some View {
        WorkbenchToolbarSection {
            Text(t("关键词分析（Target vs Reference）", "Keyword Analysis (Target vs Reference)"))
                .font(.headline)

            if viewModel.corpusOptions.isEmpty {
                Text(t("请先在语料库中导入至少两条语料，才能进行关键词分析。", "Import at least two corpora into the library before running keyword analysis."))
                    .foregroundStyle(.secondary)
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        targetPicker
                        referencePicker
                        statisticPicker
                        runButton
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            targetPicker
                            referencePicker
                        }
                        HStack(spacing: 12) {
                            statisticPicker
                            runButton
                        }
                    }
                }
            }

            HStack(spacing: 16) {
                Toggle(t("小写化", "Lowercase"), isOn: $viewModel.lowercased)
                Toggle(t("去标点", "Remove punctuation"), isOn: $viewModel.removePunctuation)
                HStack(spacing: 8) {
                    Text(t("最小 Target 频次", "Min Target Freq"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("2", text: $viewModel.minimumFrequency)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 72)
                }
            }

            StopwordControlsView(
                filter: $viewModel.stopwordFilter,
                isEditorPresented: $viewModel.isEditingStopwords
            )

            Text(t("关键词不是简单高频词，而是指在 Target 中相对 Reference 显著更突出的词项。默认使用 Log-Likelihood 作为 keyness 统计量。", "Keywords are not just frequent words; they are terms that are statistically more prominent in the target corpus than in the reference corpus. Log-Likelihood is used by default for keyness."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    var targetPicker: some View {
        Picker(
            t("Target Corpus", "Target Corpus"),
            selection: Binding(
                get: { viewModel.targetCorpusIDSnapshot },
                set: { onAction(.changeTargetCorpus($0)) }
            )
        ) {
            ForEach(viewModel.corpusOptions) { option in
                Text(option.title).tag(option.id)
            }
        }
        .pickerStyle(.menu)
    }

    var referencePicker: some View {
        Picker(
            t("Reference Corpus", "Reference Corpus"),
            selection: Binding(
                get: { viewModel.referenceCorpusIDSnapshot },
                set: { onAction(.changeReferenceCorpus($0)) }
            )
        ) {
            ForEach(viewModel.corpusOptions) { option in
                Text(option.title).tag(option.id)
            }
        }
        .pickerStyle(.menu)
    }

    var statisticPicker: some View {
        WorkbenchMenuPicker(
            title: t("统计量", "Statistic"),
            selection: Binding(
                get: { viewModel.statistic },
                set: { onAction(.changeStatistic($0)) }
            ),
            options: Array(KeywordStatisticMethod.allCases)
        ) {
            $0.title(in: languageMode)
        }
    }

    var runButton: some View {
        Button(t("运行关键词分析", "Run Keyword Analysis")) {
            onAction(.run)
        }
        .buttonStyle(.borderedProminent)
        .disabled(isBusy || !viewModel.canRun)
    }

    var keywordHeaderSummary: String {
        let target = viewModel.selectedTargetCorpusItem()?.name
            ?? viewModel.corpusOptions.first(where: { $0.id == viewModel.targetCorpusIDSnapshot })?.title
            ?? t("未选择 Target", "No target selected")
        let reference = viewModel.selectedReferenceCorpusItem()?.name
            ?? viewModel.corpusOptions.first(where: { $0.id == viewModel.referenceCorpusIDSnapshot })?.title
            ?? t("未选择 Reference", "No reference selected")
        return "\(target) → \(reference)"
    }
}
