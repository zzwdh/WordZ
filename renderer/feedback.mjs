const DEFAULT_TOAST_DURATION = 3200

function noop() {}

export function createFeedbackController(dom) {
  const {
    feedbackModal,
    feedbackTitle,
    feedbackMessage,
    feedbackInputWrap,
    feedbackInput,
    feedbackError,
    feedbackCancelButton,
    feedbackConfirmButton,
    toastViewport
  } = dom

  let dialogQueue = Promise.resolve()
  let activeDialog = null

  function resetDialog() {
    feedbackModal.classList.add('hidden')
    feedbackTitle.textContent = '提示'
    feedbackMessage.textContent = ''
    feedbackInput.value = ''
    feedbackInput.placeholder = ''
    feedbackInputWrap.classList.add('hidden')
    feedbackError.textContent = ''
    feedbackError.classList.add('hidden')
    feedbackCancelButton.classList.remove('hidden')
    feedbackConfirmButton.classList.remove('danger')
  }

  function closeDialog(result) {
    if (!activeDialog) return
    const { cleanup, previousActiveElement, resolve } = activeDialog
    activeDialog = null
    cleanup()
    resetDialog()
    if (previousActiveElement && typeof previousActiveElement.focus === 'function') {
      requestAnimationFrame(() => previousActiveElement.focus())
    }
    resolve(result)
  }

  function enqueueDialog(createDialog) {
    const task = dialogQueue.then(() => createDialog())
    dialogQueue = task.catch(noop)
    return task
  }

  function openDialog({
    mode = 'alert',
    title = '提示',
    message = '',
    confirmText = '确认',
    cancelText = '取消',
    danger = false,
    defaultValue = '',
    placeholder = '',
    validate = null,
    transform = null
  }) {
    return enqueueDialog(() => new Promise(resolve => {
      const cleanupFns = []
      const previousActiveElement = document.activeElement instanceof HTMLElement ? document.activeElement : null
      const isPrompt = mode === 'prompt'
      const cancelValue = mode === 'confirm' ? false : (isPrompt ? null : undefined)

      const setError = errorMessage => {
        feedbackError.textContent = errorMessage || ''
        feedbackError.classList.toggle('hidden', !errorMessage)
      }

      const attach = (target, eventName, handler) => {
        target.addEventListener(eventName, handler)
        cleanupFns.push(() => target.removeEventListener(eventName, handler))
      }

      const cleanup = () => {
        cleanupFns.splice(0).forEach(fn => fn())
      }

      const handleCancel = () => {
        closeDialog(cancelValue)
      }

      const handleConfirm = () => {
        if (!activeDialog) return
        if (!isPrompt) {
          closeDialog(mode === 'confirm' ? true : undefined)
          return
        }

        const rawValue = feedbackInput.value
        const transformedValue = typeof transform === 'function' ? transform(rawValue) : rawValue
        const validationMessage = typeof validate === 'function' ? validate(rawValue, transformedValue) : ''

        if (validationMessage) {
          setError(validationMessage)
          feedbackInput.focus()
          feedbackInput.select()
          return
        }

        closeDialog(transformedValue)
      }

      activeDialog = {
        cleanup,
        previousActiveElement,
        resolve
      }

      feedbackTitle.textContent = title
      feedbackMessage.textContent = message
      feedbackCancelButton.textContent = cancelText
      feedbackConfirmButton.textContent = confirmText
      feedbackConfirmButton.classList.toggle('danger', Boolean(danger))
      feedbackCancelButton.classList.toggle('hidden', mode === 'alert')
      feedbackInputWrap.classList.toggle('hidden', !isPrompt)
      feedbackInput.placeholder = placeholder
      feedbackInput.value = defaultValue
      setError('')
      feedbackModal.classList.remove('hidden')

      attach(feedbackConfirmButton, 'click', handleConfirm)
      attach(feedbackCancelButton, 'click', handleCancel)
      attach(feedbackModal, 'click', event => {
        if (event.target === feedbackModal) handleCancel()
      })
      attach(document, 'keydown', event => {
        if (!activeDialog) return
        if (event.key === 'Escape') {
          event.preventDefault()
          handleCancel()
        }
      })

      if (isPrompt) {
        attach(feedbackInput, 'input', () => setError(''))
        attach(feedbackInput, 'keydown', event => {
          if (event.key === 'Enter') {
            event.preventDefault()
            handleConfirm()
          }
        })
      }

      requestAnimationFrame(() => {
        if (isPrompt) {
          feedbackInput.focus()
          feedbackInput.select()
          return
        }
        feedbackConfirmButton.focus()
      })
    }))
  }

  function showAlert(options) {
    return openDialog({
      mode: 'alert',
      confirmText: '知道了',
      ...options
    })
  }

  function showConfirm(options) {
    return openDialog({
      mode: 'confirm',
      confirmText: '确认',
      cancelText: '取消',
      ...options
    })
  }

  function showPrompt(options) {
    return openDialog({
      mode: 'prompt',
      confirmText: '保存',
      cancelText: '取消',
      ...options
    })
  }

  function showToast(message, { title = '', type = 'info', duration = DEFAULT_TOAST_DURATION } = {}) {
    if (!toastViewport || !message) return

    const toast = document.createElement('div')
    toast.className = `toast ${type}`
    toast.setAttribute('role', 'status')

    if (title) {
      const titleNode = document.createElement('div')
      titleNode.className = 'toast-title'
      titleNode.textContent = title
      toast.append(titleNode)
    }

    const messageNode = document.createElement('div')
    messageNode.className = 'toast-message'
    messageNode.textContent = message
    toast.append(messageNode)
    toastViewport.append(toast)

    let closed = false
    const closeToast = () => {
      if (closed) return
      closed = true
      toast.classList.add('closing')
      window.setTimeout(() => toast.remove(), 180)
    }

    const timeoutId = window.setTimeout(closeToast, duration)
    toast.addEventListener('click', () => {
      window.clearTimeout(timeoutId)
      closeToast()
    })
  }

  resetDialog()

  return {
    showAlert,
    showConfirm,
    showPrompt,
    showToast
  }
}
