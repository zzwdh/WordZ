import SwiftUI

struct ChiSquareView: View {
    @Environment(\.wordZLanguageMode) var languageMode
    @ObservedObject var viewModel: ChiSquarePageViewModel
    let isBusy: Bool
    let onAction: (ChiSquarePageAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            WorkbenchFixedTopScrollContent {
                inputSection
            } scrolling: {
                if let scene = viewModel.scene {
                    summarySection(scene)

                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 150), spacing: 12)],
                        alignment: .leading,
                        spacing: 12
                    ) {
                        ForEach(scene.metrics) { metric in
                            WorkbenchMetricCard(title: metric.title, value: metric.value)
                        }
                    }

                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: 16) {
                            matrixSection(
                                title: t("观察频数", "Observed Frequencies"),
                                description: t("你输入的 2x2 频数表。", "The original 2x2 frequency table you entered."),
                                rows: scene.observedRows
                            )
                            .frame(maxWidth: .infinity, alignment: .topLeading)

                            matrixSection(
                                title: t("期望频数", "Expected Frequencies"),
                                description: t("在“没有差异”假设下模型应看到的频数。", "The frequencies expected under the no-difference hypothesis."),
                                rows: scene.expectedRows
                            )
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                        }

                        VStack(alignment: .leading, spacing: 16) {
                            matrixSection(
                                title: t("观察频数", "Observed Frequencies"),
                                description: t("你输入的 2x2 频数表。", "The original 2x2 frequency table you entered."),
                                rows: scene.observedRows
                            )
                            matrixSection(
                                title: t("期望频数", "Expected Frequencies"),
                                description: t("在“没有差异”假设下模型应看到的频数。", "The frequencies expected under the no-difference hypothesis."),
                                rows: scene.expectedRows
                            )
                        }
                    }

                    totalsSection(scene)

                    if !scene.warnings.isEmpty {
                        warningsSection(scene.warnings)
                    }
                } else {
                    WorkbenchSectionCard {
                        ContentUnavailableView(
                            t("尚未生成卡方结果", "No chi-square results yet"),
                            systemImage: "tablecells.badge.ellipsis",
                            description: Text(
                                t(
                                    "先在上方填入 2x2 列联表，再点击“计算卡方”。",
                                    "Fill the 2x2 contingency table above, then click Run Chi-Square."
                                )
                            )
                        )
                        .frame(maxWidth: .infinity, minHeight: 220)
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    func t(_ zh: String, _ en: String) -> String {
        wordZText(zh, en, mode: languageMode)
    }
}
