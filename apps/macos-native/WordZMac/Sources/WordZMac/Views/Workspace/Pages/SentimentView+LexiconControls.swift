import SwiftUI

extension SentimentView {
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
}
