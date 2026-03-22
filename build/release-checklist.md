`WordZ` 稳定版签名后发布检查清单

适用场景：
- macOS 产物已经完成签名，且如需外部分发，已完成 notarization。
- Windows 产物已经完成签名。

正式发布前建议逐项确认：

1. 基础信息
- `package.json` 版本号、Git tag、GitHub Release 标题一致。
- Release 说明与当前版本实际功能一致。
- `latest.yml`、blockmap、安装包文件名中的版本号一致。
- `npm run release:artifacts -- --target=mac` / `--target=win` 已通过。
- `npm run test:packaged-smoke` 已在对应平台通过。

2. macOS 安装器
- 打开 `.dmg` 后，背景图、图标大小、拖拽到 `/Applications` 的布局正常。
- `WordZ.app` 图标、名称、版本号正确。
- 从 `/Applications` 首次启动能正常进入主界面。
- Finder 中“打开方式”可以看到 `txt / docx / pdf` 关联到 WordZ。
- 如已 notarize，第一次打开不应出现“无法验证开发者”的阻断提示。

3. Windows 安装器
- 安装器欢迎页、安装模式页、完成页文案正常显示。
- 默认选项应为“当前用户安装”，不应强制写入 `Program Files`。
- 如切换到“所有用户安装”，应只在需要时请求管理员授权。
- 桌面快捷方式、开始菜单快捷方式、控制面板卸载项名称正确。
- 卸载项中的 Help / About / Update / Readme 链接能跳到正确页面。

4. 应用启动与核心链路
- 首次启动不白屏、不闪退。
- 欢迎页、快速打开、本地语料库、导入 `txt / docx / pdf` 均可用。
- 统计、KWIC、Collocate、词云、卡方检验、导出链路至少各烟测一次。
- 自动更新检查不会报错，Release 元信息可正确读取。

5. 会话与数据安全
- 工作区恢复、最近打开、备份、恢复、修复、可恢复删除正常。
- 误删恢复链路可用，且不会破坏已有语料库数据。
- 诊断导出、错误反馈入口、GitHub Issue 跳转可用。

6. 发布后核对
- GitHub Releases 里同时存在 macOS 与 Windows 产物。
- Release 已标记为最新稳定版。
- 如当前版本仍有平台限制，需要在 Release 正文中明确写出。

建议的最终动作顺序：
1. 本地跑 `npm run verify:smoke`
2. 本地或 CI 完成 `dist:mac` / `dist:win`
3. 完成签名与 notarization
4. 按本清单做一次人工复核
5. 再把 Release 标记为正式稳定版
