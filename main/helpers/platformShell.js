function getPlatformShellPaths({ path, baseDir, platform }) {
  const rendererShellSourcePath = path.join(baseDir, 'index.html')
  const windowsIndexHtmlPath = path.join(baseDir, 'index.windows.html')
  const indexHtmlPath = platform === 'win32'
    ? windowsIndexHtmlPath
    : rendererShellSourcePath

  return {
    rendererShellSourcePath,
    windowsIndexHtmlPath,
    indexHtmlPath,
    protocolStartupAssets: [
      indexHtmlPath,
      path.join(baseDir, 'styles.css'),
      path.join(baseDir, 'styles.compat.css'),
      path.join(baseDir, 'renderer.js')
    ]
  }
}

module.exports = {
  getPlatformShellPaths
}
