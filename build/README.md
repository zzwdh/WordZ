`WordZ` 的发布资源现在放在这个目录里，已经不是默认 Electron 占位状态了。

当前会用到的文件：
- `icon.png`：1024x1024 主图标源
- `icon.ico`：Windows 应用与安装器图标
- `icon.icns`：macOS 应用图标
- `background.png`：macOS DMG 安装窗口背景图
- `installer-sidebar.bmp`：NSIS 安装器侧边图
- `installer-header.bmp`：NSIS 安装器顶部图
- `installer.nsh`：NSIS 安装器欢迎页、完成页、卸载页自定义脚本
- `license_zh_CN.txt`：Windows 安装器许可文案（简体中文）
- `license_en.txt`：Windows 安装器许可文案（英文）
- `release-checklist.md`：签名/公证后的最终发布检查清单
- `entitlements.mac.plist`：macOS 主应用签名权限
- `entitlements.mac.inherit.plist`：macOS 继承签名权限

图标与安装器图片是自动生成的：
- 运行 `npm run build:assets`
- 生成脚本在 `/Users/zouyuxuan/corpus-lite/scripts/generate-build-assets.mjs`
- 发布体检命令：`npm run release:doctor`

安装器策略补充：
- Windows NSIS 安装器现在默认优先“当前用户安装”，这样通常不会落到 `Program Files`，能减少管理员权限、路径编码和更新失败风险；如果用户需要，也仍可在安装过程中切换为“所有用户安装”。
- Windows 许可页不再固定写死单一文件，而是由 `electron-builder` 根据系统语言自动匹配 `license_zh_CN.txt` / `license_en.txt`。
- Windows 安装器现在额外自定义了欢迎页、完成页和卸载页文案，并把安装器语言收口到 `en_US` / `zh_CN`，避免默认多语言模板和实际产品信息不一致。
- macOS DMG 现在使用品牌化背景图、固定窗口尺寸和更明确的拖拽布局，打开镜像后会直接看到更完整的安装指引画面。
- 应用包现在默认启用 `asar`；发布链会额外校验 `app.asar` 是否真正进入 macOS / Windows 打包结果，避免开发态正常、安装态漏包。

发布策略：
- 当前只维护一个稳定版渠道
- 自动更新默认走 `GitHub Releases`
- GitHub Actions 工作流会把当前仓库 owner/repo 注入到打包结果中
- Release 说明会自动生成并写回 GitHub Release 页面

稳定版发布步骤：
1. 修改 `/Users/zouyuxuan/corpus-lite/package.json` 的 `version`
2. 运行 `npm run verify:smoke`
3. 提交代码并推送 tag，例如 `v1.0.3`
4. 打开 `/Users/zouyuxuan/corpus-lite/.github/workflows/github-release.yml` 对应的 Actions 结果
5. 等待 macOS / Windows 构建完成后，到 GitHub Releases 检查产物和正文

本地打包命令：
- `npm run pack`
- `npm run dist`
- `npm run dist:mac`
- `npm run dist:win`
- `npm run dist:win:arm64`
- `npm run test:packaged-smoke`
- `npm run release:artifacts -- --target=mac`
- `npm run release:artifacts -- --target=win`
- `npm run release:doctor`

签名与 notarization：
- macOS 如果需要正式分发，请在 GitHub Secrets 或本地环境中配置以下任一组：
  - `APPLE_API_KEY`、`APPLE_API_KEY_ID`、`APPLE_API_ISSUER`
  - 或 `APPLE_ID`、`APPLE_APP_SPECIFIC_PASSWORD`、`APPLE_TEAM_ID`
  - 或 `APPLE_KEYCHAIN`、`APPLE_KEYCHAIN_PROFILE`
- macOS 证书可通过 `CSC_LINK` + `CSC_KEY_PASSWORD`（以及可选的 `CSC_NAME`）提供
- Windows 证书可通过 `CSC_LINK` + `CSC_KEY_PASSWORD`，或 `WIN_CSC_LINK` + `WIN_CSC_KEY_PASSWORD` 提供
- 如果这些变量缺失，构建仍可继续，但产物会是未签名安装包

当前仓库的 GitHub Secrets 建议最少准备：
- Windows 签名：
  - `WIN_CSC_LINK`
  - `WIN_CSC_KEY_PASSWORD`
- macOS 签名：
  - `CSC_LINK`
  - `CSC_KEY_PASSWORD`
  - 可选 `CSC_NAME`
- macOS notarization：
  - 推荐 `APPLE_API_KEY`、`APPLE_API_KEY_ID`、`APPLE_API_ISSUER`
  - 或者 `APPLE_ID`、`APPLE_APP_SPECIFIC_PASSWORD`、`APPLE_TEAM_ID`

可以用下面命令快速查看还缺什么：
- 本地与 GitHub 一起检查：`npm run release:doctor`
- 只看本地：`node /Users/zouyuxuan/corpus-lite/scripts/release-doctor.mjs --no-github`
- 机器可读输出：`node /Users/zouyuxuan/corpus-lite/scripts/release-doctor.mjs --json`
- 人工复核清单：查看 `/Users/zouyuxuan/corpus-lite/build/release-checklist.md`

发布工作流补充：
- 工作流会校验 Git tag 与 `package.json` 版本是否一致
- 工作流会先生成品牌资源，再执行基础校验、平台打包、产物校验和打包态烟测，然后才进入正式发布
- 发布完成后会把 Release 标记为最新稳定版，并更新 Release 正文
