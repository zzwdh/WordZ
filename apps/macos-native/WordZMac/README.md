# WordZMac Native

## 运行

需要完整 **Xcode**。仅安装 Command Line Tools 时，`SwiftUI/AppKit` 桌面 App 往往无法正常编译。

在仓库根目录执行：

```bash
swift run --package-path apps/macos-native/WordZMac
```

## 当前实现

- 纯 Swift 本地引擎
- 原生工作区、结果表、导出、帮助、更新与最近打开
- 独立 mac 用户数据目录与文档窗口语义
- 原生菜单、辅助窗口、任务中心、欢迎页

## 架构约定

长期模块边界和演进规则记录在 [`ARCHITECTURE.md`](ARCHITECTURE.md)。修改目录结构、
SwiftPM target、工作区功能路由或核心边界守卫时，需要同步更新这份契约，并运行：

```bash
zsh apps/macos-native/WordZMac/Scripts/engineering-guard.sh
```

日常开发、重构、测试准入、文档同步和发布前检查遵循
[`Docs/EngineeringStandards.md`](Docs/EngineeringStandards.md)。这份规范是当前工程工作的默认准入线；
如果规范需要改变，必须同步更新架构契约、守卫脚本和相应测试。

## 打包

在仓库根目录执行：

```bash
npm run native:mac:build
npm run native:mac:package
```

如果只需要生成 `.pkg` 安装器，也可以执行：

```bash
zsh apps/macos-native/WordZMac/Scripts/package-pkg.sh
```

产物默认输出到：

```bash
/Users/zouyuxuan/corpus-lite/apps/macos-native/WordZMac/dist-native
```

打包完成后会额外生成：

- `WordZ-<version>-mac-<arch>.zip`
- `WordZ-<version>-mac-<arch>.dmg`
- `WordZ-<version>-mac-<arch>.pkg`
- `WordZ-<version>-mac-<arch>.checksums.txt`
- `WordZ-<version>-mac-<arch>.manifest.json`

这样可以把 `zip / dmg / pkg` 的校验和和发布元信息一起留档，方便之后复核或上传 Release。

### 签名

可选环境变量：

- `WORDZ_MAC_SIGN_IDENTITY`
- `WORDZ_MAC_ENTITLEMENTS_PATH`
- `WORDZ_MAC_INSTALLER_SIGN_IDENTITY`

例如：

```bash
WORDZ_MAC_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" npm run native:mac:package
WORDZ_MAC_INSTALLER_SIGN_IDENTITY="Developer ID Installer: Your Name (TEAMID)" npm run native:mac:package
```

### 公证

先准备好 `notarytool` keychain profile，然后执行：

```bash
WORDZ_MAC_NOTARY_PROFILE="your-profile" npm run native:mac:notarize -- /absolute/path/to/WordZ-1.2.9-mac-arm64.dmg
WORDZ_MAC_NOTARY_PROFILE="your-profile" npm run native:mac:notarize -- /absolute/path/to/WordZ-1.2.9-mac-arm64.pkg
```

### 校验发布资产

建议在上传 GitHub Release 之前做一次本地校验：

```bash
zsh apps/macos-native/WordZMac/Scripts/verify-release.sh \
  /absolute/path/to/apps/macos-native/WordZMac/dist-native/WordZ-1.2.9-mac-arm64.manifest.json
```

也可以直接把 `.checksums.txt` 传给脚本：

```bash
zsh apps/macos-native/WordZMac/Scripts/verify-release.sh \
  /absolute/path/to/apps/macos-native/WordZMac/dist-native/WordZ-1.2.9-mac-arm64.checksums.txt
```

### 一键发布检查

如果你想把“单测 + 打包 + 校验和校验 + 原生 smoke”串成一条流程，可以直接运行：

```bash
zsh apps/macos-native/WordZMac/Scripts/release-checklist.sh
```

如果已经有现成产物，也可以跳过打包和单测，只复核已有 manifest：

```bash
zsh apps/macos-native/WordZMac/Scripts/release-checklist.sh \
  --skip-tests \
  --skip-package \
  --manifest /absolute/path/to/apps/macos-native/WordZMac/dist-native/WordZ-1.2.9-mac-arm64.manifest.json
```

脚本完成后，若要正式对外发布，仍需要继续完成公证、上传 release 资产，并在干净机器或干净账户上做一次冷启动抽检。

## 说明

- `.app` 构建会把 `export-xlsx.mjs` 一起打进 bundle 资源目录
- `.app` 构建会写入 `WordZMacBuildInfo.json`，供应用内诊断和构建信息展示使用
- 应用内“导出诊断包”会生成 `.zip`，内含文本诊断、构建元信息、任务状态、工作区快照和持久化状态副本
- 当前更新链默认仍然使用 GitHub Releases
- 若未提供 Developer ID 证书，构建脚本默认执行 ad-hoc 签名，便于本地运行
- 版本号采用次版本发布主功能、补丁号发布修复的策略，例如 `1.2.8 -> 1.2.9 -> 1.3.0`
