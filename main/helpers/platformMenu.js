function buildApplicationMenuTemplate({ app, platform, dispatchAppMenuAction }) {
  const locale = String(typeof app.getLocale === 'function' ? app.getLocale() : '').toLowerCase()
  const isZhLocale = locale.startsWith('zh')
  const fileMenuLabel = isZhLocale ? '文件' : 'File'
  const toolsMenuLabel = isZhLocale ? '工具' : 'Tools'
  const statsLabel = isZhLocale ? '开始统计' : 'Run Statistics'
  const checkUpdateLabel = isZhLocale ? '检查更新' : 'Check Updates'
  const settingsLabel = isZhLocale ? '打开设置' : 'Open Settings'
  const taskCenterLabel = isZhLocale ? '切换任务中心' : 'Toggle Task Center'
  const commandPaletteLabel = isZhLocale ? '命令面板…' : 'Command Palette…'
  const helpLabel = isZhLocale ? '打开帮助中心' : 'Open Help Center'
  const quickOpenLabel = isZhLocale ? '快速打开语料…' : 'Quick Open Corpus…'
  const importAndSaveLabel = isZhLocale ? '导入并保存语料…' : 'Import And Save Corpus…'
  const openLibraryLabel = isZhLocale ? '打开本地语料库' : 'Open Local Library'
  const fileSubmenu = [
    {
      label: quickOpenLabel,
      accelerator: 'CmdOrCtrl+O',
      click: () => dispatchAppMenuAction('open-quick-corpus')
    },
    {
      label: importAndSaveLabel,
      accelerator: 'CmdOrCtrl+Shift+O',
      click: () => dispatchAppMenuAction('import-and-save-corpus')
    },
    {
      label: openLibraryLabel,
      accelerator: 'CmdOrCtrl+L',
      click: () => dispatchAppMenuAction('open-library')
    },
    { type: 'separator' },
    platform === 'darwin' ? { role: 'close' } : { role: 'quit' }
  ]

  const toolsSubmenu = [
    {
      label: statsLabel,
      accelerator: 'CmdOrCtrl+Enter',
      click: () => dispatchAppMenuAction('run-stats')
    },
    { type: 'separator' },
    {
      label: checkUpdateLabel,
      accelerator: 'CmdOrCtrl+U',
      click: () => dispatchAppMenuAction('check-update')
    },
    {
      label: settingsLabel,
      accelerator: 'CmdOrCtrl+,',
      click: () => dispatchAppMenuAction('open-settings')
    },
    {
      label: commandPaletteLabel,
      accelerator: 'CmdOrCtrl+K',
      click: () => dispatchAppMenuAction('open-command-palette')
    },
    {
      label: taskCenterLabel,
      accelerator: 'CmdOrCtrl+J',
      click: () => dispatchAppMenuAction('toggle-task-center')
    },
    {
      label: helpLabel,
      click: () => dispatchAppMenuAction('open-help-center')
    }
  ]

  const template = [
    {
      label: fileMenuLabel,
      submenu: fileSubmenu
    },
    {
      label: toolsMenuLabel,
      submenu: toolsSubmenu
    },
    { role: 'editMenu' },
    { role: 'viewMenu' },
    { role: 'windowMenu' }
  ]

  if (platform === 'darwin') {
    template.unshift({
      role: 'appMenu',
      submenu: [{ role: 'about' }, { type: 'separator' }, { role: 'services' }, { type: 'separator' }, { role: 'hide' }, { role: 'hideOthers' }, { role: 'unhide' }, { type: 'separator' }, { role: 'quit' }]
    })
  } else {
    template.push({
      role: 'help',
      submenu: [{ label: '关于 WordZ', click: () => dispatchAppMenuAction('open-help-center') }]
    })
  }

  return template
}

function setupApplicationMenu({ Menu, app, platform, dispatchAppMenuAction }) {
  const menu = Menu.buildFromTemplate(
    buildApplicationMenuTemplate({ app, platform, dispatchAppMenuAction })
  )
  Menu.setApplicationMenu(menu)
}

function setupDockQuickMenu({ app, Menu, platform, dispatchAppMenuAction }) {
  if (platform !== 'darwin') return
  if (!app.dock || typeof app.dock.setMenu !== 'function') return

  const dockMenu = Menu.buildFromTemplate([
    {
      label: '快速打开语料…',
      click: () => dispatchAppMenuAction('open-quick-corpus')
    },
    {
      label: '导入并保存语料…',
      click: () => dispatchAppMenuAction('import-and-save-corpus')
    },
    {
      label: '打开本地语料库',
      click: () => dispatchAppMenuAction('open-library')
    }
  ])
  app.dock.setMenu(dockMenu)
}

function setupWindowsJumpList({ app, platform, processExecPath, captureMainError }) {
  if (platform !== 'win32') return
  if (typeof app.setJumpList !== 'function') return

  const taskIconPath = processExecPath
  const taskProgramPath = processExecPath
  const buildTaskItem = ({ title, description, action }) => ({
    type: 'task',
    title,
    description,
    program: taskProgramPath,
    args: `--wordz-action=${action}`,
    iconPath: taskIconPath,
    iconIndex: 0
  })

  try {
    app.setJumpList([
      {
        type: 'tasks',
        items: [
          buildTaskItem({
            title: '快速打开语料',
            description: '快速打开 txt / docx / pdf 语料',
            action: 'open-quick-corpus'
          }),
          buildTaskItem({
            title: '导入并保存语料',
            description: '导入语料并保存到本地语料库',
            action: 'import-and-save-corpus'
          }),
          buildTaskItem({
            title: '打开本地语料库',
            description: '进入本地语料库并管理语料',
            action: 'open-library'
          })
        ]
      },
      { type: 'recent' }
    ])
  } catch (error) {
    captureMainError('windows.jump-list', error)
  }
}

function setupPlatformFileIntegration({
  app,
  Menu,
  platform,
  processExecPath,
  dispatchAppMenuAction,
  captureMainError
}) {
  setupDockQuickMenu({
    app,
    Menu,
    platform,
    dispatchAppMenuAction
  })
  setupWindowsJumpList({
    app,
    platform,
    processExecPath,
    captureMainError
  })
}

function handleLaunchActionArgs({ argv = [], extractLaunchAction, dispatchAppMenuAction }) {
  const launchAction = extractLaunchAction(argv)
  if (!launchAction) return
  dispatchAppMenuAction(launchAction)
}

module.exports = {
  buildApplicationMenuTemplate,
  setupApplicationMenu,
  setupDockQuickMenu,
  setupWindowsJumpList,
  setupPlatformFileIntegration,
  handleLaunchActionArgs
}
