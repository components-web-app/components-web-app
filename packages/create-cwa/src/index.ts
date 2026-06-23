import {
  intro,
  outro,
  text,
  select,
  multiselect,
  confirm,
  spinner,
  cancel,
  isCancel,
  note,
  log,
} from '@clack/prompts'
import { downloadTemplate } from 'giget'
import fse from 'fs-extra'
import fg from 'fast-glob'
import { readFile, writeFile } from 'node:fs/promises'
import { existsSync } from 'node:fs'
import { join, resolve } from 'node:path'
import { tmpdir } from 'node:os'
import { randomBytes } from 'node:crypto'
import { spawnSync } from 'node:child_process'
import type { Manifest, Answers } from './types.js'

const MANIFEST_URL =
  'https://raw.githubusercontent.com/components-web-app/components-web-app/main/cwa-manifest.json'

async function fetchManifest(): Promise<Manifest> {
  try {
    const res = await fetch(MANIFEST_URL)
    if (!res.ok) throw new Error(`HTTP ${res.status}`)
    return (await res.json()) as Manifest
  } catch {
    throw new Error(
      'Could not fetch the CWA manifest. Check your internet connection and try again.'
    )
  }
}

function checkCancel<T>(value: T | symbol): T {
  if (isCancel(value)) {
    cancel('Cancelled.')
    process.exit(0)
  }
  return value as T
}

function commandExists(cmd: string): boolean {
  const result = spawnSync(process.platform === 'win32' ? 'where' : 'which', [cmd], {
    stdio: 'pipe',
  })
  return result.status === 0
}

function run(cmd: string, args: string[], cwd: string): boolean {
  const result = spawnSync(cmd, args, { stdio: 'inherit', cwd })
  return result.status === 0
}

async function askQuestions(manifest: Manifest, argv: string[]): Promise<Answers> {
  const targetArg = argv[2]

  const projectName = checkCancel(
    await text({
      message: 'Project name?',
      placeholder: 'my-cwa-app',
      initialValue: targetArg ?? '',
      validate: (v) => (v.trim() ? undefined : 'Project name is required'),
    })
  ) as string

  const ci = checkCancel(
    await select({
      message: 'CI/CD pipeline?',
      options: [
        { value: 'github', label: 'GitHub Actions' },
        { value: 'gitlab', label: 'GitLab CI' },
        { value: 'none', label: 'None' },
      ],
    })
  ) as string

  const featureChoices =
    manifest.questions
      .find((q) => q.id === 'features')
      ?.choices?.map((c) => ({ value: c.value, label: c.label })) ?? []

  const features = checkCancel(
    await multiselect({
      message: 'Which features to include? (space to toggle, enter to confirm)',
      options: featureChoices,
      required: false,
    })
  ) as string[]

  // Auto-include required features
  const resolved = new Set(features)
  for (const feat of features) {
    const requires =
      manifest.questions
        .find((q) => q.id === 'features')
        ?.choices?.find((c) => c.value === feat)?.requires ?? []
    requires.forEach((r) => resolved.add(r))
  }

  if (resolved.size > features.length) {
    const added = [...resolved].filter((f) => !features.includes(f))
    note(`Also enabling: ${added.join(', ')} (required by selected features)`, 'Dependencies')
  }

  const fixtures = checkCancel(
    await confirm({
      message: 'Include database fixtures for selected features?',
      initialValue: true,
    })
  ) as boolean

  return { projectName: projectName.trim(), ci, features: [...resolved], fixtures }
}

async function downloadRepo(manifest: Manifest, tempDir: string): Promise<void> {
  const s = spinner()
  s.start('Downloading template...')
  try {
    await downloadTemplate(`github:${manifest.repo}#${manifest.branch}`, {
      dir: tempDir,
      force: true,
    })
    s.stop('Template downloaded.')
  } catch (err) {
    s.stop('Download failed.')
    throw err
  }
}

async function removeExcluded(tempDir: string, excludePaths: string[]): Promise<void> {
  for (const pattern of excludePaths) {
    const fullPath = join(tempDir, pattern)
    if (existsSync(fullPath)) {
      await fse.remove(fullPath)
    }
  }
}

async function processNuxtConfig(tempDir: string, selectedFeatures: string[]): Promise<void> {
  const configPath = join(tempDir, 'app', 'nuxt.config.ts')
  if (!existsSync(configPath)) return

  let content = await readFile(configPath, 'utf-8')

  const allFeatureNames =
    content
      .match(/\/\/ @cwa-if:([a-z-]+)/g)
      ?.map((m) => m.replace('// @cwa-if:', '')) ?? []

  for (const feature of [...new Set(allFeatureNames)]) {
    if (!selectedFeatures.includes(feature)) {
      const regex = new RegExp(
        `[ \\t]*\\/\\/ @cwa-if:${feature}[^\\n]*\\n[\\s\\S]*?[ \\t]*\\/\\/ @cwa-end:${feature}[^\\n]*\\n?`,
        'g'
      )
      content = content.replace(regex, '')
    } else {
      content = content.replace(new RegExp(`[ \\t]*\\/\\/ @cwa-if:${feature}[^\\n]*\\n`, 'g'), '')
      content = content.replace(
        new RegExp(`[ \\t]*\\/\\/ @cwa-end:${feature}[^\\n]*\\n?`, 'g'),
        ''
      )
    }
  }

  content = content.replace(/\n{3,}/g, '\n\n')
  await writeFile(configPath, content, 'utf-8')
}

async function replaceProjectName(tempDir: string, projectName: string): Promise<void> {
  const slug = projectName.toLowerCase().replace(/\s+/g, '-')
  const targets = await fg(['app/nuxt.config.ts', 'app/package.json', 'helm/cwa/Chart.yaml'], {
    cwd: tempDir,
    absolute: true,
  })

  for (const file of targets) {
    let content = await readFile(file, 'utf-8')
    content = content.replace(/CWA Preview Web App/g, projectName)
    content = content.replace(/cwa-preview-web-app/g, slug)
    await writeFile(file, content, 'utf-8')
  }
}

async function generateReadme(tempDir: string, answers: Answers): Promise<void> {
  const featureList = answers.features.length
    ? answers.features.map((f) => `- ${f}`).join('\n')
    : '- Core (Title component)'

  const ciSection =
    answers.ci === 'github'
      ? '## CI/CD\n\nGitHub Actions workflows are in `.github/workflows/`. See the workflow files for required secrets and variables.\n'
      : answers.ci === 'gitlab'
        ? '## CI/CD\n\nGitLab CI is configured in `.gitlab-ci.yml`. See `bin/devops/` for the reusable pipeline scripts.\n'
        : ''

  const fixturesSection = answers.fixtures
    ? `## Fixtures

Sample content is bundled. Load it after the API container is healthy:

\`\`\`bash
docker compose exec php bin/console doctrine:fixtures:load
\`\`\`
`
    : ''

  const readme = `# ${answers.projectName}

A [CWA](https://github.com/components-web-app/components-web-app) project.

## Features

${featureList}

## Getting started

\`\`\`bash
# 1. Start the stack
#    composer install, database wait, and migrations all run automatically
docker compose up -d

# 2. Install Nuxt app dependencies (run locally, not inside Docker)
cd app
pnpm install

# 3. Start the dev server
pnpm dev
\`\`\`

| URL | Description |
|---|---|
| https://localhost | Nuxt app |
| https://localhost/_api | API (JSON-LD / HAL) |
| https://localhost/admin | CWA admin panel |

> **SSL:** The dev stack uses self-signed certs. Accept the browser warning or trust the CA at \`api/frankenphp/caddy/certs/\`.

${fixturesSection}
${ciSection}## Learn more

- [CWA documentation](https://cwa.rocks)
- [API Components Bundle](https://github.com/silverbackdan/api-components-bundle)
- [\`@cwa/nuxt\` module](https://github.com/components-web-app/cwa-nuxt-3-module)
`

  await writeFile(join(tempDir, 'README.md'), readme, 'utf-8')
}

async function moveToTarget(tempDir: string, targetDir: string): Promise<void> {
  if (existsSync(targetDir)) {
    const entries = await fse.readdir(targetDir)
    if (entries.length > 0) {
      throw new Error(`Directory "${targetDir}" already exists and is not empty.`)
    }
  }
  await fse.move(tempDir, targetDir, { overwrite: false })
}

async function main(): Promise<void> {
  intro('create-cwa — Components Web App scaffolder')

  const s = spinner()
  s.start('Fetching manifest...')
  let manifest: Manifest
  try {
    manifest = await fetchManifest()
    s.stop('Manifest loaded.')
  } catch (err) {
    s.stop((err as Error).message)
    process.exit(1)
  }

  const answers = await askQuestions(manifest, process.argv)
  const targetDir = resolve(process.cwd(), answers.projectName)
  const tempDir = join(tmpdir(), `cwa-${randomBytes(6).toString('hex')}`)

  await downloadRepo(manifest, tempDir)

  const s2 = spinner()
  s2.start('Configuring project...')

  try {
    await removeExcluded(tempDir, manifest.alwaysExclude)

    const ciExclude = manifest.ci[answers.ci]?.exclude ?? []
    await removeExcluded(tempDir, ciExclude)

    for (const [feature, config] of Object.entries(manifest.features)) {
      if (!answers.features.includes(feature)) {
        await removeExcluded(tempDir, config.exclude)
      }
    }

    if (!answers.fixtures) {
      await removeExcluded(tempDir, ['api/src/DataFixtures/Parts/'])
    }

    await processNuxtConfig(tempDir, answers.features)
    await replaceProjectName(tempDir, answers.projectName)
    await generateReadme(tempDir, answers)
    await moveToTarget(tempDir, targetDir)

    s2.stop('Project created.')
  } catch (err) {
    s2.stop('Failed.')
    await fse.remove(tempDir).catch(() => {})
    throw err
  }

  note(
    [
      'When Docker starts, the entrypoint automatically:',
      '  • runs composer install (when vendor/ is empty)',
      '  • waits for PostgreSQL to be ready',
      '  • runs database migrations',
      '',
      'You only need to run pnpm install and pnpm dev locally.',
      answers.fixtures
        ? '\nFixtures are NOT loaded automatically — you will be reminded below.'
        : '',
    ]
      .join('\n')
      .trim(),
    'What Docker handles for you'
  )

  // Offer to start Docker
  const hasDocker = commandExists('docker')
  if (hasDocker) {
    const startDocker = checkCancel(
      await confirm({ message: 'Start the Docker stack now? (docker compose up -d)', initialValue: true })
    ) as boolean

    if (startDocker) {
      log.step('Running: docker compose up -d')
      const ok = run('docker', ['compose', 'up', '-d'], targetDir)
      if (!ok) {
        log.warn('docker compose up -d failed. Start it manually before running pnpm dev.')
      }
    }
  } else {
    log.warn('docker not found — install Docker Desktop, then run: docker compose up -d')
  }

  // Offer to install Nuxt deps
  const hasPnpm = commandExists('pnpm')
  if (hasPnpm) {
    const installDeps = checkCancel(
      await confirm({
        message: 'Install Nuxt app dependencies now? (pnpm install in app/)',
        initialValue: true,
      })
    ) as boolean

    if (installDeps) {
      log.step('Running: pnpm install')
      const ok = run('pnpm', ['install'], join(targetDir, 'app'))
      if (!ok) {
        log.warn('pnpm install failed. Run it manually inside app/.')
      }
    }
  } else {
    log.warn('pnpm not found — run: npm i -g pnpm, then pnpm install inside app/')
  }

  const outroLines = [
    `Start the dev server:`,
    `  cd ${answers.projectName}/app && pnpm dev`,
    '',
    'Then visit:',
    '  https://localhost        — app',
    '  https://localhost/_api   — API',
    '  https://localhost/admin  — admin panel',
  ]

  if (answers.fixtures) {
    outroLines.push('')
    outroLines.push('Load sample content (once the API container is healthy):')
    outroLines.push('  docker compose exec php bin/console doctrine:fixtures:load')
  }

  outro(outroLines.join('\n'))
}

main().catch((err) => {
  console.error(err instanceof Error ? err.message : err)
  process.exit(1)
})
