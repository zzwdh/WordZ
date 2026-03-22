import fs from 'node:fs/promises'
import path from 'node:path'
import process from 'node:process'
import { fileURLToPath } from 'node:url'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const projectRoot = path.resolve(__dirname, '..')
const distDir = path.join(projectRoot, 'dist')

function normalizeText(value, fallback = '') {
  return String(value ?? fallback).trim()
}

function escapeRegExp(text) {
  return normalizeText(text).replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
}

function parseArgs(argv = []) {
  const targetOption = argv.find(argument => argument.startsWith('--target='))
  return {
    target: normalizeText(targetOption?.slice('--target='.length), 'current').toLowerCase(),
    json: argv.includes('--json')
  }
}

function resolveTarget(target) {
  if (target && target !== 'current') return target
  if (process.platform === 'darwin') return 'mac'
  if (process.platform === 'win32') return 'win'
  throw new Error(`当前平台 ${process.platform} 未提供默认构建产物校验目标，请显式传入 --target=mac 或 --target=win`)
}

async function pathExists(targetPath) {
  try {
    await fs.access(targetPath)
    return true
  } catch {
    return false
  }
}

async function readDirectoryNames(targetPath) {
  try {
    const entries = await fs.readdir(targetPath, { withFileTypes: true })
    return entries.map(entry => ({
      name: entry.name,
      isDirectory: entry.isDirectory()
    }))
  } catch {
    return []
  }
}

async function statSize(targetPath) {
  try {
    const stats = await fs.stat(targetPath)
    return stats.size
  } catch {
    return 0
  }
}

function formatBytes(size) {
  const value = Number(size) || 0
  if (value < 1024) return `${value} B`
  if (value < 1024 * 1024) return `${(value / 1024).toFixed(1)} KB`
  if (value < 1024 * 1024 * 1024) return `${(value / (1024 * 1024)).toFixed(1)} MB`
  return `${(value / (1024 * 1024 * 1024)).toFixed(2)} GB`
}

async function buildArtifactRecord(relativePath) {
  const absolutePath = path.join(projectRoot, relativePath)
  const present = await pathExists(absolutePath)
  return {
    path: relativePath,
    present,
    size: present ? await statSize(absolutePath) : 0
  }
}

async function collectMacArtifacts({ productName, version }) {
  const entries = await readDirectoryNames(distDir)
  const dmgPattern = new RegExp(`^${escapeRegExp(productName)}-${escapeRegExp(version)}-mac-.*\\.dmg$`, 'i')
  const zipPattern = new RegExp(`^${escapeRegExp(productName)}-${escapeRegExp(version)}-mac-.*\\.zip$`, 'i')
  const blockmapPattern = /\.(?:dmg|zip)\.blockmap$/i

  const macBuildDirs = entries
    .filter(entry => entry.isDirectory && /^mac-/i.test(entry.name))
    .map(entry => entry.name)

  const candidateFiles = entries
    .filter(entry => !entry.isDirectory)
    .map(entry => entry.name)

  const records = []

  for (const filename of candidateFiles.filter(name => dmgPattern.test(name))) {
    records.push(await buildArtifactRecord(path.join('dist', filename)))
  }
  for (const filename of candidateFiles.filter(name => zipPattern.test(name))) {
    records.push(await buildArtifactRecord(path.join('dist', filename)))
  }
  for (const filename of candidateFiles.filter(name => blockmapPattern.test(name) && name.includes(`-${version}-mac-`))) {
    records.push(await buildArtifactRecord(path.join('dist', filename)))
  }

  for (const buildDir of macBuildDirs) {
    const appRelativePath = path.join('dist', buildDir, `${productName}.app`, 'Contents', 'MacOS', productName)
    const asarRelativePath = path.join('dist', buildDir, `${productName}.app`, 'Contents', 'Resources', 'app.asar')
    records.push(await buildArtifactRecord(appRelativePath))
    records.push(await buildArtifactRecord(asarRelativePath))
  }

  const hasDmg = records.some(record => record.present && /\.dmg$/i.test(record.path))
  const hasZip = records.some(record => record.present && /\.zip$/i.test(record.path))
  const hasDmgBlockmap = records.some(record => record.present && /\.dmg\.blockmap$/i.test(record.path))
  const hasZipBlockmap = records.some(record => record.present && /\.zip\.blockmap$/i.test(record.path))
  const hasPackagedApp = records.some(record => record.present && record.path.endsWith(`/MacOS/${productName}`))
  const hasAsar = records.some(record => record.present && record.path.endsWith('/Resources/app.asar'))

  return {
    target: 'mac',
    ok: hasDmg && hasZip && hasDmgBlockmap && hasZipBlockmap && hasPackagedApp && hasAsar,
    checks: [
      { label: 'DMG 安装包', ok: hasDmg },
      { label: 'ZIP 归档包', ok: hasZip },
      { label: 'DMG blockmap', ok: hasDmgBlockmap },
      { label: 'ZIP blockmap', ok: hasZipBlockmap },
      { label: '打包后应用可执行文件', ok: hasPackagedApp },
      { label: 'app.asar', ok: hasAsar }
    ],
    records
  }
}

async function collectWindowsArtifacts({ productName, version }) {
  const entries = await readDirectoryNames(distDir)
  const exePattern = new RegExp(`^${escapeRegExp(productName)}-${escapeRegExp(version)}-win-.*\\.exe$`, 'i')
  const candidateFiles = entries
    .filter(entry => !entry.isDirectory)
    .map(entry => entry.name)
    .filter(name => !/__uninstaller/i.test(name))

  const records = []
  for (const filename of candidateFiles.filter(name => exePattern.test(name) && !/portable/i.test(name))) {
    records.push(await buildArtifactRecord(path.join('dist', filename)))
  }
  for (const filename of candidateFiles.filter(name => /\.exe\.blockmap$/i.test(name) && name.includes(`-${version}-win-`))) {
    records.push(await buildArtifactRecord(path.join('dist', filename)))
  }

  records.push(await buildArtifactRecord(path.join('dist', 'win-unpacked', `${productName}.exe`)))
  records.push(await buildArtifactRecord(path.join('dist', 'win-unpacked', 'resources', 'app.asar')))

  const hasInstaller = records.some(record => record.present && /-win-.*\.exe$/i.test(record.path) && !/\.blockmap$/i.test(record.path))
  const hasBlockmap = records.some(record => record.present && /\.exe\.blockmap$/i.test(record.path))
  const hasPackagedApp = records.some(record => record.present && record.path.endsWith(`/win-unpacked/${productName}.exe`))
  const hasAsar = records.some(record => record.present && record.path.endsWith('/win-unpacked/resources/app.asar'))

  return {
    target: 'win',
    ok: hasInstaller && hasBlockmap && hasPackagedApp && hasAsar,
    checks: [
      { label: 'NSIS 安装包', ok: hasInstaller },
      { label: 'EXE blockmap', ok: hasBlockmap },
      { label: '打包后应用可执行文件', ok: hasPackagedApp },
      { label: 'app.asar', ok: hasAsar }
    ],
    records
  }
}

function printSummary(result) {
  process.stdout.write(`\n[release-artifacts] ${result.target}\n`)
  for (const check of result.checks) {
    process.stdout.write(`- ${check.ok ? '通过' : '缺失'} ${check.label}\n`)
  }
  for (const record of result.records) {
    if (!record.present) {
      process.stdout.write(`- 缺失 ${record.path}\n`)
      continue
    }
    process.stdout.write(`- 已找到 ${record.path} (${formatBytes(record.size)})\n`)
  }
}

async function main() {
  const options = parseArgs(process.argv.slice(2))
  const packageManifest = JSON.parse(await fs.readFile(path.join(projectRoot, 'package.json'), 'utf-8'))
  const target = resolveTarget(options.target)
  const targets = target === 'all' ? ['mac', 'win'] : [target]
  const results = []

  for (const item of targets) {
    if (item === 'mac') {
      results.push(await collectMacArtifacts({
        productName: packageManifest.productName || 'WordZ',
        version: packageManifest.version || '0.0.0'
      }))
      continue
    }

    if (item === 'win') {
      results.push(await collectWindowsArtifacts({
        productName: packageManifest.productName || 'WordZ',
        version: packageManifest.version || '0.0.0'
      }))
      continue
    }

    throw new Error(`不支持的产物校验目标：${item}`)
  }

  if (options.json) {
    process.stdout.write(`${JSON.stringify(results, null, 2)}\n`)
  } else {
    for (const result of results) {
      printSummary(result)
    }
  }

  if (results.some(result => !result.ok)) {
    process.exitCode = 1
  }
}

main().catch(error => {
  console.error(`[release-artifacts] ${error instanceof Error ? error.message : String(error)}`)
  process.exit(1)
})
