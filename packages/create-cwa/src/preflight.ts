import { spawnSync } from 'node:child_process'
import { createConnection, createServer } from 'node:net'

// Ports the dev stack publishes: compose.yaml (80, 443) and compose.override.yaml (3001, 5432, 8025).
export const STACK_PORTS: { port: number; service: string; culprits: string; alternative?: string }[] = [
  {
    port: 80,
    service: 'Caddy (php container), HTTP',
    culprits:
      'another CWA project (`docker compose stop` in its directory), Laravel Valet (`valet stop`), Herd (quit it), nginx or Apache',
  },
  {
    port: 443,
    service: 'Caddy (php container), HTTPS',
    culprits:
      'another CWA project (`docker compose stop` in its directory), Laravel Valet (`valet stop`), Herd (quit it), nginx or Apache',
  },
  {
    port: 3001,
    service: 'Nuxt dev server (app container)',
    culprits: 'another CWA project (`docker compose stop` in its directory) or a Node dev server',
    alternative: 'Or change `published: 3001` under `app:` in compose.override.yaml to a free port.',
  },
  {
    port: 5432,
    service: 'PostgreSQL (database container)',
    culprits:
      'another CWA project (`docker compose stop` in its directory) or a local PostgreSQL (Postgres.app, `brew services stop postgresql`)',
    alternative: 'Or change `published: 5432` under `database:` in compose.override.yaml to a free port.',
  },
  {
    port: 8025,
    service: 'Mailpit web UI (mailpit container)',
    culprits: 'another CWA project (`docker compose stop` in its directory) or a local Mailpit or MailHog',
    alternative: 'Or change `published: 8025` under `mailpit:` in compose.override.yaml to a free port.',
  },
]

// Docker Desktop reports a little less than the VM's allocation, so 4 GiB shows as ~3.8 GiB.
const MIN_DOCKER_MEMORY = 3.5 * 1024 ** 3

function canConnect(port: number): Promise<boolean> {
  return new Promise((resolve) => {
    const socket = createConnection({ host: '127.0.0.1', port })
    const done = (result: boolean) => {
      socket.destroy()
      resolve(result)
    }
    socket.setTimeout(1000, () => done(false))
    socket.once('connect', () => done(true))
    socket.once('error', () => done(false))
  })
}

function addressInUse(port: number): Promise<boolean> {
  return new Promise((resolve) => {
    const server = createServer()
    server.once('error', (err: NodeJS.ErrnoException) => resolve(err.code === 'EADDRINUSE'))
    server.once('listening', () => server.close(() => resolve(false)))
    server.listen(port, '0.0.0.0')
  })
}

function output(cmd: string, args: string[]): string | null {
  const result = spawnSync(cmd, args, { stdio: 'pipe', encoding: 'utf8' })
  return result.status === 0 ? result.stdout.trim() : null
}

// What holds the port: the containers Docker publishes it for, else the process lsof sees.
function portHolder(port: number): { holder: string; stop?: string } | null {
  const containers = output('docker', [
    'ps',
    '--filter',
    `publish=${port}`,
    '--format',
    '{{.Names}}\t{{.Label "com.docker.compose.project"}}',
  ])
  if (containers) {
    const rows = containers.split('\n').map((row) => row.split('\t'))
    const names = rows.map(([name]) => name).join(', ')
    const projects = [...new Set(rows.map(([, project]) => project).filter(Boolean))]
    return projects.length
      ? {
          holder: `container ${names} (compose project ${projects.join(', ')})`,
          stop: projects.map((p) => `docker compose -p ${p} stop`).join(' and '),
        }
      : { holder: `container ${names}`, stop: `docker stop ${rows.map(([name]) => name).join(' ')}` }
  }
  if (process.platform === 'win32') return null
  const lsof = output('lsof', ['-nP', `-iTCP:${port}`, '-sTCP:LISTEN', '-Fc'])
  const command = lsof?.split('\n').find((l) => l.startsWith('c'))?.slice(1)
  return command ? { holder: `process ${command}` } : null
}

export interface PreflightResult {
  dockerRunning: boolean
  takenPorts: string[]
  memoryWarning: string | null
}

export async function preflight(): Promise<PreflightResult> {
  const memTotal = output('docker', ['info', '--format', '{{.MemTotal}}'])
  if (memTotal === null) {
    return { dockerRunning: false, takenPorts: [], memoryWarning: null }
  }

  const takenPorts: string[] = []
  for (const { port, service, culprits, alternative } of STACK_PORTS) {
    if ((await canConnect(port)) || (await addressInUse(port))) {
      const found = portHolder(port)
      const lines = [`Port ${port} (${service}) is in use${found ? ` by ${found.holder}` : ''}.`]
      lines.push(found?.stop ? `  Stop it with: ${found.stop}` : `  Free it. Likely: ${culprits}.`)
      if (alternative) lines.push(`  ${alternative}`)
      takenPorts.push(lines.join('\n'))
    }
  }

  const bytes = Number(memTotal)
  const memoryWarning =
    bytes > 0 && bytes < MIN_DOCKER_MEMORY
      ? `Docker has ${(bytes / 1024 ** 3).toFixed(1)} GiB of memory; the stack needs about 4 GiB. Raise it in Docker Desktop → Settings → Resources.`
      : null

  return { dockerRunning: true, takenPorts, memoryWarning }
}
