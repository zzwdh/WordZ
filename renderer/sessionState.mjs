import { normalizeSearchOptions } from '../analysisCore.mjs'
import { WORKSPACE_SNAPSHOT_VERSION } from './constants.mjs'

const VALID_RESTORABLE_TABS = new Set(['stats', 'compare', 'word-cloud', 'kwic', 'collocate', 'locator'])

function saveOnboardingState(storage, storageKey, state) {
  storage.setItem(storageKey, JSON.stringify(state))
}

export function loadOnboardingState(storage, storageKey) {
  try {
    const rawValue = storage.getItem(storageKey)
    if (!rawValue) {
      return {
        tutorialCompleted: false,
        completedAt: 0
      }
    }

    const parsedValue = JSON.parse(rawValue)
    return {
      tutorialCompleted: parsedValue?.tutorialCompleted === true,
      completedAt: Number(parsedValue?.completedAt) || 0
    }
  } catch {
    return {
      tutorialCompleted: false,
      completedAt: 0
    }
  }
}

export function shouldShowFirstRunTutorial(onboardingState) {
  return onboardingState?.tutorialCompleted !== true
}

export function markOnboardingTutorialCompleted(storage, storageKey, onboardingState) {
  if (onboardingState?.tutorialCompleted === true) return onboardingState
  const nextState = {
    tutorialCompleted: true,
    completedAt: Date.now()
  }
  saveOnboardingState(storage, storageKey, nextState)
  return nextState
}

export function hasMeaningfulWorkspaceSnapshot(snapshot) {
  if (!snapshot) return false
  return Array.isArray(snapshot.workspace?.corpusIds) && snapshot.workspace.corpusIds.length > 0
}

export function getWorkspaceSnapshotSummary(snapshot, { getTabLabel } = {}) {
  const corpusNames = Array.isArray(snapshot?.workspace?.corpusNames)
    ? snapshot.workspace.corpusNames.map(item => String(item || '').trim()).filter(Boolean)
    : []
  const summaryParts = []

  if (corpusNames.length > 0) {
    const namesPreview = corpusNames.slice(0, 2).join('、')
    summaryParts.push(corpusNames.length > 2 ? `${namesPreview} 等 ${corpusNames.length} 条语料` : namesPreview)
  } else if (snapshot?.workspace?.corpusIds?.length > 0) {
    summaryParts.push(`已保存语料 ${snapshot.workspace.corpusIds.length} 条`)
  }

  const tabName = getRestorableTabFromSnapshot(snapshot)
  summaryParts.push(typeof getTabLabel === 'function' ? getTabLabel(tabName) : tabName)

  if (snapshot?.search?.query) {
    summaryParts.push(`搜索词：${snapshot.search.query}`)
  }

  return summaryParts.join(' · ') || '上次工作区包含已保存语料与检索状态。'
}

export function normalizeWorkspaceSnapshot(rawSnapshot) {
  if (!rawSnapshot || typeof rawSnapshot !== 'object') return null
  if (Number(rawSnapshot.version) !== WORKSPACE_SNAPSHOT_VERSION) return null

  const corpusIds = Array.isArray(rawSnapshot.workspace?.corpusIds)
    ? rawSnapshot.workspace.corpusIds.map(item => String(item || '').trim()).filter(Boolean)
    : []
  const corpusNames = Array.isArray(rawSnapshot.workspace?.corpusNames)
    ? rawSnapshot.workspace.corpusNames.map(item => String(item || '').trim()).filter(Boolean)
    : []

  return {
    version: WORKSPACE_SNAPSHOT_VERSION,
    savedAt: String(rawSnapshot.savedAt || '').trim(),
    currentTab: VALID_RESTORABLE_TABS.has(rawSnapshot.currentTab) ? rawSnapshot.currentTab : 'stats',
    currentLibraryFolderId: String(rawSnapshot.currentLibraryFolderId || 'all').trim() || 'all',
    previewCollapsed: rawSnapshot.previewCollapsed !== false,
    workspace: {
      corpusIds,
      corpusNames
    },
    search: {
      query: String(rawSnapshot.search?.query || ''),
      options: normalizeSearchOptions(rawSnapshot.search?.options || {})
    },
    stats: {
      pageSize: String(rawSnapshot.stats?.pageSize || '10')
    },
    compare: {
      pageSize: String(rawSnapshot.compare?.pageSize || '10')
    },
    kwic: {
      pageSize: String(rawSnapshot.kwic?.pageSize || '10'),
      scope: String(rawSnapshot.kwic?.scope || 'current'),
      sortMode: String(rawSnapshot.kwic?.sortMode || 'original'),
      leftWindow: String(rawSnapshot.kwic?.leftWindow || '5'),
      rightWindow: String(rawSnapshot.kwic?.rightWindow || '5')
    },
    collocate: {
      pageSize: String(rawSnapshot.collocate?.pageSize || '10'),
      leftWindow: String(rawSnapshot.collocate?.leftWindow || '5'),
      rightWindow: String(rawSnapshot.collocate?.rightWindow || '5'),
      minFreq: String(rawSnapshot.collocate?.minFreq || '1')
    }
  }
}

export function loadStoredWorkspaceSnapshot(storage, storageKey) {
  try {
    const rawValue = storage.getItem(storageKey)
    if (!rawValue) return null
    return normalizeWorkspaceSnapshot(JSON.parse(rawValue))
  } catch (error) {
    console.warn('[workspace.snapshot.load]', error)
    return null
  }
}

export function getRestorableTabFromSnapshot(snapshot) {
  if (!snapshot) return 'stats'
  if (snapshot.currentTab === 'locator') {
    return snapshot.search?.query ? 'kwic' : 'stats'
  }
  return snapshot.currentTab || 'stats'
}
