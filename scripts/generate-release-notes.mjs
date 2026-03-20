import fs from 'node:fs/promises'
import path from 'node:path'
import process from 'node:process'
import { fileURLToPath } from 'node:url'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const projectRoot = path.resolve(__dirname, '..')

function normalizeText(value, fallback = '') {
  return String(value ?? fallback).trim()
}

function escapeRegExp(text) {
  return String(text).replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
}

function parseArgs(argv) {
  const options = {
    output: path.join(projectRoot, 'build', 'release-notes.generated.md')
  }

  for (let index = 0; index < argv.length; index += 1) {
    const argument = argv[index]
    if (argument === '--output') {
      options.output = path.resolve(projectRoot, argv[index + 1] || options.output)
      index += 1
    }
  }

  return options
}

function buildReleaseNotes(packageManifest) {
  const version = normalizeText(packageManifest.version, '0.0.0')
  const productName = normalizeText(packageManifest.productName || packageManifest.name, 'WordZ')
  const description = normalizeText(packageManifest.description, '一个本地桌面语料分析工具。')
  const wordzMeta = packageManifest.wordz && typeof packageManifest.wordz === 'object'
    ? packageManifest.wordz
    : {}
  const releaseNotes = Array.isArray(wordzMeta.releaseNotes)
    ? wordzMeta.releaseNotes.map(item => normalizeText(item)).filter(Boolean)
    : []

  const winExeName = `${productName}-${version}-win-x64.exe`
  const macDmgName = `${productName}-${version}-mac-arm64.dmg`

  const sections = [
    `# ${productName} ${version}`,
    '',
    `${productName} 是一款本地桌面语料分析工具，适合在 macOS 和 Windows 上进行轻量、稳定的文本语料整理与分析。`,
    '',
    '## 本版亮点',
    '',
    ...(releaseNotes.length > 0
      ? releaseNotes.map(item => `- ${item}`)
      : ['- 本次版本已更新，请查看下方下载说明并体验最新功能。']),
    '',
    '## 下载说明',
    '',
    `- Windows 用户：优先下载 \`${winExeName}\``,
    `- macOS Apple Silicon 用户：优先下载 \`${macDmgName}\``,
    '- 如果你只想解压即用，也可以下载对应平台的 `.zip`',
    '',
    '## 自动更新',
    '',
    `- 从 \`v${version}\` 开始，${productName} 支持通过 GitHub Releases 检查更新`,
    '- 在应用内点击“检查更新”即可确认当前是否为最新版本',
    '',
    '## 已知说明',
    '',
    '- 当前版本按空格分词，更适合英文等空格分隔语言',
    '- PDF 导入目前支持可提取文本的 PDF，扫描版 PDF 暂不包含 OCR'
  ]

  if (!new RegExp(`^#\\s+${escapeRegExp(productName)}\\s+${escapeRegExp(version)}$`, 'm').test(sections[0])) {
    throw new Error('Release 说明标题生成失败')
  }

  if (!description) {
    throw new Error('应用描述不能为空')
  }

  return `${sections.join('\n')}\n`
}

async function main() {
  const options = parseArgs(process.argv.slice(2))
  const packageManifestPath = path.join(projectRoot, 'package.json')
  const packageManifest = JSON.parse(await fs.readFile(packageManifestPath, 'utf-8'))
  const releaseNotes = buildReleaseNotes(packageManifest)

  await fs.mkdir(path.dirname(options.output), { recursive: true })
  await fs.writeFile(options.output, releaseNotes, 'utf-8')
  process.stdout.write(`${options.output}\n`)
}

main().catch(error => {
  console.error('[generate-release-notes]', error)
  process.exit(1)
})

export { buildReleaseNotes }
