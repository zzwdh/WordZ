import process from 'node:process'
import { spawnSync } from 'node:child_process'

const npmCommand = process.platform === 'win32' ? 'npm.cmd' : 'npm'

function parseArgs(argv = []) {
  const targetArg = argv.find(argument => argument.startsWith('--target='))
  return {
    skipSmoke: argv.includes('--skip-smoke'),
    withPackagedSmoke: argv.includes('--with-packaged-smoke'),
    skipDoctor: argv.includes('--skip-doctor'),
    noStrictDoctor: argv.includes('--no-strict-doctor'),
    target: String(targetArg || '').replace('--target=', '').trim().toLowerCase() || 'current'
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

function resolveCurrentPlatformTarget() {
  if (process.platform === 'darwin') return 'mac'
  if (process.platform === 'win32') return 'win'
  throw new Error(`当前平台 ${process.platform} 未提供默认打包烟测目标，请显式传入 --target=mac 或 --target=win`)
}

function resolveSmokeTarget(target) {
  if (target === 'current') return resolveCurrentPlatformTarget()
  if (target === 'all') return resolveCurrentPlatformTarget()
  if (target === 'mac' || target === 'win') return target
  throw new Error(`不支持的发布校验目标：${target}`)
}

function main() {
  const options = parseArgs(process.argv.slice(2))
  runStep('语法与单测校验', ['run', 'verify'])

  if (!options.skipSmoke) {
    runStep('Electron 冒烟测试', ['run', 'test:smoke'])
  }

  if (!options.skipDoctor) {
    const doctorArgs = ['run', 'release:doctor', '--', `--target=${options.target}`]
    if (!options.noStrictDoctor) {
      doctorArgs.push('--strict')
    }
    runStep('发布医生检查', doctorArgs)
  }

  runStep('构建资源校验', ['run', 'build:assets'])

  if (options.withPackagedSmoke) {
    const smokeTarget = resolveSmokeTarget(options.target)
    runStep('构建当前平台安装产物', ['run', `dist:${smokeTarget}`])
    runStep('构建产物校验', ['run', 'release:artifacts', '--', `--target=${smokeTarget}`])
    runStep('打包态冒烟测试', ['run', 'test:packaged-smoke'])
  }

  process.stdout.write('\n[release-verify] 全部检查通过，可以进入 stable 发布流程。\n')
}

try {
  main()
} catch (error) {
  console.error(`[release-verify] ${error instanceof Error ? error.message : String(error)}`)
  process.exit(1)
}
