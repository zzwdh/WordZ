function getPlatformShellPaths({ path, baseDir }) {
  const indexHtmlPath = path.join(baseDir, 'index.html')

  return {
    indexHtmlPath,
    protocolStartupAssets: [
      indexHtmlPath,
      path.join(baseDir, 'styles.css'),
      path.join(baseDir, 'renderer.js')
    ]
  }
}

module.exports = {
  getPlatformShellPaths
}
