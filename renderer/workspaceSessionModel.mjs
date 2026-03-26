function normalizeSelectionItem(item = {}) {
  return {
    id: String(item?.id || '').trim(),
    name: String(item?.name || '').trim(),
    folderId: String(item?.folderId || '').trim(),
    folderName: String(item?.folderName || '').trim(),
    sourceType: String(item?.sourceType || '').trim()
  }
}

export function normalizeWorkspaceCorpusState(state = {}) {
  return {
    mode: String(state?.mode || 'quick').trim() || 'quick',
    displayName: String(state?.displayName || '').trim(),
    folderName: String(state?.folderName || '').trim(),
    selectedCorpora: Array.isArray(state?.selectedCorpora)
      ? state.selectedCorpora.map(normalizeSelectionItem).filter(item => item.id)
      : []
  }
}

export function getWorkspaceFileInfoText(state = {}) {
  const normalized = normalizeWorkspaceCorpusState(state)
  if (!normalized.displayName) {
    return '尚未选择文件'
  }

  if (normalized.mode === 'saved') {
    return `当前语料（已保存 / ${normalized.folderName || '未分类'}）：${normalized.displayName}`
  }

  if (normalized.mode === 'saved-multi') {
    return `当前语料（多选 / ${normalized.selectedCorpora.length} 条）：${normalized.displayName}`
  }

  return `当前语料（Quick Corpus）：${normalized.displayName}`
}

export function buildWorkspaceShellState(state = {}) {
  const normalized = normalizeWorkspaceCorpusState(state)
  return {
    ...normalized,
    fileInfoText: getWorkspaceFileInfoText(normalized)
  }
}
