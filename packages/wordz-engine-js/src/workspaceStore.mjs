import fs from 'node:fs/promises'
import path from 'node:path'

const DEFAULT_UI_SETTINGS = Object.freeze({
  zoom: 100,
  fontScale: 100,
  fontFamily: 'system',
  showWelcomeScreen: true,
  restoreWorkspace: true,
  systemNotifications: true,
  windowAttention: true,
  notifyAnalysisComplete: true,
  notifyUpdateDownloaded: true,
  notifyDiagnosticsExport: true,
  followSystemAccessibility: true,
  debugLogging: false
})

const DEFAULT_ONBOARDING_STATE = Object.freeze({
  tutorialCompleted: false,
  completedAt: 0
})

const DEFAULT_WORKSPACE_STORE = Object.freeze({
  version: 1,
  savedAt: '',
  currentTab: 'stats',
  currentLibraryFolderId: 'all',
  previewCollapsed: true,
  workspace: {
    corpusIds: [],
    corpusNames: []
  },
  search: {
    query: '',
    options: {
      words: true,
      caseSensitive: false,
      regex: false
    }
  },
  stats: { pageSize: '10' },
  compare: { pageSize: '10' },
  ngram: { pageSize: '10', size: '2' },
  kwic: {
    pageSize: '10',
    scope: 'current',
    sortMode: 'original',
    leftWindow: '5',
    rightWindow: '5'
  },
  collocate: {
    pageSize: '10',
    leftWindow: '5',
    rightWindow: '5',
    minFreq: '1'
  },
  chiSquare: {
    a: '',
    b: '',
    c: '',
    d: '',
    yates: false
  }
})

function cloneJson(value) {
  return JSON.parse(JSON.stringify(value))
}

async function readJsonFile(filePath, fallbackValue) {
  try {
    const content = await fs.readFile(filePath, 'utf8')
    return JSON.parse(content)
  } catch {
    return cloneJson(fallbackValue)
  }
}

async function writeJsonFile(filePath, value) {
  await fs.mkdir(path.dirname(filePath), { recursive: true })
  await fs.writeFile(filePath, JSON.stringify(value, null, 2), 'utf8')
}

function normalizeRecentOpenEntry(rawEntry = {}) {
  const type = ['quick', 'saved', 'saved-multi'].includes(rawEntry.type) ? rawEntry.type : ''
  const label = String(rawEntry.label || '').trim()
  if (!type || !label) return null
  const entry = {
    key: String(rawEntry.key || '').trim(),
    type,
    label,
    detail: String(rawEntry.detail || '').trim(),
    filePath: String(rawEntry.filePath || '').trim(),
    corpusId: String(rawEntry.corpusId || '').trim(),
    corpusIds: Array.isArray(rawEntry.corpusIds)
      ? rawEntry.corpusIds.map(item => String(item || '').trim()).filter(Boolean)
      : [],
    sourceType: String(rawEntry.sourceType || '').trim(),
    openedAt: String(rawEntry.openedAt || '').trim() || new Date().toISOString()
  }

  if (!entry.key) {
    entry.key =
      entry.type === 'quick'
        ? `quick:${entry.filePath}`
        : entry.type === 'saved'
          ? `saved:${entry.corpusId}`
          : `saved-multi:${[...entry.corpusIds].sort().join(',')}`
  }

  if (entry.type === 'quick' && !entry.filePath) return null
  if (entry.type === 'saved' && !entry.corpusId) return null
  if (entry.type === 'saved-multi' && entry.corpusIds.length === 0) return null
  return entry
}

export function createWorkspaceStore({ userDataDir }) {
  const stateDir = path.join(userDataDir, 'native-state')
  const workspacePath = path.join(stateDir, 'wordz-workspace-state.json')
  const recentOpenPath = path.join(stateDir, 'wordz-recent-open.json')
  const uiSettingsPath = path.join(stateDir, 'corpus-ui-settings.json')
  const onboardingPath = path.join(stateDir, 'wordz-onboarding.json')

  return {
    async getWorkspaceState() {
      return readJsonFile(workspacePath, DEFAULT_WORKSPACE_STORE)
    },
    async saveWorkspaceState(snapshot = {}) {
      const nextValue = {
        ...cloneJson(DEFAULT_WORKSPACE_STORE),
        ...(snapshot && typeof snapshot === 'object' ? snapshot : {}),
        savedAt: new Date().toISOString()
      }
      await writeJsonFile(workspacePath, nextValue)
      return nextValue
    },
    async getRecentOpen() {
      const entries = await readJsonFile(recentOpenPath, [])
      return Array.isArray(entries)
        ? entries.map(normalizeRecentOpenEntry).filter(Boolean).slice(0, 8)
        : []
    },
    async saveRecentOpen(entries = []) {
      const normalizedEntries = Array.isArray(entries)
        ? entries.map(normalizeRecentOpenEntry).filter(Boolean).slice(0, 8)
        : []
      await writeJsonFile(recentOpenPath, normalizedEntries)
      return normalizedEntries
    },
    async getUiSettings() {
      return readJsonFile(uiSettingsPath, DEFAULT_UI_SETTINGS)
    },
    async saveUiSettings(settings = {}) {
      const nextValue = {
        ...cloneJson(DEFAULT_UI_SETTINGS),
        ...(settings && typeof settings === 'object' ? settings : {})
      }
      await writeJsonFile(uiSettingsPath, nextValue)
      return nextValue
    },
    async getOnboardingState() {
      return readJsonFile(onboardingPath, DEFAULT_ONBOARDING_STATE)
    },
    async saveOnboardingState(state = {}) {
      const nextValue = {
        ...cloneJson(DEFAULT_ONBOARDING_STATE),
        ...(state && typeof state === 'object' ? state : {})
      }
      await writeJsonFile(onboardingPath, nextValue)
      return nextValue
    }
  }
}
