import process from 'node:process'
import { spawnSync } from 'node:child_process'

const npmCommand = process.platform === 'win32' ? 'npm.cmd' : 'npm'

function parseArgs(argv = []) {
  return {
    skipSmoke: argv.includes('--skip-smoke'),
    skipDoctor: argv.includes('--skip-doctor'),
    noStrictDoctor: argv.includes('--no-strict-doctor')
  }
}

function runStep(label, args) {
  process.stdout.write(`\n[release-verify] ${label}\n`)
  const result = spawnSync(npmCommand, args, {
    stdio: 'inherit',
    env: process.env
  })
  if ((result.status ?? 1) !== 0) {
    throw new Error(`${label} 失败（exit code: ${result.status ?? 1}）`)
  }
}

function main() {
  const options = parseArgs(process.argv.slice(2))
  runStep('语法与单测校验', ['run', 'verify'])

  if (!options.skipSmoke) {
    runStep('Electron 冒烟测试', ['run', 'test:smoke'])
  }

  if (!options.skipDoctor) {
    const doctorArgs = ['run', 'release:doctor', '--']
    if (!options.noStrictDoctor) {
      doctorArgs.push('--strict')
    }
    runStep('发布医生检查', doctorArgs)
  }

  runStep('构建资源校验', ['run', 'build:assets'])
  process.stdout.write('\n[release-verify] 全部检查通过，可以进入 stable 发布流程。\n')
}

try {
  main()
} catch (error) {
  console.error(`[release-verify] ${error instanceof Error ? error.message : String(error)}`)
  process.exit(1)
}
