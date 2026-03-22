;(function bootstrapRendererEntry() {
  function writeRendererStubLog(scope, details = null) {
    try {
      if (details && typeof details === 'object') {
        console.warn(`[startup.renderer] ${scope}`, JSON.stringify(details))
        return
      }
      console.warn(`[startup.renderer] ${scope}`)
    } catch {
      // ignore stub logging failures
    }
  }

  function showBootstrapError(message) {
    try {
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

      const panel = document.createElement('div')
      panel.style.width = 'min(480px, 100%)'
      panel.style.padding = '20px'
      panel.style.borderRadius = '20px'
      panel.style.background = 'rgba(255, 255, 255, 0.96)'
      panel.style.color = '#102033'
      panel.style.border = '1px solid rgba(15, 23, 42, 0.08)'

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
      document.body?.append(notice)
    } catch {
      // ignore bootstrap overlay failures
    }
  }

  function reportBootstrapFailure(error, fallbackMessage = '前端初始化失败，请重启应用后重试。') {
    console.error('[renderer.bootstrap]', error)
    showBootstrapError(fallbackMessage)
  }

  function start() {
    writeRendererStubLog('stub.begin', {
      readyState: document.readyState,
      href: window.location.href
    })
    import('./renderer/entry.mjs')
      .then(moduleExports => {
        writeRendererStubLog('stub.entry.resolved')
        if (typeof moduleExports?.startWordzRenderer !== 'function') {
          throw new Error('未找到 startWordzRenderer')
        }
        return moduleExports.startWordzRenderer()
      })
      .catch(error => {
        writeRendererStubLog('stub.entry.failed', {
          message: error instanceof Error ? error.message : String(error || '')
        })
        reportBootstrapFailure(error)
      })
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', start, { once: true })
    return
  }
  start()
})()
