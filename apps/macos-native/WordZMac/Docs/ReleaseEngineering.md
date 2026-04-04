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
  负责生成 `.zip / .dmg`，并自动补 `checksums.txt` 与 `manifest.json`
- `Scripts/release-manifest.sh`
  独立生成发布资产校验清单
- `Scripts/verify-release.sh`
  使用 `checksums.txt` 校验 release 资产
- `Scripts/release-smoke.sh`
  对打包后的 `.app` 做结构型 smoke 检查，确认 Info.plist、可执行文件和 `WordZMacBuildInfo.json` 一致
- `Scripts/release-checklist.sh`
  把单测、打包、校验和校验、原生 smoke 串成一条可重复执行的发布检查流程
- `Scripts/notarize-app.sh`
  用 `notarytool` 提交公证并尝试 `staple`

## 建议发布顺序

1. 运行 `package-app.sh`
2. 运行 `verify-release.sh`
3. 运行 `release-smoke.sh`
4. 如果需要一次性跑完整检查，执行 `release-checklist.sh`
5. 如果需要对外分发，执行 `notarize-app.sh`
6. 再上传 GitHub Release 资产

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
