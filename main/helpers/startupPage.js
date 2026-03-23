function buildWindowLoadErrorHtml(error) {
  const detail = String(error?.message || error || 'Unknown error').slice(0, 4000)
  return `<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>WordZ</title>
  <style>
    body { margin: 0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", "PingFang SC", "Microsoft YaHei", Arial, sans-serif; background: #f4efe7; color: #182131; }
    .wrap { max-width: 760px; margin: 10vh auto 0; padding: 24px; }
    .card { background: #fffaf3; border: 1px solid rgba(88, 75, 55, 0.18); border-radius: 16px; box-shadow: 0 18px 44px rgba(20, 24, 38, 0.1); padding: 20px; }
    h1 { margin: 0 0 10px; font-size: 22px; }
    p { margin: 0 0 8px; line-height: 1.7; }
    pre { margin: 12px 0 0; background: #f2ebe1; border-radius: 12px; padding: 12px; white-space: pre-wrap; word-break: break-word; }
  </style>
</head>
<body>
  <div class="wrap">
    <div class="card">
      <h1>WordZ 启动失败</h1>
      <p>主界面加载失败，请重启应用后重试。</p>
      <p>如果问题持续，请在“帮助中心/反馈”中导出诊断并提交 Issue。</p>
      <pre>${detail}</pre>
    </div>
  </div>
</body>
</html>`
}

module.exports = {
  buildWindowLoadErrorHtml
}
