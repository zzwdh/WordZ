# WordZ 1.3.9 Release Notes

## 概览

WordZ 1.3.9 是 `1.3.x` 线的一次体验与稳定性发布。这个版本主要把分析结果表、研究阅读链路、情感可视化、标注筛选反馈和原生窗口细节继续收紧，让研究者在查看结果、追溯来源、整理证据和复核图表时少一些手工判断，多一些可见的上下文。

## 本版亮点

- 结果表格升级：各分析页统一接入共享结果表区域、快照驱动刷新、类型化列/行描述和更稳定的列显示、排序、分页控制。
- 研究阅读链路增强：Source Reader 新增来源链、证据草稿与引用预览，KWIC/Locator 共享阅读导出和摘录整理面板。
- 分析解释与可视化增强：标注口径状态条、跨分析说明面板和情感分布/趋势图让筛选、比较与情感结果更容易复核。
- 原生窗口与回归继续硬化：窗口 toolbar/chrome 适配、表格交互、删除确认和工程守卫测试进一步补齐。

## 工作流更新

### 结果表格与分页

- `Stats / Word / N-Gram / KWIC / Locator / Collocate / Cluster / Compare / Sentiment / Topics / Tokenize` 等结果页迁移到共享 `AnalysisResultTableSection`。
- 表格改为传递 `ResultTableSnapshot`，减少大结果集刷新时依赖行数组比较带来的额外开销。
- 新增类型化列与行构建能力，保留字符串兼容层，同时让数值、布尔值和自定义单元格呈现更明确。
- 列菜单改为更符合桌面使用习惯的开关控件，并会阻止用户隐藏最后一列。
- 表头排序、列显示切换、分页范围和页面大小控制的行为进一步统一。

### Source Reader 与证据链

- Source Reader 会展示当前高亮的来源链，包括来源分析、查询口径、语料、原始文件和当前高亮。
- 捕获证据前可以预览引用文本，并把 section、claim、tags、note 等草稿字段写入证据项。
- KWIC 与 Locator 共享阅读导出菜单，支持复制或导出当前行、可见行、完整句和引用格式。
- 摘录整理面板可以在分析页内快速查看证据状态、补充备注、切换评审状态，并继续跳转到独立 Evidence Workbench。

### 解释面板与可视化

- 新增标注口径状态条，用于显示 profile、script filter、lexical class filter，以及当前筛选对结果数量的影响。
- Compare 与 Topics 的跨分析区域使用统一说明面板和指标行，更清楚地区分比较口径、指标和值。
- Sentiment 新增柱状图、环形图和趋势线视图，并配套图例、空状态和统一图表表面。
- Plot 与 Cluster 结果继续整理到共享表格和图表组件，降低页面之间的交互差异。

### 原生窗口与工程稳定性

- 辅助窗口 toolbar、标题区域和 native chrome 行为继续适配，减少不同窗口之间的外观漂移。
- 表格 coordinator 增强列构建、格式化、布局、渲染和选择同步逻辑。
- 新增和补强原生表格、窗口展示、工作区删除确认、Source Reader 链路和工程守卫测试。
- `PlotDistributionTableView` 的独立实现被共享结果表结构取代，降低重复维护成本。

## 兼容性说明

- 这个版本继续兼容现有本地语料库、workspace 快照和分析结果结构。
- 表格内部表示增强为类型化值，但对既有字符串读取路径保持兼容。
- GitHub Releases 自动更新链路继续沿用稳定频道和现有 manifest 格式。

## 已知限制

- 当前 macOS 安装流程仍以下载 DMG/ZIP 后手动替换为主。
- 图表能力优先覆盖情感结果，更多分析页的可视化仍会继续迭代。
- Source Reader 的来源链依赖分析入口提供的上下文，历史或外部打开路径可能只显示部分信息。

## 验证

- `zsh Scripts/release-metadata-check.sh`
- `swift test --package-path apps/macos-native/WordZMac`
- `zsh Scripts/architecture-guard.sh`
- `zsh Scripts/package-app.sh`
- `zsh Scripts/verify-release.sh`
- `zsh Scripts/release-smoke.sh`
