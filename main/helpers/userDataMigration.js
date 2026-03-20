async function pathExists(fs, targetPath) {
  try {
    await fs.access(targetPath)
    return true
  } catch {
    return false
  }
}

async function copyDirectoryContents(fs, path, sourceDir, targetDir) {
  await fs.mkdir(targetDir, { recursive: true })
  const entries = await fs.readdir(sourceDir, { withFileTypes: true })
  for (const entry of entries) {
    const sourcePath = path.join(sourceDir, entry.name)
    const targetPath = path.join(targetDir, entry.name)
    if (entry.isDirectory()) {
      await copyDirectoryContents(fs, path, sourcePath, targetPath)
    } else if (entry.isFile()) {
      await fs.copyFile(sourcePath, targetPath)
    }
  }
}

async function migrateLegacyUserDataDirIfNeeded({ app, fs, path, legacyDirNames, smokeUserDataDir, logger = console }) {
  if (smokeUserDataDir) return

  const targetUserDataDir = app.getPath('userData')
  if (await pathExists(fs, targetUserDataDir)) return

  const appDataDir = app.getPath('appData')
  for (const legacyDirName of legacyDirNames) {
    const legacyUserDataDir = path.join(appDataDir, legacyDirName)
    if (legacyUserDataDir === targetUserDataDir) continue
    if (!(await pathExists(fs, legacyUserDataDir))) continue

    try {
      await fs.rename(legacyUserDataDir, targetUserDataDir)
      logger.log?.(`[user-data] 已迁移旧目录：${legacyUserDataDir} -> ${targetUserDataDir}`)
      return
    } catch (renameError) {
      logger.warn?.('[user-data.rename]', renameError)
    }

    try {
      await copyDirectoryContents(fs, path, legacyUserDataDir, targetUserDataDir)
      logger.log?.(`[user-data] 已复制旧目录：${legacyUserDataDir} -> ${targetUserDataDir}`)
      return
    } catch (copyError) {
      logger.warn?.('[user-data.copy]', copyError)
    }
  }
}

module.exports = {
  migrateLegacyUserDataDirIfNeeded,
  pathExists
}
