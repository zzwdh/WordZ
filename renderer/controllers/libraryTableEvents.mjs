export function decorateLibraryTableControls({ libraryFolderList, libraryTableWrapper, decorateButton }) {
  libraryFolderList.querySelectorAll('[data-rename-folder-id]').forEach(button => decorateButton(button, 'edit'))
  libraryFolderList.querySelectorAll('[data-delete-folder-id]').forEach(button => decorateButton(button, 'delete'))
  libraryTableWrapper.querySelectorAll('[data-open-corpus-id]').forEach(button => decorateButton(button, 'open'))
  libraryTableWrapper.querySelectorAll('[data-show-corpus-id]').forEach(button => decorateButton(button, 'reveal'))
  libraryTableWrapper.querySelectorAll('[data-rename-corpus-id]').forEach(button => decorateButton(button, 'edit'))
  libraryTableWrapper.querySelectorAll('[data-move-corpus-id]').forEach(button => decorateButton(button, 'move'))
  libraryTableWrapper.querySelectorAll('[data-delete-corpus-id]').forEach(button => decorateButton(button, 'delete'))
}

export function decorateRecycleTableControls({ recycleTableWrapper, decorateButton }) {
  recycleTableWrapper.querySelectorAll('[data-show-recycle-entry-id]').forEach(button => decorateButton(button, 'reveal'))
  recycleTableWrapper.querySelectorAll('[data-restore-recycle-entry-id]').forEach(button => decorateButton(button, 'restore'))
  recycleTableWrapper.querySelectorAll('[data-purge-recycle-entry-id]').forEach(button => decorateButton(button, 'delete'))
}

export function bindLibraryTableEvents({
  libraryTableWrapper,
  recycleTableWrapper,
  getSelectedLibraryCorpusIds,
  updateLoadSelectedCorporaButton,
  updateLibraryMetaText,
  closeLibraryModal,
  loadCorpusResult,
  showMissingBridge,
  showAlert,
  showConfirm,
  showToast,
  promptForName,
  electronAPI,
  getCurrentCorpusId,
  setCurrentCorpusDisplayName,
  setCurrentCorpusFolder,
  updateCurrentCorpusInfo,
  patchCurrentSelectedCorpora,
  removeCurrentSelectedCorpora,
  getCurrentLibraryFolderId,
  refreshLibraryModal,
  refreshRecycleBinModal,
  isRecycleModalVisible,
  isLibraryModalVisible
}) {
  libraryTableWrapper.addEventListener('change', event => {
    const target = event.target
    if (!(target instanceof Element)) return
    const checkbox = target.closest('[data-select-corpus-id]')
    if (!(checkbox instanceof HTMLInputElement)) return

    const corpusId = checkbox.dataset.selectCorpusId || ''
    if (!corpusId) return

    const selectedLibraryCorpusIds = getSelectedLibraryCorpusIds()
    if (checkbox.checked) selectedLibraryCorpusIds.add(corpusId)
    else selectedLibraryCorpusIds.delete(corpusId)

    updateLoadSelectedCorporaButton()
    updateLibraryMetaText()
  })

  libraryTableWrapper.addEventListener('click', async event => {
    const openButton = event.target.closest('[data-open-corpus-id]')
    const showButton = event.target.closest('[data-show-corpus-id]')
    const renameButton = event.target.closest('[data-rename-corpus-id]')
    const moveButton = event.target.closest('[data-move-corpus-id]')
    const deleteButton = event.target.closest('[data-delete-corpus-id]')

    if (openButton) {
      const corpusId = openButton.dataset.openCorpusId
      const result = await electronAPI.openSavedCorpus(corpusId)
      closeLibraryModal()
      await loadCorpusResult(result)
      return
    }

    if (showButton) {
      if (!electronAPI?.showSavedCorpusInFolder) {
        await showMissingBridge('showSavedCorpusInFolder')
        return
      }

      const corpusId = showButton.dataset.showCorpusId
      const corpusName = showButton.dataset.corpusName || '该语料'
      const result = await electronAPI.showSavedCorpusInFolder(corpusId)
      if (!result.success) {
        await showAlert({
          title: '显示位置失败',
          message: result.message || '无法在系统文件管理器中显示该语料'
        })
        return
      }

      showToast(`已在 Finder / 资源管理器中显示「${corpusName}」。`, {
        title: '已显示位置',
        type: 'success'
      })
      return
    }

    if (renameButton) {
      const corpusId = renameButton.dataset.renameCorpusId
      const currentName = renameButton.dataset.currentName || ''
      const newName = await promptForName({
        title: '重命名语料',
        message: '请输入新的语料名称。',
        defaultValue: currentName,
        placeholder: '请输入语料名称',
        confirmText: '保存',
        label: '语料名称'
      })
      if (newName === null) return
      const result = await electronAPI.renameSavedCorpus(corpusId, newName)
      if (!result.success) {
        await showAlert({
          title: '重命名语料失败',
          message: result.message || '重命名失败'
        })
        return
      }
      if (getCurrentCorpusId() === corpusId) {
        setCurrentCorpusDisplayName(result.item.name)
        updateCurrentCorpusInfo()
      }
      patchCurrentSelectedCorpora(
        item => item.id === corpusId,
        item => ({ ...item, name: result.item.name })
      )
      await refreshLibraryModal(getCurrentLibraryFolderId())
      return
    }

    if (moveButton) {
      const corpusId = moveButton.dataset.moveCorpusId
      const row = moveButton.closest('tr')
      const select = row ? row.querySelector(`[data-move-folder-select="${corpusId}"]`) : null
      const targetFolderId = select ? select.value : ''
      const result = await electronAPI.moveSavedCorpus(corpusId, targetFolderId)
      if (!result.success) {
        await showAlert({
          title: '移动语料失败',
          message: result.message || '移动语料失败'
        })
        return
      }

      if (getCurrentCorpusId() === corpusId) {
        setCurrentCorpusFolder(result.item.folderId, result.item.folderName)
        updateCurrentCorpusInfo()
      }
      patchCurrentSelectedCorpora(
        item => item.id === corpusId,
        item => ({
          ...item,
          folderId: result.item.folderId,
          folderName: result.item.folderName
        })
      )

      await refreshLibraryModal(getCurrentLibraryFolderId())
      return
    }

    if (deleteButton) {
      const corpusId = deleteButton.dataset.deleteCorpusId
      const corpusName = deleteButton.dataset.corpusName || '该语料'
      const confirmed = await showConfirm({
        title: '删除语料',
        message: `确定要删除语料「${corpusName}」吗？它会先移入回收站，你之后仍可恢复。`,
        confirmText: '移入回收站',
        cancelText: '取消',
        danger: true
      })
      if (!confirmed) return

      const result = await electronAPI.deleteSavedCorpus(corpusId)
      if (!result.success) {
        await showAlert({
          title: '删除语料失败',
          message: result.message || '删除语料失败'
        })
        return
      }

      const selectedLibraryCorpusIds = getSelectedLibraryCorpusIds()
      if (selectedLibraryCorpusIds.has(corpusId)) {
        selectedLibraryCorpusIds.delete(corpusId)
        updateLoadSelectedCorporaButton()
        updateLibraryMetaText()
      }
      removeCurrentSelectedCorpora(item => item.id === corpusId)

      await refreshLibraryModal(getCurrentLibraryFolderId())
      if (isRecycleModalVisible()) {
        await refreshRecycleBinModal()
      }
      showToast(`语料「${corpusName}」已移入回收站。`, {
        title: '可恢复删除',
        type: 'success'
      })
    }
  })

  recycleTableWrapper?.addEventListener('click', async event => {
    const showButton = event.target.closest('[data-show-recycle-entry-id]')
    const restoreButton = event.target.closest('[data-restore-recycle-entry-id]')
    const purgeButton = event.target.closest('[data-purge-recycle-entry-id]')

    if (showButton) {
      if (!electronAPI?.showRecycleEntryInFolder) {
        await showMissingBridge('showRecycleEntryInFolder')
        return
      }

      const recycleEntryId = showButton.dataset.showRecycleEntryId
      const entryName = showButton.dataset.recycleEntryName || '该项目'
      const entryType = showButton.dataset.recycleEntryType === 'folder' ? '文件夹' : '语料'
      const result = await electronAPI.showRecycleEntryInFolder(recycleEntryId)

      if (!result.success) {
        await showAlert({
          title: '显示位置失败',
          message: result.message || '无法在系统文件管理器中显示该回收站项目'
        })
        return
      }

      showToast(`已在 Finder / 资源管理器中显示回收站${entryType}「${entryName}」。`, {
        title: '已显示位置',
        type: 'success'
      })
      return
    }

    if (restoreButton) {
      const recycleEntryId = restoreButton.dataset.restoreRecycleEntryId
      const entryName = restoreButton.dataset.recycleEntryName || '该项目'
      const entryType = restoreButton.dataset.recycleEntryType === 'folder' ? '文件夹' : '语料'
      const confirmed = await showConfirm({
        title: `恢复${entryType}`,
        message:
          entryType === '文件夹'
            ? `确定要恢复文件夹「${entryName}」吗？如果原位置已存在同 ID 文件夹，会自动恢复为新的文件夹。`
            : `确定要恢复语料「${entryName}」吗？如果原位置已不存在，会恢复到“未分类”或保留的新位置。`,
        confirmText: '恢复',
        cancelText: '取消'
      })
      if (!confirmed) return

      const result = await electronAPI.restoreRecycleEntry(recycleEntryId)
      if (!result.success) {
        await showAlert({
          title: '恢复失败',
          message: result.message || `恢复${entryType}失败`
        })
        return
      }

      await refreshRecycleBinModal()
      if (isLibraryModalVisible()) {
        await refreshLibraryModal(getCurrentLibraryFolderId())
      }

      const restoredMessage =
        result.restoredType === 'folder'
          ? (result.restoredAsNewFolder ? `文件夹「${entryName}」已恢复，并因冲突保存为新的文件夹。` : `文件夹「${entryName}」已恢复。`)
          : (result.restoredToOriginalFolder === false ? `语料「${entryName}」已恢复到可用文件夹。` : `语料「${entryName}」已恢复。`)
      showToast(restoredMessage, {
        title: '恢复完成',
        type: 'success'
      })
      return
    }

    if (purgeButton) {
      const recycleEntryId = purgeButton.dataset.purgeRecycleEntryId
      const entryName = purgeButton.dataset.recycleEntryName || '该项目'
      const entryType = purgeButton.dataset.recycleEntryType === 'folder' ? '文件夹' : '语料'
      const confirmed = await showConfirm({
        title: `彻底删除${entryType}`,
        message: `确定要彻底删除${entryType}「${entryName}」吗？删除后将无法再从回收站恢复。`,
        confirmText: '彻底删除',
        cancelText: '取消',
        danger: true
      })
      if (!confirmed) return

      const result = await electronAPI.purgeRecycleEntry(recycleEntryId)
      if (!result.success) {
        await showAlert({
          title: '彻底删除失败',
          message: result.message || `彻底删除${entryType}失败`
        })
        return
      }

      await refreshRecycleBinModal()
      showToast(`${entryType}「${entryName}」已从回收站彻底删除。`, {
        title: '删除完成',
        type: 'success'
      })
    }
  })
}
