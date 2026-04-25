# WordZ 1.4.0 Roadmap

## 版本主题

`1.4.0` 建议定为：

**语言学增强与研究证据交付**

`1.3.0` 已经把研究输入、参考语料、分析预设、报告 bundle、`Source Reader` 和 `Evidence Workbench` 串成了第一条可用闭环。
`1.4.0` 不适合再继续横向铺新页面，而应该把已经存在但还偏“底层能力”的部分真正推到用户面前：

- 让 `lemma / lexical class / sentiment / topics` 变成可组合、可解释的研究视角
- 让 `Source Reader + Evidence Workbench` 从“可查看、可保存”升级成“可整理、可导出、可交付”的研究 dossier
- 让 `Topics / Sentiment / Compare / KWIC` 不再各自孤立，而是能回答“差异是由什么语言现象驱动的”
- 把当前已经暴露出来的热点模块降温，避免 `1.4.x` 开发周期被 `Keyword / Topic / Library` 大文件继续拖慢

## 顶层目标

`1.4.0` 建议锁定 5 条主线：

1. 标注感知分析与检索
2. 证据工作台与原文阅读器 2.0
3. 主题、情感与对比的跨分析联动
4. 关键词、主题与语料库场景的热点降温
5. 面向外部分发的原生发布链路成熟化

## 非目标

以下内容不建议作为 `1.4.0` 的硬目标：

- 云同步或多人协作
- 在线大模型推理
- 完整平行语料/对齐编辑器
- OCR 扫描 PDF 工作流
- iOS / iPadOS 适配
- 复杂 BI 风格仪表盘系统

## P0

### 1. 标注感知分析与检索

目标：

- 把当前已经存在的 `lemma` 与 `lexical class` 底座，升级成真正可见、可控、可持久化的研究维度
- 让 `Word / KWIC / Keyword / Collocate / Cluster` 不再只围绕表层 token 工作

交付内容：

- 统一的 annotation profile
  - `surface`
  - `lemma preferred`
  - `surface + lemma fallback`
- 统一的 lexical filter
  - 名词 / 动词 / 形容词 / 副词
  - `other / mixed / all lexical classes`
- `Tokenize` 与 `Source Reader` 中增加轻量标注可视化
  - 当前 token 的 lemma
  - lexical class
  - script 分类
- `Keyword / Collocate / Cluster` 改为显式展示当前 annotation profile
- 预设、方法摘要与报告 bundle 附带 annotation profile

验收标准：

- 同一份语料在 `surface` 与 `lemma preferred` 之间切换后，结果页与方法说明始终一致
- `Keyword / Collocate / Cluster` 在 lexical filter 打开后能稳定复现同一组结果
- 导出的报告 bundle 足以说明“当前分析是按 surface 还是 lemma 做的”

涉及模块：

- `Sources/WordZMac/Analysis/Support/LinguisticAnnotationSupport.swift`
- `Sources/WordZMac/Analysis/Support/KeywordSuiteAnalysisSupport.swift`
- `Sources/WordZMac/Analysis/Services/NativeAnalysisEngine+DocumentSupport.swift`
- `Sources/WordZMac/ViewModels/Pages/TokenizePageViewModel.swift`
- `Sources/WordZMac/ViewModels/Pages/KeywordPageViewModel.swift`
- `Sources/WordZMac/Views/Windows/SourceReaderWindowView.swift`

### 2. 证据工作台与原文阅读器 2.0

目标：

- 把当前的 `Evidence Workbench` 从“证据列表”升级成“可审阅、可整理、可交付”的研究 dossier
- 把 `Source Reader` 从“阅读入口”升级成“证据整理入口”

交付内容：

- 证据分组与章节
  - 按 claim / theme / corpus set 分组
  - 支持手工排序与章节标题
- 证据补充字段
  - claim
  - tags
  - reviewer note
  - citation format
- `Source Reader` 内联整理动作
  - 加入证据时直接附带 note / tag
  - 从当前句直接复制规范化引文
  - 从 `Plot / Sentiment / Topics` 衍生页面进入证据整理
- 导出 `research dossier`
  - Markdown 包
  - JSON 包
  - 引文与上下文并列导出

验收标准：

- 用户可以从 `KWIC / Locator / Plot / Sentiment` 至少四个入口收集证据
- 证据工作台内可按主题或论点组织材料，而不是只有平铺列表
- 导出的 dossier 能在不打开 WordZ 的情况下用于写作或审阅

涉及模块：

- `Sources/WordZMac/Models/Analysis/EvidenceWorkbenchModels.swift`
- `Sources/WordZMac/ViewModels/Workspace/EvidenceWorkbenchViewModel.swift`
- `Sources/WordZMac/ViewModels/Workspace/SourceReaderViewModel.swift`
- `Sources/WordZMac/Views/Windows/EvidenceWorkbenchWindowView.swift`
- `Sources/WordZMac/Views/Windows/SourceReaderWindowView.swift`
- `Sources/WordZMac/Workspace/Services/WorkspaceEvidenceWorkflowService.swift`

### 3. 主题、情感与对比的跨分析联动

目标：

- 让 `Topics / Sentiment / Compare / Keyword` 能共同回答“差异由哪些主题、情感或词汇现象驱动”
- 避免这些页面继续作为平行但互不解释的分析岛

交付内容：

- `Topics x Sentiment`
  - 每个 topic 的情感分布
  - 从 topic 直接打开对应 `Sentiment` 子集或 `KWIC`
- `Compare x Topics`
  - 哪些 topic 在 target / reference 中最分离
  - topic 级代表句 drilldown
- `Compare x Sentiment`
  - 比较结果附带 polarity distribution 摘要
  - 从 compare row 打开对应情感证据
- 跨分析方法摘要
  - 当前 target / reference
  - 当前 topic/sentiment 聚合口径
  - 当前 annotation profile

验收标准：

- 用户可以从 UI 直接回答“哪类主题或情感倾向驱动了当前 target/reference 差异”
- 任一跨分析结果都必须能回到 `KWIC` 或 `Source Reader` 看原句证据
- 导出文本至少包含一份 cross-analysis summary

涉及模块：

- `Sources/WordZMac/Analysis/Builders/TopicsSceneBuilder.swift`
- `Sources/WordZMac/Analysis/Builders/SentimentSceneBuilder.swift`
- `Sources/WordZMac/ViewModels/Pages/TopicsPageViewModel.swift`
- `Sources/WordZMac/ViewModels/Pages/SentimentPageViewModel.swift`
- `Sources/WordZMac/ViewModels/Pages/ComparePageViewModel.swift`
- `Sources/WordZMac/Workspace/Services/WorkspaceFlowCoordinator+CrossAnalysisDrilldown.swift`

### 4. 关键词、主题与语料库场景的热点降温

目标：

- 把当前最明显的开发/编译热点先拆掉，避免 `1.4.x` 每次增强都继续叠加到超大文件
- 优先处理已经在基线文档里暴露出来的几处热点

当前热点参考：

- `KeywordSuiteAnalysisSupport.swift`
- `TopicModelManager.swift`
- `LibraryManagementViewModel+Scene.swift`
- `KeywordPageViewModel.swift`

交付内容：

- `Keyword` 逻辑拆分
  - config assembly
  - row derivation
  - summary assembly
  - export/report support
- `TopicModelManager` 拆分
  - manifest
  - provider resolution
  - benchmark/support helpers
- `LibraryManagementViewModel+Scene` 拆分
  - navigation scene
  - detail scene
  - maintenance scene
- 新增热点专项 benchmark / guard
  - keyword suite smoke benchmark
  - topic benchmark budget
  - library scene build baseline

验收标准：

- 上述热点文件都不再继续单点膨胀
- `swift test` 保持全绿
- `Scripts/architecture-guard.sh` 与工程 guard 能覆盖新增边界

涉及模块：

- `Docs/ArchitectureBaseline-1.3.0.md`
- `Scripts/architecture-guard.sh`
- `Tests/WordZMacTests/EngineeringGuardrailTests.swift`
- `Tests/WordZMacTests/TopicBenchmarkTests.swift`
- `Tests/WordZMacTests/MainWorkspaceViewModelTests.swift`

## P1

### 5. 面向外部分发的原生发布链路成熟化

目标：

- 让 `1.4.0` 不只是“功能上更强”，也成为第一个真正适合持续外部分发的原生版本

交付内容：

- macOS notarization 流程收口
- 签名、manifest、release notes、checksum 自动串联
- `release checklist -> package -> notarize -> release upload` 的半自动或全自动脚本
- 应用内更新文案与渠道说明统一

验收标准：

- release checklist 可以稳定生成对外发布包
- 外部分发包通过 notarization
- release notes 与产物版本号不再需要手工同步

涉及模块：

- `Scripts/package-app.sh`
- `Scripts/notarize-app.sh`
- `Scripts/release-checklist.sh`
- `Docs/ReleaseEngineering.md`
- `Sources/WordZHost/NativeUpdateService.swift`

### 6. 资源包与教学场景优化

目标：

- 把当前已经零散存在的停用词、情感词典、topic 资源，升级成面向课程和研究项目的可选配置包

交付内容：

- 自定义 stopword / whitelist bundle
- 自定义 sentiment lexicon bundle
- 面向课程作业的 preset/template 包
- “演示模式”输出收口
  - 更清楚的空状态
  - 更清楚的指标解释
  - 更好的导出默认模板

验收标准：

- 一个项目组可以导入自己的 stopword / lexicon 资源而不改代码
- 教学环境里可以直接分发 preset/template，而不是手工截图配置

## P2

### 7. 平行语料与对齐基础设施预研

目标：

- 只做基础设施预研，不做完整产品化页面
- 为后续 `1.5.x` 的双语/对齐研究留接口，而不在 `1.4.0` 硬做完整体验

交付内容：

- 对齐单元模型
- 双语文档引用与 provenance 预留
- `Source Reader` 的多文档上下文接口预留

验收标准：

- 不破坏现有单语路径
- 新接口可以在后续版本继续扩展，而不需要重写 `Source Reader` 与证据工作台

## 里程碑建议

### M1: 标注与热点基础

- annotation profile
- lexical filter
- keyword/topic/library 热点拆分第一轮
- benchmark guard 补齐

### M2: 证据工作台 2.0

- Evidence Workbench 分组与 dossier
- Source Reader 内联整理
- Plot / Sentiment -> 证据入口

### M3: 跨分析联动

- Topics x Sentiment
- Compare x Topics
- Compare x Sentiment
- cross-analysis summary export

### M4: 发布链路成熟化

- notarization
- release notes / manifest 串联
- release automation 收口

## Storage Baseline

以下本地持久化基线已经落地，不再作为 `1.4.0` 的待定项：

- 存储拓扑固定为 `library.db + workspace.db + corpora/<id>.db`
- 运行时已移除旧 JSON 持久化层，目录域和 workspace 域都只读写数据库真源
- `corpus_search_fts` 与 `sentence_fts` 已上线，库搜索和上下文召回优先走数据库索引路径

## Definition of Done

`1.4.0` 至少应满足以下条件：

- `lemma / lexical class` 已经是用户可见、可持久化、可导出的分析维度
- 证据工作台可以组织并导出跨页面证据 dossier
- `Topics / Sentiment / Compare / KWIC` 之间至少形成一条稳定的跨分析解释链
- `Keyword / Topic / Library` 的热点文件已经拆分，新增 guard 与 benchmark 全绿
- macOS 外部分发流程具备可重复执行的发布链路
- 历史 workspace snapshot 与本地 `.db` 继续保持 additive 兼容，不引入破坏性迁移

## 推荐的开工顺序

1. 先做 annotation profile 与热点拆分，否则后续所有增强都会继续堆到 `Keyword / Topic / Library` 热点上。
2. 再做 `Evidence Workbench + Source Reader` 的 dossier 路径，把 `1.3.0` 的阅读闭环升级成交付闭环。
3. 然后补 `Topics / Sentiment / Compare` 的跨分析联动，形成 `1.4.0` 的核心用户价值。
4. 最后收 notarization 与 release automation，把发布链路一起补齐。

## Assumptions

- `1.4.0` 继续坚持 macOS-first、local-first，不引入在线依赖作为核心路径
- 当前 `library.db`、`workspace.db` 与 shard `.db` 只能做 additive 扩展，不能做破坏性改写
- 语言学增强以英文和中英混合语料的稳态工作流为主，不把完整中文高级 NLP 作为本版 P0
