# WordZ 1.3.8 Release Notes

## 概览

WordZ 1.3.8 是一次面向研究闭环、证据整理和原生架构收口的稳定版更新。这个版本把 `1.3.x` 期间积累的 Source Reader、Evidence Workbench、情感分析审阅、主题分析重组、工作区运行时和发布工程能力整理到同一条可验证的发布线上。

## 本版亮点

- 证据工作流升级：Evidence Workbench 支持证据捕获、分组整理、dossier 草稿与 Markdown 导出，Source Reader 可以把阅读片段带回研究上下文。
- 情感分析工作流增强：新增情感审阅样本、配置档案、用户词典包导入导出、cross-analysis/export 支撑，并补齐基准与 gold 数据回归。
- 主题与工作区架构收口：Topics 代码按领域重组，feature workflow 协议、运行任务监督与页面状态抽象落地，WorkspaceFeature 不再依赖具体页面 ViewModel。
- 原生工程与发布链路硬化：WordZEngine、WordZAnalysis、WordZShared 拆出真实 target，新增架构守卫、发布元数据检查、打包/上传脚本和更完整的回归测试。

## 工作流更新

### Evidence Workbench 与 Source Reader

- 支持从阅读、检索和分析路径中捕获证据项。
- 支持证据分组、排序、编辑和导出。
- 支持生成 research dossier 草稿，并以 Markdown 形式交付。
- Source Reader 窗口继续增强原文阅读、片段捕获和上下文回跳能力。

### Sentiment

- 新增情感审阅样本存储与工作流服务。
- 补强情感分析配置档案、选择状态和结果视图拆分。
- 支持用户情感词典包的导入、导出和复用。
- 增加 benchmark / gold fixture 回归，降低规则和模型迭代时的漂移风险。

### Topics

- Topics builder、model、view model、view 和 workflow 按目录拆分。
- 主题分析相关服务迁移到更清晰的领域子目录。
- 保留现有使用路径，同时为后续 feature 模块化继续降低耦合。

## 架构与工程

- `WordZEngine` 开始承载 engine transport/support 源码，不再只是占位 target。
- `WordZAnalysis` 与 `WordZShared` 接管对应资源与共享支持代码。
- Workspace feature handles 改为保存页面状态协议，而不是具体页面 ViewModel。
- 新增 architecture guard，防止已经拆出的模块边界回退。
- 发布脚本补齐 metadata check、package-from-app、release-support、release-upload 等链路。

## 兼容性说明

- 这个版本继续沿用本地桌面语料库与 workspace 存储语义。
- 历史 workspace、语料库和分析结果仍按现有迁移路径读取。
- macOS 当前发布包仍建议通过 GitHub Release 手动下载 DMG 或 ZIP。

## 验证

- `swift build`
- `swift test`
- `zsh Scripts/engineering-guard.sh`
- `zsh Scripts/release-metadata-check.sh`
- `git diff --check`

