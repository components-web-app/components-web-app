// Fails unless every listed test ran and passed (#157): nothing skipped, filtered out or lost.
import { readFileSync } from 'node:fs'
import { execFileSync } from 'node:child_process'

const listed = JSON.parse(execFileSync('npx', ['playwright', 'test', '--list', '--reporter=json'], { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 }))
const countSpecs = suites => suites.reduce((n, s) => n + (s.specs?.reduce((m, spec) => m + spec.tests.length, 0) ?? 0) + countSpecs(s.suites ?? []), 0)
const expected = countSpecs(listed.suites)

const { stats } = JSON.parse(readFileSync('test-results/results.json', 'utf8'))
const ran = stats.expected + stats.unexpected + stats.flaky
console.log(`Listed ${expected} tests; ${stats.expected} passed, ${stats.unexpected} failed, ${stats.flaky} flaky, ${stats.skipped} skipped.`)
if (ran !== expected || stats.skipped > 0 || stats.unexpected > 0) {
  console.error('Not every test ran and passed.')
  process.exit(1)
}
