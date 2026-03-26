import SwiftUI

struct KWICView: View {
    @ObservedObject var viewModel: MainWorkspaceViewModel
    let onRun: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("KWIC")
                    .font(.title2.weight(.semibold))
                Spacer()
            }

            HStack(spacing: 12) {
                TextField("检索词", text: $viewModel.kwicKeyword)
                    .textFieldStyle(.roundedBorder)
                TextField("左窗口", text: $viewModel.kwicLeftWindow)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 90)
                TextField("右窗口", text: $viewModel.kwicRightWindow)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 90)
                Button("开始检索") { onRun() }
            }

            if let result = viewModel.kwicResult {
                Table(result.rows.prefix(200)) {
                    TableColumn("左侧上下文") { row in
                        Text(row.left)
                            .foregroundStyle(.secondary)
                    }
                    TableColumn("节点词") { row in
                        Text(row.node)
                            .fontWeight(.semibold)
                    }
                    TableColumn("右侧上下文") { row in
                        Text(row.right)
                            .foregroundStyle(.secondary)
                    }
                    TableColumn("句号") { row in
                        Text("\(row.sentenceId + 1)")
                            .monospacedDigit()
                    }
                }
            } else {
                ContentUnavailableView(
                    "尚未生成 KWIC 结果",
                    systemImage: "text.magnifyingglass",
                    description: Text("打开语料后输入关键词，即可运行最小原生版 KWIC。")
                )
            }
        }
        .padding(20)
    }
}
