;(function bootstrapLoader() {
  const DIAGNOSTIC_MODES = new Set(['full', 'styles', 'renderer-no-style', 'minimal'])
  const FULL_PROBE_MODES = new Set(['safe-style', 'delay-renderer-start'])

  function normalizeDiagnosticMode(rawMode) {
    const normalizedMode = String(rawMode || '').trim().toLowerCase()
    if (DIAGNOSTIC_MODES.has(normalizedMode)) return normalizedMode
    return 'full'
  }

  function normalizeFullProbeMode(rawMode) {
    const normalizedMode = String(rawMode || '').trim().toLowerCase()
    if (FULL_PROBE_MODES.has(normalizedMode)) return normalizedMode
    return ''
  }

  const searchParams = new URLSearchParams(window.location.search || '')
  const mode = normalizeDiagnosticMode(searchParams.get('diag'))
  const fullProbeMode = mode === 'full'
    ? normalizeFullProbeMode(searchParams.get('fullProbe'))
    : ''
  const loaderState = {
    mode,
    fullProbeMode,
    status: 'booting',
    startedAt: new Date().toISOString(),
    completedAt: '',
    errorMessage: ''
  }
  window.__WORDZ_STARTUP_LOADER_STATE__ = loaderState
  window.__WORDZ_FULL_PROBE_MODE__ = fullProbeMode

  function writeLoaderLog(scope, details) {
    try {
      if (details && typeof details === 'object') {
        console.warn(`[startup.loader] ${scope}`, JSON.stringify(details))
        return
      }
      console.warn(`[startup.loader] ${scope}`)
    } catch {
      // ignore logging failures
    }
  }

  function markLoaderCompleted() {
    loaderState.status = 'completed'
    loaderState.completedAt = new Date().toISOString()
    writeLoaderLog('completed', {
      mode,
      fullProbeMode
    })
  }

  function markLoaderFailed(error) {
    loaderState.status = 'failed'
    loaderState.completedAt = new Date().toISOString()
    loaderState.errorMessage = error instanceof Error ? error.message : String(error || '')
    console.error('[startup.loader] failed', {
      mode,
      fullProbeMode,
      message: loaderState.errorMessage
    })
  }

  function applyFullProbeConfig() {
    if (fullProbeMode !== 'safe-style') return
    document.documentElement.classList.add('wordz-probe-safe-style')
    if (document.body) {
      document.body.classList.add('wordz-probe-safe-style')
    }
    if (document.getElementById('wordzSafeStyleProbeOverrides')) return
    const style = document.createElement('style')
    style.id = 'wordzSafeStyleProbeOverrides'
    style.textContent = `
html.wordz-probe-safe-style,
html.wordz-probe-safe-style body {
  background: #f4efe7 !important;
  color: #182131 !important;
}
html.wordz-probe-safe-style body::before,
html.wordz-probe-safe-style body::after {
  content: none !important;
  display: none !important;
}
html.wordz-probe-safe-style *,
html.wordz-probe-safe-style *::before,
html.wordz-probe-safe-style *::after {
  animation: none !important;
  transition: none !important;
  transform: none !important;
  filter: none !important;
  backdrop-filter: none !important;
  box-shadow: none !important;
}
html.wordz-probe-safe-style .app-shell,
html.wordz-probe-safe-style .topbar,
html.wordz-probe-safe-style .welcome-panel,
html.wordz-probe-safe-style .drop-import-panel,
html.wordz-probe-safe-style [id$="Modal"],
html.wordz-probe-safe-style .task-center-panel,
html.wordz-probe-safe-style .command-palette,
html.wordz-probe-safe-style .toast-viewport,
html.wordz-probe-safe-style .table-shell {
  background: #fffaf3 !important;
  background-image: none !important;
  border-color: rgba(88, 75, 55, 0.18) !important;
}
html.wordz-probe-safe-style .topbar,
html.wordz-probe-safe-style .table-toolbar,
html.wordz-probe-safe-style .stats-summary,
html.wordz-probe-safe-style thead th,
html.wordz-probe-safe-style .kwic-meta,
html.wordz-probe-safe-style .compare-meta {
  position: static !important;
}
html.wordz-probe-safe-style .welcome-overlay,
html.wordz-probe-safe-style .drop-import-overlay,
html.wordz-probe-safe-style .task-center-panel,
html.wordz-probe-safe-style [id$="Modal"],
html.wordz-probe-safe-style .toast-viewport {
  position: static !important;
  inset: auto !important;
}
`
    document.head.appendChild(style)
    writeLoaderLog('full-probe.safe-style-applied', {
      mode,
      fullProbeMode
    })
  }

  function appendDiagnosticModeBadge() {
    if (mode === 'full') return
    const createBadge = () => {
      if (!document.body || document.getElementById('wordzStartupModeBadge')) return
      const badge = document.createElement('div')
      badge.id = 'wordzStartupModeBadge'
      badge.setAttribute('aria-live', 'polite')
      badge.style.position = 'fixed'
      badge.style.right = '12px'
      badge.style.bottom = '12px'
      badge.style.zIndex = '2147483646'
      badge.style.padding = '6px 10px'
      badge.style.borderRadius = '999px'
      badge.style.fontSize = '12px'
      badge.style.fontFamily = 'Consolas, Menlo, Monaco, "Courier New", monospace'
      badge.style.background = '#182131'
      badge.style.color = '#f7f5f1'
      badge.style.border = '1px solid rgba(247, 245, 241, 0.28)'
      badge.style.boxShadow = '0 6px 18px rgba(0, 0, 0, 0.26)'
      badge.style.pointerEvents = 'none'
      badge.textContent = `WordZ Diagnostic Mode: ${mode}`
      document.body.appendChild(badge)
    }
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', createBadge, { once: true })
      return
    }
    createBadge()
  }

  function appendMinimalModePanel() {
    if (mode !== 'minimal') return

    const navigateToMode = (nextMode) => {
      const targetUrl = new URL(window.location.href)
      if (nextMode === 'full') {
        targetUrl.searchParams.delete('diag')
      } else {
        targetUrl.searchParams.set('diag', nextMode)
      }
      window.location.href = targetUrl.toString()
    }

    const createPanel = () => {
      if (!document.body || document.getElementById('wordzMinimalModePanel')) return

      const panel = document.createElement('div')
      panel.id = 'wordzMinimalModePanel'
      panel.style.position = 'fixed'
      panel.style.left = '16px'
      panel.style.bottom = '16px'
      panel.style.zIndex = '2147483646'
      panel.style.maxWidth = '420px'
      panel.style.padding = '14px 16px'
      panel.style.borderRadius = '12px'
      panel.style.background = 'rgba(24, 33, 49, 0.94)'
      panel.style.color = '#f7f5f1'
      panel.style.border = '1px solid rgba(247, 245, 241, 0.22)'
      panel.style.boxShadow = '0 10px 24px rgba(0, 0, 0, 0.28)'
      panel.style.fontFamily = '-apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif'
      panel.style.fontSize = '13px'
      panel.style.lineHeight = '1.55'

      const title = document.createElement('div')
      title.textContent = 'WordZ 启动兼容模式'
      title.style.fontWeight = '700'
      title.style.marginBottom = '6px'

      const desc = document.createElement('div')
      desc.textContent = '已进入最小模式。你可以尝试“兼容界面（无样式）”继续使用核心功能。'
      desc.style.marginBottom = '10px'

      const actions = document.createElement('div')
      actions.style.display = 'flex'
      actions.style.flexWrap = 'wrap'
      actions.style.gap = '8px'

      const toNoStyleButton = document.createElement('button')
      toNoStyleButton.type = 'button'
      toNoStyleButton.textContent = '打开兼容界面'
      toNoStyleButton.style.cursor = 'pointer'
      toNoStyleButton.style.border = '1px solid rgba(247, 245, 241, 0.28)'
      toNoStyleButton.style.background = '#b4874f'
      toNoStyleButton.style.color = '#182131'
      toNoStyleButton.style.borderRadius = '8px'
      toNoStyleButton.style.padding = '6px 10px'
      toNoStyleButton.addEventListener('click', () => {
        navigateToMode('renderer-no-style')
      })

      const retryFullButton = document.createElement('button')
      retryFullButton.type = 'button'
      retryFullButton.textContent = '重试完整模式'
      retryFullButton.style.cursor = 'pointer'
      retryFullButton.style.border = '1px solid rgba(247, 245, 241, 0.28)'
      retryFullButton.style.background = 'transparent'
      retryFullButton.style.color = '#f7f5f1'
      retryFullButton.style.borderRadius = '8px'
      retryFullButton.style.padding = '6px 10px'
      retryFullButton.addEventListener('click', () => {
        navigateToMode('full')
      })

      actions.append(toNoStyleButton, retryFullButton)
      panel.append(title, desc, actions)
      document.body.appendChild(panel)
    }

    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', createPanel, { once: true })
      return
    }
    createPanel()
  }

  function loadStylesheet() {
    return new Promise((resolve, reject) => {
      const existingSheet = document.querySelector('link[data-wordz-loader="styles"]')
      if (existingSheet) {
        resolve()
        return
      }

      const sheet = document.createElement('link')
      sheet.rel = 'stylesheet'
      sheet.href = './styles.css'
      sheet.dataset.wordzLoader = 'styles'
      sheet.onload = () => {
        writeLoaderLog('styles.loaded', { mode, fullProbeMode })
        resolve()
      }
      sheet.onerror = () => {
        reject(new Error('styles.css 加载失败'))
      }
      document.head.appendChild(sheet)
      writeLoaderLog('styles.loading', { mode, fullProbeMode })
    })
  }

  function loadRendererScript() {
    return new Promise((resolve, reject) => {
      const existingScript = document.querySelector('script[data-wordz-loader="renderer"]')
      if (existingScript) {
        resolve()
        return
      }

      const script = document.createElement('script')
      script.src = './renderer.js'
      script.async = false
      script.dataset.wordzLoader = 'renderer'
      script.onload = () => {
        writeLoaderLog('renderer.loaded', { mode, fullProbeMode })
        resolve()
      }
      script.onerror = () => {
        reject(new Error('renderer.js 加载失败'))
      }
      document.body.appendChild(script)
      writeLoaderLog('renderer.loading', { mode, fullProbeMode })
    })
  }

  async function runLoader() {
    writeLoaderLog('started', { mode, fullProbeMode })
    appendDiagnosticModeBadge()
    appendMinimalModePanel()
    applyFullProbeConfig()

    if (mode === 'minimal') {
      markLoaderCompleted()
      return
    }

    if (mode !== 'renderer-no-style') {
      await loadStylesheet()
    }

    if (mode !== 'styles') {
      await loadRendererScript()
    }

    markLoaderCompleted()
  }

  runLoader().catch(error => {
    markLoaderFailed(error)
  })
})()
