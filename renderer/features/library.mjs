export function getFolderById(folders, folderId) {
  return folders.find(folder => folder.id === folderId) || null
}

export function getImportTargetFolder(currentLibraryFolderId, currentLibraryFolders) {
  const targetFolderId = currentLibraryFolderId === 'all' ? 'uncategorized' : currentLibraryFolderId
  const folder = getFolderById(currentLibraryFolders, targetFolderId)
  return {
    id: targetFolderId || 'uncategorized',
    name: folder ? folder.name : (targetFolderId === 'uncategorized' ? '未分类' : '当前文件夹')
  }
}

export function getLibraryTargetChipText(currentLibraryFolderId, currentLibraryFolders) {
  const viewingLabel =
    currentLibraryFolderId === 'all'
      ? '全部语料'
      : (getFolderById(currentLibraryFolders, currentLibraryFolderId)?.name || '未分类')
  const importTarget = getImportTargetFolder(currentLibraryFolderId, currentLibraryFolders)
  return `当前查看：${viewingLabel} · 导入目标：${importTarget.name}`
}

function buildFolderOptions(folders, selectedFolderId, escapeHtml) {
  return folders
    .map(folder => {
      const selected = folder.id === selectedFolderId ? ' selected' : ''
      return `<option value="${folder.id}"${selected}>${escapeHtml(folder.name)}</option>`
    })
    .join('')
}

export function buildLibraryFolderList(folders, selectedFolderId, totalCount, escapeHtml) {
  let html = `
    <div class="library-folder-item ${selectedFolderId === 'all' ? 'active' : ''}">
      <button class="library-folder-button" data-library-folder-id="all">
        <div class="library-folder-main">
          <div class="library-folder-name">全部语料</div>
          <div class="library-folder-note">跨文件夹查看全部已保存语料</div>
        </div>
        <span class="library-folder-count">${totalCount}</span>
      </button>
    </div>
  `

  for (const folder of folders) {
    html += `
      <div class="library-folder-item ${selectedFolderId === folder.id ? 'active' : ''}">
        <button class="library-folder-button" data-library-folder-id="${folder.id}">
          <div class="library-folder-main">
            <div class="library-folder-name">${escapeHtml(folder.name)}</div>
            <div class="library-folder-note">${
              folder.id === 'uncategorized' ? '默认归档位置' : `已保存 ${folder.itemCount} 条语料`
            }</div>
          </div>
          <span class="library-folder-count">${folder.itemCount}</span>
        </button>
        <div class="library-folder-controls">
          ${
            folder.canRename
              ? `<button class="button small gray" data-rename-folder-id="${folder.id}" data-current-folder-name="${escapeHtml(folder.name)}">改名</button>`
              : ''
          }
          ${
            folder.canDelete
              ? `<button class="button small danger" data-delete-folder-id="${folder.id}" data-folder-name="${escapeHtml(folder.name)}">删除</button>`
              : ''
          }
        </div>
      </div>
    `
  }

  return html
}

export function buildLibraryTable(items, folders, currentLibraryFolderId, escapeHtml, options = {}) {
  const selectedCorpusIds = options.selectedCorpusIds instanceof Set ? options.selectedCorpusIds : new Set()
  if (!items || items.length === 0) {
    if (currentLibraryFolderId === 'all') {
      return '<div class="empty-tip">本地语料库还是空的。你可以先点击“导入并保存”。</div>'
    }
    return '<div class="empty-tip">当前文件夹还是空的。可以直接导入到这个文件夹，或者把别的语料移动进来。</div>'
  }

  let html = `<table class="data-table"><thead><tr><th class="table-checkbox-cell">选择</th><th class="library-name-cell">名称</th><th class="library-folder-cell">分类</th><th>原文件名</th><th>创建时间</th><th>操作</th></tr></thead><tbody>`
  for (const item of items) {
    const createdAt = (item.createdAt || '').replace('T', ' ').slice(0, 19)
    const isSelected = selectedCorpusIds.has(item.id)
    html += `
      <tr>
        <td class="table-checkbox-cell"><input class="table-checkbox" type="checkbox" data-select-corpus-id="${item.id}"${isSelected ? ' checked' : ''} /></td>
        <td>${escapeHtml(item.name)}</td>
        <td class="library-folder-cell">${escapeHtml(item.folderName || '未分类')}</td>
        <td>${escapeHtml(item.originalName || '')}</td>
        <td>${escapeHtml(createdAt)}</td>
        <td>
          <div class="library-actions">
            <button class="button small" data-open-corpus-id="${item.id}">打开</button>
            <button class="button small gray" data-show-corpus-id="${item.id}" data-corpus-name="${escapeHtml(item.name)}">显示位置</button>
            <button class="button small gray" data-rename-corpus-id="${item.id}" data-current-name="${escapeHtml(item.name)}">重命名</button>
            <select class="select library-move-select" data-move-folder-select="${item.id}">
              ${buildFolderOptions(folders, item.folderId, escapeHtml)}
            </select>
            <button class="button small gray" data-move-corpus-id="${item.id}">移动</button>
            <button class="button small danger" data-delete-corpus-id="${item.id}" data-corpus-name="${escapeHtml(item.name)}">删除</button>
          </div>
        </td>
      </tr>
    `
  }
  html += `</tbody></table>`
  return html
}

export function buildSelectedCorporaTable(items, escapeHtml) {
  if (!items || items.length === 0) {
    return '<div class="empty-tip">当前还没有已保存语料被加入工作区。</div>'
  }

  let html = '<table class="data-table current-corpus-table"><thead><tr><th>名称</th><th>分类</th><th>类型</th></tr></thead><tbody>'
  for (const item of items) {
    html += `
      <tr>
        <td>${escapeHtml(item.name || '')}</td>
        <td>${escapeHtml(item.folderName || '未分类')}</td>
        <td>${escapeHtml(String(item.sourceType || 'txt').toUpperCase())}</td>
      </tr>
    `
  }
  html += '</tbody></table>'
  return html
}

function getRecycleTypeLabel(entry) {
  if (entry.type === 'folder') {
    return `文件夹 · 含 ${entry.itemCount || 0} 条语料`
  }
  return `语料 · ${(entry.sourceType || 'txt').toUpperCase()}`
}

function getRecycleOriginLabel(entry) {
  if (entry.type === 'folder') {
    return '本地语料库文件夹'
  }
  return entry.originalFolderName || '未分类'
}

export function buildRecycleBinTable(entries, escapeHtml) {
  if (!entries || entries.length === 0) {
    return '<div class="empty-tip">回收站现在是空的。删除的语料和文件夹会先放到这里。</div>'
  }

  let html = '<table class="data-table"><thead><tr><th>名称</th><th>类型</th><th>原位置</th><th>删除时间</th><th>操作</th></tr></thead><tbody>'
  for (const entry of entries) {
    const deletedAt = String(entry.deletedAt || '').replace('T', ' ').slice(0, 19)
    html += `
      <tr>
        <td>${escapeHtml(entry.name || '')}</td>
        <td>${escapeHtml(getRecycleTypeLabel(entry))}</td>
        <td>${escapeHtml(getRecycleOriginLabel(entry))}</td>
        <td>${escapeHtml(deletedAt)}</td>
        <td>
          <div class="library-actions">
            <button class="button small gray" data-show-recycle-entry-id="${entry.recycleEntryId}" data-recycle-entry-name="${escapeHtml(entry.name || '')}" data-recycle-entry-type="${entry.type}">显示位置</button>
            <button class="button small" data-restore-recycle-entry-id="${entry.recycleEntryId}" data-recycle-entry-name="${escapeHtml(entry.name || '')}" data-recycle-entry-type="${entry.type}">恢复</button>
            <button class="button small danger" data-purge-recycle-entry-id="${entry.recycleEntryId}" data-recycle-entry-name="${escapeHtml(entry.name || '')}" data-recycle-entry-type="${entry.type}">彻底删除</button>
          </div>
        </td>
      </tr>
    `
  }
  html += '</tbody></table>'
  return html
}
