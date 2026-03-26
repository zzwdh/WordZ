function setupDockQuickMenu({ app, Menu, platform, labels, dispatchAppMenuAction }) {
  if (platform !== 'darwin') return
  if (!app.dock || typeof app.dock.setMenu !== 'function') return

  const dockMenu = Menu.buildFromTemplate([
    {
      label: labels.quickOpenLabel,
      click: () => dispatchAppMenuAction('open-quick-corpus')
    },
    {
      label: labels.importAndSaveLabel,
      click: () => dispatchAppMenuAction('import-and-save-corpus')
    },
    {
      label: labels.openLibraryLabel,
      click: () => dispatchAppMenuAction('open-library')
    }
  ])

  app.dock.setMenu(dockMenu)
}

module.exports = {
  setupDockQuickMenu
}
