import SwiftUI

extension SentimentView {
    var sentimentControlsSection: some View {
        WorkbenchToolbarSection {
            VStack(alignment: .leading, spacing: 12) {
                WorkbenchInlineActionStrip {
                    WorkbenchAdaptiveControls {
                        HStack(spacing: 12) {
                            sourcePicker
                            unitPicker
                            if viewModel.source == .kwicVisible {
                                contextPicker
                            }
                            if viewModel.showsBackendPicker {
                                backendPicker
                            }
                            domainPackPicker
                            if viewModel.backend == .lexicon {
                                ruleProfilePicker
                                calibrationProfilePicker
                            }
                            presetPicker
                            chartPicker
                        }
                    } compact: {
                        VStack(alignment: .leading, spacing: 12) {
                            sourcePicker
                            unitPicker
                            if viewModel.source == .kwicVisible {
                                contextPicker
                            }
                            if viewModel.showsBackendPicker {
                                backendPicker
                            }
                            HStack(spacing: 12) {
                                domainPackPicker
                            }
                            if viewModel.backend == .lexicon {
                                HStack(spacing: 12) {
                                    ruleProfilePicker
                                    calibrationProfilePicker
                                }
                            }
                            HStack(spacing: 12) {
                                presetPicker
                                chartPicker
                            }
                        }
                    }
                } actions: {
                    Button(t("运行情感分析", "Run Sentiment")) {
                        onAction(.run)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isBusy)
                }

                if viewModel.backend == .lexicon {
                    thresholdControls
                    calibrationControls
                    userLexiconBundleSection
                } else {
                    Text(t("本地模型使用内置校准，不显示规则阈值。", "The local model uses built-in calibration, so rule thresholds are hidden."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if viewModel.source == .pastedText {
                    manualTextEditor
                }

                if viewModel.source == .corpusCompare {
                    corpusSelectionSection
                }

                if let backendNotice = viewModel.backendNotice, !backendNotice.isEmpty {
                    Text(backendNotice)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                Text(methodSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if viewModel.selectedDomainPackID == .mixed,
                   viewModel.currentPackRecommendation.usesAutomaticSelection {
                    Text(
                        t(
                            "当前将按 \(viewModel.currentPackSummaryTitle) 运行；若要固定规则包，请手动选择非 Mixed 的 pack。",
                            "This run will use \(viewModel.currentPackSummaryTitle); choose a non-Mixed pack to pin it."
                        )
                    )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

    var sourcePicker: some View {
        WorkbenchMenuPicker(
            title: t("来源", "Source"),
            selection: Binding(
                get: { viewModel.source },
                set: { onAction(.changeSource($0)) }
            ),
            options: SentimentInputSource.allCases
        ) {
            $0.title(in: languageMode)
        }
    }

    var unitPicker: some View {
        WorkbenchMenuPicker(
            title: t("单位", "Unit"),
            selection: Binding(
                get: { viewModel.unit },
                set: { onAction(.changeUnit($0)) }
            ),
            options: viewModel.supportedUnits
        ) {
            $0.title(in: languageMode)
        }
    }

    var contextPicker: some View {
        WorkbenchMenuPicker(
            title: t("上下文", "Context"),
            selection: Binding(
                get: { viewModel.contextBasis },
                set: { onAction(.changeContextBasis($0)) }
            ),
            options: SentimentContextBasis.allCases
        ) {
            $0.title(in: languageMode)
        }
    }

    var backendPicker: some View {
        WorkbenchMenuPicker(
            title: t("后端", "Backend"),
            selection: Binding(
                get: { viewModel.backend },
                set: { onAction(.changeBackend($0)) }
            ),
            options: viewModel.availableBackends
        ) {
            $0.title(in: languageMode)
        }
    }

    var domainPackPicker: some View {
        WorkbenchMenuPicker(
            title: t("规则包", "Pack"),
            selection: Binding(
                get: { viewModel.selectedDomainPackID },
                set: { onAction(.changeDomainPack($0)) }
            ),
            options: viewModel.availableDomainPacks
        ) {
            $0.title(in: languageMode)
        }
    }

    var ruleProfilePicker: some View {
        let profiles = viewModel.availableRuleProfiles
        return WorkbenchMenuPicker(
            title: t("配置", "Profile"),
            selection: Binding(
                get: { viewModel.selectedRuleProfileID },
                set: { onAction(.changeRuleProfile($0)) }
            ),
            options: profiles,
            label: { $0.title },
            value: { $0.id }
        )
    }

    var calibrationProfilePicker: some View {
        let profiles = viewModel.availableCalibrationProfiles
        return WorkbenchMenuPicker(
            title: t("校准", "Calibration"),
            selection: Binding(
                get: { viewModel.selectedCalibrationProfileID },
                set: { onAction(.changeCalibrationProfile($0)) }
            ),
            options: profiles,
            label: { $0.title },
            value: { $0.id }
        )
    }

    var presetPicker: some View {
        WorkbenchMenuPicker(
            title: t("阈值", "Preset"),
            selection: Binding(
                get: { viewModel.thresholdPreset },
                set: { onAction(.changeThresholdPreset($0)) }
            ),
            options: SentimentThresholdPreset.allCases
        ) {
            $0.title(in: languageMode)
        }
    }

    var chartPicker: some View {
        WorkbenchMenuPicker(
            title: t("图表", "Chart"),
            selection: Binding(
                get: { viewModel.chartKind },
                set: { onAction(.changeChartKind($0)) }
            ),
            options: SentimentChartKind.allCases
        ) {
            $0.title(in: languageMode)
        }
    }

    var thresholdControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                thresholdSlider(
                    title: t("决策阈值", "Decision"),
                    binding: Binding(
                        get: { viewModel.decisionThreshold },
                        set: { viewModel.decisionThreshold = $0 }
                    ),
                    range: 0.1...0.8
                )
                thresholdSlider(
                    title: t("最小证据", "Evidence"),
                    binding: Binding(
                        get: { viewModel.minimumEvidence },
                        set: { viewModel.minimumEvidence = $0 }
                    ),
                    range: 0.1...2.0
                )
                thresholdSlider(
                    title: t("中性偏置", "Neutral Bias"),
                    binding: Binding(
                        get: { viewModel.neutralBias },
                        set: { viewModel.neutralBias = $0 }
                    ),
                    range: 0.4...1.8
                )
            }
        }
    }

    var calibrationControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                Text(t("本地校准", "Local Calibration"))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(viewModel.selectedCalibrationProfileTitle(in: languageMode))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if viewModel.canEditWorkspaceCalibration {
                HStack(spacing: 12) {
                    thresholdSlider(
                        title: t("当前 Pack Bias", "Current Pack Bias"),
                        binding: Binding(
                            get: { viewModel.currentPackCalibrationBias },
                            set: { viewModel.currentPackCalibrationBias = $0 }
                        ),
                        range: -0.3...0.3
                    )
                    Text(t("数值越高越保守，越容易回落中性；数值越低越容易保留极性。", "Higher values are more conservative and favor neutral; lower values preserve polarity more aggressively."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: 420, alignment: .leading)
                }
            } else {
                Text(t("默认校准使用内置的 pack-aware bias。切换到 Workspace 后可以保存当前工作区的本地调节。", "Default calibration uses the built-in pack-aware bias. Switch to Workspace to save local tuning for this workspace."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    var userLexiconBundleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                Text(t("用户词典 Bundle", "User Lexicon Bundles"))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button(t("导入 Bundle", "Import Bundle")) {
                    onAction(.importUserLexiconBundle)
                }
                .buttonStyle(.bordered)
                .disabled(isBusy)
            }

            if viewModel.importedLexiconBundles.isEmpty {
                Text(t("尚未导入自定义词典。导入 JSON bundle 后，它会出现在 Profile 列表里，并跟随工作区一起恢复。", "No custom lexicon bundle has been imported yet. After importing a JSON bundle, it will appear in the Profile list and restore with this workspace."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(viewModel.importedLexiconBundles) { bundle in
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(bundle.manifest.id)
                                    .font(.subheadline.weight(.medium))
                                Text(importedBundleSubtitle(bundle))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if viewModel.selectedRuleProfile.importedBundleIDs.contains(bundle.id) {
                                Text(t("当前启用", "Active"))
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            }
                            Button(t("移除", "Remove")) {
                                onAction(.removeUserLexiconBundle(bundle.id))
                            }
                            .buttonStyle(.bordered)
                            .disabled(isBusy)
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.secondary.opacity(0.08))
                        )
                    }
                }
            }
        }
    }

    func thresholdSlider(
        title: String,
        binding: Binding<Double>,
        range: ClosedRange<Double>
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(title): \(format(binding.wrappedValue))")
                .font(.caption)
                .foregroundStyle(.secondary)
            Slider(value: binding, in: range)
                .frame(maxWidth: 220)
        }
    }

    var manualTextEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(t("输入英文文本", "Input English Text"))
                .font(.subheadline.weight(.semibold))
            TextEditor(text: Binding(
                get: { viewModel.manualText },
                set: { onAction(.changeManualText($0)) }
            ))
            .font(.body.monospaced())
            .frame(minHeight: 140)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.18))
            )
            Text("\(viewModel.manualTextCharacterCount) \(t("字符", "chars")) · \(viewModel.manualTextSentenceCountEstimate) \(t("句", "sentences"))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    var corpusSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(t("选择目标语料", "Select Target Corpora"))
                .font(.subheadline.weight(.semibold))
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(viewModel.selectionItems) { item in
                    Toggle(
                        isOn: Binding(
                            get: { item.isSelected },
                            set: { _ in onAction(.toggleCorpusSelection(item.id)) }
                        )
                    ) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                            Text(item.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(.checkbox)
                }
            }

            Picker(
                t("参照范围", "Reference Scope"),
                selection: Binding(
                    get: { viewModel.selectedReferenceOptionID },
                    set: { onAction(.changeReferenceCorpus($0.isEmpty ? nil : $0)) }
                )
            ) {
                Text(t("不设参照", "None")).tag("")
                ForEach(viewModel.referenceOptions) { option in
                    Text(option.title).tag(option.id)
                }
            }
            .pickerStyle(.menu)
        }
    }

    var methodSummary: String {
        let sourceSummary: String
        switch viewModel.source {
        case .topicSegments:
            sourceSummary = t("Topics x Sentiment 交叉分析", "Topics x Sentiment cross-analysis")
        case .corpusCompare:
            let scopeSummary = viewModel.corpusCompareScopeSummary(in: languageMode)
            let focusTerm = viewModel.rowFilterQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            if focusTerm.isEmpty {
                sourceSummary = "\(t("目标 / 参照语料对照", "Target / reference contrast")) · \(scopeSummary)"
            } else {
                sourceSummary = "\(t("目标 / 参照语料对照", "Target / reference contrast")) · \(scopeSummary) · \(t("聚焦词项", "Focus Term")): \(focusTerm)"
            }
        default:
            sourceSummary = "neutrality / positivity / negativity"
        }
        let packSummary = " · \(t("规则包", "Pack")): \(viewModel.currentPackSummaryTitle)"
        let lexiconSummary = viewModel.backend == .lexicon
            ? "\(packSummary) · \(t("配置", "Profile")): \(viewModel.selectedRuleProfile.title) · \(t("校准", "Calibration")): \(viewModel.selectedCalibrationProfileTitle(in: languageMode))\(selectedBundleSummarySuffix)"
            : packSummary
        return "\(t("当前后端", "Selected backend")): \(viewModel.backend.title(in: languageMode))\(lexiconSummary) · \(sourceSummary)"
    }

    var selectedBundleSummarySuffix: String {
        guard !viewModel.selectedRuleProfile.importedBundleIDs.isEmpty else { return "" }
        return " · \(t("用户词典", "Bundles")): \(viewModel.selectedRuleProfile.importedBundleIDs.joined(separator: ", "))"
    }
}
