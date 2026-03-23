import {
  buildRecycleBinTable,
  buildLibraryFolderList,
  buildLibraryTable
} from '../features/library.mjs'
import {
  bindLibraryTableEvents,
  decorateLibraryTableControls,
  decorateRecycleTableControls
} from './libraryTableEvents.mjs'

export function createLibraryManagerController({
  electronAPI,
  dom,
  escapeHtml,
  formatCount,
  beginBusyState,
  setButtonsBusy,
  showMissingBridge,
  showAlert,
  showConfirm,
  showToast,
  notifySystem,
  promptForName,
  loadCorpusResult,
  setWindowProgressState,
  buildBackupSummaryMessage,
  buildRestoreSummaryMessage,
  buildRepairSummaryMessage,
  syncLibrarySelectionWithCurrentCorpora,
  updateLoadSelectedCorporaButton,
  updateLibraryMetaText,
  updateLibraryTargetChip,
  setLibraryFolderSelection,
  getCurrentLibraryFolderId,
  setCurrentLibraryFolders,
  setCurrentLibraryVisibleCount,
  setCurrentLibraryTotalCount,
  getSelectedLibraryCorpusIds,
  getImportTargetFolder,
  getCurrentCorpusId,
  getCurrentCorpusMode,
  getCurrentCorpusFolderId,
  setCurrentCorpusDisplayName,
  setCurrentCorpusFolder,
  updateCurrentCorpusInfo,
  patchCurrentSelectedCorpora,
  removeCurrentSelectedCorpora,
  decorateButton
}) {
  const {
    libraryMeta,
    libraryFolderList,
    libraryTableWrapper,
    libraryModal,
    selectSavedCorporaButton,
    closeLibraryButton,
    createFolderButton,
    importToFolderButton,
    loadSelectedCorporaButton,
    recycleBinButton,
    recycleMeta,
    recycleTableWrapper,
    recycleModal,
    closeRecycleButton,
    backupLibraryButton,
    restoreLibraryButton,
    repairLibraryButton
  } = dom

  function isLibraryModalVisible() {
    return Boolean(libraryModal && !libraryModal.classList.contains('hidden'))
  }

  function isRecycleModalVisible() {
    return Boolean(recycleModal && !recycleModal.classList.contains('hidden'))
  }

  function decorateLibraryControls() {
    decorateLibraryTableControls({
      libraryFolderList,
      libraryTableWrapper,
      decorateButton
    })
  }

  function decorateRecycleControls() {
    decorateRecycleTableControls({
      recycleTableWrapper,
      decorateButton
    })
  }

  async function refreshLibraryModal(folderId = getCurrentLibraryFolderId()) {
    const endBusyState = beginBusyState('正在读取本地语料库...')
    setCurrentLibraryVisibleCount(0)
    libraryMeta.textContent = '正在读取本地语料库...'
    libraryFolderList.innerHTML = '<div class="empty-tip">正在加载文件夹...</div>'
    libraryTableWrapper.innerHTML = '<div class="empty-tip">正在加载本地语料库...</div>'

    try {
      const result = await electronAPI.listSavedCorpora(folderId)
      if (!result.success) {
        libraryMeta.textContent = '读取失败'
        libraryFolderList.innerHTML = '<div class="empty-tip">无法读取文件夹信息</div>'
        libraryTableWrapper.innerHTML = '<div class="empty-tip">无法读取本地语料库</div>'
        return
      }

      const nextFolders = result.folders || []
      const nextVisibleCount = (result.items || []).length
      const nextTotalCount = result.totalCount || 0
      setCurrentLibraryFolders(nextFolders)
      setCurrentLibraryVisibleCount(nextVisibleCount)
      setCurrentLibraryTotalCount(nextTotalCount)
      setLibraryFolderSelection(result.selectedFolderId || 'all')
      updateLibraryTargetChip()
      libraryFolderList.innerHTML = buildLibraryFolderList(
        nextFolders,
        getCurrentLibraryFolderId(),
        nextTotalCount,
        escapeHtml
      )
      libraryTableWrapper.innerHTML = buildLibraryTable(
        result.items || [],
        nextFolders,
        getCurrentLibraryFolderId(),
        escapeHtml,
        { selectedCorpusIds: getSelectedLibraryCorpusIds() }
      )
      decorateLibraryControls()
      updateLoadSelectedCorporaButton()
      updateLibraryMetaText()
    } finally {
      endBusyState()
    }
  }

  async function openLibraryModal(folderId = getCurrentLibraryFolderId()) {
    if (!electronAPI?.listSavedCorpora) {
      await showMissingBridge('listSavedCorpora')
      return
    }

    syncLibrarySelectionWithCurrentCorpora()
    updateLoadSelectedCorporaButton()
    libraryModal.classList.remove('hidden')
    await refreshLibraryModal(folderId)
  }

  function closeLibraryModal() {
    libraryModal.classList.add('hidden')
  }

  async function refreshRecycleBinModal() {
    recycleMeta.textContent = '正在读取回收站...'
    recycleTableWrapper.innerHTML = '<div class="empty-tip">正在读取回收站...</div>'

    const result = await electronAPI.listRecycleBin()
    if (!result.success) {
      recycleMeta.textContent = '读取失败'
      recycleTableWrapper.innerHTML = '<div class="empty-tip">无法读取回收站</div>'
      return
    }

    recycleMeta.textContent = `共 ${formatCount(result.totalCount || 0)} 条项目，其中 ${formatCount(result.folderCount || 0)} 个文件夹、${formatCount(result.corpusCount || 0)} 条语料。`
    recycleTableWrapper.innerHTML = buildRecycleBinTable(result.entries || [], escapeHtml)
    decorateRecycleControls()
  }

  async function openRecycleModal() {
    if (!electronAPI?.listRecycleBin) {
      await showMissingBridge('listRecycleBin')
      return
    }

    recycleModal.classList.remove('hidden')
    await refreshRecycleBinModal()
  }

  function closeRecycleModal() {
    recycleModal.classList.add('hidden')
  }

  function bindLibraryManagerEvents() {
    selectSavedCorporaButton?.addEventListener('click', async () => {
      syncLibrarySelectionWithCurrentCorpora()
      await openLibraryModal('all')
    })

    closeLibraryButton?.addEventListener('click', () => {
      closeLibraryModal()
    })

    libraryModal?.addEventListener('click', event => {
      if (event.target === libraryModal) closeLibraryModal()
    })

    createFolderButton?.addEventListener('click', async () => {
      const folderName = await promptForName({
        title: '新建文件夹',
        message: '请输入新文件夹名称。',
        placeholder: '例如：毕业论文语料',
        confirmText: '创建',
        label: '文件夹名称'
      })
      if (folderName === null) return

      const result = await electronAPI.createCorpusFolder(folderName)
      if (!result.success) {
        await showAlert({
          title: '创建文件夹失败',
          message: result.message || '创建文件夹失败'
        })
        return
      }

      await refreshLibraryModal(result.folder.id)
    })

    importToFolderButton?.addEventListener('click', async () => {
      if (!electronAPI?.importAndSaveCorpus) {
        await showMissingBridge('importAndSaveCorpus')
        return
      }

      const result = await electronAPI.importAndSaveCorpus(getImportTargetFolder().id)
      await loadCorpusResult(result)
      await refreshLibraryModal(getCurrentLibraryFolderId())
    })

    loadSelectedCorporaButton?.addEventListener('click', async () => {
      if (!electronAPI?.openSavedCorpora) {
        await showMissingBridge('openSavedCorpora')
        return
      }

      const selectedCorpusIds = [...getSelectedLibraryCorpusIds()]
      if (selectedCorpusIds.length === 0) {
        showToast('请先勾选至少一条已保存语料。', {
          title: '未选择语料'
        })
        return
      }

      const result = await electronAPI.openSavedCorpora(selectedCorpusIds)
      if (!result.success) {
        await showAlert({
          title: '载入语料失败',
          message: result.message || '无法载入选中的语料'
        })
        return
      }

      closeLibraryModal()
      await loadCorpusResult(result)
    })

    recycleBinButton?.addEventListener('click', async () => {
      await openRecycleModal()
    })

    closeRecycleButton?.addEventListener('click', () => {
      closeRecycleModal()
    })

    recycleModal?.addEventListener('click', event => {
      if (event.target === recycleModal) closeRecycleModal()
    })

    backupLibraryButton?.addEventListener('click', async () => {
      if (!electronAPI?.backupCorpusLibrary) {
        await showMissingBridge('backupCorpusLibrary')
        return
      }

      const endBusyState = beginBusyState('正在创建语料库备份...')
      setButtonsBusy([backupLibraryButton, restoreLibraryButton, repairLibraryButton], true)
      void setWindowProgressState({
        source: 'library-maintenance',
        state: 'indeterminate',
        priority: 35
      })
      try {
        const result = await electronAPI.backupCorpusLibrary()
        if (!result.success) {
          if (result.canceled) {
            showToast('已取消备份位置选择', { title: '未创建备份' })
            return
          }
          await showAlert({
            title: '备份失败',
            message: result.message || '创建语料库备份失败'
          })
          return
        }

        await showAlert({
          title: '备份完成',
          message: buildBackupSummaryMessage(result)
        })
        void notifySystem({
          title: '语料库备份完成',
          body: result.backupPath || '本地语料库备份已创建完成。',
          tag: 'library-backup'
        })
      } finally {
        endBusyState()
        setButtonsBusy([backupLibraryButton, restoreLibraryButton, repairLibraryButton], false)
        void setWindowProgressState({
          source: 'library-maintenance',
          state: 'none'
        })
      }
    })

    restoreLibraryButton?.addEventListener('click', async () => {
      if (!electronAPI?.restoreCorpusLibrary) {
        await showMissingBridge('restoreCorpusLibrary')
        return
      }

      const confirmed = await showConfirm({
        title: '恢复本地语料库',
        message: '这会用一个备份目录替换当前本地语料库。恢复前会自动保留当前语料库快照，便于回退。是否继续？',
        confirmText: '选择备份并恢复',
        cancelText: '取消'
      })
      if (!confirmed) return

      const endBusyState = beginBusyState('正在从备份恢复语料库...')
      setButtonsBusy([backupLibraryButton, restoreLibraryButton, repairLibraryButton], true)
      void setWindowProgressState({
        source: 'library-maintenance',
        state: 'indeterminate',
        priority: 35
      })
      try {
        const result = await electronAPI.restoreCorpusLibrary()
        if (!result.success) {
          if (result.canceled) {
            showToast('已取消备份目录选择', { title: '未恢复语料库' })
            return
          }
          await showAlert({
            title: '恢复失败',
            message: result.message || '恢复语料库失败'
          })
          return
        }

        await refreshLibraryModal(getCurrentLibraryFolderId())
        await showAlert({
          title: '恢复完成',
          message: buildRestoreSummaryMessage(result)
        })
        void notifySystem({
          title: '语料库恢复完成',
          body: result.restoredFrom || '本地语料库已从备份恢复完成。',
          tag: 'library-restore'
        })
      } finally {
        endBusyState()
        setButtonsBusy([backupLibraryButton, restoreLibraryButton, repairLibraryButton], false)
        void setWindowProgressState({
          source: 'library-maintenance',
          state: 'none'
        })
      }
    })

    repairLibraryButton?.addEventListener('click', async () => {
      if (!electronAPI?.repairCorpusLibrary) {
        await showMissingBridge('repairCorpusLibrary')
        return
      }

      const confirmed = await showConfirm({
        title: '修复本地语料库',
        message: '这会检查语料库结构，自动补回缺失元数据，并把异常目录移动到隔离区。是否继续？',
        confirmText: '开始修复',
        cancelText: '取消'
      })
      if (!confirmed) return

      const endBusyState = beginBusyState('正在检查并修复本地语料库...')
      setButtonsBusy([backupLibraryButton, restoreLibraryButton, repairLibraryButton], true)
      void setWindowProgressState({
        source: 'library-maintenance',
        state: 'indeterminate',
        priority: 35
      })
      try {
        const result = await electronAPI.repairCorpusLibrary()
        if (!result.success) {
          await showAlert({
            title: '修复失败',
            message: result.message || '语料库修复失败'
          })
          return
        }

        await refreshLibraryModal(getCurrentLibraryFolderId())
        await showAlert({
          title: '修复完成',
          message: buildRepairSummaryMessage(result)
        })
        void notifySystem({
          title: '语料库修复完成',
          body: `已修复 ${formatCount(result.repairedCorpusCount || 0)} 条语料，隔离 ${formatCount(result.quarantinedEntryCount || 0)} 个异常项目。`,
          tag: 'library-repair'
        })
      } finally {
        endBusyState()
        setButtonsBusy([backupLibraryButton, restoreLibraryButton, repairLibraryButton], false)
        void setWindowProgressState({
          source: 'library-maintenance',
          state: 'none'
        })
      }
    })

    libraryFolderList?.addEventListener('click', async event => {
      const target = event.target
      if (!(target instanceof Element)) return

      const folderButton = target.closest('[data-library-folder-id]')
      const renameFolderButton = target.closest('[data-rename-folder-id]')
      const deleteFolderButton = target.closest('[data-delete-folder-id]')

      if (folderButton) {
        await refreshLibraryModal(folderButton.dataset.libraryFolderId)
        return
      }

      if (renameFolderButton) {
        const folderId = renameFolderButton.dataset.renameFolderId
        const currentName = renameFolderButton.dataset.currentFolderName || ''
        const newName = await promptForName({
          title: '重命名文件夹',
          message: '请输入新的文件夹名称。',
          defaultValue: currentName,
          placeholder: '请输入文件夹名称',
          confirmText: '保存',
          label: '文件夹名称'
        })
        if (newName === null) return

        const result = await electronAPI.renameCorpusFolder(folderId, newName)
        if (!result.success) {
          await showAlert({
            title: '重命名文件夹失败',
            message: result.message || '重命名文件夹失败'
          })
          return
        }

        if (getCurrentCorpusMode() === 'saved' && getCurrentCorpusFolderId() === folderId) {
          setCurrentCorpusFolder(getCurrentCorpusFolderId(), result.folder.name)
          updateCurrentCorpusInfo()
        }
        patchCurrentSelectedCorpora(
          item => item.folderId === folderId,
          item => ({ ...item, folderName: result.folder.name })
        )

        await refreshLibraryModal(getCurrentLibraryFolderId())
        return
      }

      if (deleteFolderButton) {
        const folderId = deleteFolderButton.dataset.deleteFolderId
        const folderName = deleteFolderButton.dataset.folderName || '该文件夹'
        const confirmed = await showConfirm({
          title: '删除文件夹',
          message: `删除文件夹「${folderName}」后，它和里面的语料会先移入回收站，你之后仍可恢复。是否继续？`,
          confirmText: '移入回收站',
          cancelText: '取消',
          danger: true
        })
        if (!confirmed) return

        const result = await electronAPI.deleteCorpusFolder(folderId)
        if (!result.success) {
          await showAlert({
            title: '删除文件夹失败',
            message: result.message || '删除文件夹失败'
          })
          return
        }

        removeCurrentSelectedCorpora(item => item.folderId === folderId)

        await refreshLibraryModal(getCurrentLibraryFolderId())
        if (isRecycleModalVisible()) {
          await refreshRecycleBinModal()
        }
        showToast(`文件夹「${folderName}」已移入回收站。`, {
          title: '可恢复删除',
          type: 'success'
        })
      }
    })

    bindLibraryTableEvents({
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
    })
  }

  return {
    refreshLibraryModal,
    openLibraryModal,
    closeLibraryModal,
    refreshRecycleBinModal,
    openRecycleModal,
    closeRecycleModal,
    isLibraryModalVisible,
    isRecycleModalVisible,
    bindLibraryManagerEvents
  }
}
