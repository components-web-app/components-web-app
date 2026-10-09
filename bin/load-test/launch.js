// k6 load test for a CWA site. Manual tool, deliberately not wired into CI.
// See bin/load-test/README.md for the full guide.
//
//   BASE_URL=https://localhost INSECURE=true MODE=smoke k6 run bin/load-test/launch.js
//   BASE_URL=https://staging.example.com CONFIRM=yes MODE=capacity k6 run bin/load-test/launch.js
//   BASE_URL=https://www.example.com CONFIRM=yes MODE=surge PEOPLE=200 CACHE=mixed k6 run bin/load-test/launch.js
//
// TRAP: run it from a cloud VM near the cluster, not a laptop. A laptop runs out
// of sockets and downlink first: around 300 VUs k6 reports `dial: i/o timeout`
// long before the cluster notices anything, and the result measures your Wi-Fi.
//
// Environment (all optional except BASE_URL):
//   BASE_URL      site origin, e.g. https://www.example.com (required)
//   CONFIRM       must be "yes" for any host that is not local (see the guard)
//   MODE          smoke | capacity | surge | soak                 (default smoke)
//   PEOPLE        simultaneous visitors for surge; soak uses a sixth (default 100)
//   CACHE         warm | cold | mixed                              (default warm)
//   COLD_RATIO    share of page loads that bust the cache in mixed (default 0.2)
//   COLD_API      "true" also busts the cache on the /_api calls   (default false)
//   PAGES         comma-separated paths, overrides the sitemap
//   MAX_PAGES     cap on pages taken from the sitemap              (default 50)
//   MAX_ASSETS    /_nuxt files fetched per page load               (default 12)
//   MAX_RESOURCES resources from the manifest fetched per navigation (default 20)
//   RANDOM_SEED   fixes the random choices (pages, timings), so runs compare
//   ORIGIN_IP     send requests for BASE_URL's host to this address (the origin,
//                 skipping a CDN in front); the Host header stays the same
//   DURATION      length of smoke / soak, or the surge hold
//   STAGE         length of each capacity step                     (default 30s)
//   PEAK_RATE     capacity's top arrival rate, visitors/second     (default PEOPLE/7, min 2)
//   PAGE_P95_MS   page time-to-first-byte p95 threshold            (default 2000)
//   INSECURE      "true" skips TLS verification (local self-signed stack only)
//   SUMMARY_JSON  also write k6's full summary data to this file
import http from 'k6/http'
import { check, group, sleep, fail } from 'k6'
import { Trend, Rate, Counter } from 'k6/metrics'

// ---------------------------------------------------------------------------
// Configuration and the production guard. This all runs in k6's init context,
// before setup() and before any request is sent, so a refusal sends nothing.
// ---------------------------------------------------------------------------

const RAW_BASE = (__ENV.BASE_URL || '').trim().replace(/\/+$/, '')
if (!RAW_BASE) {
  throw new Error('BASE_URL is required, e.g. BASE_URL=https://localhost INSECURE=true k6 run bin/load-test/launch.js')
}
const BASE = /^https?:\/\//.test(RAW_BASE) ? RAW_BASE : `https://${RAW_BASE}`
const HOST = (BASE.match(/^https?:\/\/(\[[^\]]+\]|[^/:?#]+)/) || [])[1] || ''

const MODE = __ENV.MODE || 'smoke'
const PEOPLE = Math.max(1, Number(__ENV.PEOPLE || 100))
const CACHE = __ENV.CACHE || 'warm'
const COLD_RATIO = CACHE === 'cold' ? 1 : CACHE === 'mixed' ? Number(__ENV.COLD_RATIO || 0.2) : 0
const COLD_API = __ENV.COLD_API === 'true'
const MAX_PAGES = Number(__ENV.MAX_PAGES || 50)
const MAX_ASSETS = Number(__ENV.MAX_ASSETS || 12)
const MAX_RESOURCES = Number(__ENV.MAX_RESOURCES ?? 20)
const STAGE = __ENV.STAGE || '30s'
const PEAK_RATE = Math.max(2, Number(__ENV.PEAK_RATE || Math.ceil(PEOPLE / 7)))
const PAGE_P95_MS = Number(__ENV.PAGE_P95_MS || 2000)

if (!['smoke', 'capacity', 'surge', 'soak'].includes(MODE)) {
  throw new Error(`MODE must be smoke, capacity, surge or soak (got "${MODE}")`)
}
if (!['warm', 'cold', 'mixed'].includes(CACHE)) {
  throw new Error(`CACHE must be warm, cold or mixed (got "${CACHE}")`)
}
if (!(COLD_RATIO >= 0 && COLD_RATIO <= 1)) {
  throw new Error(`COLD_RATIO must be between 0 and 1 (got "${__ENV.COLD_RATIO}")`)
}

// Anything but a local development host needs CONFIRM=yes. A surge is a small
// denial of service by design, and cold mode stores a new cache entry for every
// request (with prod's long s-maxage those stay until purged or the pod restarts).
const LOCAL_HOST = /^(localhost|127\.\d+\.\d+\.\d+|\[::1\]|host\.docker\.internal|.+\.(local|localhost|test))$/i
if (!LOCAL_HOST.test(HOST) && __ENV.CONFIRM !== 'yes') {
  throw new Error(
    `Refusing to load-test ${HOST || BASE}: it is not a local host. ` +
    `This sends real traffic (MODE=${MODE}, PEOPLE=${PEOPLE}, CACHE=${CACHE}). ` +
    'Only test a site you are responsible for, tell its owners first, and re-run with CONFIRM=yes.',
  )
}

// A value that is NOT in the Caddyfile's `uri query { -utm_source ... }` strip
// list, so it survives into the Souin cache key and every busted request is a
// miss that reaches Nuxt (pages) or php (API). Do not rename it to utm_*, gclid,
// fbclid, srsltid etc.: those are stripped before the cache and would be hits.
const BUST_PARAM = 'k6cb'

// TRAP: pin Accept-Encoding to gzip. k6 cannot decode brotli (or zstd), which
// Caddy's `encode` prefers, and reports the undecodable response in a way that is
// indistinguishable from a server error: one run showed 89% "failed" against a
// perfectly healthy server.
const PAGE_HEADERS = { 'Accept-Encoding': 'gzip', Accept: 'text/html,application/xhtml+xml' }
// What @cwa/nuxt sends for its API fetches. Accept is part of the API cache key
// (Caddyfile, issue #79), so a different value would measure a separate entry.
const API_HEADERS = { 'Accept-Encoding': 'gzip', Accept: 'application/ld+json,application/json' }
const ASSET_HEADERS = { 'Accept-Encoding': 'gzip' }

// ---------------------------------------------------------------------------
// Metrics. Latency is time to first byte (k6's `waiting`), kept apart per kind,
// because a cached page, an SSR render, an API call and a static file differ by
// orders of magnitude and a blended average describes none of them.
// ---------------------------------------------------------------------------

const pageTtfb = new Trend('page_ttfb', true)
const apiTtfb = new Trend('api_ttfb', true)
const assetTtfb = new Trend('asset_ttfb', true)
const pageOk = new Rate('page_ok')
const pageHit = new Rate('page_cache_hit')
// A page view is what a visitor sees: a full page load, or a client-side
// navigation (the route, its manifest and the resources it lists).
const pageViews = new Counter('page_views')
const apiHit = new Rate('api_cache_hit')
const cacheCounters = {}
for (const kind of ['page', 'api']) {
  for (const outcome of ['hit', 'miss', 'bypass', 'none']) {
    cacheCounters[`${kind}_${outcome}`] = new Counter(`cache_${kind}_${outcome}`)
  }
}
// Cloudflare's cf-cache-status, when the site is behind it (HIT, MISS, DYNAMIC, …).
const edgeCounters = {}
for (const outcome of ['hit', 'other', 'none']) edgeCounters[outcome] = new Counter(`edge_${outcome}`)
function recordEdge(res) {
  const v = (res.headers['Cf-Cache-Status'] || '').toUpperCase()
  edgeCounters[!v ? 'none' : v === 'HIT' ? 'hit' : 'other'].add(1)
}

// Souin's Cache-Status: "Souin; hit; ttl=55; ..." on a hit, "Souin; fwd=uri-miss;
// stored" on a miss, "Souin; fwd=bypass; ..." when it did not serve from cache
// (e.g. DEADLINE-EXCEEDED). No header at all means the request never reached
// Souin's matcher (excluded path, a cookie, or no Souin in front).
function cacheOutcome(res) {
  const v = (res.headers['Cache-Status'] || '').toLowerCase()
  if (!v) return 'none'
  if (/(^|;)\s*hit\b/.test(v)) return 'hit'
  if (v.includes('fwd=bypass')) return 'bypass'
  return 'miss'
}

function recordCache(kind, res) {
  recordEdge(res)
  const outcome = cacheOutcome(res)
  cacheCounters[`${kind}_${outcome}`].add(1)
  ;(kind === 'page' ? pageHit : apiHit).add(outcome === 'hit')
}

// The script's random choices (pages, cold loads, reading time). With
// RANDOM_SEED each VU draws the same sequence on every run, so two runs, or two
// sites with the same pages, see the same visitors. (k6's own randomSeed option
// is gone in recent versions.) Cache-busting tokens stay truly random.
let seeded = null
function random() {
  if (!__ENV.RANDOM_SEED) return Math.random()
  if (!seeded) {
    // mulberry32, seeded per VU
    let a = (Number(__ENV.RANDOM_SEED) * 2654435761 + __VU) >>> 0
    seeded = () => {
      a = (a + 0x6D2B79F5) | 0
      let t = Math.imul(a ^ (a >>> 15), 1 | a)
      t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296
    }
  }
  return seeded()
}

function bust(path) {
  const token = `${__VU}-${__ITER}-${Date.now()}-${Math.floor(Math.random() * 1e9)}`
  return `${path}${path.includes('?') ? '&' : '?'}${BUST_PARAM}=${token}`
}

// ---------------------------------------------------------------------------
// Scenarios. PEOPLE is simultaneous visitors; one iteration is one visitor
// (a page load with its assets, reading time, one client-side navigation).
// ---------------------------------------------------------------------------

function capacityStages() {
  // Step the arrival rate up to PEAK_RATE and hold, to find where latency runs
  // away. This is the one to use while tuning: it gives visitors/second per pod.
  const steps = [0.05, 0.125, 0.25, 0.5, 1].map(f => Math.max(1, Math.round(PEAK_RATE * f)))
  const stages = [...new Set(steps)].map(target => ({ duration: STAGE, target }))
  stages.push({ duration: STAGE, target: PEAK_RATE })
  return stages
}

const SCENARIOS = {
  // A couple of visitors for 30s: proves the script, the target and the cache
  // headers are wired up before real load is pointed at anything.
  smoke: {
    executor: 'constant-vus',
    vus: Math.min(PEOPLE, 2),
    duration: __ENV.DURATION || '30s',
  },
  capacity: {
    executor: 'ramping-arrival-rate',
    startRate: 1,
    timeUnit: '1s',
    // An iteration lasts ~10s of simulated reading, so each arrival/second
    // keeps roughly ten VUs busy.
    preAllocatedVUs: Math.max(5, PEAK_RATE * 3),
    maxVUs: Math.max(10, PEAK_RATE * 15),
    stages: capacityStages(),
  },
  // The launch moment: the URL goes on a screen and the room reaches for their
  // phones. Nobody arrives instantly, so ramp over 60s, then hold.
  surge: {
    executor: 'ramping-vus',
    startVUs: 0,
    stages: [
      { duration: '60s', target: PEOPLE },
      { duration: __ENV.DURATION || '3m', target: PEOPLE },
      { duration: '30s', target: 0 },
    ],
  },
  // Steady background browsing, to catch leaks and slow degradation.
  soak: {
    executor: 'constant-vus',
    vus: Math.max(1, Math.round(PEOPLE / 6)),
    duration: __ENV.DURATION || '15m',
  },
}

export const options = {
  scenarios: { [MODE]: SCENARIOS[MODE] },
  ...(__ENV.ORIGIN_IP ? { hosts: { [HOST]: __ENV.ORIGIN_IP } } : {}),
  insecureSkipTLSVerify: __ENV.INSECURE === 'true',
  // Bodies are only read where needed (the sitemap and page HTML, for asset URLs).
  discardResponseBodies: true,
  summaryTrendStats: ['avg', 'med', 'p(95)', 'p(99)', 'max'],
  thresholds: {
    // A page slower than this at a launch is a page nobody sees.
    page_ttfb: [`p(95)<${PAGE_P95_MS}`],
    page_ok: ['rate>0.99'],
    api_ttfb: ['p(95)<1000'],
    asset_ttfb: ['p(95)<1000'],
    http_req_failed: ['rate<0.01'],
  },
}

// ---------------------------------------------------------------------------
// setup(): read the page list once, from PAGES or the sitemap.
// ---------------------------------------------------------------------------

function sitemapLocs(xml) {
  const locs = []
  const re = /<loc>\s*([^<]*?)\s*<\/loc>/g
  let m
  while ((m = re.exec(xml)) !== null) locs.push(m[1].replace(/&amp;/g, '&'))
  return locs
}

// The same approach as sitemap_pages in bin/devops/k8s.sh: /sitemap.xml
// (redirects are followed, e.g. to /sitemap_index.xml), one level of child
// sitemaps, and each <loc>'s origin replaced by BASE_URL. The sitemap may name
// another origin (http://localhost:3000 in dev), and Souin keys on Host.
function toPath(loc) {
  return loc.replace(/^https?:\/\/[^/]+/i, '') || '/'
}

function fetchXml(url) {
  const res = http.get(url, { responseType: 'text', headers: { 'Accept-Encoding': 'gzip' }, tags: { kind: 'setup' } })
  if (res.status !== 200 || typeof res.body !== 'string') {
    fail(`could not fetch ${url} (status ${res.status}${res.error ? `, ${res.error}` : ''}). Set PAGES=/,/about to skip the sitemap.`)
  }
  return res.body
}

function sitemapPages() {
  const root = fetchXml(`${BASE}/sitemap.xml`)
  let locs = []
  if (root.includes('<sitemapindex')) {
    for (const child of sitemapLocs(root)) {
      locs = locs.concat(sitemapLocs(fetchXml(`${BASE}${toPath(child)}`)))
    }
  } else {
    locs = sitemapLocs(root)
  }
  return [...new Set(locs.map(toPath))]
}

export function setup() {
  const pages = __ENV.PAGES
    ? __ENV.PAGES.split(',').map(p => p.trim()).filter(Boolean).map(p => (p.startsWith('/') ? p : `/${p}`))
    : sitemapPages().slice(0, MAX_PAGES)
  if (!pages.length) fail('no pages to test: the sitemap listed none and PAGES is not set')

  console.log(
    `\nLoad test: MODE=${MODE} against ${BASE}\n` +
    `  PEOPLE=${PEOPLE}${MODE === 'capacity' ? ` (capacity peak ${PEAK_RATE} visitors/s)` : ''}\n` +
    `  CACHE=${CACHE}${CACHE === 'mixed' ? ` (COLD_RATIO=${COLD_RATIO})` : ''}${COLD_API ? ', COLD_API=true' : ''}\n` +
    `  ${pages.length} page(s)${__ENV.PAGES ? ' from PAGES' : ` from the sitemap (MAX_PAGES=${MAX_PAGES})`}: ${pages.slice(0, 5).join(' ')}${pages.length > 5 ? ' ...' : ''}\n`,
  )
  return { pages }
}

// ---------------------------------------------------------------------------
// One visitor: a full page load (served from the page cache when warm, rendered
// by SSR when cold), the /_nuxt files it pulls, reading time, then one click.
// A click is client-side in CWA: the route and its resource manifest come from
// /_api, which Souin caches, so no second SSR render happens.
// ---------------------------------------------------------------------------

// The resources a navigation loads: the manifest's IRIs (a tree, from the route
// down to each component), fetched a depth at a time as the module does, up to
// MAX_RESOURCES. The same cap on every site, so one with charts or long pages
// isn't measured against a heavier mix than one without.
function fetchResources(manifest) {
  if (!MAX_RESOURCES || !manifest || manifest.status !== 200 || typeof manifest.body !== 'string') return
  let level
  try {
    level = JSON.parse(manifest.body).resource_iris || []
  } catch {
    return
  }
  let left = MAX_RESOURCES
  const seen = new Set()
  while (level.length && left > 0) {
    const iris = level.map(n => n.iri).filter(iri => iri && !iri.startsWith('/_api/_/routes/') && !seen.has(iri)).slice(0, left)
    iris.forEach(iri => seen.add(iri))
    left -= iris.length
    if (iris.length) {
      const reqs = iris.map(iri => ['GET', `${BASE}${iri}`, null, { headers: API_HEADERS, tags: { kind: 'api', name: 'api resource' } }])
      for (const r of http.batch(reqs)) {
        apiTtfb.add(r.timings.waiting)
        recordCache('api', r)
        check(r, { 'resource 200': x => x.status === 200 })
      }
    }
    level = level.flatMap(n => n.children || [])
  }
}

export default function ({ pages }) {
  const landing = pages[Math.floor(random() * pages.length)]
  const cold = random() < COLD_RATIO

  let assets = []
  group('page load', () => {
    const url = `${BASE}${cold ? bust(landing) : landing}`
    const res = http.get(url, {
      headers: PAGE_HEADERS,
      responseType: 'text',
      tags: { kind: 'page', cache_mode: cold ? 'cold' : 'warm', name: `page ${landing}` },
    })
    pageTtfb.add(res.timings.waiting, { cache_mode: cold ? 'cold' : 'warm' })
    pageOk.add(res.status === 200)
    pageViews.add(1)
    recordCache('page', res)
    check(res, { 'page 200': r => r.status === 200 })

    if (res.status === 200 && typeof res.body === 'string') {
      // Same-origin build files only; a site that serves /_nuxt from a CDN
      // (app.cdnURL) is not measured here, which is usually what you want.
      const found = res.body.match(/\/_nuxt\/[^"'\s<>()?#]+\.(?:m?js|css)/g) || []
      assets = [...new Set(found)].slice(0, MAX_ASSETS)
    }
  })

  // The browser fetches these in parallel off the back of the HTML. They are
  // immutable and cheap, but they land on the same Nuxt pods as SSR. Every
  // iteration is a new visitor, so none are in a browser cache yet.
  if (assets.length) {
    const reqs = assets.map(a => ['GET', `${BASE}${a}`, null, { headers: ASSET_HEADERS, tags: { kind: 'asset', name: 'asset /_nuxt' } }])
    for (const r of http.batch(reqs)) assetTtfb.add(r.timings.waiting)
  }

  sleep(2 + random() * 4) // reading the page

  group('client-side navigation', () => {
    const next = pages[Math.floor(random() * pages.length)]
    const paths = [`/_api/_/routes/${next}`, `/_api/_/resource_manifest/${next}`]
    // The manifest's body is read: it lists the resources the page needs.
    const reqs = paths.map((p, i) => ['GET', `${BASE}${COLD_API ? bust(p) : p}`, null, { headers: API_HEADERS, ...(i === 1 ? { responseType: 'text' } : {}), tags: { kind: 'api', name: p.replace(/\/\/.*$/, '/{path}') } }])
    const [, manifest] = http.batch(reqs).map((r) => {
      apiTtfb.add(r.timings.waiting)
      recordCache('api', r)
      check(r, { 'api 200': x => x.status === 200 })
      return r
    })
    pageViews.add(1)
    fetchResources(manifest)
  })

  sleep(3 + random() * 6)
}

// ---------------------------------------------------------------------------
// Summary. This replaces k6's default end-of-test summary with the numbers that
// matter here; SUMMARY_JSON=path.json also writes k6's full data to a file.
// ---------------------------------------------------------------------------

export function handleSummary(data) {
  const m = data.metrics
  const val = (name, key) => (m[name] && m[name].values[key]) || 0
  const line = (label, metric) => {
    if (!m[metric]) return `  ${label.padEnd(20)} (no data)`
    const p = m[metric].values
    return `  ${label.padEnd(20)} avg ${Math.round(p.avg)}ms  med ${Math.round(p.med)}ms  p95 ${Math.round(p['p(95)'])}ms  max ${Math.round(p.max)}ms`
  }
  const cacheLine = (label, kind) => {
    const n = o => val(`cache_${kind}_${o}`, 'count')
    const total = ['hit', 'miss', 'bypass', 'none'].reduce((s, o) => s + n(o), 0)
    if (!total) return `  ${label.padEnd(20)} (no data)`
    const pct = Math.round((n('hit') / total) * 100)
    return `  ${label.padEnd(20)} ${pct}% hits  (hit ${n('hit')}, miss ${n('miss')}, bypass ${n('bypass')}, no header ${n('none')})`
  }
  const edgeLine = () => {
    const n = o => val(`edge_${o}`, 'count')
    const seen = n('hit') + n('other')
    if (!seen) return ''
    return `\nCloudflare\n  ${'Pages and API'.padEnd(20)} ${Math.round((n('hit') / seen) * 100)}% HIT  (hit ${n('hit')}, other ${n('other')})`
  }
  const pageTotal = ['hit', 'miss', 'bypass', 'none'].reduce((s, o) => s + val(`cache_page_${o}`, 'count'), 0)
  const hitShare = pageTotal ? val('cache_page_hit', 'count') / pageTotal : 0
  const verdict = !pageTotal
    ? 'no page responses recorded'
    : hitShare >= 0.8
      ? 'page latency above is mostly the CACHE (Souin hits), not SSR'
      : hitShare <= 0.2
        ? 'page latency above is mostly SSR rendering (cache misses)'
        : 'page latency above MIXES cache hits and SSR renders; compare warm and cold runs'
  const failedChecks = Object.entries(m)
    .filter(([name, metric]) => metric.thresholds && Object.values(metric.thresholds).some(t => !t.ok))
    .map(([name]) => name)

  const text = `
=== ${MODE} against ${BASE} (CACHE=${CACHE}${CACHE === 'mixed' ? `, COLD_RATIO=${COLD_RATIO}` : ''}) ===
Time to first byte
${line('Pages (HTML)', 'page_ttfb')}
${line('API (/_api)', 'api_ttfb')}
${line('Static (/_nuxt)', 'asset_ttfb')}
Souin cache
${cacheLine('Pages', 'page')}
${cacheLine('API', 'api')}${edgeLine()}
  => ${verdict}
Totals
  requests            ${val('http_reqs', 'count')} (${val('http_reqs', 'rate').toFixed(2)} req/s)
  visitors            ${val('iterations', 'count')} (${val('iterations', 'rate').toFixed(2)}/s)
  page views          ${val('page_views', 'count')} (${val('page_views', 'rate').toFixed(2)}/s)
  page 200s           ${(val('page_ok', 'rate') * 100).toFixed(2)}%
  failed requests     ${(val('http_req_failed', 'rate') * 100).toFixed(2)}%
  thresholds          ${failedChecks.length ? `FAILED: ${failedChecks.join(', ')}` : 'all passed'}
`
  const out = { stdout: text }
  if (__ENV.SUMMARY_JSON) out[__ENV.SUMMARY_JSON] = JSON.stringify(data, null, 2)
  return out
}
