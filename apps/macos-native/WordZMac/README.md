# WordZMac Native Preview

第一阶段 mac 原生版预览壳，目标是：

- 提供一个真正的 `SwiftUI + AppKit` 方向入口
- 通过 `JSON-RPC over stdio` 连接现有 `Node.js` sidecar
- 在不修改共享分析核心的前提下，先跑通：
  - app info
  - 本地语料库列表
  - 打开已保存语料
  - `stats`
  - `KWIC`

## 运行

需要完整 **Xcode**。仅安装 Command Line Tools 时，`SwiftUI/AppKit` 桌面 App 往往无法正常编译。

在仓库根目录执行：

```bash
swift run --package-path apps/macos-native/WordZMac
```

## 当前实现

- 左侧原生工作区 / 本地语料库面板
- 右侧 `Stats / KWIC / Settings` 三页
- 通过 `packages/wordz-engine-js/src/index.mjs` 启动 sidecar
- 复用当前 `~/Library/Application Support/WordZ` 数据目录

## 说明

- 当前仍属于“原生版第一阶段骨架”
- 还没有替换现有 Electron mac 主线
- 结果表、工作区恢复、导出、帮助、更新等能力会在后续阶段继续补齐
