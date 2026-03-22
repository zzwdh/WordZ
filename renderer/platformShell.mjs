export function getFullProbeMode() {
  try {
    const fromGlobal = String(window.__WORDZ_FULL_PROBE_MODE__ || '').trim().toLowerCase()
    if (fromGlobal === 'safe-style' || fromGlobal === 'delay-renderer-start') {
      return fromGlobal
    }
    const fromQuery = String(new URLSearchParams(window.location.search || '').get('fullProbe') || '').trim().toLowerCase()
    if (fromQuery === 'safe-style' || fromQuery === 'delay-renderer-start') {
      return fromQuery
    }
  } catch {
    // ignore probe parse failures
  }
  return ''
}

export function getUiStyleMode() {
  try {
    const mode = String(new URLSearchParams(window.location.search || '').get('uiStyle') || '').trim().toLowerCase()
    if (mode === 'compat' || mode === 'full') {
      return mode
    }
  } catch {
    // ignore ui style parse failures
  }
  return ''
}

export function getDiagnosticMode() {
  try {
    const mode = String(new URLSearchParams(window.location.search || '').get('diag') || '').trim().toLowerCase()
    if (mode === 'minimal' || mode === 'styles' || mode === 'renderer-no-style') {
      return mode
    }
  } catch {
    // ignore diagnostic mode parse failures
  }
  return 'full'
}

export function getWindowsBootMode() {
  return String(document.body?.dataset?.wordzWindowsBoot || '').trim().toLowerCase()
}

export function shouldUseWindowsStagedBoot(diagnosticMode = '', fullProbeMode = '') {
  const bootMode = getWindowsBootMode()
  return (bootMode === 'staged' || bootMode === 'safe-static') &&
    diagnosticMode === 'full' &&
    !fullProbeMode
}

export function shouldUseWindowsSafeStaticShell(diagnosticMode = '', fullProbeMode = '') {
  return getWindowsBootMode() === 'safe-static' &&
    diagnosticMode === 'full' &&
    !fullProbeMode
}

export function getPreBootStyleMode(diagnosticMode, uiStyleMode, useWindowsStagedBoot = false) {
  if (diagnosticMode === 'minimal' || diagnosticMode === 'renderer-no-style') {
    return ''
  }
  if (useWindowsStagedBoot) {
    return ''
  }
  if (uiStyleMode === 'compat' || uiStyleMode === 'full') {
    return uiStyleMode
  }
  return 'full'
}

export function getPostBootStyleMode(diagnosticMode, uiStyleMode) {
  if (diagnosticMode !== 'renderer-no-style') {
    return ''
  }
  return uiStyleMode === 'compat' || uiStyleMode === 'full'
    ? uiStyleMode
    : ''
}

export function shouldUpgradeWindowsToFormalShell({
  diagnosticMode = '',
  fullProbeMode = '',
  useWindowsStagedBoot = false
} = {}) {
  return false
}

export function resolveWindowsFormalStyleMode(uiStyleMode = '') {
  return uiStyleMode === 'compat' ? 'compat' : 'full'
}
