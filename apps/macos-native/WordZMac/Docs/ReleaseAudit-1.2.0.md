# WordZ 1.2.0 Release Audit

## 目的

这份文档用于冻结 `1.2.0` 的对外承诺，并把“文档承诺 / 当前实现 / 自动化验证 / 手工验证 / 发版动作”收敛成一份收尾清单。

默认决策：

- `Word Cloud` 不作为 `1.2.0` 原生工作区的活跃交付项继续对外承诺；只保留历史 workspace 快照回退兼容。
- 打包产物默认目录以脚本真实行为为准，即 `apps/macos-native/WordZMac/dist-native`。
- `1.3.0` 相关工作流扩展不回流到 `1.2.0` 收尾范围。

## 范围审计矩阵

| 主线 | 保留承诺 | 当前实现证据 | 自动化验证 | 手工验证 | 对外说明处理 |
| --- | --- | --- | --- | --- | --- |
| 分析可信度升级 | `Compare` 固定参考语料、自动主导语料、workspace 恢复、统计列统一、导出附带方法信息 | `Sources/WordZMac/ViewModels/Pages/ComparePageViewModel.swift`、`Sources/WordZMac/Workspace/Services/WorkspacePersistenceService.swift`、`Sources/WordZMac/Analysis/Support/ReadingExportSupport.swift` | `ViewModelsTests.testComparePageViewModelRestoresAndAppliesFixedReferenceCorpus`、`ViewModelsTests.testComparePageViewModelRestoresSelectedCorpusSetFromSnapshot`、`CoordinatorsTests.testWorkspaceFlowCoordinatorCurrentDraftIncludesCompareSelection`、`WorkspaceServicesTests.testWorkspaceExportCoordinatorExportsOnlyVisibleStatsColumns`、`WorkspaceServicesTests.testWorkspaceExportCoordinatorExportsOnlyVisibleWordColumns` | 恢复一个包含多语料和固定参考语料的 workspace，确认 target/reference 不漂移；导出 Compare / Stats / Word 结果，确认附带方法摘要和可见列约束 | 保留在 `ReleaseNotes-1.2.0.md` 中 |
| 大语料性能专项 | 大结果页后台 scene build、结果缓存、`.db` 元数据优先读取、表格布局优化 | `Sources/WordZMac/Analysis/Support/LargeResultSceneBuildSupport.swift`、`Sources/WordZMac/Analysis/Services/NativeAnalysisResultCache.swift`、`Sources/WordZMac/Storage/Support/NativeCorpusDatabaseSupport.swift`、`Sources/WordZMac/Views/Workbench/Table/` | `ViewModelsTests.testStatsPageViewModelFallsBackFromAllPageSizeForLargeResults`、`ViewModelsTests.testWordPageViewModelBuildsLargeScenesOffMainPath`、`ViewModelsTests.testLocatorPageViewModelBuildsLargeScenesOffMainPath`、`NativeAnalysisResultCacheTests`、`EngineIntegrationTests.testNativeWorkspaceRepositoryLoadsCorpusInfoFromStoredDatabaseMetadata` | 用大结果页确认 UI 不因切分页或切列而卡死；重复运行分析确认热路径不重新做整轮重算 | 保留在 `ReleaseNotes-1.2.0.md` 中 |
| 语料库体系升级 | SQLite `.db` 成为稳定底座、元数据可管理、主工作区和语料库窗口都能打开信息面板、历史语料自动迁移 | `Sources/WordZMac/Storage/Library/NativeCorpusStore.swift`、`Sources/WordZMac/Storage/Support/NativeCorpusDatabaseSupport.swift`、`Sources/WordZMac/ViewModels/Library/LibraryManagementViewModel.swift`、`Sources/WordZMac/ViewModels/Workspace/MainWorkspaceViewModel+Diagnostics.swift` | `WorkspaceServicesTests.testNativeCorpusStoreImportsCorporaIntoDBStorageFiles`、`WorkspaceServicesTests.testNativeCorpusStoreMigratesLegacyTXTStorageToDB`、`WorkspaceServicesTests.testNativeCorpusStoreUpdatesCorpusMetadataAndInfoSummary`、`WorkspaceActionDispatcherTests.testDispatcherLibraryInfoActionBuildsCorpusInfoSheet`、`MainWorkspaceViewModelTests.testShowSelectedCorpusInfoBuildsLibraryInfoSheet` | 导入 `.txt`、旧 JSON `.db`、旧 SQLite `.db`；在主工作区和语料库窗口分别打开语料信息面板；修改元数据后重启确认持久化 | 保留在 `ReleaseNotes-1.2.0.md` 中 |
| 学术型分析能力扩展 | `Collocate` 指标补齐、研究阅读型 `KWIC / Locator`、引文复制和跳转定位器 | `Sources/WordZMac/Analysis/Builders/CollocateSceneBuilder.swift`、`Sources/WordZMac/Analysis/Support/ReadingExportSupport.swift`、`Sources/WordZMac/ViewModels/Pages/KWICPageViewModel.swift`、`Sources/WordZMac/ViewModels/Pages/LocatorPageViewModel.swift` | `NativeAnalysisEngineTests.testRunCollocateComputesAssociationMetrics`、`WorkspaceActionDispatcherTests.testDispatcherKwicActivationRunsLocatorFromSelectedRow`、`ViewModelsTests.testKWICPageViewModelSelectionChangesPrimaryLocatorSource`、`MainWorkspaceViewModelTests.testSaveCurrentAnalysisPresetPersistsAndReloadsPresetList` | 在 `KWIC` 中复制引文、跳转 `Locator`、查看完整句；在 `Collocate` 中切换指标并导出阅读文本 | 保留 `Collocate / KWIC / Locator` 相关说明；移除 `Word Cloud` 活跃功能表述 |
| 产品体验与 macOS 原生化打磨 | 分析中心主工作区、独立窗口、菜单和 toolbar 收敛、说明卡与详情面板、表格体验打磨 | `Sources/WordZMac/Views/Windows/`、`Sources/WordZMac/Views/Workspace/`、`Sources/WordZMac/Views/Workbench/`、`Sources/WordZMac/App/NativeWindowRoute.swift` | `RootContentSceneTests`、`RootContentSceneTests.testWorkspaceShellFallsBackFromLegacyWordCloudTabToWord`、`CompositionTests`、`WorkspaceActionDispatcherTests`、`EngineeringGuardrailTests` | 检查主工作区、语料库、设置、任务中心、版本说明窗口是否独立；检查 toolbar / 右键 / 菜单入口是否指向同一状态 | 保留在 `ReleaseNotes-1.2.0.md` 中 |
| 发布与工程化体系完善 | 打包、manifest、checksums、smoke、诊断包脱敏、构建元信息 | `Scripts/build-app.sh`、`Scripts/package-app.sh`、`Scripts/release-manifest.sh`、`Scripts/verify-release.sh`、`Scripts/release-smoke.sh`、`Scripts/release-checklist.sh`、`Sources/WordZMac/Diagnostics/Services/`、`Sources/WordZMac/Host/Support/NativeBuildMetadataService.swift` | `MainWorkspaceViewModelTests.testExportDiagnosticsWritesReportThroughHostActionService`、`NativeBuildMetadataServiceTests`、`NativeDiagnosticsBundleServiceTests`、`zsh Scripts/release-checklist.sh` | 成功产出 `.app / .zip / .dmg / checksums / manifest`；检查 `manifest` 与 `WordZMacBuildInfo.json` 版本一致；导出诊断包确认路径被脱敏 | 保留在 `ReleaseNotes-1.2.0.md` 和 `README.md` 中 |

## 范围外内容

以下能力明确留在 `1.3.0`，不纳入 `1.2.0` 收尾：

- 命名参考语料集与子语料构建器
- 批量研究工作流与批量实验导出
- 百万词级导入、索引和取消机制的进一步升级
- 面向共享或跨语料复用的完整预设体系
- `Word Cloud` 重新作为独立分析页回归

## 自动化门槛

发版前至少满足以下命令全部通过：

```bash
swift test --package-path apps/macos-native/WordZMac
zsh apps/macos-native/WordZMac/Scripts/engineering-guard.sh
zsh apps/macos-native/WordZMac/Scripts/release-checklist.sh
```

通过标准：

- `swift test` 全绿
- `engineering-guard.sh` 全绿
- `release-checklist.sh` 成功产出 `.app / .zip / .dmg / checksums / manifest`
- `release-smoke.sh` 能确认 `Info.plist`、可执行文件和 `WordZMacBuildInfo.json` 的版本一致

## 手工 QA 门槛

- [ ] 新用户数据目录首次启动，主工作区、语料库窗口、设置窗口都能正常打开
- [ ] 导入历史 `.txt`、旧 JSON `.db`、旧 SQLite `.db` 后可继续分析，且需要时自动迁移
- [ ] `Compare` 固定参考语料恢复后，target/reference 关系与保存前一致
- [ ] 主工作区侧边栏与语料库窗口都能打开语料信息面板
- [ ] `KWIC -> Locator` 联动、完整句查看、引文复制都可用
- [ ] CSV / XLSX / 阅读导出携带当前方法摘要或可见列信息
- [ ] 导出诊断包后，路径类字段已脱敏，构建信息完整
- [ ] 更新下载、Reveal、Install and Restart 交接链路可走通
- [ ] 打包后的 `.app` 首次启动正常

## 发版执行顺序

1. 冻结 `1.2.0` 范围，先同步 `Release Notes / README / ReleaseEngineering / 本审计文档`
2. 运行 `swift test` 与 `engineering-guard.sh`
3. 运行 `release-checklist.sh`
4. 若对外分发，执行 `notarize-app.sh`
5. 上传 `.zip / .dmg / checksums / manifest`
6. 在干净机器或干净账户做一次冷启动抽检后再正式发布
