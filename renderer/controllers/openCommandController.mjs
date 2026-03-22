export function createOpenCommandController({
  dom,
  taskCenter,
  getRecentOpenEntries,
  renderRecentOpenList,
  openRecentOpenEntry,
  clearRecentOpenEntries,
  showToast,
  showAlert,
  getErrorMessage,
  escapeHtml,
  getCommandPaletteCommands,
  onQuickOpen,
  onImportAndSave,
  onOpenLibrary,
  onOpenHelpCenter,
  onRunStats,
  onCheckUpdate,
  onOpenSettings,
  clearTaskCenterAttention,
  closeHelpCenterModal,
  closeRecycleModal,
  hideWelcomeOverlay,
  isWelcomeOverlayVisible,
  handleDroppedPaths,
  onDropImportError
}) {
  const {
    dropImportOverlay,
    dropImportHint,
    openCorpusMenuButton,
    openCorpusMenuPanel,
    quickOpenButton,
    saveImportButton,
    libraryButton,
    clearRecentOpenButton,
    commandPaletteModal,
    commandPaletteInput,
    commandPaletteList,
    closeCommandPaletteButton
  } = dom

  let openCorpusMenuOpen = false
  let dropImportDragDepth = 0
  let commandPaletteOpen = false
  let commandPaletteActiveIndex = 0
  let commandPaletteFilteredItems = []
  let shellHandlersBound = false
  let dropImportHandlersBound = false

  function setOpenCorpusMenuOpen(open) {
    if (!openCorpusMenuButton || !openCorpusMenuPanel) return
    openCorpusMenuOpen = Boolean(open)
    if (openCorpusMenuOpen) renderRecentOpenList()
    openCorpusMenuPanel.classList.toggle('hidden', !openCorpusMenuOpen)
    openCorpusMenuButton.setAttribute('aria-expanded', String(openCorpusMenuOpen))
  }

  function dismissFloatingOverlaysForPrimaryAction() {
    setOpenCorpusMenuOpen(false)
    closeHelpCenterModal()
    closeRecycleModal()
    closeCommandPalette()
    if (taskCenter.isOpen()) taskCenter.setOpen(false)
    if (isWelcomeOverlayVisible()) hideWelcomeOverlay({ immediate: true })
  }

  async function runQuickOpenAction() {
    dismissFloatingOverlaysForPrimaryAction()
    await onQuickOpen()
  }

  async function runImportAndSaveAction() {
    dismissFloatingOverlaysForPrimaryAction()
    await onImportAndSave()
  }

  async function runOpenLibraryAction() {
    dismissFloatingOverlaysForPrimaryAction()
    await onOpenLibrary()
  }

  async function runOpenHelpCenterAction() {
    dismissFloatingOverlaysForPrimaryAction()
    await onOpenHelpCenter()
  }

  async function handleAppMenuAction(payload = {}) {
    const action = String(payload?.action || '').trim()
    if (!action) return

    if (action === 'run-stats') {
      await onRunStats()
      return
    }
    if (action === 'check-update') {
      onCheckUpdate()
      return
    }
    if (action === 'open-settings') {
      onOpenSettings()
      return
    }
    if (action === 'toggle-task-center') {
      taskCenter.setOpen(!taskCenter.isOpen())
      if (taskCenter.isOpen()) {
        clearTaskCenterAttention()
      }
      return
    }
    if (action === 'open-command-palette') {
      openCommandPalette()
      return
    }
    if (action === 'open-quick-corpus') {
      await runQuickOpenAction()
      return
    }
    if (action === 'import-and-save-corpus') {
      await runImportAndSaveAction()
      return
    }
    if (action === 'open-library') {
      await runOpenLibraryAction()
      return
    }
    if (action === 'open-help-center') {
      await runOpenHelpCenterAction()
    }
  }

  function filterCommandPaletteItems(queryText = '') {
    const normalizedQuery = String(queryText || '').trim().toLowerCase()
    const commands = getCommandPaletteCommands()
    if (!normalizedQuery) return commands
    return commands.filter(item => {
      const haystack = `${item.title} ${item.meta || ''} ${item.keywords || ''}`.toLowerCase()
      return haystack.includes(normalizedQuery)
    })
  }

  function setCommandPaletteActiveIndex(nextIndex, { scroll = false } = {}) {
    if (!Array.isArray(commandPaletteFilteredItems) || commandPaletteFilteredItems.length === 0) {
      commandPaletteActiveIndex = 0
      return
    }
    const maxIndex = commandPaletteFilteredItems.length - 1
    commandPaletteActiveIndex = Math.max(0, Math.min(maxIndex, nextIndex))
    if (!commandPaletteList) return
    const nodes = Array.from(commandPaletteList.querySelectorAll('[data-command-index]'))
    for (const node of nodes) {
      const index = Number(node.dataset.commandIndex)
      node.classList.toggle('active', index === commandPaletteActiveIndex)
    }
    if (scroll) {
      const activeNode = commandPaletteList.querySelector(`[data-command-index="${commandPaletteActiveIndex}"]`)
      activeNode?.scrollIntoView({ block: 'nearest' })
    }
  }

  function renderCommandPaletteItems() {
    if (!commandPaletteList) return
    commandPaletteList.replaceChildren()
    if (commandPaletteFilteredItems.length === 0) {
      const emptyNode = document.createElement('div')
      emptyNode.className = 'empty-tip'
      emptyNode.textContent = '没有匹配的命令。'
      commandPaletteList.append(emptyNode)
      return
    }

    const fragment = document.createDocumentFragment()
    commandPaletteFilteredItems.forEach((item, index) => {
      const button = document.createElement('button')
      button.type = 'button'
      button.className = 'command-palette-item'
      button.dataset.commandIndex = String(index)
      button.innerHTML = `
        <span class="command-palette-item-title">${escapeHtml(item.title)}</span>
        <span class="command-palette-item-meta">${escapeHtml(item.meta || '')}</span>
      `
      button.addEventListener('click', () => {
        void executeCommandPaletteCommand(index)
      })
      fragment.append(button)
    })
    commandPaletteList.append(fragment)
    setCommandPaletteActiveIndex(commandPaletteActiveIndex, { scroll: true })
  }

  function closeCommandPalette() {
    if (!commandPaletteModal || !commandPaletteOpen) return
    commandPaletteOpen = false
    commandPaletteModal.classList.add('hidden')
  }

  function openCommandPalette(initialQuery = '') {
    if (!commandPaletteModal || !commandPaletteInput) return
    setOpenCorpusMenuOpen(false)
    commandPaletteOpen = true
    commandPaletteModal.classList.remove('hidden')
    commandPaletteInput.value = String(initialQuery || '')
    commandPaletteFilteredItems = filterCommandPaletteItems(commandPaletteInput.value)
    commandPaletteActiveIndex = 0
    renderCommandPaletteItems()
    requestAnimationFrame(() => {
      commandPaletteInput.focus()
      commandPaletteInput.select()
    })
  }

  async function executeCommandPaletteCommand(index = commandPaletteActiveIndex) {
    const item = commandPaletteFilteredItems[index]
    if (!item) return
    closeCommandPalette()
    try {
      await item.run()
    } catch (error) {
      await showAlert({
        title: '命令执行失败',
        message: getErrorMessage(error, '命令执行失败')
      })
    }
  }

  function isFileDragEvent(event) {
    const dataTransfer = event?.dataTransfer
    if (!dataTransfer) return false
    return Array.from(dataTransfer.types || []).includes('Files')
  }

  function setDropImportOverlayVisible(visible, hintText = '') {
    if (!dropImportOverlay) return
    const shouldShow = Boolean(visible)
    dropImportOverlay.classList.toggle('hidden', !shouldShow)
    dropImportOverlay.setAttribute('aria-hidden', String(!shouldShow))
    if (dropImportHint && hintText) {
      dropImportHint.textContent = hintText
    }
  }

  function extractDroppedPathsFromEvent(event) {
    const dataTransfer = event?.dataTransfer
    if (!dataTransfer) return []
    const paths = []
    const pushPath = value => {
      const filePath = String(value || '').trim()
      if (!filePath) return
      paths.push(filePath)
    }

    for (const file of Array.from(dataTransfer.files || [])) {
      pushPath(file?.path)
    }
    for (const item of Array.from(dataTransfer.items || [])) {
      if (item?.kind !== 'file') continue
      const file = item.getAsFile?.()
      pushPath(file?.path)
    }

    return [...new Set(paths)]
  }

  async function handleDropImportEvent(event) {
    const droppedPaths = extractDroppedPathsFromEvent(event)
    await handleDroppedPaths(droppedPaths)
  }

  function bindDropImportHandlers() {
    if (dropImportHandlersBound) return
    dropImportHandlersBound = true

    window.addEventListener('dragenter', event => {
      if (!isFileDragEvent(event)) return
      event.preventDefault()
      dropImportDragDepth += 1
      setDropImportOverlayVisible(true, '松开鼠标后将自动导入语料，并按文件夹层级归类。')
    })

    window.addEventListener('dragover', event => {
      if (!isFileDragEvent(event)) return
      event.preventDefault()
      if (event.dataTransfer) {
        event.dataTransfer.dropEffect = 'copy'
      }
      setDropImportOverlayVisible(true, '松开鼠标后将自动导入语料，并按文件夹层级归类。')
    })

    window.addEventListener('dragleave', event => {
      if (!isFileDragEvent(event)) return
      event.preventDefault()
      dropImportDragDepth = Math.max(0, dropImportDragDepth - 1)
      if (dropImportDragDepth === 0) {
        setDropImportOverlayVisible(false)
      }
    })

    window.addEventListener('drop', event => {
      if (!isFileDragEvent(event)) return
      event.preventDefault()
      dropImportDragDepth = 0
      setDropImportOverlayVisible(false)
      void handleDropImportEvent(event).catch(error => {
        if (typeof onDropImportError === 'function') {
          onDropImportError(error)
          return
        }
        console.error('[drop-import]', error)
      })
    })

    window.addEventListener('dragend', () => {
      dropImportDragDepth = 0
      setDropImportOverlayVisible(false)
    })
  }

  function bindShellInteractionHandlers() {
    if (shellHandlersBound) return
    shellHandlersBound = true

    openCorpusMenuButton?.addEventListener('click', () => {
      setOpenCorpusMenuOpen(!openCorpusMenuOpen)
    })

    openCorpusMenuPanel?.addEventListener('click', async event => {
      const target = event.target
      if (!(target instanceof Element)) return

      const recentButton = target.closest('[data-recent-open-index]')
      if (recentButton instanceof HTMLButtonElement) {
        const recentIndex = Number(recentButton.dataset.recentOpenIndex)
        const entry = getRecentOpenEntries()[recentIndex]
        if (!entry) return
        await openRecentOpenEntry(entry)
        return
      }

      if (clearRecentOpenButton && (target === clearRecentOpenButton || clearRecentOpenButton.contains(target))) {
        clearRecentOpenEntries()
        showToast('最近打开列表已清空。', {
          title: '已清空'
        })
      }
    })

    commandPaletteModal?.addEventListener('click', event => {
      if (event.target === commandPaletteModal) {
        closeCommandPalette()
      }
    })

    closeCommandPaletteButton?.addEventListener('click', () => {
      closeCommandPalette()
    })

    commandPaletteInput?.addEventListener('input', () => {
      commandPaletteFilteredItems = filterCommandPaletteItems(commandPaletteInput.value)
      commandPaletteActiveIndex = 0
      renderCommandPaletteItems()
    })

    commandPaletteInput?.addEventListener('keydown', event => {
      if (event.key === 'ArrowDown') {
        event.preventDefault()
        setCommandPaletteActiveIndex(commandPaletteActiveIndex + 1, { scroll: true })
        return
      }
      if (event.key === 'ArrowUp') {
        event.preventDefault()
        setCommandPaletteActiveIndex(commandPaletteActiveIndex - 1, { scroll: true })
        return
      }
      if (event.key === 'Enter') {
        event.preventDefault()
        void executeCommandPaletteCommand()
        return
      }
      if (event.key === 'Escape') {
        event.preventDefault()
        closeCommandPalette()
      }
    })

    quickOpenButton?.addEventListener('click', async () => {
      await runQuickOpenAction()
    })

    saveImportButton?.addEventListener('click', async () => {
      await runImportAndSaveAction()
    })

    libraryButton?.addEventListener('click', () => {
      void runOpenLibraryAction()
    })

    document.addEventListener('click', event => {
      const target = event.target
      if (!(target instanceof Node)) return
      if (openCorpusMenuOpen && openCorpusMenuPanel && openCorpusMenuButton) {
        if (!openCorpusMenuPanel.contains(target) && !openCorpusMenuButton.contains(target)) {
          setOpenCorpusMenuOpen(false)
        }
      }
    })

    document.addEventListener('keydown', event => {
      const isCommandPaletteShortcut =
        (event.metaKey || event.ctrlKey) &&
        !event.altKey &&
        String(event.key || '').toLowerCase() === 'k'
      if (isCommandPaletteShortcut) {
        event.preventDefault()
        event.stopImmediatePropagation()
        openCommandPalette()
        return
      }
      if (event.key === 'Escape' && commandPaletteOpen) {
        event.preventDefault()
        event.stopImmediatePropagation()
        closeCommandPalette()
        return
      }
      if (event.key === 'Escape' && openCorpusMenuOpen) {
        event.preventDefault()
        event.stopImmediatePropagation()
        setOpenCorpusMenuOpen(false)
      }
    })
  }

  return {
    bindDropImportHandlers,
    bindShellInteractionHandlers,
    closeCommandPalette,
    dismissFloatingOverlaysForPrimaryAction,
    handleAppMenuAction,
    openCommandPalette,
    runImportAndSaveAction,
    runOpenHelpCenterAction,
    runOpenLibraryAction,
    runQuickOpenAction,
    setOpenCorpusMenuOpen
  }
}
