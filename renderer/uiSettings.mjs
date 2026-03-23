export function createUISettingsController({
  dom,
  electronAPI,
  stateStore,
  defaultTheme,
  defaultSettings,
  fontFamilies,
  clampNumber
}) {
  const THEME_MODE_SET = new Set(['light', 'dark', 'system'])
  let currentUISettings = { ...defaultSettings }
  let currentThemeMode = defaultTheme === 'dark' ? 'dark' : 'light'
  let systemThemeMediaQuery = null
  let themeMediaUnsubscriber = null
  let accessibilityMediaUnsubscribers = []
  let hasBoundSystemThemeListener = false

  function addMediaChangeListener(mediaQuery, listener) {
    if (!mediaQuery || typeof listener !== 'function') return () => {}
    if (typeof mediaQuery.addEventListener === 'function') {
      mediaQuery.addEventListener('change', listener)
      return () => {
        mediaQuery.removeEventListener('change', listener)
      }
    }
    if (typeof mediaQuery.addListener === 'function') {
      mediaQuery.addListener(listener)
      return () => {
        mediaQuery.removeListener(listener)
      }
    }
    return () => {}
  }

  function getSystemThemeMediaQuery() {
    if (systemThemeMediaQuery || typeof window.matchMedia !== 'function') return systemThemeMediaQuery
    systemThemeMediaQuery = window.matchMedia('(prefers-color-scheme: dark)')
    return systemThemeMediaQuery
  }

  function resolveThemeMode(value) {
    const normalizedValue = String(value || '').trim().toLowerCase()
    if (THEME_MODE_SET.has(normalizedValue)) return normalizedValue
    const normalizedDefault = String(defaultTheme || '').trim().toLowerCase()
    return normalizedDefault === 'dark' ? 'dark' : 'light'
  }

  function resolveEffectiveTheme(themeMode) {
    if (themeMode === 'dark') return 'dark'
    if (themeMode === 'system') {
      const mediaQuery = getSystemThemeMediaQuery()
      return mediaQuery?.matches ? 'dark' : 'light'
    }
    return 'light'
  }

  function applyAccessibilityPreferences() {
    if (!document.body) return
    const followsSystem = currentUISettings.followSystemAccessibility !== false
    if (!followsSystem || typeof window.matchMedia !== 'function') {
      document.body.classList.remove('reduce-motion')
      document.body.classList.remove('high-contrast')
      return
    }

    const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches
    const prefersHighContrast = window.matchMedia('(prefers-contrast: more)').matches
    const forcedColorsEnabled = window.matchMedia('(forced-colors: active)').matches
    document.body.classList.toggle('reduce-motion', prefersReducedMotion)
    document.body.classList.toggle('high-contrast', prefersHighContrast || forcedColorsEnabled)
  }

  function normalizeUISettings(settings = {}) {
    const fontFamily = fontFamilies[settings.fontFamily] ? settings.fontFamily : defaultSettings.fontFamily
    return {
      zoom: clampNumber(settings.zoom, 80, 135, defaultSettings.zoom),
      fontScale: clampNumber(settings.fontScale, 85, 140, defaultSettings.fontScale),
      fontFamily,
      showWelcomeScreen: settings.showWelcomeScreen !== false,
      restoreWorkspace: settings.restoreWorkspace !== false,
      systemNotifications: settings.systemNotifications !== false,
      windowAttention: settings.windowAttention !== false,
      notifyAnalysisComplete: settings.notifyAnalysisComplete !== false,
      notifyUpdateDownloaded: settings.notifyUpdateDownloaded !== false,
      notifyDiagnosticsExport: settings.notifyDiagnosticsExport !== false,
      followSystemAccessibility: settings.followSystemAccessibility !== false,
      debugLogging: settings.debugLogging === true
    }
  }

  function updateUISettingLabels(settings) {
    dom.uiZoomValue.textContent = `${settings.zoom}%`
    dom.uiFontSizeValue.textContent = `${settings.fontScale}%`
  }

  function syncUISettingControls(settings) {
    dom.uiZoomRange.value = String(settings.zoom)
    dom.uiFontSizeRange.value = String(settings.fontScale)
    dom.uiFontFamilySelect.value = settings.fontFamily
    if (dom.showWelcomeScreenToggle) {
      dom.showWelcomeScreenToggle.checked = settings.showWelcomeScreen !== false
    }
    if (dom.restoreWorkspaceToggle) {
      dom.restoreWorkspaceToggle.checked = settings.restoreWorkspace !== false
    }
    if (dom.systemNotificationsToggle) {
      dom.systemNotificationsToggle.checked = settings.systemNotifications !== false
    }
    if (dom.windowAttentionToggle) {
      dom.windowAttentionToggle.checked = settings.windowAttention !== false
    }
    if (dom.notifyAnalysisCompleteToggle) {
      dom.notifyAnalysisCompleteToggle.checked = settings.notifyAnalysisComplete !== false
    }
    if (dom.notifyUpdateDownloadedToggle) {
      dom.notifyUpdateDownloadedToggle.checked = settings.notifyUpdateDownloaded !== false
    }
    if (dom.notifyDiagnosticsExportToggle) {
      dom.notifyDiagnosticsExportToggle.checked = settings.notifyDiagnosticsExport !== false
    }
    if (dom.followSystemAccessibilityToggle) {
      dom.followSystemAccessibilityToggle.checked = settings.followSystemAccessibility !== false
    }
    if (dom.debugLoggingToggle) {
      dom.debugLoggingToggle.checked = settings.debugLogging === true
    }
    updateUISettingLabels(settings)
  }

  function setAppZoom(zoomPercent) {
    const zoomFactor = zoomPercent / 100
    if (electronAPI?.setZoomFactor) {
      electronAPI.setZoomFactor(zoomFactor)
      return
    }
    document.body.style.zoom = String(zoomFactor)
  }

  function persistUISettings(settings) {
    stateStore?.saveUiSettings?.(settings)
  }

  function applyUISettings(settings, options = {}) {
    const { persist = true, syncControls = true } = options
    const normalizedSettings = normalizeUISettings(settings)
    const previousDebugLogging = currentUISettings.debugLogging === true
    currentUISettings = normalizedSettings
    document.documentElement.style.setProperty('--font-scale', String(normalizedSettings.fontScale / 100))
    document.documentElement.style.setProperty('--app-font-family', fontFamilies[normalizedSettings.fontFamily])
    setAppZoom(normalizedSettings.zoom)
    if (electronAPI?.setDiagnosticLoggingEnabled && previousDebugLogging !== (normalizedSettings.debugLogging === true)) {
      void electronAPI.setDiagnosticLoggingEnabled(normalizedSettings.debugLogging === true)
    }
    applyAccessibilityPreferences()
    if (syncControls) syncUISettingControls(normalizedSettings)
    if (persist) persistUISettings(normalizedSettings)
  }

  function loadStoredUISettings() {
    return normalizeUISettings(stateStore?.loadUiSettings?.(defaultSettings) || defaultSettings)
  }

  function openUISettingsModal() {
    dom.uiSettingsModal.classList.remove('hidden')
  }

  function closeUISettingsModal() {
    dom.uiSettingsModal.classList.add('hidden')
  }

  function applyUISettingsFromControls() {
    applyUISettings({
      zoom: dom.uiZoomRange.value,
      fontScale: dom.uiFontSizeRange.value,
      fontFamily: dom.uiFontFamilySelect.value,
      showWelcomeScreen: dom.showWelcomeScreenToggle?.checked !== false,
      restoreWorkspace: dom.restoreWorkspaceToggle?.checked !== false,
      systemNotifications: dom.systemNotificationsToggle?.checked !== false,
      windowAttention: dom.windowAttentionToggle?.checked !== false,
      notifyAnalysisComplete: dom.notifyAnalysisCompleteToggle?.checked !== false,
      notifyUpdateDownloaded: dom.notifyUpdateDownloadedToggle?.checked !== false,
      notifyDiagnosticsExport: dom.notifyDiagnosticsExportToggle?.checked !== false,
      followSystemAccessibility: dom.followSystemAccessibilityToggle?.checked !== false,
      debugLogging: dom.debugLoggingToggle?.checked === true
    })
  }

  function applyTheme(themeMode, options = {}) {
    const { persist = true } = options
    const normalizedThemeMode = resolveThemeMode(themeMode)
    const effectiveTheme = resolveEffectiveTheme(normalizedThemeMode)
    currentThemeMode = normalizedThemeMode
    if (effectiveTheme === 'dark') {
      document.body.setAttribute('data-theme', 'dark')
    } else {
      document.body.removeAttribute('data-theme')
    }
    if (document.body) {
      document.body.setAttribute('data-theme-mode', normalizedThemeMode)
    }
    if (dom.themeModeValue) {
      dom.themeModeValue.textContent = normalizedThemeMode === 'system'
        ? `跟随系统（当前${effectiveTheme === 'dark' ? '深色' : '浅色'}）`
        : (effectiveTheme === 'dark' ? '深色模式' : '浅色模式')
    }
    dom.lightThemeButton?.classList.toggle('active', normalizedThemeMode === 'light')
    dom.darkThemeButton?.classList.toggle('active', normalizedThemeMode === 'dark')
    dom.systemThemeButton?.classList.toggle('active', normalizedThemeMode === 'system')
    if (persist) {
      stateStore?.saveThemeMode?.(normalizedThemeMode)
    }
  }

  function bindSystemPreferenceListeners() {
    if (hasBoundSystemThemeListener) return
    hasBoundSystemThemeListener = true

    const themeQuery = getSystemThemeMediaQuery()
    themeMediaUnsubscriber = addMediaChangeListener(themeQuery, () => {
      if (currentThemeMode === 'system') {
        applyTheme('system', { persist: false })
      }
    })

    if (typeof window.matchMedia === 'function') {
      const accessibilityQueries = [
        window.matchMedia('(prefers-reduced-motion: reduce)'),
        window.matchMedia('(prefers-contrast: more)'),
        window.matchMedia('(forced-colors: active)')
      ]
      accessibilityMediaUnsubscribers = accessibilityQueries.map(mediaQuery =>
        addMediaChangeListener(mediaQuery, () => {
          applyAccessibilityPreferences()
        })
      )
    }
  }

  function clearSystemPreferenceListeners() {
    themeMediaUnsubscriber?.()
    themeMediaUnsubscriber = null
    for (const unsubscribe of accessibilityMediaUnsubscribers) {
      unsubscribe()
    }
    accessibilityMediaUnsubscribers = []
    hasBoundSystemThemeListener = false
  }

  function init() {
    clearSystemPreferenceListeners()
    bindSystemPreferenceListeners()
    const savedThemeMode = resolveThemeMode(stateStore?.loadThemeMode?.(defaultTheme) || defaultTheme)
    applyTheme(savedThemeMode, { persist: false })
    applyUISettings(loadStoredUISettings(), { persist: false })
    return { ...currentUISettings }
  }

  return {
    applyTheme,
    applyUISettings,
    applyUISettingsFromControls,
    closeUISettingsModal,
    getCurrentUISettings: () => ({ ...currentUISettings }),
    init,
    openUISettingsModal
  }
}
