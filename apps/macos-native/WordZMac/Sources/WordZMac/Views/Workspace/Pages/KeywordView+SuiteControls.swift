import SwiftUI

extension KeywordView {
    var keywordSuiteControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            focusSelectionSection
            referenceSelectionSection
            keywordSuiteParameterControls
            thresholdSection

            HStack(spacing: 12) {
                scriptsMenu
                lexicalClassesMenu
            }

            StopwordControlsView(
                filter: $viewModel.stopwordFilter,
                isEditorPresented: $viewModel.isEditingStopwords
            )

            if viewModel.result != nil {
                keywordCurrentResultSaveControls
            }

            Text(
                t(
                    "Keyword Suite 强制使用显式 Focus / Reference。Words、Terms、N-grams 共用同一套统计量、方向、阈值和语言筛选。",
                    "Keyword Suite always uses explicit focus/reference scopes. Words, Terms, and N-grams share the same statistics, direction, thresholds, and language filters."
                )
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    var keywordSuiteParameterControls: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                unitPicker
                directionPicker
                statisticPicker
                languagePresetPicker
                runButton
            }
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    unitPicker
                    directionPicker
                }
                HStack(spacing: 12) {
                    statisticPicker
                    languagePresetPicker
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
                Text(t("Focus", "Focus"))
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
                    title: t("Focus Corpus", "Focus Corpus"),
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
                    title: t("Focus Corpus Set", "Focus Corpus Set"),
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
                Text(t("Reference", "Reference"))
                    .font(.headline)
                WorkbenchMenuPicker(
                    title: t("来源", "Source"),
                    selection: $viewModel.referenceSourceKind,
                    options: Array(KeywordReferenceSourceKind.allCases)
                ) {
                    $0.title(in: languageMode)
                }
            }

            switch viewModel.referenceSourceKind {
            case .singleCorpus:
                corpusPicker(
                    title: t("Reference Corpus", "Reference Corpus"),
                    selection: Binding(
                        get: { viewModel.selectedReferenceCorpusID ?? "" },
                        set: { viewModel.selectedReferenceCorpusID = $0.isEmpty ? nil : $0 }
                    )
                )
            case .namedCorpusSet:
                corpusSetPicker(
                    title: t("Reference Corpus Set", "Reference Corpus Set"),
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
            Text(t("每行一个词项，或使用 term<TAB>freq。", "One term per line, or use term<TAB>freq."))
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
                keywordThresholdField(title: t("Min Focus", "Min Focus"), text: $viewModel.minFocusFrequency)
                keywordThresholdField(title: t("Min Ref", "Min Ref"), text: $viewModel.minReferenceFrequency)
                keywordThresholdField(title: t("Min Combined", "Min Combined"), text: $viewModel.minCombinedFrequency)
                keywordThresholdField(title: t("Max p", "Max p"), text: $viewModel.maxPValue)
                keywordThresholdField(title: t("Min |LR|", "Min |LR|"), text: $viewModel.minAbsLogRatio)
            }
        }
    }

    var unitPicker: some View {
        WorkbenchMenuPicker(
            title: t("单位", "Unit"),
            selection: $viewModel.unit,
            options: Array(KeywordUnit.allCases)
        ) {
            $0.title(in: languageMode)
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
            title: t("统计量", "Statistic"),
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

    var scriptsMenu: some View {
        Menu {
            ForEach(TokenScript.allCases) { script in
                Button {
                    viewModel.toggleScript(script)
                } label: {
                    Label(
                        script.title(in: languageMode),
                        systemImage: viewModel.selectedScripts.contains(script) ? "checkmark.circle.fill" : "circle"
                    )
                }
            }
        } label: {
            Label(
                viewModel.selectedScripts.isEmpty
                    ? t("全部脚本", "All Scripts")
                    : "\(t("脚本", "Scripts")) \(viewModel.selectedScripts.count)",
                systemImage: "character.cursor.ibeam"
            )
        }
        .menuStyle(.borderlessButton)
    }

    var lexicalClassesMenu: some View {
        Menu {
            ForEach(TokenLexicalClass.allCases) { lexicalClass in
                Button {
                    viewModel.toggleLexicalClass(lexicalClass)
                } label: {
                    Label(
                        lexicalClass.title(in: languageMode),
                        systemImage: viewModel.selectedLexicalClasses.contains(lexicalClass) ? "checkmark.circle.fill" : "circle"
                    )
                }
            }
        } label: {
            Label(
                viewModel.selectedLexicalClasses.isEmpty
                    ? t("全部词类", "All Classes")
                    : "\(t("词类", "Classes")) \(viewModel.selectedLexicalClasses.count)",
                systemImage: "line.3.horizontal.decrease.circle"
            )
        }
        .menuStyle(.borderlessButton)
    }
}
