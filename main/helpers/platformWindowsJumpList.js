function setupWindowsJumpList({ app, platform, processExecPath, captureMainError }) {
  if (platform !== 'win32') return
  if (typeof app.setJumpList !== 'function') return

  const taskIconPath = processExecPath
  const taskProgramPath = processExecPath
  const buildTaskItem = ({ title, description, action }) => ({
    type: 'task',
    title,
    description,
    program: taskProgramPath,
    args: `--wordz-action=${action}`,
    iconPath: taskIconPath,
    iconIndex: 0
  })

  try {
    app.setJumpList([
      {
        type: 'tasks',
        items: [
          buildTaskItem({
            title: '快速打开语料',
            description: '快速打开 txt / docx / pdf 语料',
            action: 'open-quick-corpus'
          }),
          buildTaskItem({
            title: '导入并保存语料',
            description: '导入语料并保存到本地语料库',
            action: 'import-and-save-corpus'
          }),
          buildTaskItem({
            title: '打开本地语料库',
            description: '进入本地语料库并管理语料',
            action: 'open-library'
          })
        ]
      },
      { type: 'recent' }
    ])
  } catch (error) {
    captureMainError('windows.jump-list', error)
  }
}

module.exports = {
  setupWindowsJumpList
}
