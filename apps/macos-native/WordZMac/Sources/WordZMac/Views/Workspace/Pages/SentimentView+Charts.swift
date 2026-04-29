import Charts
import SwiftUI

extension SentimentView {
    @ViewBuilder
    func chartView(_ scene: SentimentSceneModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            WorkbenchChartSurface(
                isEmpty: chartIsEmpty(scene),
                emptyTitle: t("当前没有可绘制的情感分布。", "No sentiment distribution to chart.")
            ) {
                switch scene.chartKind {
                case .distributionBar:
                    sentimentBarChart(scene)
                case .distributionDonut:
                    sentimentDonutChart(scene)
                case .trendLine:
                    sentimentTrendChart(scene)
                }
            }

            WorkbenchChartLegend(items: sentimentLegendItems(scene))
        }
    }

    func chartSubtitle(_ scene: SentimentSceneModel) -> String {
        "\(scene.summary.totalTexts) \(t("条分析单位", "analysis units")) · \(scene.chartKind.title(in: languageMode))"
    }

    private func sentimentBarChart(_ scene: SentimentSceneModel) -> some View {
        Chart(scene.chartSegments) { segment in
            BarMark(
                x: .value("Label", segment.label.title(in: languageMode)),
                y: .value("Count", segment.count)
            )
            .foregroundStyle(color(for: segment.label))
            .cornerRadius(5)
            .annotation(position: .top, alignment: .center) {
                if segment.count > 0 {
                    Text("\(segment.count)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .chartYAxisLabel(t("条数", "Count"))
        .chartXAxis { styledXAxisMarks() }
        .chartYAxis { styledYAxisMarks() }
        .chartPlotStyle { plotArea in
            styledPlotArea(plotArea)
        }
    }

    private func sentimentDonutChart(_ scene: SentimentSceneModel) -> some View {
        ZStack {
            Chart(scene.chartSegments) { segment in
                SectorMark(
                    angle: .value("Count", segment.count),
                    innerRadius: .ratio(0.62),
                    angularInset: 2.5
                )
                .foregroundStyle(color(for: segment.label))
            }
            .chartLegend(.hidden)

            VStack(spacing: 2) {
                Text("\(scene.summary.totalTexts)")
                    .font(.title3.weight(.semibold).monospacedDigit())
                Text(t("总条数", "Total"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func sentimentTrendChart(_ scene: SentimentSceneModel) -> some View {
        Chart {
            RuleMark(y: .value("Neutral", 0))
                .foregroundStyle(WordZTheme.divider.opacity(0.7))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))

            ForEach(scene.trendPoints) { point in
                LineMark(
                    x: .value("Index", point.index),
                    y: .value("Net", point.netScore)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(WorkbenchChartPalette.accent)
                .lineStyle(StrokeStyle(lineWidth: 2.2))

                PointMark(
                    x: .value("Index", point.index),
                    y: .value("Net", point.netScore)
                )
                .foregroundStyle(color(for: point.label))
                .symbolSize(44)
            }
        }
        .chartYAxisLabel("Net")
        .chartYScale(domain: -1 ... 1)
        .chartXAxis { styledXAxisMarks() }
        .chartYAxis { styledYAxisMarks() }
        .chartPlotStyle { plotArea in
            styledPlotArea(plotArea)
        }
    }

    private func styledXAxisMarks() -> some AxisContent {
        AxisMarks { _ in
            AxisGridLine()
                .foregroundStyle(.clear)
            AxisTick()
                .foregroundStyle(WordZTheme.divider.opacity(0.55))
            AxisValueLabel()
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func styledYAxisMarks() -> some AxisContent {
        AxisMarks(position: .leading) { _ in
            AxisGridLine()
                .foregroundStyle(WordZTheme.divider.opacity(0.45))
            AxisTick()
                .foregroundStyle(WordZTheme.divider.opacity(0.55))
            AxisValueLabel()
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private func styledPlotArea(_ plotArea: ChartPlotContent) -> some View {
        plotArea
            .background(
                WordZTheme.primarySurfaceSoft,
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(WordZTheme.divider.opacity(0.35), lineWidth: 1)
            )
    }

    private func sentimentLegendItems(_ scene: SentimentSceneModel) -> [WorkbenchChartLegendItem] {
        scene.chartSegments.map { segment in
            WorkbenchChartLegendItem(
                id: segment.label.id,
                title: segment.label.title(in: languageMode),
                value: "\(segment.count)",
                detail: formatPercent(segment.ratio),
                color: color(for: segment.label)
            )
        }
    }

    private func chartIsEmpty(_ scene: SentimentSceneModel) -> Bool {
        switch scene.chartKind {
        case .distributionBar, .distributionDonut:
            return !scene.chartSegments.contains { $0.count > 0 }
        case .trendLine:
            return scene.trendPoints.isEmpty
        }
    }
}
