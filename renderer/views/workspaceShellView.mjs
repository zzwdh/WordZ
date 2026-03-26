import { buildSelectedCorporaTable } from '../features/library.mjs'
import {
  renderWorkspaceOverview as renderWorkspaceOverviewSection
} from '../features/stats.mjs'
import { buildWorkspaceShellState } from '../workspaceSessionModel.mjs'

export function renderWorkspaceShell(
  {
    currentCorpusMode,
    currentCorpusDisplayName,
    currentCorpusFolderName,
    currentSelectedCorpora,
    statsState
  } = {},
  dom,
  {
    escapeHtml,
    formatCount
  } = {}
) {
  const shellState = buildWorkspaceShellState({
    mode: currentCorpusMode,
    displayName: currentCorpusDisplayName,
    folderName: currentCorpusFolderName,
    selectedCorpora: currentSelectedCorpora
  })

  if (dom?.fileInfo) {
    dom.fileInfo.textContent = shellState.fileInfoText
  }

  if (dom?.selectedCorporaWrapper) {
    dom.selectedCorporaWrapper.innerHTML = buildSelectedCorporaTable(
      shellState.selectedCorpora,
      escapeHtml
    )
  }

  renderWorkspaceOverviewSection(statsState, dom, { formatCount })
  return shellState
}
