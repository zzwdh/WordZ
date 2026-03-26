const THEME_MODE_SET = new Set(['light', 'dark', 'system'])
const THEME_ACCENT_SET = new Set(['system', 'ocean', 'forest', 'amber', 'rose', 'slate'])
const THEME_ACCENT_LABELS = Object.freeze({
  system: '跟随系统',
  ocean: '海蓝',
  forest: '森林',
  amber: '琥珀',
  rose: '玫瑰',
  slate: '石墨'
})
const THEME_ACCENT_PRESETS = Object.freeze({
  ocean: '#2c6288',
  forest: '#2f6f4e',
  amber: '#b06a11',
  rose: '#b55371',
  slate: '#5d6672'
})
const DEFAULT_SYSTEM_ACCENT_COLOR = '#2c6288'
const DEFAULT_AUTO_UPDATE_PREFERENCES = Object.freeze({
  enabled: true,
  checkOnLaunch: true,
  autoDownload: true
})

function clampChannel(value) {
  return Math.min(Math.max(Math.round(Number(value) || 0), 0), 255)
}

function parseHexColor(hexValue) {
  const normalizedHex = String(hexValue || '').trim().replace(/^#/, '')
  if (!/^[0-9a-f]{6}$/i.test(normalizedHex)) return null
  return {
    r: Number.parseInt(normalizedHex.slice(0, 2), 16),
    g: Number.parseInt(normalizedHex.slice(2, 4), 16),
    b: Number.parseInt(normalizedHex.slice(4, 6), 16)
  }
}

function rgbToHex(color) {
  if (!color) return DEFAULT_SYSTEM_ACCENT_COLOR
  return `#${[color.r, color.g, color.b]
    .map(channel => clampChannel(channel).toString(16).padStart(2, '0'))
    .join('')}`
}

function rgbaString(color, alpha = 1) {
  if (!color) return `rgba(44, 98, 136, ${alpha})`
  return `rgba(${clampChannel(color.r)}, ${clampChannel(color.g)}, ${clampChannel(color.b)}, ${alpha})`
}

function mixColors(colorA, colorB, ratio = 0.5) {
  const normalizedRatio = Math.min(Math.max(Number(ratio) || 0, 0), 1)
  return {
    r: colorA.r + (colorB.r - colorA.r) * normalizedRatio,
    g: colorA.g + (colorB.g - colorA.g) * normalizedRatio,
    b: colorA.b + (colorB.b - colorA.b) * normalizedRatio
  }
}

function normalizeAutoUpdatePreferences(preferences = {}) {
  return {
    enabled: preferences.enabled !== false,
    checkOnLaunch: preferences.checkOnLaunch !== false,
    autoDownload: preferences.autoDownload !== false
  }
}

export function createUISettingsController({
  dom,
  electronAPI,
  stateStore,
  defaultTheme,
  defaultSettings,
  fontFamilies,
  clampNumber
}) {
  let currentUISettings = { ...defaultSettings }
  let currentThemeMode = defaultTheme === 'dark' ? 'dark' : 'light'
  let currentAutoUpdatePreferences = { ...DEFAULT_AUTO_UPDATE_PREFERENCES }
  let currentAutoUpdateState = null
  let currentSystemAppearance = {
    accentColor: '',
    supportsAccentColor: false
  }
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

  function resolveThemeAccent(value) {
    const normalizedValue = String(value || '').trim().toLowerCase()
    return THEME_ACCENT_SET.has(normalizedValue) ? normalizedValue : defaultSettings.themeAccent || 'system'
  }

  function getAccentBaseColor(accentMode) {
    if (accentMode === 'system') {
      return currentSystemAppearance.accentColor || DEFAULT_SYSTEM_ACCENT_COLOR
    }
    return THEME_ACCENT_PRESETS[accentMode] || DEFAULT_SYSTEM_ACCENT_COLOR
  }

  function buildAccentPalette(accentMode, effectiveTheme) {
    const baseColor = parseHexColor(getAccentBaseColor(accentMode)) || parseHexColor(DEFAULT_SYSTEM_ACCENT_COLOR)
    if (effectiveTheme === 'dark') {
      const primary = mixColors(baseColor, { r: 255, g: 255, b: 255 }, 0.12)
      const primaryStrong = mixColors(baseColor, { r: 0, g: 0, b: 0 }, 0.16)
      return {
        primary: rgbToHex(primary),
        primaryStrong: rgbToHex(primaryStrong),
        primarySoft: rgbaString(baseColor, 0.2),
        primarySoftBorder: rgbaString(baseColor, 0.34),
        primaryText: rgbToHex(mixColors(baseColor, { r: 255, g: 255, b: 255 }, 0.76)),
        buttonShadow: `0 14px 30px ${rgbaString(baseColor, 0.24)}`,
        activeRow: rgbaString(baseColor, 0.14)
      }
    }
    return {
      primary: rgbToHex(baseColor),
      primaryStrong: rgbToHex(mixColors(baseColor, { r: 0, g: 0, b: 0 }, 0.18)),
      primarySoft: rgbaString(baseColor, 0.14),
      primarySoftBorder: rgbaString(baseColor, 0.28),
      primaryText: rgbToHex(mixColors(baseColor, { r: 0, g: 0, b: 0 }, 0.32)),
      buttonShadow: `0 12px 26px ${rgbaString(baseColor, 0.22)}`,
      activeRow: rgbaString(baseColor, 0.12)
    }
  }

  function applyAccentPalette(accentMode = currentUISettings.themeAccent || 'system') {
    const effectiveTheme = resolveEffectiveTheme(currentThemeMode)
    const palette = buildAccentPalette(accentMode, effectiveTheme)
    document.documentElement.style.setProperty('--primary', palette.primary)
    document.documentElement.style.setProperty('--primary-strong', palette.primaryStrong)
    document.documentElement.style.setProperty('--primary-soft', palette.primarySoft)
    document.documentElement.style.setProperty('--primary-soft-border', palette.primarySoftBorder)
    document.documentElement.style.setProperty('--primary-text', palette.primaryText)
    document.documentElement.style.setProperty('--button-shadow', palette.buttonShadow)
    document.documentElement.style.setProperty('--active-row', palette.activeRow)
    if (document.body) {
      document.body.setAttribute('data-theme-accent', accentMode)
    }
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
      themeAccent: resolveThemeAccent(settings.themeAccent),
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

  function updateThemeLabels() {
    const effectiveTheme = resolveEffectiveTheme(currentThemeMode)
    if (dom.themeModeValue) {
      dom.themeModeValue.textContent = currentThemeMode === 'system'
        ? `跟随系统（当前${effectiveTheme === 'dark' ? '深色' : '浅色'}）`
        : (effectiveTheme === 'dark' ? '深色模式' : '浅色模式')
    }
    dom.lightThemeButton?.classList.toggle('active', currentThemeMode === 'light')
    dom.darkThemeButton?.classList.toggle('active', currentThemeMode === 'dark')
    dom.systemThemeButton?.classList.toggle('active', currentThemeMode === 'system')
  }

  function updateAccentSettingLabels(settings = currentUISettings) {
    const accentMode = resolveThemeAccent(settings.themeAccent)
    const accentBaseColor = getAccentBaseColor(accentMode).toUpperCase()
    if (dom.themeAccentValue) {
      dom.themeAccentValue.textContent = accentMode === 'system'
        ? `跟随系统${currentSystemAppearance.supportsAccentColor ? ` · ${accentBaseColor}` : ''}`
        : THEME_ACCENT_LABELS[accentMode]
    }
    if (dom.themeAccentStatusText) {
      dom.themeAccentStatusText.textContent = accentMode === 'system'
        ? (currentSystemAppearance.supportsAccentColor
            ? `当前会跟随系统强调色 ${accentBaseColor}。如果你在系统设置里更改强调色，WordZ 会在重新聚焦时自动同步。`
            : '当前没有读取到系统强调色，WordZ 会先使用默认海蓝主题。')
        : `${THEME_ACCENT_LABELS[accentMode]} 会应用到主要按钮、标签和高亮状态。你也可以随时切回“跟随系统”。`
    }
  }

  function updateUISettingLabels(settings) {
    dom.uiZoomValue.textContent = `${settings.zoom}%`
    dom.uiFontSizeValue.textContent = `${settings.fontScale}%`
    updateAccentSettingLabels(settings)
  }

  function updateAutoUpdateStatus(updateState = currentAutoUpdateState) {
    const preferences = currentAutoUpdatePreferences
    if (dom.autoUpdatePreferenceValue) {
      if (preferences.enabled === false) {
        dom.autoUpdatePreferenceValue.textContent = '已关闭'
      } else if (preferences.checkOnLaunch && preferences.autoDownload) {
        dom.autoUpdatePreferenceValue.textContent = '自动检查 + 自动下载'
      } else if (preferences.checkOnLaunch) {
        dom.autoUpdatePreferenceValue.textContent = '自动检查'
      } else {
        dom.autoUpdatePreferenceValue.textContent = '手动检查'
      }
    }

    if (dom.autoUpdatePreferenceStatusText) {
      const providerLabel = String(updateState?.providerLabel || '').trim()
      const providerTarget = String(updateState?.providerTarget || '').trim()
      const targetText = providerTarget ? ` · ${providerTarget}` : ''
      const statusMessage = String(updateState?.message || '').trim()
      const availabilityMessage = preferences.enabled === false
        ? '自动更新已在设置中关闭。你仍然可以手动点击顶部“更新”按钮检查版本。'
        : (statusMessage || '会按照你当前的设置决定是否在启动时检查并自动下载更新。')
      dom.autoUpdatePreferenceStatusText.textContent = providerLabel
        ? `${providerLabel}${targetText}：${availabilityMessage}`
        : availabilityMessage
    }
  }

  function syncAutoUpdateControls(preferences = currentAutoUpdatePreferences) {
    if (dom.autoUpdateEnabledToggle) {
      dom.autoUpdateEnabledToggle.checked = preferences.enabled !== false
    }
    if (dom.autoUpdateCheckOnLaunchToggle) {
      dom.autoUpdateCheckOnLaunchToggle.checked = preferences.checkOnLaunch !== false
      dom.autoUpdateCheckOnLaunchToggle.disabled = preferences.enabled === false
    }
    if (dom.autoUpdateAutoDownloadToggle) {
      dom.autoUpdateAutoDownloadToggle.checked = preferences.autoDownload !== false
      dom.autoUpdateAutoDownloadToggle.disabled = preferences.enabled === false
    }
    updateAutoUpdateStatus(currentAutoUpdateState)
  }

  function syncUISettingControls(settings) {
    dom.uiZoomRange.value = String(settings.zoom)
    dom.uiFontSizeRange.value = String(settings.fontScale)
    dom.uiFontFamilySelect.value = settings.fontFamily
    if (dom.uiAccentSelect) {
      dom.uiAccentSelect.value = settings.themeAccent
    }
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
    syncAutoUpdateControls()
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
    applyAccentPalette(normalizedSettings.themeAccent)
    if (syncControls) syncUISettingControls(normalizedSettings)
    if (persist) persistUISettings(normalizedSettings)
  }

  function loadStoredUISettings() {
    return normalizeUISettings(stateStore?.loadUiSettings?.(defaultSettings) || defaultSettings)
  }

  async function refreshSystemAppearanceState({ force = false } = {}) {
    if (!electronAPI?.getSystemAppearanceState) return currentSystemAppearance
    const result = await electronAPI.getSystemAppearanceState()
    if (!result?.success || !result.appearance) return currentSystemAppearance

    const normalizedAppearance = {
      accentColor: String(result.appearance.accentColor || '').trim().toLowerCase(),
      supportsAccentColor: Boolean(result.appearance.supportsAccentColor)
    }
    const previousAccentColor = currentSystemAppearance.accentColor
    currentSystemAppearance = normalizedAppearance

    if (force || previousAccentColor !== normalizedAppearance.accentColor || currentUISettings.themeAccent === 'system') {
      updateAccentSettingLabels(currentUISettings)
      if (currentUISettings.themeAccent === 'system') {
        applyAccentPalette('system')
      }
    }
    return currentSystemAppearance
  }

  async function refreshAutoUpdatePreferences({ silent = false } = {}) {
    if (!electronAPI?.getAutoUpdateState) {
      if (!silent) updateAutoUpdateStatus(null)
      return { success: false, message: '自动更新状态不可用。' }
    }
    const result = await electronAPI.getAutoUpdateState()
    if (result?.success) {
      currentAutoUpdateState = result.updateState || null
      currentAutoUpdatePreferences = normalizeAutoUpdatePreferences(result.updateState?.preferences || DEFAULT_AUTO_UPDATE_PREFERENCES)
      syncAutoUpdateControls(currentAutoUpdatePreferences)
      return {
        success: true,
        updateState: currentAutoUpdateState,
        preferences: { ...currentAutoUpdatePreferences }
      }
    }
    if (!silent) updateAutoUpdateStatus(null)
    return {
      success: false,
      message: result?.message || '自动更新状态不可用。'
    }
  }

  async function applyAutoUpdatePreferencesFromControls() {
    const nextPreferences = normalizeAutoUpdatePreferences({
      enabled: dom.autoUpdateEnabledToggle?.checked !== false,
      checkOnLaunch: dom.autoUpdateCheckOnLaunchToggle?.checked !== false,
      autoDownload: dom.autoUpdateAutoDownloadToggle?.checked !== false
    })

    if (!electronAPI?.setAutoUpdatePreferences) {
      currentAutoUpdatePreferences = nextPreferences
      syncAutoUpdateControls(nextPreferences)
      return {
        success: false,
        message: '自动更新设置当前不可用。'
      }
    }

    const result = await electronAPI.setAutoUpdatePreferences(nextPreferences)
    if (result?.success) {
      currentAutoUpdatePreferences = normalizeAutoUpdatePreferences(result.preferences || nextPreferences)
      currentAutoUpdateState = result.updateState || currentAutoUpdateState
      syncAutoUpdateControls(currentAutoUpdatePreferences)
      return {
        success: true,
        updateState: currentAutoUpdateState,
        preferences: { ...currentAutoUpdatePreferences }
      }
    }

    syncAutoUpdateControls(currentAutoUpdatePreferences)
    return {
      success: false,
      message: result?.message || '自动更新设置保存失败。'
    }
  }

  function openUISettingsModal() {
    dom.uiSettingsModal.classList.remove('hidden')
    void refreshSystemAppearanceState({ force: true })
    void refreshAutoUpdatePreferences({ silent: true })
  }

  function closeUISettingsModal() {
    dom.uiSettingsModal.classList.add('hidden')
  }

  function applyUISettingsFromControls() {
    applyUISettings({
      zoom: dom.uiZoomRange.value,
      fontScale: dom.uiFontSizeRange.value,
      fontFamily: dom.uiFontFamilySelect.value,
      themeAccent: dom.uiAccentSelect?.value,
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
    updateThemeLabels()
    applyAccentPalette(currentUISettings.themeAccent)
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
    syncAutoUpdateControls()
    void refreshSystemAppearanceState({ force: true })
    void refreshAutoUpdatePreferences({ silent: true })
    return { ...currentUISettings }
  }

  return {
    applyTheme,
    applyUISettings,
    applyUISettingsFromControls,
    applyAutoUpdatePreferencesFromControls,
    closeUISettingsModal,
    getCurrentUISettings: () => ({ ...currentUISettings }),
    getCurrentAutoUpdatePreferences: () => ({ ...currentAutoUpdatePreferences }),
    init,
    openUISettingsModal,
    refreshAutoUpdatePreferences,
    refreshSystemAppearanceState
  }
}
