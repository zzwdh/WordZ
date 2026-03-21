const MAX_TITLE_LENGTH = 80
const MAX_BODY_LENGTH = 240
const MAX_TAG_LENGTH = 64
const MAX_ACTION_ID_LENGTH = 80

function normalizeText(value, fallback = '', maxLength = MAX_BODY_LENGTH) {
  const normalizedValue = String(value ?? fallback).trim()
  if (!normalizedValue) return String(fallback || '').trim().slice(0, maxLength)
  return normalizedValue.slice(0, maxLength)
}

function normalizeNotificationAction(action) {
  if (!action) return null
  if (typeof action === 'string') {
    const actionId = normalizeText(action, '', MAX_ACTION_ID_LENGTH)
    if (!actionId) return null
    return {
      id: actionId,
      payload: null
    }
  }
  if (typeof action !== 'object') return null

  const actionId = normalizeText(action.actionId ?? action.id, '', MAX_ACTION_ID_LENGTH)
  if (!actionId) return null
  return {
    id: actionId,
    payload: action.actionPayload ?? action.payload ?? null
  }
}

function normalizeNotificationPayload(payload = {}, fallbackTitle = 'WordZ') {
  const title = normalizeText(payload.title, fallbackTitle, MAX_TITLE_LENGTH)
  const body = normalizeText(payload.body, '', MAX_BODY_LENGTH)
  const subtitle = normalizeText(payload.subtitle, '', MAX_TITLE_LENGTH)
  const tag = normalizeText(payload.tag, '', MAX_TAG_LENGTH)
  const silent = payload.silent === true
  const action = normalizeNotificationAction(payload.action)
  return {
    title,
    body,
    subtitle,
    tag,
    silent,
    action
  }
}

function createSystemNotificationController({
  NotificationClass,
  appName = 'WordZ',
  logger = console,
  onShow = null,
  onAction = null
}) {
  function isSupported() {
    if (!NotificationClass) return false
    if (typeof NotificationClass.isSupported === 'function') {
      return NotificationClass.isSupported()
    }
    return true
  }

  function showNotification(payload = {}) {
    if (!isSupported()) {
      const result = {
        success: false,
        supported: false,
        message: '当前系统环境暂不支持系统通知。'
      }
      onShow?.({
        payload: normalizeNotificationPayload(payload, appName),
        result
      })
      return result
    }

    const normalizedPayload = normalizeNotificationPayload(payload, appName)

    try {
      const notification = new NotificationClass({
        title: normalizedPayload.title,
        body: normalizedPayload.body,
        subtitle: normalizedPayload.subtitle || undefined,
        silent: normalizedPayload.silent,
        urgency: 'normal',
        timeoutType: 'default'
      })

      if (normalizedPayload.action?.id) {
        const emitAction = () => {
          onAction?.({
            actionId: normalizedPayload.action.id,
            tag: normalizedPayload.tag,
            title: normalizedPayload.title,
            body: normalizedPayload.body,
            actionPayload: normalizedPayload.action.payload
          })
        }
        if (typeof notification.once === 'function') {
          notification.once('click', emitAction)
        } else if (typeof notification.on === 'function') {
          notification.on('click', emitAction)
        }
      }

      notification.show()
      const result = {
        success: true,
        supported: true
      }
      onShow?.({
        payload: normalizedPayload,
        result
      })
      return result
    } catch (error) {
      logger.warn?.('[system-notification.show]', error)
      const result = {
        success: false,
        supported: true,
        message: error?.message || '系统通知发送失败。'
      }
      onShow?.({
        payload: normalizedPayload,
        result
      })
      return result
    }
  }

  return {
    isSupported,
    showNotification
  }
}

module.exports = {
  createSystemNotificationController,
  normalizeNotificationPayload,
  normalizeNotificationAction
}
