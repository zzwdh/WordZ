# WordZ 1.4.0 Release Notes

## 概览

WordZ 1.4.0 是一次聚焦性能优化和 API 调用稳定化的版本。这个版本不扩张新的研究工作流，而是把现有的语料库、分析任务、大结果页和联网 API 路径整理成更快、更可测、更容易恢复的基础。

## 本版亮点

- 性能基线收口：新增 1.4.0 release 基线、UI 性能门禁和 before/after 记录，覆盖 Topics、Library/import、大结果页交互和参考语料分析。
- 高频路径优化：Library import/index、重复 Library 刷新、Topics 结果组装和 slice/embedding 分配完成实测优化，并保留质量字段对比。
- API 调用稳定化：更新检查和手动 API 连接检查统一走可取消、可超时、可重试、限并发和脱敏记录的 API 底座。
- 本地优先与隐私保护：API 总开关、Keychain 凭据、连接测试、错误恢复和诊断包脱敏已落地，未配置 API 时本地语料分析仍完整可用。

## 性能更新

### 基线与门禁

- 新增 `Docs/PerformanceAPIBaseline-1.4.0.md`，记录固定机器算法基线、用户样本、内置参考语料、Library/import 和 release 聚合报告。
- `Scripts/run-1.4-performance-baseline.sh` 支持 debug/release 口径、可选外部用户语料和受限环境下的 SwiftPM sandbox 关闭参数。
- `Scripts/run-1.4-ui-performance-check.sh` 增加 release UI 性能门禁，大结果页交互派发 P95 预算固定为 50 ms。
- release checklist 已接入 UI 性能门禁、API 隐私门禁和 API 错误恢复门禁。

### 优化结果

- Library 重复应用相同快照时跳过重复 scene rebuild，1,200 corpus 合成场景刷新 p95 从约 108.9 ms 降到约 0.003 ms。
- Library import/index 分片写入改为先批量写入再创建二级索引，focused release p95 从约 368.5 ms 降到约 230.3 ms。
- Topics 结果组装预计算 slice 统计，debug 参考语料 Topics p95 从约 3463.0 ms 降到约 3287.1 ms。
- Topics slice token-count 复用和 embedding 投影分配优化后，focused release 参考语料 Topics p95 从约 854.4 ms 降到约 754.3 ms。
- KWIC、Compare、Keyword、Topics、Sentiment、Plot、N-Gram、Cluster、Collocate、Stats、Word、Tokenize、ChiSquare 和 Locator 的用户触发运行统一走 latest-result 保护，快速重复操作只应用最新结果。

## API 与隐私

- `NativeAPIClient` 提供统一请求 ID、超时、限并发、取消、重试、`Retry-After`、HTTP metadata、ETag 读取和错误类型。
- GitHub release 更新检查和手动 API 连接检查已迁移到统一 API 底座。
- 设置页新增 API 总开关、Keychain 凭据保存/清除、连接测试、请求超时和最大并发设置。
- API 关闭时，更新检查、更新下载和手动 API 动作会停止，本地语料分析不受影响。
- API 诊断包只导出脱敏后的请求 host/path/status/duration/header 元数据，不写入 API key、Authorization header、query token、请求正文或完整语料文本。
- API 401/403、429、离线 transport 错误、取消和更新失败都使用面向用户的恢复文案，不暴露凭据或原始技术堆栈。

## 任务状态

- Task Center 新增独立 cancelled 状态和 cancelledCount，用户取消不再混入失败统计。
- Managed analysis、更新检查/下载、诊断导出和报告导出都能把用户取消记录为取消状态。
- 已取消任务的后续完成或失败事件不会覆盖终态，也不会触发失败通知。

## 兼容性说明

- 这个版本继续兼容现有本地语料库、workspace 快照和分析结果结构。
- API 能力是可选增强，不是本地分析的前置条件。
- 1.4.0 的 API 试点范围保持很窄，只包含更新检查、更新下载和用户手动触发的 API 连接检查。
- 当前发布包继续通过 GitHub Releases 提供 macOS app、ZIP、DMG 或 PKG 资产。

## 已知限制

- 1.4.0 不包含平行语料、OCR、多人协作、云同步或大型新研究工作流。
- Topics 仍是参考语料上的主要长耗时路径，后续优化必须继续保留质量字段对比。
- 最终 DMG 产物仍需要在支持 `hdiutil create` 的发布机器上生成和 smoke 验证。

## 验证

- `swift build --disable-sandbox`
- `zsh Scripts/engineering-guard.sh`
- `zsh Scripts/run-1.4-ui-performance-check.sh --release --disable-swiftpm-sandbox`
- `zsh Scripts/run-1.4-api-privacy-check.sh --release --disable-swiftpm-sandbox`
- `zsh Scripts/run-1.4-api-recovery-check.sh --release --disable-swiftpm-sandbox`
- `swift test --filter UserBenchmarkTests/testRunReferenceCorpusFixtureBenchmarkForRoadmapBaseline`
- `swift test --filter LibraryPerformanceBaselineTests/testRunLibraryPerformanceBaselineForRoadmap`
- `zsh Scripts/release-metadata-check.sh`
