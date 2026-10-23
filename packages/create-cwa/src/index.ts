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

interface CliOptions {
  projectName?: string
  ref: string
  refGiven: boolean
  yes: boolean
  ci: boolean
  templateDir?: string
  pipeline?: string
  features?: string[]
  fixtures?: boolean
  start?: boolean
  installDeps?: boolean
  help: boolean
}

const USAGE = `Usage: create-cwa [project-name] [options]

Without options every question is asked. A flag answers its question, so it isn't asked.

Options:
  --ref <tag|branch>          template version to download (default v${CLI_VERSION})
  --template-dir <path>       copy the template from a local checkout instead of downloading it
  --pipeline <id>             CI/CD pipeline: github, gitlab or none
  --features <list>           comma-separated features, "all" or "none"
  --fixtures, --no-fixtures   include the sample pages, or not
  --start, --no-start         run bin/up once the project is created, or not
  --install-deps, --no-install-deps
                              pnpm install in app/ on this machine (only when the stack isn't started)
  -y, --yes                   take the default for every question no flag answers
  --ci                        never prompt (implies --yes); a missing project name is an error
  -h, --help                  show this help`

class UsageError extends Error {}

const VALUE_FLAGS = ['--ref', '--template-dir', '--pipeline', '--features']

// Flags for unattended runs (#215); with none given, every question is asked as before.
function parseArgs(argv: string[]): CliOptions {
  const args = argv.slice(2)
  const opts: CliOptions = { ref: `v${CLI_VERSION}`, refGiven: false, yes: false, ci: false, help: false }
  const positional: string[] = []
  for (let i = 0; i < args.length; i++) {
    let arg = args[i]
    let value: string | undefined
    const eq = arg.indexOf('=')
    if (arg.startsWith('--') && eq > 0) {
      value = arg.slice(eq + 1)
      arg = arg.slice(0, eq)
      if (!VALUE_FLAGS.includes(arg)) throw new UsageError(`${arg} takes no value`)
    } else if (VALUE_FLAGS.includes(arg)) {
      value = args[i + 1]
      if (value === undefined || value.startsWith('-')) throw new UsageError(`${arg} needs a value`)
      i++
    }
    switch (arg) {
      case '--':
        break
      case '--ref':
        opts.ref = value as string
        opts.refGiven = true
        break
      case '--template-dir':
        opts.templateDir = value
        break
      case '--pipeline':
        opts.pipeline = value
        break
      case '--features':
        opts.features = (value as string).split(',').map((f) => f.trim()).filter(Boolean)
        break
      case '--fixtures':
      case '--no-fixtures':
        opts.fixtures = arg === '--fixtures'
        break
      case '--start':
      case '--no-start':
        opts.start = arg === '--start'
        break
      case '--install-deps':
      case '--no-install-deps':
        opts.installDeps = arg === '--install-deps'
        break
      case '-y':
      case '--yes':
        opts.yes = true
        break
      case '--ci':
        opts.ci = true
        opts.yes = true
        break
      case '-h':
      case '--help':
        opts.help = true
        break
      default:
        if (arg.startsWith('-')) throw new UsageError(`Unknown option ${arg}`)
        positional.push(arg)
    }
  }
  if (positional.length > 1) throw new UsageError(`Unexpected argument "${positional[1]}"`)
  if (opts.templateDir && opts.refGiven) throw new UsageError("--ref and --template-dir can't be used together")
  if (opts.start && opts.installDeps) {
    throw new UsageError('--install-deps is only for a stack that isn\'t started: the app container installs its own')
  }
  opts.projectName = positional[0]
  return opts
}

function fail(message: string): never {
  cancel(message)
  process.exit(1)
}

// A spinner when someone is watching, plain log lines under --ci.
function progress(plain: boolean): { start(msg: string): void; stop(msg: string): void } {
  return plain ? { start: (msg) => log.step(msg), stop: (msg) => log.info(msg) } : spinner()
}

async function readLocalManifest(templateDir: string): Promise<Manifest> {
  const path = join(resolve(templateDir), 'cwa-manifest.json')
  if (!existsSync(path)) throw new Error(`No CWA template in "${templateDir}": ${path} is missing.`)
  try {
    return JSON.parse(await readFile(path, 'utf-8')) as Manifest
  } catch {
    throw new Error(`${path} is not valid JSON.`)
  }
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

// Each answer comes from its flag, else the default under --yes (what Enter picks), else a prompt (#215).
async function askQuestions(manifest: Manifest, opts: CliOptions): Promise<Answers> {
  const question = (id: string): ManifestQuestion | undefined =>
    manifest.questions.find((q) => q.id === id)

  const nameQuestion = question('projectName')
  let projectName: string
  if (opts.yes && opts.projectName !== undefined) {
    const error = validateProjectName(opts.projectName)
    if (error) fail(`Project name "${opts.projectName}": ${error}`)
    projectName = opts.projectName
  } else if (opts.ci) {
    fail('--ci needs the project name: create-cwa <project-name> --ci')
  } else {
    projectName = checkCancel(
      await text({
        message: withHint(nameQuestion?.message ?? 'Project name?', nameQuestion?.hint),
        placeholder: nameQuestion?.placeholder ?? 'my-cwa-app',
        initialValue: opts.projectName ?? '',
        validate: validateProjectName,
      })
    ) as string
  }

  const ciQuestion = question('ci')
  const ciOptions = ciQuestion?.choices?.map((c) => ({ value: c.value, label: c.label, hint: c.hint })) ?? [
    { value: 'github', label: 'GitHub Actions' },
    { value: 'gitlab', label: 'GitLab CI' },
    { value: 'none', label: 'None' },
  ]
  let ci: string
  if (opts.pipeline !== undefined) {
    if (!ciOptions.some((c) => c.value === opts.pipeline)) {
      fail(`--pipeline ${opts.pipeline}: choose one of ${ciOptions.map((c) => c.value).join(', ')}`)
    }
    ci = opts.pipeline
  } else if (opts.yes) {
    ci = ciOptions[0].value
  } else {
    ci = checkCancel(
      await select({
        message: withHint(ciQuestion?.message ?? 'CI/CD pipeline?', ciQuestion?.hint),
        options: ciOptions,
      })
    ) as string
  }

  const featuresQuestion = question('features')
  const featureChoices =
    featuresQuestion?.choices?.map((c) => ({ value: c.value, label: c.label, hint: c.hint })) ?? []

  let features: string[]
  if (opts.features !== undefined) {
    const all = featureChoices.map((c) => c.value)
    const flag = opts.features
    features = flag.length === 1 && flag[0] === 'all' ? all : flag.length === 1 && flag[0] === 'none' ? [] : flag
    const unknown = features.filter((f) => !all.includes(f))
    if (unknown.length) {
      fail(`--features: unknown ${unknown.join(', ')}. Choose from ${all.join(', ')}, or "all" or "none"`)
    }
  } else if (opts.yes) {
    features = []
  } else {
    features = checkCancel(
      await multiselect({
        message: withHint(
          `${featuresQuestion?.message ?? 'Which features to include?'} (space to toggle, enter to confirm)`,
          featuresQuestion?.hint
        ),
        options: featureChoices,
        required: false,
      })
    ) as string[]
  }

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
  const fixtures =
    opts.fixtures ??
    (opts.yes
      ? (fixturesQuestion?.default ?? true)
      : (checkCancel(
          await confirm({
            message: withHint(
              fixturesQuestion?.message ?? 'Include database fixtures for selected features?',
              fixturesQuestion?.hint
            ),
            initialValue: fixturesQuestion?.default ?? true,
          })
        ) as boolean))

  return { projectName: projectName.trim(), ci, features: [...resolved], fixtures }
}

// Files a download would contain: what git tracks or would track, minus export-ignore paths (GitHub's tarball honours them).
function templateFiles(src: string): string[] | null {
  const ls = spawnSync('git', ['ls-files', '-z', '--cached', '--others', '--exclude-standard'], {
    cwd: src,
    encoding: 'utf8',
  })
  if (ls.status !== 0) return null
  const files = ls.stdout.split('\0').filter((f) => f && existsSync(join(src, f)))

  const paths = new Set<string>()
  for (const file of files) {
    const parts = file.split('/')
    for (let i = 1; i <= parts.length; i++) paths.add(parts.slice(0, i).join('/'))
  }
  const attr = spawnSync('git', ['check-attr', '-z', '--stdin', 'export-ignore'], {
    cwd: src,
    input: [...paths].join('\0'),
    encoding: 'utf8',
  })
  if (attr.status !== 0) return null
  const out = attr.stdout.split('\0')
  const ignored = new Set<string>()
  for (let i = 0; i + 2 < out.length; i += 3) {
    if (out[i + 2] === 'set') ignored.add(out[i])
  }
  return files.filter((file) => {
    const parts = file.split('/')
    for (let i = 1; i <= parts.length; i++) if (ignored.has(parts.slice(0, i).join('/'))) return false
    return true
  })
}

// --template-dir (#215): a local checkout instead of the download; excludes and stripping still apply after.
async function copyTemplateDir(templateDir: string, tempDir: string, plain: boolean): Promise<void> {
  const src = resolve(templateDir)
  const s = progress(plain)
  s.start(`Copying template from ${src}...`)
  const files = templateFiles(src)
  if (files) {
    for (const file of files) {
      await fse.copy(join(src, file), join(tempDir, file), { dereference: false })
    }
  } else {
    // Not a git checkout: everything but dependencies and VCS data.
    const skip = new Set(['.git', 'node_modules', 'vendor'])
    await fse.copy(src, tempDir, {
      filter: (path) => !path.slice(src.length).split(/[\\/]/).some((part) => skip.has(part)),
    })
  }
  s.stop('Template copied.')
}

async function downloadRepo(manifest: Manifest, ref: string, tempDir: string, plain: boolean): Promise<void> {
  const s = progress(plain)
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

  const fixturesSection = `## Fixtures and the admin account

\`bin/up\` loads the fixtures with \`--append\`, which only creates what's missing: the admin
(\`ADMIN_USERNAME\` / \`ADMIN_PASSWORD\` / \`ADMIN_EMAIL\` in \`api/.env.local\`, default
\`admin\` / \`admin\` / \`admin@example.com\`)${answers.fixtures ? ' and the sample pages' : ''}. Each load resets the
admin's password to \`ADMIN_PASSWORD\`; \`bin/up --skip-fixtures\` keeps one changed in the admin.
To load them by hand:

\`\`\`bash
docker compose exec php bin/console doctrine:fixtures:load --append
\`\`\`
`

  const readme = `# ${answers.projectName}

A [CWA](https://github.com/components-web-app/components-web-app) project.

## Features

${featureList}

## Getting started

\`\`\`bash
# Start the stack, wait until it's healthy, load the fixtures, pre-compile the
# first pages and print where to sign in. Safe to run again.
bin/up

# Follow the Nuxt dev server
docker compose logs -f app
\`\`\`

\`bin/up\` runs \`docker compose up -d --wait\`: the php container runs composer install,
waits for the database and migrates; the app container installs the Nuxt dependencies
and runs the dev server. Without a POSIX shell (Windows without WSL), run
\`docker compose up -d --wait\` and the fixtures command below instead.

\`app/\` is mounted into the app container, so its \`node_modules\` is shared: your
editor gets the types from the container's install. Don't run \`pnpm install\` on
this machine while the stack runs (it rewrites \`node_modules\` under the dev
server); if you do, run \`docker compose restart app\`.

| URL | Description |
|---|---|
| https://localhost | Nuxt app |
| https://localhost/_api | API (JSON-LD / HAL) |
| https://localhost/login | Sign in to the CWA admin |
| http://localhost:8025 | Mailpit: every email the API sends in dev |

> **Certificate warning:** Caddy signs the local certificate with its own CA, so the browser warns
> on the first visit. Accepting the warning is expected for local development.

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
// --start fails when the stack can't be started; without it (prompted or --yes) the project is created anyway (#215).
async function askSetup(opts: CliOptions): Promise<{ startDocker: boolean; installDeps: boolean }> {
  let startDocker = false
  if (commandExists('docker')) {
    startDocker =
      opts.start ??
      (opts.yes ||
        (checkCancel(
          await confirm({
            message: withHint('Start the Docker stack when the project is ready?', 'bin/up: starts it, loads fixtures, prints the login'),
            initialValue: true,
          })
        ) as boolean))
  } else if (opts.start) {
    fail('--start: docker not found. Install Docker Desktop (or Docker Engine with the compose plugin).')
  } else {
    log.warn('docker not found. Install Docker Desktop, then run `bin/up` in the project.')
  }

  if (startDocker) {
    const s = progress(opts.ci)
    s.start('Checking Docker and ports...')
    const result = await preflight()
    s.stop('Docker checked.')
    const problem = !result.dockerRunning
      ? 'Docker is installed but `docker info` failed: start Docker Desktop (or the Docker daemon).'
      : result.takenPorts.join('\n\n')
    if (result.memoryWarning) log.warn(result.memoryWarning)
    if (problem) {
      if (opts.start) fail(`--start: ${problem}`)
      log.warn(problem)
      log.info('The project will be created without starting Docker. Run `bin/up` in it once that is fixed.')
      startDocker = false
    }
    return { startDocker, installDeps: false }
  }

  let installDeps = false
  if (commandExists('pnpm')) {
    installDeps =
      opts.installDeps ??
      (!opts.yes &&
        (checkCancel(
          await confirm({
            message: withHint(
              'Install app/ dependencies on this machine?',
              'only for editor types; the app container installs its own on first start'
            ),
            initialValue: false,
          })
        ) as boolean))
  } else if (opts.installDeps) {
    fail('--install-deps: pnpm not found.')
  }
  return { startDocker, installDeps }
}

async function main(): Promise<void> {
  let args: CliOptions
  try {
    args = parseArgs(process.argv)
  } catch (err) {
    if (!(err instanceof UsageError)) throw err
    console.error(`create-cwa: ${err.message}\n\n${USAGE}`)
    process.exit(2)
  }
  if (args.help) {
    console.log(USAGE)
    return
  }

  intro(`create-cwa ${CLI_VERSION} — Components Web App scaffolder`)
  log.warn(
    'CWA is a prerelease: expect breaking changes between versions (see CHANGELOG.md on GitHub).\n' +
      'create-cwa collects no telemetry; it only downloads the template from GitHub.'
  )

  const s = progress(args.ci)
  s.start(args.templateDir ? `Reading the manifest in ${args.templateDir}...` : 'Fetching manifest...')
  let manifest: Manifest
  try {
    manifest = args.templateDir ? await readLocalManifest(args.templateDir) : await fetchManifest(args.ref)
    s.stop('Manifest loaded.')
  } catch (err) {
    s.stop((err as Error).message)
    process.exit(1)
  }

  const answers = await askQuestions(manifest, args)
  const setup = await askSetup(args)
  const targetDir = resolve(process.cwd(), answers.projectName)
  const tempDir = join(tmpdir(), `cwa-${randomBytes(6).toString('hex')}`)

  if (args.templateDir) await copyTemplateDir(args.templateDir, tempDir, args.ci)
  else await downloadRepo(manifest, args.ref, tempDir, args.ci)

  const s2 = progress(args.ci)
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
      '',
      'bin/up waits for all that, loads the fixtures (the admin' +
        (answers.fixtures ? ' and sample pages' : '') +
        '),',
      'pre-compiles the first pages and prints where to sign in. Run it again any time.',
    ]
      .join('\n')
      .trim(),
    'What Docker handles for you'
  )

  if (setup.installDeps) {
    log.step('Running: pnpm install (in app/)')
    if (!run('pnpm', ['install'], join(targetDir, 'app'))) {
      log.warn('pnpm install failed. Run it manually inside app/.')
      if (args.ci) process.exitCode = 1
    }
  }

  // bin/up is POSIX sh; Windows without sh (no WSL or Git Bash) gets the steps instead (#206).
  const hasShell = process.platform !== 'win32' || commandExists('sh')
  let ready = false
  if (setup.startDocker) {
    if (hasShell) {
      log.step('Running: bin/up')
      ready = run('sh', ['bin/up'], targetDir)
      if (!ready) log.warn('bin/up failed (see above). Fix it, then run bin/up again in the project directory.')
      // Under --ci a failed start fails the run (#215).
      if (!ready && args.ci) process.exitCode = 1
    } else {
      log.step('Running: docker compose up -d --wait')
      if (!run('docker', ['compose', 'up', '-d', '--wait'], targetDir)) {
        log.warn('docker compose up -d --wait failed. Run it again in the project directory.')
        if (args.ci) process.exitCode = 1
      }
    }
  }

  const outroLines = ready
    ? [`The site is ready: sign in with the login printed above. Next time: cd ${answers.projectName} && bin/up`]
    : hasShell
      ? ['Start the stack, load the fixtures and get the login with:', `  cd ${answers.projectName} && bin/up`]
      : [
          'Start the stack and create the admin (and any sample pages) with:',
          `  cd ${answers.projectName}`,
          '  docker compose up -d --wait',
          '  docker compose exec php bin/console doctrine:fixtures:load --append',
          'Then sign in at https://localhost/login as admin / admin (accept the certificate warning).',
        ]

  outroLines.push(
    '',
    'Follow the dev server with: docker compose logs -f app',
    "Don't run pnpm install on this machine while the stack runs: app/node_modules",
    'is shared with the dev server. If you do, run: docker compose restart app'
  )

  outro(outroLines.join('\n'))
}

main().catch((err) => {
  console.error(err instanceof Error ? err.message : err)
  process.exit(1)
})
