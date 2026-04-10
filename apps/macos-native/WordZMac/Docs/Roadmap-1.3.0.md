# WordZ 1.3.0 Roadmap

## 版本主题

`1.3.0` 的主题建议定为：

**研究工作流与可复现实验**

`1.2.0` 已经把可信度、性能、语料库存储和工程化底座补到了一个比较稳的状态。`1.3.0` 不适合再做零散功能堆叠，而应该把这些底座真正组织成适合教学、课程作业和论文研究的完整工作流。

目标不是“再多几个分析页面”，而是让用户可以：

- 明确地定义参考语料和子语料
- 复用一套分析参数而不是每次重新点选
- 在大语料下稳定运行并保持结果可追踪
- 把实验方法、参数和结果一起导出

## 顶层目标

`1.3.0` 建议锁定 5 条主线：

1. 参考语料与子语料工作流
2. 元数据驱动的语料筛选与批量管理
3. 百万词级导入、索引与分析性能
4. 可复现分析预设与方法说明
5. 语言学扩展底座

## 非目标

以下内容可以先不作为 `1.3.0` 的硬目标：

- 云同步或多设备协作
- 在线语料抓取
- 重型深度学习模型内置推理
- 复杂图形化仪表盘系统
- iOS / iPadOS 适配

## P0

### 1. 参考语料与子语料工作流

目标：

- 不再只支持“选几份语料做比较”，而是支持真正的参考语料管理
- 让 `Compare / Keyness / Collocate / KWIC` 都能明确绑定“研究对象子语料”和“参考子语料”

交付内容：

- 子语料构建器
  - 基于 `source / year / genre / tags` 组合筛选
  - 支持保存为命名集合
- 参考语料配置器
  - `自动参考`
  - `固定参考`
  - `命名参考语料集`
- 对比结果说明卡升级
  - 明确展示 target / reference 的构成
  - 明确展示当前统计口径
- 导出时附带方法摘要
  - 目标语料
  - 参考语料
  - 过滤条件
  - 时间戳
  - 指标口径

验收标准：

- 用户可以在不切换主语料文件的前提下构建多个子语料
- `Compare` 恢复工作区后不会丢失 target/reference 关系
- 导出的结果文件足以让另一个人复原同一组比较

涉及模块：

- `Engine/Models/EngineAnalysisModels.swift`
- `Storage/Library/NativeCorpusStore.swift`
- `Workspace/Services/NativeWorkspaceRepository.swift`
- `Workspace/Services/WorkspaceFlowCoordinator.swift`
- `ViewModels/ComparePageViewModel.swift`
- `Views/Workspace/Pages/CompareView.swift`
- `Views/Windows/LibraryManagementView.swift`

### 2. 元数据驱动的语料筛选与批量管理

目标：

- 把当前“单条编辑元数据”升级成“真正可管理、可批量操作、可筛选的语料库”

交付内容：

- 语料库筛选条
  - 年份范围
  - 体裁
  - 来源
  - 标签
- 批量元数据编辑
  - 批量补标签
  - 批量改来源
  - 批量改体裁
- 语料集视图
  - 全部语料
  - 已保存子语料
  - 最近使用
- 元数据完整性提示
  - 缺年份
  - 缺体裁
  - 缺标签

验收标准：

- 语料库窗口内能直接筛出一个研究用子集并保存
- 批量编辑不会破坏现有 `.db` 兼容性
- 主工作区能直接选择命名子语料集作为分析输入

涉及模块：

- `Storage/Support/NativeCorpusDatabaseSupport.swift`
- `Workspace/Services/LibraryManagementCoordinator.swift`
- `ViewModels/LibraryManagementViewModel.swift`
- `Views/Windows/LibraryManagementView.swift`
- `Models/Scene/LibraryManagementSceneModel.swift`

### 3. 百万词级导入、索引与分析性能

目标：

- 让 `1.3.0` 把“几十万词可用”推进到“百万词级仍然可接受”

交付内容：

- 导入过程流式化
  - 大文件分块读取
  - 更稳的编码探测
  - 明确的导入进度与取消
- `.db` 索引增强
  - `token_frequency`
  - 文档元数据字段
  - 常用检索字段
- 热路径缓存细化
  - `KWIC`
  - `Compare`
  - `Collocate`
  - `Word`
- 导出流式化继续扩面
  - 大结果导出不整块拼内存

验收标准：

- 导入大文本时 UI 不冻结
- 取消导入后不会留下半残状态
- 常见频次页和对比页在大语料下响应时间明显下降

涉及模块：

- `Storage/Library/NativeCorpusStore.swift`
- `Storage/Support/NativeCorpusDatabaseSupport.swift`
- `Analysis/Services/NativeAnalysisEngine.swift`
- `Analysis/Services/NativeAnalysisResultCache.swift`
- `Export/Services/TableExportService.swift`
- `Views/Workbench/Table/NativeTableView.swift`

### 4. 可复现分析预设与方法说明

目标：

- 把“当前工作区状态”升级成“可命名、可复用、可分享的分析预设”

交付内容：

- 分析预设
  - `词频`
  - `关键词`
  - `搭配`
  - `KWIC`
  - `对比`
- 方法说明面板
  - 当前过滤条件
  - 当前规范化口径
  - 当前参考语料策略
  - 当前停用词策略
- 一键复制方法摘要
- 导出报告 bundle
  - 表格结果
  - 方法说明
  - 构建信息

验收标准：

- 用户可以保存一套预设并在另一份语料上复用
- 导出的报告 bundle 能独立说明“这份结果是怎么来的”

涉及模块：

- `Workspace/Services/WorkspacePersistenceService.swift`
- `Analysis/Support/AnalysisExportMetadataSupport.swift`
- `ViewModels/*PageViewModel.swift`
- `Views/Workbench/`

## P1

### 5. 语言学扩展底座

目标：

- 为后续词性标注、词形归并、轻量情感分析等能力预留标准接口

交付内容：

- 标注层数据模型
- 词形归并策略插槽
- 自定义停用词表管理
- 自定义白名单词表
- 中英混合分词配置预设

验收标准：

- 不破坏当前分析逻辑
- 新增接口可以在不重写现有页面的情况下逐步接入

### 6. 研究阅读体验升级

目标：

- 让 `KWIC / Locator / Compare / Collocate` 更适合课堂展示和论文整理

交付内容：

- 引文导出格式可选
- 更强的复制与粘贴格式
- 详情区支持更清楚的上下文和来源信息
- 更清楚的空状态与指标解释

## P2

### 7. 工程化与诊断继续增强

目标：

- 让 `1.3.0` 的开发周期更稳，减少后期返工

交付内容：

- 性能基准脚本
- 导入与分析 smoke 数据集
- 更系统的数据库迁移测试
- 支持模式下的增强诊断包选项

## 里程碑建议

### M1: 研究输入与元数据

- 子语料构建器
- 语料筛选器
- 批量元数据编辑
- 命名语料集

### M2: 研究计算与性能

- 参考语料管理
- 大文件导入与取消
- 索引优化
- 缓存细化

### M3: 研究输出与复现

- 分析预设
- 方法说明面板
- 报告 bundle
- 引文与结果导出增强

## Definition of Done

`1.3.0` 至少应满足以下条件：

- 关键研究流程可以在 UI 中闭环完成
- target/reference/subcorpus 状态都能持久化并恢复
- 大语料导入和主要结果页不出现明显主线程冻结
- 导出结果带完整方法说明
- 至少为 `Compare / KWIC / Collocate / Word` 补齐准确性与回归测试
- Release 脚本、诊断链路和迁移测试保持全绿

## 推荐的开工顺序

1. 先做子语料构建器和命名语料集
2. 再做参考语料配置与 Compare 方法说明
3. 然后做导入流式化、索引和缓存
4. 最后补分析预设与报告 bundle
