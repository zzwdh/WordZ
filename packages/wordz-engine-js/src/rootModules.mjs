import os from 'node:os'
import path from 'node:path'
import { createRequire } from 'node:module'
import { fileURLToPath, pathToFileURL } from 'node:url'

const require = createRequire(import.meta.url)
const currentFilePath = fileURLToPath(import.meta.url)
const currentDir = path.dirname(currentFilePath)
const repoRoot = path.resolve(currentDir, '../../../')
const packageManifest = require(path.join(repoRoot, 'package.json'))
const { CorpusStorage } = require(path.join(repoRoot, 'corpusStorage.js'))
const {
  readCorpusFile,
  inspectCorpusFilePreflight,
  SUPPORTED_CORPUS_EXTENSIONS
} = require(path.join(repoRoot, 'corpusFileReader.js'))
const { createDiagnosticsController } = require(path.join(repoRoot, 'diagnostics/controller.js'))
const {
  normalizeBooleanInput,
  normalizeFilePathInput,
  normalizeIdentifier,
  normalizeTextInput
} = require(path.join(repoRoot, 'main/helpers/inputGuards.js'))

export {
  CorpusStorage,
  SUPPORTED_CORPUS_EXTENSIONS,
  createDiagnosticsController,
  inspectCorpusFilePreflight,
  normalizeBooleanInput,
  normalizeFilePathInput,
  normalizeIdentifier,
  normalizeTextInput,
  os,
  packageManifest,
  path,
  pathToFileURL,
  readCorpusFile,
  repoRoot
}

export function resolveUserDataDir(explicitDir = '') {
  const normalizedExplicitDir = String(explicitDir || process.env.WORDZ_USER_DATA_DIR || '').trim()
  if (normalizedExplicitDir) {
    return path.resolve(normalizedExplicitDir)
  }

  if (process.platform === 'win32') {
    const appDataDir = process.env.APPDATA || path.join(os.homedir(), 'AppData', 'Roaming')
    return path.join(appDataDir, 'WordZ')
  }

  if (process.platform === 'darwin') {
    return path.join(os.homedir(), 'Library', 'Application Support', 'WordZ')
  }

  return path.join(os.homedir(), '.config', 'WordZ')
}

export async function importRootEsmModule(relativePath) {
  return import(pathToFileURL(path.join(repoRoot, relativePath)).toString())
}
