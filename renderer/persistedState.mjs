import {
  LIBRARY_FOLDER_STORAGE_KEY,
  ONBOARDING_STORAGE_KEY,
  RECENT_OPEN_STORAGE_KEY,
  STOPWORD_FILTER_STORAGE_KEY,
  UI_SETTINGS_STORAGE_KEY,
  WORKSPACE_STATE_STORAGE_KEY
} from './constants.mjs'
import { normalizeStopwordFilterState } from './stopwordFilter.mjs'
import {
  loadOnboardingState as loadOnboardingStateFromStorage,
  loadStoredWorkspaceSnapshot as loadStoredWorkspaceSnapshotFromStorage,
  markOnboardingTutorialCompleted as markOnboardingTutorialCompletedInStorage
} from './sessionState.mjs'
import {
  loadRecentOpenEntries as loadRecentOpenEntriesFromStorage,
  persistRecentOpenEntries as persistRecentOpenEntriesToStorage
} from './recentOpen.mjs'

const THEME_STORAGE_KEY = 'corpus-theme'

function createSafeStorageAdapter(storage = globalThis.localStorage) {
  return {
    getItem(key) {
      try {
        return storage?.getItem?.(key) ?? null
      } catch {
        return null
      }
    },
    setItem(key, value) {
      try {
        storage?.setItem?.(key, value)
        return true
      } catch {
        return false
      }
    },
    removeItem(key) {
      try {
        storage?.removeItem?.(key)
        return true
      } catch {
        return false
      }
    }
  }
}

export function createPersistedStateStore(storage = globalThis.localStorage) {
  const safeStorage = createSafeStorageAdapter(storage)

  return {
    storage: safeStorage,
    getLibraryFolderId() {
      return String(safeStorage.getItem(LIBRARY_FOLDER_STORAGE_KEY) || 'all').trim() || 'all'
    },
    setLibraryFolderId(folderId) {
      const normalizedFolderId = String(folderId || 'all').trim() || 'all'
      safeStorage.setItem(LIBRARY_FOLDER_STORAGE_KEY, normalizedFolderId)
      return normalizedFolderId
    },
    loadWorkspaceSnapshot() {
      return loadStoredWorkspaceSnapshotFromStorage(safeStorage, WORKSPACE_STATE_STORAGE_KEY)
    },
    saveWorkspaceSnapshot(snapshot = {}) {
      safeStorage.setItem(WORKSPACE_STATE_STORAGE_KEY, JSON.stringify(snapshot))
      return snapshot
    },
    clearWorkspaceSnapshot() {
      safeStorage.removeItem(WORKSPACE_STATE_STORAGE_KEY)
    },
    loadRecentOpenEntries() {
      return loadRecentOpenEntriesFromStorage(safeStorage, RECENT_OPEN_STORAGE_KEY)
    },
    saveRecentOpenEntries(entries = []) {
      persistRecentOpenEntriesToStorage(safeStorage, RECENT_OPEN_STORAGE_KEY, entries)
      return this.loadRecentOpenEntries()
    },
    loadOnboardingState() {
      return loadOnboardingStateFromStorage(safeStorage, ONBOARDING_STORAGE_KEY)
    },
    markOnboardingTutorialCompleted(onboardingState) {
      return markOnboardingTutorialCompletedInStorage(safeStorage, ONBOARDING_STORAGE_KEY, onboardingState)
    },
    loadUiSettings(defaultSettings = {}) {
      try {
        const rawValue = safeStorage.getItem(UI_SETTINGS_STORAGE_KEY)
        if (!rawValue) return { ...defaultSettings }
        return {
          ...defaultSettings,
          ...JSON.parse(rawValue)
        }
      } catch {
        return { ...defaultSettings }
      }
    },
    saveUiSettings(settings = {}) {
      safeStorage.setItem(UI_SETTINGS_STORAGE_KEY, JSON.stringify(settings))
      return settings
    },
    loadStopwordFilter(defaultState = {}) {
      try {
        const rawValue = safeStorage.getItem(STOPWORD_FILTER_STORAGE_KEY)
        if (!rawValue) return normalizeStopwordFilterState(defaultState)
        return normalizeStopwordFilterState({
          ...defaultState,
          ...JSON.parse(rawValue)
        })
      } catch {
        return normalizeStopwordFilterState(defaultState)
      }
    },
    saveStopwordFilter(stopwordFilter = {}) {
      const normalizedState = normalizeStopwordFilterState(stopwordFilter)
      safeStorage.setItem(STOPWORD_FILTER_STORAGE_KEY, JSON.stringify(normalizedState))
      return normalizedState
    },
    loadThemeMode(defaultTheme = 'light') {
      return String(safeStorage.getItem(THEME_STORAGE_KEY) || defaultTheme || 'light').trim() || 'light'
    },
    saveThemeMode(themeMode = 'light') {
      const normalizedThemeMode = String(themeMode || 'light').trim() || 'light'
      safeStorage.setItem(THEME_STORAGE_KEY, normalizedThemeMode)
      return normalizedThemeMode
    }
  }
}
