function getPlatformMenuLabels({ app }) {
  const locale = String(typeof app.getLocale === 'function' ? app.getLocale() : '').toLowerCase()
  const isZhLocale = locale.startsWith('zh')

  return {
    fileMenuLabel: isZhLocale ? '文件' : 'File',
    toolsMenuLabel: isZhLocale ? '工具' : 'Tools',
    statsLabel: isZhLocale ? '开始统计' : 'Run Statistics',
    checkUpdateLabel: isZhLocale ? '检查更新' : 'Check Updates',
    settingsLabel: isZhLocale ? '打开设置' : 'Open Settings',
    taskCenterLabel: isZhLocale ? '切换任务中心' : 'Toggle Task Center',
    commandPaletteLabel: isZhLocale ? '命令面板…' : 'Command Palette…',
    helpLabel: isZhLocale ? '打开帮助中心' : 'Open Help Center',
    quickOpenLabel: isZhLocale ? '快速打开语料…' : 'Quick Open Corpus…',
    importAndSaveLabel: isZhLocale ? '导入并保存语料…' : 'Import And Save Corpus…',
    openLibraryLabel: isZhLocale ? '打开本地语料库' : 'Open Local Library',
    aboutLabel: isZhLocale ? '关于 WordZ' : 'About WordZ'
  }
}

module.exports = {
  getPlatformMenuLabels
}
