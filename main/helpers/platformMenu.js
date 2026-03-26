const { getPlatformMenuLabels } = require('./platformMenuLabels')
const { setupDockQuickMenu } = require('./platformDockMenu')
const { setupWindowsJumpList } = require('./platformWindowsJumpList')

function buildApplicationMenuTemplate({ app, platform, dispatchAppMenuAction }) {
  const {
    fileMenuLabel,
    toolsMenuLabel,
    statsLabel,
    checkUpdateLabel,
    settingsLabel,
    taskCenterLabel,
    commandPaletteLabel,
    helpLabel,
    quickOpenLabel,
    importAndSaveLabel,
    openLibraryLabel,
    aboutLabel
  } = getPlatformMenuLabels({ app })
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
      submenu: [{ label: aboutLabel, click: () => dispatchAppMenuAction('open-help-center') }]
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

function setupPlatformFileIntegration({
  app,
  Menu,
  platform,
  processExecPath,
  dispatchAppMenuAction,
  captureMainError
}) {
  const labels = getPlatformMenuLabels({ app })
  setupDockQuickMenu({
    app,
    Menu,
    platform,
    labels,
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
