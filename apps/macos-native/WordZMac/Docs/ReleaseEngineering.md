# Release Engineering

## 目标

`WordZMac` 的原生发布流程需要稳定地产出：

- `.app`
- `.zip`
- `.dmg`
- `checksums.txt`
- `manifest.json`

同时，应用内诊断要能反向识别当前包的构建元信息，方便排查“用户到底运行的是哪一版”的问题。

## 当前脚本

- `Scripts/build-app.sh`
  负责生成 `.app`，并写入 `WordZMacBuildInfo.json`
- `Scripts/package-app.sh`
  负责从当前源码直接构建 `.app`，再串到统一打包链生成 `.zip / .dmg`
- `Scripts/package-from-app.sh`
  负责从一个现成 `.app` 重新生成 `.zip / .dmg / checksums.txt / manifest.json`，供公证后重打包复用
- `Scripts/release-manifest.sh`
  独立生成带 release metadata 的发布资产校验清单
- `Scripts/release-metadata-check.sh`
  在发版前核对 `package.json` 版本、release highlights 和对应 `Release Notes` 是否齐全
- `Scripts/verify-release.sh`
  使用 `checksums.txt` 校验 release 资产
- `Scripts/release-smoke.sh`
  对打包后的 `.app` 做结构型 smoke 检查，确认 Info.plist、可执行文件和 `WordZMacBuildInfo.json` 一致
- `Scripts/release-checklist.sh`
  把 metadata、单测、打包、校验、原生 smoke，以及可选的公证与上传串成一条可重复执行的发布检查流程
- `Scripts/notarize-app.sh`
  用 `notarytool` 提交公证并 `staple`，支持直接输入 `.app/.dmg/.zip`，也支持对 manifest/dist 走“公证 -> 重打包 -> 刷新 manifest/checksums”
- `Scripts/release-upload.sh`
  按 manifest 解析 release 资产并调用 `gh release create/upload`，避免手工漏传文件

## 默认产物目录

如果没有显式设置 `WORDZ_MAC_DIST_DIR`，脚本默认把发布产物写到：

- `apps/macos-native/WordZMac/dist-native`

## 建议发布顺序

1. 先核对当前版本的 `Release Notes`、README 和版本审计清单，确认对外承诺与当前代码一致
2. 运行 `release-metadata-check.sh`，确认版本、release highlights 和 notes 文件同步
3. 本地候选包建议直接执行 `release-checklist.sh`
4. 如果需要对外分发，执行 `release-checklist.sh --notarize`
5. 如果需要直接串到 GitHub Release，可执行 `release-checklist.sh --notarize --upload --draft`
6. 在干净机器或干净账户上做一次冷启动抽检

如果只想分步执行，也可以按下面顺序单独跑：

1. `package-app.sh`
2. `verify-release.sh`
3. `release-smoke.sh`
4. `notarize-app.sh <manifest-path>`
5. `release-upload.sh <manifest-path>`

`release-checklist.sh` 负责自动化检查，但不替代 clean-machine spot check 这道最终人工门槛。对于对外分发，仍需要准备好：

- `WORDZ_MAC_NOTARY_PROFILE`
  供 `notarytool` 使用的 keychain profile
- `gh auth login`
  已登录且对目标仓库有 release 写权限

现在的公证链路会在 `.app` stapled 之后重新生成 `.zip / .dmg`，并在 `.dmg` stapled 之后再次刷新 `checksums.txt / manifest.json`，确保最终上传资产与 manifest 中的 SHA256 保持一致。

## 版本策略

- 大功能更新沿次版本线递增，例如 `1.2.0 -> 1.3.0 -> 1.4.0`
- 补丁修复沿当前次版本线递增，例如 `1.2.0 -> 1.2.1 -> 1.2.2`
- 不建议在已经发布 `1.2.0` 后再把补丁回写成 `1.1.x`，这样会破坏版本排序与更新判断

## 发布后进入下一版本

每次正式发布完成后，建议立刻做下面 4 件事：

1. 在 `Docs/` 新建下一次版本的 `Roadmap` 文档
2. 新建下一次版本的 `ReleaseNotes` 草稿
3. 先保持运行中版本号不变，不要提前把应用展示版本切到下一个版本
4. 等下一次版本真正进入发版收尾阶段，再统一更新：
   - `package.json`
   - 应用内版本说明
   - 发布脚本中的示例命令

这样可以避免“代码还在开发中，但用户界面已经自称是下一版”的混乱。

## 诊断链路

打包后的 `.app` 会在资源目录写入 `WordZMacBuildInfo.json`，目前包含：

- 版本号
- 构建号
- 架构
- 构建时间
- Git commit / branch
- 分发渠道
- 可执行文件 SHA256

应用内的“导出诊断包”会生成一个 `.zip`，目前包含：

- 文本版诊断报告
- 解析后的构建元信息
- 当前运行时上下文
- 当前任务中心历史
- 当前工作区快照
- 当前 UI 设置快照
- 经过路径脱敏后的持久化状态副本
- 若存在，则附带最近一次 `startup-crash.log`

这样支持排查时既能看人类可读的摘要，也能直接拿结构化状态复现现场。
