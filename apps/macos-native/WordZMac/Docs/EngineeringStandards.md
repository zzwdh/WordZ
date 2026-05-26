# WordZMac 工程规范

日期：2026-05-14  
范围：原生 macOS App 的日常开发、重构、测试、发布准备与文档维护

## 1. 项目现状

WordZMac 是基于 SwiftPM 的原生 macOS 应用，当前处在“可用业务持续演进 + 架构边界逐步收紧”的阶段。

- `WordZWorkspaceCore` 仍承载主要历史代码面。
- `WordZAnalysis`、`WordZEngine`、`WordZHost`、`WordZExport`、`WordZDiagnostics`、`WordZShared`、`WordZWorkspaceFeature`、`WordZLibraryFeature`、`WordZWorkbenchUI`、`WordZWindowing` 是长期收敛方向。
- `Models`、`ViewModels`、`Views` 仍是过渡期的展示层区域，可以维护，但不能继续变成新的杂物区。
- 架构规范已经脚本化。本文必须和 `ARCHITECTURE.md`、`Docs/ArchitectureBaseline-1.3.0.md`、`Docs/EngineeringGuardrails-1.3.0.md`、`Scripts/architecture-guard.sh` 保持一致。

工程决策优先级：用户流程稳定、所有权明确、改动可审、验证可重复。

## 2. 硬性规则

1. 控制改动范围。
   不把功能行为、架构迁移、存储格式变化、视觉重做混在一个改动里，除非它们不可拆分。

2. 新代码进入最窄所有者。
   默认放进真正拥有行为的 domain，不新增随意根目录，不复活历史 overflow 目录。

3. 维持依赖方向。
   `App` 负责组合，`Workspace` 负责编排，`Analysis` 负责分析，`Storage` 负责持久化，`Host` 负责 macOS 能力，`Export` 负责输出序列化，`Diagnostics` 负责诊断包，`Shared` 保持小而轻。

4. 把持久化当作契约。
   schema、snapshot、draft、manifest 的变化必须考虑兼容和迁移，并有测试兜底。禁止随意做破坏性迁移。

5. 架构决策必须可见。
   如果改了 target 边界、路由、composition、scene sync、持久化形状或守卫脚本覆盖的目录规则，同一个改动里必须更新对应文档和 guard。

6. 落地前必须验证。
   按第 8 节选择最小但足够的验证门槛。没有跑过验证，或没有说明剩余风险，不能算完成。

## 3. 模块所有权

### App

`Sources/WordZMac/App` 负责生命周期、命令、菜单栏、顶层窗口声明和 live dependency assembly。

- `App/Composition` 只做装配。
- 不在 composition factories 里写功能 workflow、分析逻辑、持久化决策或 SwiftUI/AppKit 渲染。
- 具体 composition root 类型留在 `App` 内部。

### Workspace

`Sources/WordZMac/Workspace` 负责 workflow orchestration、repository、coordinator、dispatcher、scene graph store 和 shell state。

- Workspace 可以调用 domain protocol/service。
- Workspace 不直接构造 SwiftUI view。
- Workspace 不依赖具体 AppKit UI 类型；这类能力通过 `Host` protocol/service 进入。

### Analysis

`Sources/WordZMac/Analysis` 负责分析引擎、scene builder、过滤、分页、评分、文本规范化和分析专属 support。

- Analysis 不回指 `MainWorkspaceViewModel`、scene graph store、root view、host dialog 或 workspace shell service。
- 结果构建放在 builder 和可复用 support 里，不放进 view。

### Storage

`Sources/WordZMac/Storage` 负责语料持久化、workspace snapshot、数据库支持、迁移和文件状态。

- Storage 不知道 view、app composition、host UI service 或 workspace shell state。
- schema 和文件布局变化必须同步更新对应 docs。

### Host

`Sources/WordZMac/Host` 负责 macOS 侧能力：dialog、Quick Look、update、notification、sharing、window-facing service。

- AppKit 专属逻辑放在这里，或放在已批准的 view/window bridge 层。
- ViewModel 使用 protocol，不直接 import AppKit。

### Views 和 ViewModels

`Views` 渲染状态并发出用户意图。`ViewModels` 持有展示层和 workflow 状态。

- View 不拥有持久化、分析算法或 workflow 编排。
- ViewModel 不 import AppKit。
- extension 拆分必须有真实主题。`+Something.swift` 应该承载一个清楚的 concern，不长期保留“一两个 helper 一个文件”的碎片。

## 4. 文件放置规则

| 工作类型 | 默认位置 |
| --- | --- |
| App 生命周期、命令、菜单栏、scene 声明 | `Sources/WordZMac/App` |
| live dependency wiring | `Sources/WordZMac/App/Composition` |
| workspace 编排、action dispatch、scene graph | `Sources/WordZMac/Workspace` |
| 分析引擎、builder、filter、scoring | `Sources/WordZMac/Analysis` |
| 语料和 workspace 持久化、迁移 | `Sources/WordZMac/Storage` |
| macOS dialog、notification、Quick Look、update | `Sources/WordZMac/Host` |
| CSV/TXT/XLSX/report export | `Sources/WordZMac/Export` |
| 诊断包、脱敏、归档 | `Sources/WordZMac/Diagnostics` |
| 真正跨 domain、低依赖 helper | `Sources/WordZMac/Shared` |
| 展示层 model、action enum | `Sources/WordZMac/Models/<subfolder>` |
| page/shell/library/settings view model | `Sources/WordZMac/ViewModels/<fixed bucket>` |
| SwiftUI/AppKit 展示层 | `Sources/WordZMac/Views/<fixed bucket>` |

默认禁止：

- 新增 `Sources/WordZMac/Services`
- 在 `Models`、`ViewModels`、`Views` 根目录新增 Swift 文件
- 未同步更新架构契约和 guard 就新增 `Views` 或 `ViewModels` 一级目录
- 在非 UI domain 新增 SwiftUI/AppKit import

## 5. 状态和工作流

标准链路：

```text
View intent
-> action / command
-> view model 或 workspace workflow service
-> domain service / repository
-> scene model 或 result snapshot
-> scene graph sync
-> SwiftUI/AppKit rendering
```

规则：

- View 只表达意图，不决定 workflow policy。
- 长任务必须通过 task center 或现有 runtime-task 机制暴露状态。
- scene sync 避免 no-op rebuild，并尽量保留用户期望的 selection、pagination、sorting、column visibility。
- 跨功能 drilldown 通过 workspace coordinator 和 feature workflow protocol 走，不直接耦合具体 page view model。

## 6. Swift 与 macOS 代码风格

- 优先使用简单 Swift value type 和 protocol，避免扩大单例式访问。
- UI state 和展示层 mutation 使用 `@MainActor`。
- async 边界要明确；不要把慢文件 IO、分析任务或进程调用藏在同步 UI callback 后面。
- 优先使用 typed error 或本地化的用户可见失败模型，不把裸字符串到处传。
- 所有用户可见文案走现有 localization helper 和资源。
- 注释少而有用，解释边界、迁移或并发选择背后的原因。
- 不新增 dependency 或 package target，除非有明确所有权理由。

## 7. UI 规范

- 优先原生 macOS 工作流：toolbar、menu、sheet、window、split view、table 行为跟随现有 WordZMac 模式。
- 先复用已有 scaffold 和组件，再考虑新视觉系统。
- SwiftUI view 和 AppKit bridge 不承载业务逻辑。
- 保留基础可访问性：清楚 label、键盘可达、状态不只依赖颜色。
- 新增用户可见文案默认需要中文和英文覆盖，除非所在文件明确是单语言上下文。

## 8. 验证门槛

使用能覆盖风险的最小 gate；影响面变大时主动加宽。

| 改动类型 | 必跑门槛 |
| --- | --- |
| 纯文档 | 不要求测试，除非示例命令或脚本被修改 |
| 文件放置、Package graph、target 边界 | `zsh Scripts/architecture-guard.sh` |
| App composition、shell routing、scene sync、feature routing | `zsh Scripts/engineering-guard.sh` |
| 分析行为 | 相关 focused tests；算法影响面较大时加跑 `swift test --package-path .` |
| Storage schema、workspace snapshot、migration | 相关 storage/persistence tests，并加跑 `swift test --package-path .` |
| UI-only SwiftUI/AppKit | 有 focused tests 就跑；交互行为变动时 build 或运行 App 抽检 |
| 发布准备 | `zsh Scripts/release-checklist.sh` |
| 大范围重构 | `zsh Scripts/engineering-guard.sh` 和 `swift test --package-path .` |

在当前目录可直接执行：

```bash
zsh Scripts/architecture-guard.sh
zsh Scripts/engineering-guard.sh
swift test --package-path .
swift run --package-path .
```

## 9. 文档同步规则

改动改变契约时，文档必须同改：

- 架构或 target 边界：更新 `ARCHITECTURE.md`、architecture baseline、guard 脚本和对应测试。
- 发布流程：更新 `Docs/ReleaseEngineering.md` 和相关脚本示例。
- 持久化 schema：更新 `Docs/WorkspaceDatabaseSchema.md` 或 `Docs/CorpusLibraryDatabaseSchema.md`。
- 用户可见发布范围：更新对应 `Docs/ReleaseNotes-*.md` 或 roadmap。
- 新 source domain：同改动添加本地 `README.md`，说明所有权和放置规则。

文档要短、准、可执行。优先写命令、所有权规则和决策记录，少写泛泛说明。

## 10. Review 和落地清单

落地前确认：

1. 改动只有一个清楚目的。
2. 新代码在最窄所有 domain。
3. 没有绕过 guard 覆盖的边界。
4. 已考虑持久化和 localization 影响。
5. 已运行相关测试或 guard。
6. 契约变化已同步文档。
7. 未提交生成的 build/release artifact，除非任务明确是发布打包。

如果规范本身需要改变，就把改变做成明确工程决策：同步更新本文、`ARCHITECTURE.md`、guard 脚本和能执行该规则的测试。
