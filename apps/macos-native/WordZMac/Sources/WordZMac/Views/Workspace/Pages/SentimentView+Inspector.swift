import SwiftUI

extension SentimentView {
    func inspectorHeadline(for row: SentimentSceneRow) -> String {
        if let confidence = row.diagnostics.confidence {
            return "\(row.effectiveLabel.title(in: languageMode)) · \(t("置信度", "Confidence")) \(formatPercent(confidence))"
        }
        if row.isManuallyOverridden {
            return "\(t("人工改标", "Manual Override")) · \(row.effectiveLabel.title(in: languageMode))"
        }
        if row.reviewStatus == .confirmed {
            return "\(t("确认原判", "Confirmed Raw")) · \(row.effectiveLabel.title(in: languageMode))"
        }
        return "\(row.effectiveLabel.title(in: languageMode)) · Net \(format(row.rawNetScore))"
    }

    @ViewBuilder
    func reviewInspectorSection(for row: SentimentSceneRow) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()

            HStack(spacing: 8) {
                Text(t("审校", "Review"))
                    .font(.subheadline.weight(.semibold))
                if row.isManuallyOverridden {
                    Text(t("人工改标", "Manual Override"))
                        .font(.caption)
                        .foregroundStyle(.orange)
                } else if row.reviewStatus == .confirmed {
                    Text(t("确认原判", "Confirmed Raw"))
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }

            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(t("Raw Result", "Raw Result"))
                        .font(.caption.weight(.semibold))
                    Text("\(t("标签", "Label")): \(row.rawLabel.title(in: languageMode))")
                        .font(.caption)
                    Text("P \(formatPercent(row.rawPositivityScore)) · N \(formatPercent(row.rawNeutralityScore)) · Neg \(formatPercent(row.rawNegativityScore))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(t("Reviewed Result", "Reviewed Result"))
                        .font(.caption.weight(.semibold))
                    Text("\(t("标签", "Label")): \(row.effectiveLabel.title(in: languageMode))")
                        .font(.caption)
                    Text("P \(formatPercent(row.effectivePositivityScore)) · N \(formatPercent(row.effectiveNeutralityScore)) · Neg \(formatPercent(row.effectiveNegativityScore))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            TextField(
                t("可选审校备注", "Optional review note"),
                text: Binding(
                    get: { viewModel.selectedReviewNoteDraft },
                    set: { onAction(.changeSelectedRowReviewNote($0)) }
                )
            )
            .textFieldStyle(.roundedBorder)

            HStack(spacing: 8) {
                Button(t("Confirm Raw", "Confirm Raw")) {
                    onAction(.confirmSelectedRow)
                }
                .buttonStyle(.bordered)
                .disabled(isBusy)

                Button(t("Mark Positive", "Mark Positive")) {
                    onAction(.overrideSelectedRow(.positive))
                }
                .buttonStyle(.bordered)
                .disabled(isBusy)

                Button(t("Mark Neutral", "Mark Neutral")) {
                    onAction(.overrideSelectedRow(.neutral))
                }
                .buttonStyle(.bordered)
                .disabled(isBusy)

                Button(t("Mark Negative", "Mark Negative")) {
                    onAction(.overrideSelectedRow(.negative))
                }
                .buttonStyle(.bordered)
                .disabled(isBusy)

                Button(t("Clear Review", "Clear Review")) {
                    onAction(.clearSelectedRowReview)
                }
                .buttonStyle(.bordered)
                .disabled(isBusy || row.reviewSampleID == nil)
            }

            if let reviewNote = row.reviewNote, !reviewNote.isEmpty {
                Text("\(t("已保存备注", "Saved Note")): \(reviewNote)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let reviewedAt = row.reviewedAt, !reviewedAt.isEmpty {
                Text("\(t("更新时间", "Reviewed At")): \(reviewedAt)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    @ViewBuilder
    func rawEvidenceSection(for row: SentimentSceneRow, scene: SentimentSceneModel) -> some View {
        if row.mixedEvidence {
            Text(t("正负证据接近，原始规则结果按中性处理。", "Positive and negative evidence are close in the raw analysis, so the row was treated as neutral."))
                .font(.caption)
                .foregroundStyle(.orange)
        }
        if let ruleSummary = row.diagnostics.ruleSummary,
           !ruleSummary.isEmpty {
            Text(ruleSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        if !row.diagnostics.scopeNotes.isEmpty {
            Text(row.diagnostics.scopeNotes.joined(separator: ", "))
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        if scene.supportsEvidenceHits, row.evidence.isEmpty {
            Text(t("没有命中显著情感证据。", "No salient sentiment evidence was matched."))
                .font(.caption)
                .foregroundStyle(.secondary)
        } else if scene.supportsEvidenceHits {
            ForEach(row.evidence) { hit in
                HStack(alignment: .top, spacing: 8) {
                    Text(hit.surface)
                        .font(.subheadline.weight(.semibold))
                    Text("base \(format(hit.baseScore)) → \(format(hit.adjustedScore))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Text(hit.ruleTags.joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        } else {
            modelDiagnosticsSection(for: row)
        }
        if scene.supportsEvidenceHits, !row.diagnostics.ruleTraces.isEmpty {
            Divider()
            ruleTraceSection(for: row)
        }
    }

    @ViewBuilder
    func modelDiagnosticsSection(for row: SentimentSceneRow) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let confidence = row.diagnostics.confidence {
                Text("\(t("置信度", "Confidence")): \(formatPercent(confidence))")
                    .font(.caption.monospacedDigit())
            }
            if let topMargin = row.diagnostics.topMargin {
                Text("\(t("边际差", "Top Margin")): \(format(topMargin))")
                    .font(.caption.monospacedDigit())
            }
            if let subunitCount = row.diagnostics.subunitCount {
                Text("\(t("聚合子单元", "Aggregated Subunits")): \(subunitCount)")
                    .font(.caption.monospacedDigit())
            }
            if let modelRevision = row.diagnostics.modelRevision, !modelRevision.isEmpty {
                Text("\(t("模型版本", "Model Revision")): \(modelRevision)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let providerID = row.diagnostics.providerID, !providerID.isEmpty {
                let providerLine = "\(t("Provider", "Provider")): \(providerID)"
                    + (row.diagnostics.providerFamily.map {
                        " · \($0.title(in: languageMode))"
                    } ?? "")
                Text(providerLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let inferencePath = row.diagnostics.inferencePath {
                Text("\(t("推理路径", "Inference Path")): \(inferencePath.title(in: languageMode))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let modelInputKind = row.diagnostics.modelInputKind {
                Text("\(t("输入模式", "Input Mode")): \(modelInputKind.title(in: languageMode))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let aggregatedFrom = row.diagnostics.aggregatedFrom {
                Text("\(t("聚合方式", "Aggregation")): \(aggregationTitle(for: aggregatedFrom))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    func ruleTraceSection(for row: SentimentSceneRow) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(t("规则轨迹", "Rule Trace"))
                .font(.subheadline.weight(.semibold))
            ForEach(row.diagnostics.ruleTraces.prefix(4)) { trace in
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(trace.cueSurface) · \(format(trace.baseScore)) → \(format(trace.adjustedScore))")
                        .font(.caption.monospacedDigit())
                    Text(
                        "\(t("子句", "Clause")) \(trace.clauseIndex + 1) · \(t("权重", "Weight")) \(format(trace.clauseWeight))"
                    )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    if let shieldReason = trace.neutralShieldReason, !shieldReason.isEmpty {
                        Text("\(t("屏蔽原因", "Shield")): \(shieldReason)")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                    if !trace.appliedSteps.isEmpty {
                        Text(trace.appliedSteps.map { "\($0.tag): \($0.note)" }.joined(separator: " · "))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
}
