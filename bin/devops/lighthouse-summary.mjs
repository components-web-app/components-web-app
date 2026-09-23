// Summarises the Lighthouse CI reports that performance_audit (bin/devops/k8s.sh)
// writes, one directory per form factor, each holding `lhci upload
// --target=filesystem` output (a manifest.json plus the reports).
//
//   node bin/devops/lighthouse-summary.mjs <output-dir> [lighthouserc.json]
//
// For each page's representative (median) run it:
// - prints an aligned table for the CI job log, marking every value outside its
//   budget with ✗ (the budgets are read from the lighthouserc assertions, so the
//   marks always match what `lhci assert` enforced);
// - writes <output-dir>/summary.md, the same table as Markdown, for GitHub's step
//   summary;
// - writes <output-dir>/browser-performance.json in GitLab's browser_performance
//   report format, so merge requests can compare the metrics between pipelines.
// No dependencies: the CI images only guarantee node.
import { existsSync, readdirSync, readFileSync, writeFileSync } from 'node:fs'
import { basename, isAbsolute, join } from 'node:path'

const [dir, configPath] = process.argv.slice(2)
if (!dir) {
  console.error('usage: lighthouse-summary.mjs <output-dir> [lighthouserc.json]')
  process.exit(1)
}

// [label, Lighthouse audit id, unit, how to show the value]
const METRICS = [
  ['LCP', 'largest-contentful-paint', 'ms', v => `${(v / 1000).toFixed(2)}s`],
  ['FCP', 'first-contentful-paint', 'ms', v => `${(v / 1000).toFixed(2)}s`],
  ['TBT', 'total-blocking-time', 'ms', v => `${Math.round(v)}ms`],
  ['CLS', 'cumulative-layout-shift', '', v => v.toFixed(3)],
  ['Speed Index', 'speed-index', 'ms', v => `${(v / 1000).toFixed(2)}s`],
  ['Weight', 'total-byte-weight', 'KiB', v => `${Math.round(v / 1024)} KiB`],
]

// Budgets from the lighthouserc assertions: audit id -> { max | min, level }.
const budgets = {}
try {
  const assertions = JSON.parse(readFileSync(configPath, 'utf8'))?.ci?.assert?.assertions ?? {}
  for (const [id, [level, opts = {}]] of Object.entries(assertions)) {
    if (level === 'off') continue
    if (typeof opts.maxNumericValue === 'number') budgets[id] = { max: opts.maxNumericValue, level }
    if (typeof opts.minScore === 'number') budgets[id] = { min: opts.minScore, level }
  }
}
catch {
  // No config (or unreadable): print the table without budget marks.
}
const mark = (id, value) => {
  const budget = budgets[id]
  if (!budget || typeof value !== 'number') return ''
  const over = budget.max !== undefined ? value > budget.max : value < budget.min
  if (!over) return ' ✓'
  return budget.level === 'warn' ? ' ⚠' : ' ✗'
}

const rows = []
const gitlab = []

const formFactors = readdirSync(dir, { withFileTypes: true })
  .filter(entry => entry.isDirectory() && existsSync(join(dir, entry.name, 'manifest.json')))
  .map(entry => entry.name)
  .sort()

for (const formFactor of formFactors) {
  const manifest = JSON.parse(readFileSync(join(dir, formFactor, 'manifest.json'), 'utf8'))
  for (const run of manifest.filter(entry => entry.isRepresentativeRun)) {
    // The manifest records absolute paths from where the audit ran (/builds/... in CI).
    // Fall back to the file's name next to the manifest, so a downloaded artifact works too.
    const recorded = isAbsolute(run.jsonPath) ? run.jsonPath : join(dir, formFactor, run.jsonPath)
    const jsonPath = existsSync(recorded) ? recorded : join(dir, formFactor, basename(run.jsonPath))
    const audits = JSON.parse(readFileSync(jsonPath, 'utf8')).audits
    const path = new URL(run.url).pathname
    const scoreRaw = run.summary?.performance ?? 0
    const score = Math.round(scoreRaw * 100)
    const values = METRICS.map(([, id]) => audits[id]?.numericValue)

    rows.push([
      path,
      formFactor,
      `${score}${mark('categories:performance', scoreRaw)}`,
      ...values.map((value, i) => (typeof value === 'number'
        ? `${METRICS[i][3](value)}${mark(METRICS[i][1], value)}`
        : 'n/a')),
    ])

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

const header = ['Page', 'Device', 'Score', ...METRICS.map(([label]) => label)]
const legend = Object.keys(budgets).length
  ? '✓ within budget   ✗ over budget (fails the audit)   ⚠ over a warning budget'
  : ''
const note = 'Median of each page\'s runs. Budgets are in bin/devops/lighthouserc.json; full HTML reports are in the job artifacts.'

// Markdown, for GitHub's step summary.
const md = ['## Performance audit', '']
if (rows.length) {
  md.push(
    `| ${header.join(' | ')} |`,
    `|${header.map(() => '---').join('|')}|`,
    ...rows.map(row => `| \`${row[0]}\` | ${row.slice(1).join(' | ')} |`),
    '',
    ...(legend ? [legend, ''] : []),
    note,
  )
}
else {
  md.push('No Lighthouse results were produced.')
}
writeFileSync(join(dir, 'summary.md'), `${md.join('\n')}\n`)

// Aligned plain text, for the CI job log (which shows Markdown as raw pipes).
// Width counts characters, so the ✓/✗/⚠ marks line up in a monospace log.
if (!rows.length) {
  console.log('No Lighthouse results were produced.')
}
else {
  const widths = header.map((h, i) => Math.max(h.length, ...rows.map(row => [...row[i]].length)))
  const line = cells => cells.map((cell, i) => (i < 2 ? cell.padEnd(widths[i]) : cell.padStart(widths[i]))).join('  ')
  const rule = widths.map(w => '─'.repeat(w)).join('  ')
  console.log(['', 'Performance audit', rule, line(header), rule, ...rows.map(line), rule, ...(legend ? [legend] : []), note, ''].join('\n'))
}
