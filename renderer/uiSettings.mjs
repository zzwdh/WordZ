export function createUISettingsController({
  dom,
  defaultTheme,
  storageKey,
  defaultSettings,
  fontFamilies,
  clampNumber
}) {
  let currentUISettings = { ...defaultSettings }

  function normalizeUISettings(settings = {}) {
    const fontFamily = fontFamilies[settings.fontFamily] ? settings.fontFamily : defaultSettings.fontFamily
    return {
      zoom: clampNumber(settings.zoom, 80, 135, defaultSettings.zoom),
      fontScale: clampNumber(settings.fontScale, 85, 140, defaultSettings.fontScale),
      fontFamily
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
    updateUISettingLabels(settings)
  }

  function setAppZoom(zoomPercent) {
    const zoomFactor = zoomPercent / 100
    if (window.electronAPI?.setZoomFactor) {
      window.electronAPI.setZoomFactor(zoomFactor)
      return
    }
    document.body.style.zoom = String(zoomFactor)
  }

  function persistUISettings(settings) {
    localStorage.setItem(storageKey, JSON.stringify(settings))
  }

  function applyUISettings(settings, options = {}) {
    const { persist = true, syncControls = true } = options
    const normalizedSettings = normalizeUISettings(settings)
    currentUISettings = normalizedSettings
    document.documentElement.style.setProperty('--font-scale', String(normalizedSettings.fontScale / 100))
    document.documentElement.style.setProperty('--app-font-family', fontFamilies[normalizedSettings.fontFamily])
    setAppZoom(normalizedSettings.zoom)
    if (syncControls) syncUISettingControls(normalizedSettings)
    if (persist) persistUISettings(normalizedSettings)
  }

  function loadStoredUISettings() {
    try {
      const rawValue = localStorage.getItem(storageKey)
      if (!rawValue) return { ...defaultSettings }
      return normalizeUISettings(JSON.parse(rawValue))
    } catch (error) {
      return { ...defaultSettings }
    }
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
      fontFamily: dom.uiFontFamilySelect.value
    })
  }

  function applyTheme(theme) {
    const normalizedTheme = theme === 'dark' ? 'dark' : defaultTheme
    if (normalizedTheme === 'dark') {
      document.body.setAttribute('data-theme', 'dark')
    } else {
      document.body.removeAttribute('data-theme')
    }
    dom.themeModeValue.textContent = normalizedTheme === 'dark' ? '深色模式' : '浅色模式'
    dom.lightThemeButton.classList.toggle('active', normalizedTheme === 'light')
    dom.darkThemeButton.classList.toggle('active', normalizedTheme === 'dark')
    localStorage.setItem('corpus-theme', normalizedTheme)
  }

  function init() {
    const savedTheme = localStorage.getItem('corpus-theme') || defaultTheme
    applyTheme(savedTheme)
    applyUISettings(loadStoredUISettings(), { persist: false })
  }

  return {
    applyTheme,
    applyUISettings,
    applyUISettingsFromControls,
    closeUISettingsModal,
    init,
    openUISettingsModal
  }
}
