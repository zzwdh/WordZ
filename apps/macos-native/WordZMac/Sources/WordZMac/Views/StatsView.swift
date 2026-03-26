import SwiftUI

struct StatsView: View {
    let result: StatsResult?
    let onRun: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("统计")
                    .font(.title2.weight(.semibold))
                Spacer()
                Button("开始统计") { onRun() }
            }

            if let result {
                HStack(spacing: 16) {
                    metricCard(title: "Token", value: "\(result.tokenCount)")
                    metricCard(title: "Type", value: "\(result.typeCount)")
                    metricCard(title: "TTR", value: String(format: "%.4f", result.ttr))
                    metricCard(title: "STTR", value: String(format: "%.4f", result.sttr))
                }

                Table(result.frequencyRows.prefix(150)) {
                    TableColumn("词") { row in
                        Text(row.word)
                    }
                    TableColumn("频次") { row in
                        Text("\(row.count)")
                            .monospacedDigit()
                    }
                }
            } else {
                ContentUnavailableView(
                    "尚未生成统计结果",
                    systemImage: "chart.bar.doc.horizontal",
                    description: Text("先从左侧打开一条已保存语料，再开始统计。")
                )
            }
        }
        .padding(20)
    }

    private func metricCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
