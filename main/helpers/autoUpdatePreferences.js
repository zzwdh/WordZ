const DEFAULT_AUTO_UPDATE_PREFERENCES = Object.freeze({
  enabled: true,
  checkOnLaunch: true,
  autoDownload: true
})

function normalizeBooleanPreference(value, fallbackValue) {
  if (value === undefined || value === null || value === '') return fallbackValue
  return value !== false
}

function normalizeAutoUpdatePreferences(preferences = {}, defaults = DEFAULT_AUTO_UPDATE_PREFERENCES) {
  return {
    enabled: normalizeBooleanPreference(preferences.enabled, defaults.enabled),
    checkOnLaunch: normalizeBooleanPreference(preferences.checkOnLaunch, defaults.checkOnLaunch),
    autoDownload: normalizeBooleanPreference(preferences.autoDownload, defaults.autoDownload)
  }
}

function createAutoUpdatePreferencesStore({
  app,
  fsSync,
  path,
  logger = console
}) {
  const preferencesFilePath = path.join(app.getPath('userData'), 'auto-update-preferences.json')

  function load() {
    try {
      const rawContent = fsSync.readFileSync(preferencesFilePath, 'utf8')
      if (!rawContent) return { ...DEFAULT_AUTO_UPDATE_PREFERENCES }
      return normalizeAutoUpdatePreferences(JSON.parse(rawContent))
    } catch (error) {
      if (error?.code !== 'ENOENT') {
        logger.warn?.('[auto-update-preferences.load]', error)
      }
      return { ...DEFAULT_AUTO_UPDATE_PREFERENCES }
    }
  }

  function save(preferences = {}) {
    const normalizedPreferences = normalizeAutoUpdatePreferences(preferences)
    try {
      fsSync.mkdirSync(path.dirname(preferencesFilePath), { recursive: true })
      fsSync.writeFileSync(preferencesFilePath, JSON.stringify(normalizedPreferences, null, 2), 'utf8')
    } catch (error) {
      logger.warn?.('[auto-update-preferences.save]', error)
    }
    return normalizedPreferences
  }

  return {
    load,
    save,
    getFilePath: () => preferencesFilePath
  }
}

module.exports = {
  DEFAULT_AUTO_UPDATE_PREFERENCES,
  createAutoUpdatePreferencesStore,
  normalizeAutoUpdatePreferences
}
