import { buildWindowsSafeShellMarkup } from './windowsSafeShell.mjs'
import {
  getDiagnosticMode,
  getFullProbeMode,
  getPostBootStyleMode,
  getPreBootStyleMode,
  getUiStyleMode,
  resolveWindowsFormalStyleMode,
  shouldUpgradeWindowsToFormalShell,
  shouldUseWindowsSafeStaticShell,
  shouldUseWindowsStagedBoot
} from './platformShell.mjs'

function writeRendererBootLog(scope, details = null) {
  try {
    if (details && typeof details === 'object') {
      console.warn(`[startup.renderer] ${scope}`, JSON.stringify(details))
      return
    }
    console.warn(`[startup.renderer] ${scope}`)
  } catch {
    // ignore startup renderer log failures
  }
}

function ensureRuntimeStylesheet(styleMode = '') {
  const normalizedStyleMode = String(styleMode || '').trim().toLowerCase()
  if (normalizedStyleMode !== 'compat' && normalizedStyleMode !== 'full') {
    return Promise.resolve(false)
  }

  const stylesheetId = `wordzRuntimeStylesheet:${normalizedStyleMode}`
  const existingSheet = document.getElementById(stylesheetId)
  if (existingSheet) {
    return Promise.resolve(true)
  }

  const href = normalizedStyleMode === 'compat' ? './styles.compat.css' : './styles.css'
  writeRendererBootLog('styles.load.start', {
    styleMode: normalizedStyleMode,
    href
  })

  return new Promise((resolve, reject) => {
    const link = document.createElement('link')
    link.id = stylesheetId
    link.rel = 'stylesheet'
    link.href = href
    link.addEventListener('load', () => {
      writeRendererBootLog('styles.load.done', {
        styleMode: normalizedStyleMode,
        href
      })
      resolve(true)
    }, { once: true })
    link.addEventListener('error', () => {
      const error = new Error(`${href} load failed`)
      writeRendererBootLog('styles.load.failed', {
        styleMode: normalizedStyleMode,
        href
      })
      reject(error)
    }, { once: true })
    document.head.appendChild(link)
  })
}

function applyWindowsFormalSafetyOverrides() {
  if (document.getElementById('wordzWindowsFormalSafetyOverrides')) {
    return
  }
  const style = document.createElement('style')
  style.id = 'wordzWindowsFormalSafetyOverrides'
  style.textContent = `
html.wordz-windows-formal-upgraded body::before,
html.wordz-windows-formal-upgraded body::after {
  content: none !important;
  display: none !important;
}
html.wordz-windows-formal-upgraded .topbar,
html.wordz-windows-formal-upgraded .panel,
html.wordz-windows-formal-upgraded .tab-shell,
html.wordz-windows-formal-upgraded .task-center,
html.wordz-windows-formal-upgraded .welcome-panel,
html.wordz-windows-formal-upgraded .drop-import-panel,
html.wordz-windows-formal-upgraded .modal-panel,
html.wordz-windows-formal-upgraded .toolbar-menu-panel,
html.wordz-windows-formal-upgraded .table-render-status {
  backdrop-filter: none !important;
}
html.wordz-windows-formal-upgraded .sidebar,
html.wordz-windows-formal-upgraded .section-sticky-stack,
html.wordz-windows-formal-upgraded .sticky-toolbar,
html.wordz-windows-formal-upgraded .sticky-toolbar-top,
html.wordz-windows-formal-upgraded .sticky-toolbar-sub,
html.wordz-windows-formal-upgraded .sticky-meta,
html.wordz-windows-formal-upgraded .system-status,
html.wordz-windows-formal-upgraded thead th,
html.wordz-windows-formal-upgraded .table-render-status {
  position: static !important;
  top: auto !important;
}
html.wordz-windows-formal-upgraded .button:hover,
html.wordz-windows-formal-upgraded .tab-button:hover,
html.wordz-windows-formal-upgraded .panel-toggle:hover,
html.wordz-windows-formal-upgraded .recent-open-item:hover,
html.wordz-windows-formal-upgraded .overview-card:hover,
html.wordz-windows-formal-upgraded .word-cloud-item:hover {
  transform: none !important;
}
`
  document.head.appendChild(style)
}

function scheduleWindowsFormalUpgrade({ diagnosticMode, fullProbeMode, uiStyleMode, useWindowsStagedBoot = false }) {
  if (!shouldUpgradeWindowsToFormalShell({
    diagnosticMode,
    fullProbeMode,
    useWindowsStagedBoot
  })) {
    return
  }
  if (document.body?.dataset?.wordzWindowsFormalUpgradeBound === '1') {
    return
  }
  document.body.dataset.wordzWindowsFormalUpgradeBound = '1'
  const targetStyleMode = resolveWindowsFormalStyleMode(uiStyleMode)
  let started = false

  const startUpgrade = () => {
    if (started) return
    started = true
    writeRendererBootLog('windows-formal-upgrade.start', {
      styleMode: targetStyleMode
    })
    window.setTimeout(() => {
      void ensureRuntimeStylesheet(targetStyleMode)
        .then(() => {
          document.documentElement.classList.add('wordz-windows-formal-upgraded')
          document.body?.classList?.add('wordz-windows-formal-upgraded')
          document.body.dataset.wordzWindowsVisualMode = targetStyleMode
          applyWindowsFormalSafetyOverrides()
          writeRendererBootLog('windows-formal-upgrade.done', {
            styleMode: targetStyleMode
          })
        })
        .catch(error => {
          writeRendererBootLog('windows-formal-upgrade.failed', {
            styleMode: targetStyleMode,
            message: error instanceof Error ? error.message : String(error || '')
          })
        })
    }, 1200)
  }

  window.addEventListener('wordz:renderer-ready', startUpgrade, { once: true })
}

function showBootstrapError(message) {
  const existingNotice = document.getElementById('bootstrapErrorNotice')
  if (existingNotice) return

  const notice = document.createElement('div')
  notice.id = 'bootstrapErrorNotice'
  notice.style.position = 'fixed'
  notice.style.inset = '20px'
  notice.style.zIndex = '2000'
  notice.style.display = 'grid'
  notice.style.placeItems = 'center'
  notice.style.background = 'rgba(15, 23, 42, 0.38)'
  notice.style.backdropFilter = 'blur(12px)'

  const panel = document.createElement('div')
  panel.style.width = 'min(480px, 100%)'
  panel.style.padding = '20px'
  panel.style.borderRadius = '20px'
  panel.style.background = 'rgba(255, 255, 255, 0.96)'
  panel.style.color = '#102033'
  panel.style.border = '1px solid rgba(15, 23, 42, 0.08)'
  panel.style.boxShadow = '0 24px 80px rgba(15, 23, 42, 0.22)'

  const title = document.createElement('div')
  title.textContent = '前端初始化失败'
  title.style.fontSize = '18px'
  title.style.fontWeight = '700'
  title.style.marginBottom = '10px'

  const text = document.createElement('div')
  text.textContent = message
  text.style.fontSize = '14px'
  text.style.lineHeight = '1.7'

  panel.append(title, text)
  notice.append(panel)

  if (document.body) {
    document.body.append(notice)
    return
  }

  const mountNotice = () => {
    if (!document.body) return
    if (document.getElementById('bootstrapErrorNotice')) return
    document.body.append(notice)
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', mountNotice, { once: true })
    return
  }
  mountNotice()
}

function reportBootstrapFailure(error, fallbackMessage = '前端初始化失败，请重启应用后重试。') {
  console.error('[renderer.bootstrap]', error)
  showBootstrapError(fallbackMessage)
}

function applySafeStyleProbeOverrides(fullProbeMode = '') {
  if (fullProbeMode !== 'safe-style') return
  document.documentElement.classList.add('wordz-probe-safe-style')
  document.body?.classList?.add('wordz-probe-safe-style')
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
}

function extractRendererShellMarkup(htmlText = '') {
  const normalizedHtmlText = String(htmlText || '')
  if (!normalizedHtmlText) {
    throw new Error('主界面模板为空')
  }

  const bodyStartIndex = normalizedHtmlText.indexOf('<body>')
  if (bodyStartIndex < 0) {
    throw new Error('主界面模板缺少 <body> 标记')
  }

  const scriptTagIndex = normalizedHtmlText.lastIndexOf('<script src="./renderer.js"></script>')
  const bodyEndIndex = scriptTagIndex >= 0
    ? scriptTagIndex
    : normalizedHtmlText.lastIndexOf('</body>')
  if (bodyEndIndex <= bodyStartIndex) {
    throw new Error('主界面模板提取失败')
  }

  const markup = normalizedHtmlText
    .slice(bodyStartIndex + '<body>'.length, bodyEndIndex)
    .trim()
  if (!markup) {
    throw new Error('主界面模板正文为空')
  }
  return markup
}

async function loadRendererShellMarkupFromBridge() {
  if (!window.electronAPI?.getRendererShellMarkup) {
    return {
      success: false,
      message: 'bridge unavailable'
    }
  }
  return window.electronAPI.getRendererShellMarkup()
}

async function loadRendererShellMarkupFromFetch() {
  const response = await fetch('./index.html', {
    cache: 'no-store'
  })
  if (!response.ok) {
    throw new Error(`index.html fetch failed: ${response.status}`)
  }
  const htmlText = await response.text()
  return {
    success: true,
    markup: extractRendererShellMarkup(htmlText)
  }
}

async function readRendererShellMarkup() {
  const bridgeResult = await loadRendererShellMarkupFromBridge().catch(error => ({
    success: false,
    message: error instanceof Error ? error.message : String(error || '')
  }))
  if (bridgeResult?.success && typeof bridgeResult.markup === 'string' && bridgeResult.markup.trim()) {
    return {
      markup: bridgeResult.markup,
      source: 'ipc'
    }
  }

  const fetchedResult = await loadRendererShellMarkupFromFetch()
  if (fetchedResult?.success && typeof fetchedResult.markup === 'string' && fetchedResult.markup.trim()) {
    return {
      markup: fetchedResult.markup,
      source: 'fetch'
    }
  }

  throw new Error(bridgeResult?.message || '主界面模板读取失败')
}

function shouldUseDynamicShell(diagnosticMode = '') {
  return document.body?.dataset?.wordzDynamicShell === '1' && diagnosticMode !== 'minimal'
}

function mountDynamicShellMarkup(markup, { deferVisibleMount = false } = {}) {
  if (!deferVisibleMount) {
    document.body.innerHTML = markup
    return
  }
  document.body.innerHTML = `
    <div id="wordzWindowsStagedLoading" style="padding: 18px 24px; color: #334155;">
      Windows 兼容模式正在继续加载主界面，请稍候。
    </div>
    <div id="wordzWindowsDeferredShell" style="display: none !important;">
      ${markup}
    </div>
  `
}

function revealDeferredDynamicShell() {
  const shellWrapper = document.getElementById('wordzWindowsDeferredShell')
  if (!shellWrapper) {
    return false
  }
  writeRendererBootLog('windows-staged.shell.reveal.start')
  shellWrapper.style.display = ''
  shellWrapper.removeAttribute('aria-hidden')
  const loadingNotice = document.getElementById('wordzWindowsStagedLoading')
  if (loadingNotice) {
    loadingNotice.remove()
  }
  writeRendererBootLog('windows-staged.shell.reveal.done')
  return true
}

async function ensureDynamicShellMounted(diagnosticMode = '', { deferVisibleMount = false } = {}) {
  if (!shouldUseDynamicShell(diagnosticMode)) {
    return false
  }
  if (document.body?.dataset?.wordzDynamicShellMounted === '1') {
    return true
  }

  writeRendererBootLog('shell.mount.start', {
    diagnosticMode
  })
  const { markup, source } = await readRendererShellMarkup()
  mountDynamicShellMarkup(markup, {
    deferVisibleMount
  })
  document.body.dataset.wordzDynamicShell = '1'
  document.body.dataset.wordzDynamicShellMounted = '1'
  writeRendererBootLog('shell.mount.done', {
    diagnosticMode,
    source,
    markupLength: markup.length,
    deferVisibleMount
  })
  return true
}

function mountWindowsSafeShellMarkup(markup = '') {
  document.body.innerHTML = markup
}

async function ensureWindowsSafeShellMounted(diagnosticMode = '') {
  if (!shouldUseWindowsSafeStaticShell(diagnosticMode)) {
    return false
  }
  if (document.body?.dataset?.wordzSafeShellMounted === '1') {
    return true
  }

  writeRendererBootLog('shell.mount.start', {
    diagnosticMode,
    source: 'windows-safe-shell'
  })
  const markup = buildWindowsSafeShellMarkup()
  mountWindowsSafeShellMarkup(markup)
  document.body.dataset.wordzSafeShellMounted = '1'
  writeRendererBootLog('shell.mount.done', {
    diagnosticMode,
    source: 'windows-safe-shell',
    markupLength: markup.length,
    deferVisibleMount: false
  })
  return true
}

function bootRendererApp(fullProbeMode, diagnosticMode, uiStyleMode) {
  writeRendererBootLog('import-app.start', {
    fullProbeMode
  })
  import('./app.mjs')
    .then(() => {
      writeRendererBootLog('import-app.resolved', {
        fullProbeMode
      })
      revealDeferredDynamicShell()
      const postBootStyleMode = getPostBootStyleMode(diagnosticMode, uiStyleMode)
      if (postBootStyleMode) {
        void ensureRuntimeStylesheet(postBootStyleMode).catch(error => {
          reportBootstrapFailure(error, '兼容界面样式加载失败，请重启应用后重试。')
        })
      }
    })
    .catch(error => {
      writeRendererBootLog('import-app.failed', {
        fullProbeMode,
        message: error instanceof Error ? error.message : String(error || '')
      })
      reportBootstrapFailure(error)
    })
}

function scheduleRendererBoot({ diagnosticMode, fullProbeMode, uiStyleMode, useWindowsStagedBoot = false }) {
  if (diagnosticMode === 'minimal' || diagnosticMode === 'styles') {
    writeRendererBootLog('skipped', {
      diagnosticMode,
      reason: 'diagnostic-mode'
    })
    return
  }
  if (fullProbeMode === 'delay-renderer-start') {
    requestAnimationFrame(() => {
      bootRendererApp(fullProbeMode, diagnosticMode, uiStyleMode)
    })
    return
  }
  if (useWindowsStagedBoot) {
    writeRendererBootLog('windows-staged.import.defer', {
      diagnosticMode,
      uiStyleMode
    })
    requestAnimationFrame(() => {
      requestAnimationFrame(() => {
        bootRendererApp(fullProbeMode, diagnosticMode, uiStyleMode)
      })
    })
    return
  }
  queueMicrotask(() => {
    bootRendererApp(fullProbeMode, diagnosticMode, uiStyleMode)
  })
}

export async function startWordzRenderer() {
  const fullProbeMode = getFullProbeMode()
  const uiStyleMode = getUiStyleMode()
  const diagnosticMode = getDiagnosticMode()
  const useWindowsStagedBoot = shouldUseWindowsStagedBoot(diagnosticMode, fullProbeMode)
  writeRendererBootLog('begin', {
    readyState: document.readyState,
    fullProbeMode,
    diagnosticMode,
    uiStyleMode,
    useWindowsStagedBoot
  })

  window.addEventListener('error', event => {
    const message = event?.message ? String(event.message) : '渲染脚本运行失败。'
    reportBootstrapFailure(event?.error || new Error(message), message)
  })

  window.addEventListener('unhandledrejection', event => {
    const reason = event?.reason
    const normalizedError = reason instanceof Error ? reason : new Error(String(reason || 'Promise rejected'))
    reportBootstrapFailure(normalizedError)
  })

  try {
    if (shouldUseWindowsSafeStaticShell(diagnosticMode, fullProbeMode)) {
      await ensureWindowsSafeShellMounted(diagnosticMode)
    } else {
      await ensureDynamicShellMounted(diagnosticMode, {
        deferVisibleMount: useWindowsStagedBoot
      })
    }
    applySafeStyleProbeOverrides(fullProbeMode)
    const preBootStyleMode = getPreBootStyleMode(diagnosticMode, uiStyleMode, useWindowsStagedBoot)
    if (preBootStyleMode) {
      await ensureRuntimeStylesheet(preBootStyleMode)
      if (useWindowsStagedBoot) {
        writeRendererBootLog('windows-staged.styles-ready', {
          styleMode: preBootStyleMode
        })
      }
    } else if (useWindowsStagedBoot) {
      writeRendererBootLog('windows-staged.styles-skipped', {
        reason: 'external-stylesheet-disabled'
      })
    }
    scheduleRendererBoot({
      diagnosticMode,
      fullProbeMode,
      uiStyleMode,
      useWindowsStagedBoot
    })
    scheduleWindowsFormalUpgrade({
      diagnosticMode,
      fullProbeMode,
      uiStyleMode,
      useWindowsStagedBoot
    })
  } catch (error) {
    reportBootstrapFailure(
      error,
      diagnosticMode === 'renderer-no-style'
        ? '兼容界面初始化失败，请重启应用后重试。'
        : '主界面初始化失败，请重启应用后重试。'
    )
  }
}
