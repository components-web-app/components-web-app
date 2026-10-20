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
import { existsSync, readFileSync, readdirSync, statSync } from 'node:fs'
import { join, resolve } from 'node:path'
import { tmpdir } from 'node:os'
import { randomBytes } from 'node:crypto'
import { spawnSync } from 'node:child_process'
import { styleText } from 'node:util'
import { preflight } from './preflight.js'
import type { Manifest, ManifestQuestion, Answers } from './types.js'

const REPO = 'components-web-app/components-web-app'

// The CLI and the template share a version: create-cwa X downloads the template at
// tag vX, so an install is reproducible. `--ref <branch|tag>` overrides it, for
// example `--ref main` for the latest unreleased template.
const CLI_VERSION: string = JSON.parse(
  readFileSync(new URL('../package.json', import.meta.url), 'utf8')
).version

function parseArgs(argv: string[]): { projectName?: string; ref: string } {
  const args = argv.slice(2)
  let ref = `v${CLI_VERSION}`
  const positional: string[] = []
  for (let i = 0; i < args.length; i++) {
    const arg = args[i]
    if (arg === '--ref' && args[i + 1]) ref = args[++i]
    else if (arg.startsWith('--ref=')) ref = arg.slice('--ref='.length)
    else positional.push(arg)
  }
  return { projectName: positional[0], ref }
}

async function fetchManifest(ref: string): Promise<Manifest> {
  let res: Response
  try {
    res = await fetch(`https://raw.githubusercontent.com/${REPO}/${ref}/cwa-manifest.json`)
  } catch {
    throw new Error(
      'Could not fetch the CWA manifest. Check your internet connection and try again.'
    )
  }
  if (res.status === 404) {
    throw new Error(`No CWA template found at "${ref}". Check the --ref value.`)
  }
  if (!res.ok) {
    throw new Error(`Could not fetch the CWA manifest (HTTP ${res.status}). Try again shortly.`)
  }
  try {
    return (await res.json()) as Manifest
  } catch {
    throw new Error(`The CWA manifest at "${ref}" is not valid JSON.`)
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

function withHint(message: string, hint?: string): string {
  return hint ? `${message} ${styleText('dim', `(${hint})`)}` : message
}

// The name becomes the directory and the compose project name.
const PROJECT_NAME = /^[a-z0-9]+(?:-[a-z0-9]+)*$/

function validateProjectName(value: string | undefined): string | undefined {
  const name = value?.trim() ?? ''
  if (!name) return 'Project name is required'
  if (!PROJECT_NAME.test(name)) {
    return 'Use lower-case letters, digits and single dashes (for example my-cwa-app)'
  }
  const dir = resolve(process.cwd(), name)
  if (existsSync(dir) && (!statSync(dir).isDirectory() || readdirSync(dir).length > 0)) {
    return `"${name}" already exists here and is not an empty directory`
  }
  return undefined
}

async function askQuestions(manifest: Manifest, targetArg?: string): Promise<Answers> {
  const question = (id: string): ManifestQuestion | undefined =>
    manifest.questions.find((q) => q.id === id)

  const nameQuestion = question('projectName')
  const projectName = checkCancel(
    await text({
      message: withHint(nameQuestion?.message ?? 'Project name?', nameQuestion?.hint),
      placeholder: nameQuestion?.placeholder ?? 'my-cwa-app',
      initialValue: targetArg ?? '',
      validate: validateProjectName,
    })
  ) as string

  const ciQuestion = question('ci')
  const ci = checkCancel(
    await select({
      message: withHint(ciQuestion?.message ?? 'CI/CD pipeline?', ciQuestion?.hint),
      options: ciQuestion?.choices?.map((c) => ({ value: c.value, label: c.label, hint: c.hint })) ?? [
        { value: 'github', label: 'GitHub Actions' },
        { value: 'gitlab', label: 'GitLab CI' },
        { value: 'none', label: 'None' },
      ],
    })
  ) as string

  const featuresQuestion = question('features')
  const featureChoices =
    featuresQuestion?.choices?.map((c) => ({ value: c.value, label: c.label, hint: c.hint })) ?? []

  const features = checkCancel(
    await multiselect({
      message: withHint(
        `${featuresQuestion?.message ?? 'Which features to include?'} (space to toggle, enter to confirm)`,
        featuresQuestion?.hint
      ),
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

  const fixturesQuestion = question('fixtures')
  const fixtures = checkCancel(
    await confirm({
      message: withHint(
        fixturesQuestion?.message ?? 'Include database fixtures for selected features?',
        fixturesQuestion?.hint
      ),
      initialValue: fixturesQuestion?.default ?? true,
    })
  ) as boolean

  return { projectName: projectName.trim(), ci, features: [...resolved], fixtures }
}

async function downloadRepo(manifest: Manifest, ref: string, tempDir: string): Promise<void> {
  const s = spinner()
  s.start(`Downloading template (${ref})...`)
  try {
    await downloadTemplate(`github:${manifest.repo}#${ref}`, {
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
docker compose exec php bin/console doctrine:fixtures:load --append
\`\`\`
`
    : `## Admin account

No sample content is bundled. Create the admin (\`ADMIN_USERNAME\` / \`ADMIN_PASSWORD\` / \`ADMIN_EMAIL\`, default \`admin\` / \`admin\`) once the API container is healthy:

\`\`\`bash
docker compose exec php bin/console doctrine:fixtures:load --append
\`\`\`

Or create one by hand (\`--admin\` opens the admin at \`/_cwa\`): \`docker compose exec php bin/console silverback:api-components:user:create --admin\`.
`

  const readme = `# ${answers.projectName}

A [CWA](https://github.com/components-web-app/components-web-app) project.

## Features

${featureList}

## Getting started

\`\`\`bash
# Start the stack. The php container runs composer install, waits for the
# database and migrates; the app container installs the Nuxt dependencies and
# runs the dev server. There is nothing to start by hand.
docker compose up -d

# Follow the Nuxt dev server
docker compose logs -f app
\`\`\`

\`app/\` is mounted into the app container, so its \`node_modules\` is shared: your
editor gets the types from the container's install. Don't run \`pnpm install\` on
this machine while the stack runs (it rewrites \`node_modules\` under the dev
server); if you do, run \`docker compose restart app\`.

| URL | Description |
|---|---|
| https://localhost | Nuxt app |
| https://localhost/_api | API (JSON-LD / HAL) |
| https://localhost/login | Sign in to the CWA admin |

> **SSL:** Caddy issues local certificates from its own CA. Accept the browser warning, or trust the CA once:
> \`docker compose cp php:/data/caddy/pki/authorities/local/root.crt caddy-local-root.crt\`,
> then add \`caddy-local-root.crt\` to your system or browser trust store.

${fixturesSection}
${ciSection}## Learn more

- [CWA documentation](https://cwa.rocks)
- [API Components Bundle](https://github.com/components-web-app/api-components-bundle)
- [\`@cwa/nuxt\` module](https://github.com/components-web-app/cwa-nuxt-module)
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

// Decides, before anything is downloaded, whether to start the stack and whether to
// install app/ dependencies on the host. The host install shares app/node_modules with
// the app container, so it's only offered when the stack isn't started now (#204).
async function askSetup(): Promise<{ startDocker: boolean; installDeps: boolean }> {
  let startDocker = false
  if (commandExists('docker')) {
    startDocker = checkCancel(
      await confirm({
        message: withHint('Start the Docker stack when the project is ready?', 'docker compose up -d'),
        initialValue: true,
      })
    ) as boolean
  } else {
    log.warn('docker not found. Install Docker Desktop, then run `docker compose up -d` in the project.')
  }

  if (startDocker) {
    const s = spinner()
    s.start('Checking Docker and ports...')
    const result = await preflight()
    s.stop('Docker checked.')
    if (!result.dockerRunning) {
      log.warn('Docker is installed but `docker info` failed: start Docker Desktop (or the Docker daemon).')
      startDocker = false
    } else if (result.takenPorts.length) {
      log.warn(result.takenPorts.join('\n\n'))
      startDocker = false
    }
    if (result.memoryWarning) log.warn(result.memoryWarning)
    if (!startDocker) {
      log.info('The project will be created without starting Docker. Run `docker compose up -d` in it once that is fixed.')
    }
    return { startDocker, installDeps: false }
  }

  let installDeps = false
  if (commandExists('pnpm')) {
    installDeps = checkCancel(
      await confirm({
        message: withHint(
          'Install app/ dependencies on this machine?',
          'only for editor types; the app container installs its own on first start'
        ),
        initialValue: false,
      })
    ) as boolean
  }
  return { startDocker, installDeps }
}

async function main(): Promise<void> {
  intro(`create-cwa ${CLI_VERSION} — Components Web App scaffolder`)
  log.warn(
    'CWA is a prerelease: expect breaking changes between versions (see CHANGELOG.md on GitHub).\n' +
      'create-cwa collects no telemetry; it only downloads the template from GitHub.'
  )

  const args = parseArgs(process.argv)
  const s = spinner()
  s.start('Fetching manifest...')
  let manifest: Manifest
  try {
    manifest = await fetchManifest(args.ref)
    s.stop('Manifest loaded.')
  } catch (err) {
    s.stop((err as Error).message)
    process.exit(1)
  }

  const answers = await askQuestions(manifest, args.projectName)
  const setup = await askSetup()
  const targetDir = resolve(process.cwd(), answers.projectName)
  const tempDir = join(tmpdir(), `cwa-${randomBytes(6).toString('hex')}`)

  await downloadRepo(manifest, args.ref, tempDir)

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
      // Sample content only: UsersFixture stays, so the admin is still created from ADMIN_* (#142).
      await removeExcluded(tempDir, ['api/src/DataFixtures/AppScaffold.php', 'api/src/DataFixtures/Parts/'])
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
      'The app container installs the Nuxt dependencies into app/node_modules',
      '(which your editor reads too) and runs the dev server.',
      answers.fixtures
        ? '\nFixtures are NOT loaded automatically — you will be reminded below.'
        : '',
    ]
      .join('\n')
      .trim(),
    'What Docker handles for you'
  )

  if (setup.installDeps) {
    log.step('Running: pnpm install (in app/)')
    if (!run('pnpm', ['install'], join(targetDir, 'app'))) {
      log.warn('pnpm install failed. Run it manually inside app/.')
    }
  }

  if (setup.startDocker) {
    log.step('Running: docker compose up -d')
    if (!run('docker', ['compose', 'up', '-d'], targetDir)) {
      log.warn('docker compose up -d failed. Run it manually from the project directory.')
    }
  }

  const outroLines = [
    `The dev server runs in the app container. Follow it with:`,
    `  cd ${answers.projectName} && docker compose logs -f app`,
    '',
    'Then visit:',
    '  https://localhost        — app',
    '  https://localhost/_api   — API',
    '  https://localhost/login  — sign in to the admin',
    '',
    "Don't run pnpm install on this machine while the stack runs: app/node_modules",
    'is shared with the dev server. If you do, run: docker compose restart app',
  ]

  if (answers.fixtures) {
    outroLines.push('')
    outroLines.push('Load sample content (once the API container is healthy):')
    outroLines.push('  docker compose exec php bin/console doctrine:fixtures:load --append')
  } else {
    outroLines.push('')
    outroLines.push('Create the admin from ADMIN_* (once the API container is healthy):')
    outroLines.push('  docker compose exec php bin/console doctrine:fixtures:load --append')
  }

  outro(outroLines.join('\n'))
}

main().catch((err) => {
  console.error(err instanceof Error ? err.message : err)
  process.exit(1)
})
