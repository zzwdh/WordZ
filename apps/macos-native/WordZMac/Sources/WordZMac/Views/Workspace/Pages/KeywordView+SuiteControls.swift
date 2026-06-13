import SwiftUI

extension KeywordView {
    var keywordSuiteControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            focusSelectionSection
            referenceSelectionSection
            keywordSuiteParameterControls
            thresholdSection
            annotationSummaryCard

            StopwordControlsView(
                filter: $viewModel.stopwordFilter,
                isEditorPresented: $viewModel.isEditingStopwords
            )

            if viewModel.result != nil {
                keywordCurrentResultSaveControls
            }

            Text(
                t(
                    "先选目标语料和参照语料，再运行关键词计算。词、术语和 N-grams 共用同一套统计方式、方向、阈值和语言筛选。",
                    "Choose focus and reference scopes before running keyword analysis. Words, Terms, and N-grams share the same statistic, direction, thresholds, and language filters."
                )
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    var keywordSuiteParameterControls: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                directionPicker
                statisticPicker
                languagePresetPicker
                runButton
            }
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    directionPicker
                    statisticPicker
                    languagePresetPicker
                }
                HStack(spacing: 12) {
                    runButton
                }
            }
        }
    }

    var keywordCurrentResultSaveControls: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                TextField(t("保存当前结果为命名词表", "Save current rows as a named list"), text: $viewModel.savedListName)
                    .textFieldStyle(.roundedBorder)
                Button(t("保存词表", "Save List")) {
                    onAction(.saveCurrentList)
                }
                .buttonStyle(.bordered)
            }
            VStack(alignment: .leading, spacing: 10) {
                TextField(t("保存当前结果为命名词表", "Save current rows as a named list"), text: $viewModel.savedListName)
                    .textFieldStyle(.roundedBorder)
                Button(t("保存词表", "Save List")) {
                    onAction(.saveCurrentList)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    var focusSelectionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Text(t("目标语料", "Focus"))
                    .font(.headline)
                WorkbenchMenuPicker(
                    title: t("范围", "Scope"),
                    selection: $viewModel.focusSelectionKind,
                    options: Array(KeywordTargetSelectionKind.allCases)
                ) {
                    $0.title(in: languageMode)
                }
            }

            switch viewModel.focusSelectionKind {
            case .singleCorpus:
                corpusPicker(
                    title: t("目标语料", "Focus Corpus"),
                    selection: Binding(
                        get: { viewModel.selectedFocusCorpusID ?? "" },
                        set: { viewModel.selectedFocusCorpusID = $0.isEmpty ? nil : $0 }
                    )
                )
            case .selectedCorpora:
                keywordCorpusSelectionGrid(
                    options: viewModel.corpusOptions,
                    selectedIDs: viewModel.selectedFocusCorpusIDs,
                    toggle: viewModel.toggleFocusCorpusSelection
                )
            case .namedCorpusSet:
                corpusSetPicker(
                    title: t("目标语料集", "Focus Corpus Set"),
                    selection: Binding(
                        get: { viewModel.selectedFocusCorpusSetID ?? "" },
                        set: { viewModel.selectedFocusCorpusSetID = $0.isEmpty ? nil : $0 }
                    )
                )
            }
        }
    }

    var referenceSelectionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Text(t("参照语料", "Reference"))
                    .font(.headline)
                WorkbenchMenuPicker(
                    title: t("类型", "Type"),
                    selection: $viewModel.referenceSourceKind,
                    options: Array(KeywordReferenceSourceKind.allCases)
                ) {
                    $0.title(in: languageMode)
                }
            }

            switch viewModel.referenceSourceKind {
            case .singleCorpus:
                corpusPicker(
                    title: t("参照语料", "Reference Corpus"),
                    selection: Binding(
                        get: { viewModel.selectedReferenceCorpusID ?? "" },
                        set: { viewModel.selectedReferenceCorpusID = $0.isEmpty ? nil : $0 }
                    )
                )
            case .namedCorpusSet:
                corpusSetPicker(
                    title: t("参照语料集", "Reference Corpus Set"),
                    selection: Binding(
                        get: { viewModel.selectedReferenceCorpusSetID ?? "" },
                        set: { viewModel.selectedReferenceCorpusSetID = $0.isEmpty ? nil : $0 }
                    )
                )
            case .importedWordList:
                importedReferenceEditor
            }
        }
    }

    var importedReferenceEditor: some View {
        Group {
            HStack(spacing: 8) {
                Button(t("从文件导入", "Import From File")) {
                    onAction(.importReferenceWordList)
                }
                .buttonStyle(.bordered)

                Spacer()
            }
            TextEditor(text: $viewModel.importedReferenceListText)
                .font(.caption.monospaced())
                .frame(minHeight: 96, maxHeight: 140)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(WordZTheme.primary, lineWidth: 1)
                )
            Text(t("每行一个词；需要频次时，可写成“词<TAB>频次”。", "One term per line, or use term<TAB>freq."))
                .font(.caption)
                .foregroundStyle(.secondary)
            if !viewModel.importedReferenceParseSummaryText.isEmpty {
                Text(viewModel.importedReferenceParseSummaryText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            if let sourceName = viewModel.importedReferenceListSourceName,
               !sourceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(t("来源", "Source") + ": " + sourceName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    var thresholdSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(t("阈值", "Thresholds"))
                .font(.headline)
            HStack(spacing: 12) {
                keywordThresholdField(title: t("目标最小词频", "Min Focus"), text: $viewModel.minFocusFrequency)
                keywordThresholdField(title: t("参照最小词频", "Min Reference"), text: $viewModel.minReferenceFrequency)
                keywordThresholdField(title: t("合计最小词频", "Min Combined"), text: $viewModel.minCombinedFrequency)
                keywordThresholdField(title: t("显著性上限", "Max p"), text: $viewModel.maxPValue)
                keywordThresholdField(title: t("差异强度下限", "Min Difference Strength"), text: $viewModel.minAbsLogRatio)
            }
        }
    }

    var directionPicker: some View {
        WorkbenchMenuPicker(
            title: t("方向", "Direction"),
            selection: $viewModel.direction,
            options: Array(KeywordDirection.allCases)
        ) {
            $0.title(in: languageMode)
        }
    }

    var statisticPicker: some View {
        WorkbenchMenuPicker(
            title: t("显著性算法", "Statistic"),
            selection: $viewModel.statistic,
            options: Array(KeywordStatisticMethod.allCases)
        ) {
            $0.title(in: languageMode)
        }
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

    var annotationSummaryCard: some View {
        WorkbenchSectionCard {
            VStack(alignment: .leading, spacing: 8) {
                AnnotationFilterStatusStrip(
                    state: viewModel.workspaceAnnotationState,
                    resultCount: viewModel.scene?.totalRows
                )
            }
        }
    }
}
