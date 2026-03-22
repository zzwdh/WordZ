import { EventEmitter } from 'node:events'
import path from 'node:path'
import { Worker } from 'node:worker_threads'
import { fileURLToPath } from 'node:url'

import { ENGINE_EVENTS, ENGINE_TASK_TYPES, isEngineTaskType } from '../../wordz-contracts/src/index.mjs'

const currentFilePath = fileURLToPath(import.meta.url)
const currentDir = path.dirname(currentFilePath)
const workerPath = path.join(currentDir, 'analysisTaskWorker.mjs')

export function createAnalysisTaskRunner() {
  const emitter = new EventEmitter()
  const tasks = new Map()
  let nextTaskId = 1

  function emit(method, params) {
    emitter.emit('notification', { method, params })
  }

  function getTaskState(taskId) {
    const task = tasks.get(String(taskId || ''))
    if (!task) return null
    return {
      taskId: task.taskId,
      taskType: task.taskType,
      status: task.status,
      startedAt: task.startedAt,
      finishedAt: task.finishedAt || '',
      error: task.error || '',
      result: task.result ?? null
    }
  }

  function onNotification(listener) {
    emitter.on('notification', listener)
    return () => emitter.off('notification', listener)
  }

  function startTask(taskType, payload = {}) {
    if (!isEngineTaskType(taskType)) {
      throw new Error(`Unsupported task type: ${taskType}`)
    }

    const taskId = `task-${nextTaskId++}`
    const worker = new Worker(workerPath, {
      workerData: {
        taskType,
        payload
      }
    })
    const taskState = {
      taskId,
      taskType,
      status: 'running',
      startedAt: new Date().toISOString(),
      finishedAt: '',
      error: '',
      result: null,
      worker
    }
    tasks.set(taskId, taskState)
    emit(ENGINE_EVENTS.taskUpdated, {
      taskId,
      taskType,
      status: 'running',
      startedAt: taskState.startedAt
    })

    worker.once('message', message => {
      if (message?.success) {
        taskState.status = 'completed'
        taskState.result = message.result ?? null
        taskState.finishedAt = new Date().toISOString()
        emit(ENGINE_EVENTS.taskCompleted, {
          taskId,
          taskType,
          status: taskState.status,
          startedAt: taskState.startedAt,
          finishedAt: taskState.finishedAt,
          result: taskState.result
        })
        return
      }

      taskState.status = 'failed'
      taskState.finishedAt = new Date().toISOString()
      taskState.error = String(message?.message || 'Task failed')
      emit(ENGINE_EVENTS.taskFailed, {
        taskId,
        taskType,
        status: taskState.status,
        startedAt: taskState.startedAt,
        finishedAt: taskState.finishedAt,
        error: taskState.error
      })
    })

    worker.once('error', error => {
      taskState.status = 'failed'
      taskState.finishedAt = new Date().toISOString()
      taskState.error = error instanceof Error ? error.message : String(error || 'Task failed')
      emit(ENGINE_EVENTS.taskFailed, {
        taskId,
        taskType,
        status: taskState.status,
        startedAt: taskState.startedAt,
        finishedAt: taskState.finishedAt,
        error: taskState.error
      })
    })

    worker.once('exit', code => {
      if (taskState.status === 'running' && code !== 0) {
        taskState.status = 'failed'
        taskState.finishedAt = new Date().toISOString()
        taskState.error = `Worker exited with code ${code}`
        emit(ENGINE_EVENTS.taskFailed, {
          taskId,
          taskType,
          status: taskState.status,
          startedAt: taskState.startedAt,
          finishedAt: taskState.finishedAt,
          error: taskState.error
        })
      }
    })

    return {
      taskId,
      taskType,
      status: 'running'
    }
  }

  async function cancelTask(taskId) {
    const task = tasks.get(String(taskId || ''))
    if (!task) return null
    if (task.status !== 'running' || !task.worker) {
      return getTaskState(taskId)
    }

    await task.worker.terminate()
    task.status = 'cancelled'
    task.finishedAt = new Date().toISOString()
    emit(ENGINE_EVENTS.taskCancelled, {
      taskId: task.taskId,
      taskType: task.taskType,
      status: task.status,
      startedAt: task.startedAt,
      finishedAt: task.finishedAt
    })
    return getTaskState(taskId)
  }

  async function dispose() {
    await Promise.all(
      [...tasks.values()]
        .filter(task => task.worker && task.status === 'running')
        .map(task => task.worker.terminate().catch(() => {}))
    )
  }

  return {
    ENGINE_TASK_TYPES,
    cancelTask,
    dispose,
    getTaskState,
    onNotification,
    startTask
  }
}
