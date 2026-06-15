import Foundation
import WordZShared

extension SentimentPageViewModel {
    func exportMetadataLines(
        annotationSummary: String,
        languageMode: AppLanguageMode
    ) -> [String] {
        var lines: [String] = [
            "\(wordZText("情感词库", "Lexicon Pack", mode: languageMode)): \(rawResult?.request.domainPackSummary(in: languageMode) ?? currentPackRecommendation.summary(in: languageMode))",
            "\(wordZText("判定方式", "Rule Profile", mode: languageMode)): \(selectedRuleProfile.title)",
            "\(wordZText("校准", "Calibration", mode: languageMode)): \(selectedCalibrationProfileTitle(in: languageMode))",
            "\(wordZText("Review Filter", "Review Filter", mode: languageMode)): \(reviewFilter.title(in: languageMode))",
            "\(wordZText("审校状态", "Review Status", mode: languageMode)): \(reviewStatusFilter.title(in: languageMode))"
        ]

        if !selectedRuleProfile.importedBundleIDs.isEmpty {
            lines.append(
                "\(wordZText("自定义词典", "Custom Dictionaries", mode: languageMode)): \(selectedRuleProfile.importedBundleIDs.joined(separator: ", "))"
            )
        }

        if showOnlyHardCases {
            lines.append(wordZText("仅显示难例", "Showing hard cases only", mode: languageMode))
        }

        if let reviewSummary = presentationResult?.reviewSummary {
            lines.append(
                "\(wordZText("已审校样本", "Reviewed Samples", mode: languageMode)): \(reviewSummary.reviewedCount)"
            )
            lines.append(
                "\(wordZText("人工改标", "Overrides", mode: languageMode)): \(reviewSummary.overriddenCount)"
            )
            lines.append(
                "\(wordZText("确认原判", "Confirmed Raw", mode: languageMode)): \(reviewSummary.confirmedRawCount)"
            )
        }

        switch source {
        case .corpusCompare:
            lines.append(
                "\(wordZText("跨分析", "Cross Analysis", mode: languageMode)): \(wordZText("Compare x Sentiment", "Compare x Sentiment", mode: languageMode))"
            )
            lines.append(
                "\(wordZText("范围", "Scope", mode: languageMode)): \(corpusCompareScopeSummary(in: languageMode))"
            )
            let focusTerm = rowFilterQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            if !focusTerm.isEmpty {
                lines.append(
                    "\(wordZText("聚焦词项", "Focus Term", mode: languageMode)): \(focusTerm)"
                )
            }
        case .topicSegments:
            lines.append(
                "\(wordZText("跨分析", "Cross Analysis", mode: languageMode)): \(wordZText("Topics x Sentiment", "Topics x Sentiment", mode: languageMode))"
            )
            lines.append(
                "\(wordZText("范围", "Scope", mode: languageMode)): \(topicSegmentScopeSummary(in: languageMode))"
            )
            if let focusedTopicID = topicSegmentsFocusClusterID,
               !focusedTopicID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                lines.append(
                    "\(wordZText("聚焦主题", "Focused Topic", mode: languageMode)): \(focusedTopicID)"
                )
            }

            let visibleGroups = orderedTopicGroupTitles()
            if !visibleGroups.isEmpty {
                lines.append(
                    "\(wordZText("主题范围", "Topic Scope", mode: languageMode)): \(visibleGroups.joined(separator: " · "))"
                )
            }
        default:
            break
        }

        let trimmedAnnotationSummary = annotationSummary.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedAnnotationSummary.isEmpty {
            lines.append(trimmedAnnotationSummary)
        }

        return lines
    }
}
