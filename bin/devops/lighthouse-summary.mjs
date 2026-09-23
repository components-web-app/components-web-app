// Summarises the Lighthouse CI reports that performance_audit (bin/devops/k8s.sh)
// writes, one directory per form factor, each holding `lhci upload
// --target=filesystem` output (a manifest.json plus the reports).
//
//   node bin/devops/lighthouse-summary.mjs <output-dir>
//
// Prints a Markdown table of each page's representative (median) run, and writes
// <output-dir>/browser-performance.json in GitLab's browser_performance report
// format, so merge requests can compare the metrics between pipelines. No
// dependencies: the CI images only guarantee node.
import { existsSync, readdirSync, readFileSync, writeFileSync } from 'node:fs'
import { isAbsolute, join } from 'node:path'

const dir = process.argv[2]
if (!dir) {
  console.error('usage: lighthouse-summary.mjs <output-dir>')
  process.exit(1)
}

// [label, Lighthouse audit id, unit, how to show the value]
const METRICS = [
  ['LCP', 'largest-contentful-paint', 'ms', v => `${(v / 1000).toFixed(2)}s`],
  ['CLS', 'cumulative-layout-shift', '', v => v.toFixed(3)],
  ['TBT', 'total-blocking-time', 'ms', v => `${Math.round(v)}ms`],
  ['FCP', 'first-contentful-paint', 'ms', v => `${(v / 1000).toFixed(2)}s`],
  ['Speed Index', 'speed-index', 'ms', v => `${(v / 1000).toFixed(2)}s`],
  ['Page weight', 'total-byte-weight', 'KiB', v => `${Math.round(v / 1024)} KiB`],
]

const rows = []
const gitlab = []

const formFactors = readdirSync(dir, { withFileTypes: true })
  .filter(entry => entry.isDirectory() && existsSync(join(dir, entry.name, 'manifest.json')))
  .map(entry => entry.name)
  .sort()

for (const formFactor of formFactors) {
  const manifest = JSON.parse(readFileSync(join(dir, formFactor, 'manifest.json'), 'utf8'))
  for (const run of manifest.filter(entry => entry.isRepresentativeRun)) {
    const jsonPath = isAbsolute(run.jsonPath) ? run.jsonPath : join(dir, formFactor, run.jsonPath)
    const audits = JSON.parse(readFileSync(jsonPath, 'utf8')).audits
    const path = new URL(run.url).pathname
    const score = Math.round((run.summary?.performance ?? 0) * 100)
    const values = METRICS.map(([, id]) => audits[id]?.numericValue)

    rows.push(`| \`${path}\` | ${formFactor} | ${score} | ${values
      .map((value, i) => (typeof value === 'number' ? METRICS[i][3](value) : 'n/a'))
      .join(' | ')} |`)

    gitlab.push({
      // Stable across pipelines, so GitLab can compare the same page and form factor.
      subject: `${path} (${formFactor})`,
      metrics: [
        { name: 'Performance score', value: score, desiredSize: 'larger' },
        ...METRICS.flatMap(([label, , unit], i) => typeof values[i] === 'number'
          ? [{
              name: unit ? `${label} (${unit})` : label,
              value: unit === 'KiB'
                ? Math.round(values[i] / 1024)
                : unit === 'ms' ? Math.round(values[i]) : Math.round(values[i] * 1000) / 1000,
              desiredSize: 'smaller',
            }]
          : []),
      ],
    })
  }
}

writeFileSync(join(dir, 'browser-performance.json'), `${JSON.stringify(gitlab, null, 2)}\n`)

const out = ['## Performance audit', '']
if (rows.length) {
  out.push(
    `| Page | Form factor | Score | ${METRICS.map(([label]) => label).join(' | ')} |`,
    `|---|---|---|${METRICS.map(() => '---').join('|')}|`,
    ...rows,
    '',
    'Median of each page\'s runs. Budgets are in `bin/devops/lighthouserc.json`; full reports are in the job artifacts.',
  )
} else {
  out.push('No Lighthouse results were produced.')
}
console.log(out.join('\n'))
