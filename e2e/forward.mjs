// Sends localhost:80 and :443 to the site (E2E_SITE_HOST), so the browser and API both use https://localhost (#157).
// Then runs its arguments as a command and exits with its status.
import { spawn } from 'node:child_process'
import net from 'node:net'

const host = process.env.E2E_SITE_HOST ?? 'php'
const forward = port => new Promise(resolve => net.createServer((client) => {
  const upstream = net.connect(port, host)
  client.pipe(upstream).pipe(client)
  const close = () => {
    client.destroy()
    upstream.destroy()
  }
  client.on('error', close)
  upstream.on('error', close)
}).listen(port, resolve))

Promise.all([forward(80), forward(443)]).then(() => {
  const child = spawn(process.argv[2], process.argv.slice(3), { stdio: 'inherit', shell: true })
  child.on('exit', code => process.exit(code ?? 1))
})
