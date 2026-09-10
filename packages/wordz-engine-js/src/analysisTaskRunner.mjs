import { EventEmitter } from 'node:events'
import path from 'node:path'
import { Worker } from 'node:worker_threads'
import { fileURLToPath } from 'node:url'

import { ENGINE_EVENTS, ENGINE_TASK_TYPES, isEngineTaskType } from '../../wordz-contracts/src/index.mjs'

const currentFilePath = fileURLToPath(import.meta.url)
const currentDir = path.dirname(currentFilePath)
const workerPath = path.join(currentDir, 'analysisTaskWorker.mjs')
const MAX_RETAINED_TASKS = 128

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

  function pruneFinishedTasks() {
    if (tasks.size < MAX_RETAINED_TASKS) return
    for (const [taskId, task] of tasks) {
      if (tasks.size < MAX_RETAINED_TASKS) break
      if (task.status === 'running') continue
      tasks.delete(taskId)
    }
  }

  function completeTask(taskState, result) {
    if (taskState.status !== 'running') return false
    taskState.status = 'completed'
    taskState.result = result ?? null
    taskState.finishedAt = new Date().toISOString()
    taskState.worker = null
    emit(ENGINE_EVENTS.taskCompleted, {
      taskId: taskState.taskId,
      taskType: taskState.taskType,
      status: taskState.status,
      startedAt: taskState.startedAt,
      finishedAt: taskState.finishedAt,
      result: taskState.result
    })
    return true
  }

  function failTask(taskState, error) {
    if (taskState.status !== 'running') return false
    taskState.status = 'failed'
    taskState.finishedAt = new Date().toISOString()
    taskState.error = error instanceof Error
      ? error.message
      : String(error || 'Task failed')
    taskState.worker = null
    emit(ENGINE_EVENTS.taskFailed, {
      taskId: taskState.taskId,
      taskType: taskState.taskType,
      status: taskState.status,
      startedAt: taskState.startedAt,
      finishedAt: taskState.finishedAt,
      error: taskState.error
    })
    return true
  }

  function startTask(taskType, payload = {}) {
    if (!isEngineTaskType(taskType)) {
      throw new Error(`Unsupported task type: ${taskType}`)
    }

    pruneFinishedTasks()
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
        completeTask(taskState, message.result)
        return
      }
      failTask(taskState, message?.message || 'Task failed')
    })

    worker.once('error', error => {
      failTask(taskState, error)
    })

    worker.once('exit', code => {
      if (taskState.worker === worker) {
        taskState.worker = null
      }
      if (taskState.status === 'running' && code !== 0) {
        failTask(taskState, `Worker exited with code ${code}`)
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

    const worker = task.worker
    task.status = 'cancelled'
    task.finishedAt = new Date().toISOString()
    task.worker = null
    await worker.terminate()
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
    const runningTasks = [...tasks.values()].filter(task => task.worker && task.status === 'running')
    const workers = runningTasks.map(task => task.worker)
    const finishedAt = new Date().toISOString()
    for (const task of runningTasks) {
      task.status = 'cancelled'
      task.finishedAt = finishedAt
      task.worker = null
    }
    await Promise.all(workers.map(worker => worker.terminate().catch(() => {})))
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
