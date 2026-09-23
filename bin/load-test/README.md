# Load testing

`launch.js` is a [k6](https://k6.io) script for stress testing a CWA site: how many
visitors it serves, how quickly, and whether they got the page cache or a fresh
server-side render. It is a manual tool. **It is not wired into CI on purpose**:
a load test sends real traffic, costs money on autoscaled clusters and should only
run when someone decides to run it.

## Install k6

```sh
brew install k6                      # macOS
sudo apt-get install k6              # Debian/Ubuntu, after adding Grafana's apt repo
docker run --rm -i grafana/k6 ...    # or no install at all
```

See <https://grafana.com/docs/k6/latest/set-up/install-k6/>.

## Run it from a cloud VM, not a laptop

Run anything bigger than `smoke` from a VM in the same region as the cluster. A
laptop runs out of sockets and bandwidth first: at around 300 visitors k6 reports
`dial: i/o timeout` long before the cluster notices anything, and the numbers
measure your Wi-Fi. A small VM (2 vCPU) is enough for a few hundred visitors.

## Examples

```sh
# Local stack (self-signed certificate). Local hosts need no confirmation.
BASE_URL=https://localhost INSECURE=true k6 run bin/load-test/launch.js

# Any other host needs CONFIRM=yes.
BASE_URL=https://staging.example.com CONFIRM=yes MODE=smoke    k6 run bin/load-test/launch.js
BASE_URL=https://staging.example.com CONFIRM=yes MODE=capacity k6 run bin/load-test/launch.js
BASE_URL=https://www.example.com     CONFIRM=yes MODE=surge PEOPLE=300 k6 run bin/load-test/launch.js
BASE_URL=https://www.example.com     CONFIRM=yes MODE=soak DURATION=30m k6 run bin/load-test/launch.js

# The same test against the page cache, against SSR, and a realistic mix.
... CACHE=warm  k6 run bin/load-test/launch.js   # cached pages (the default)
... CACHE=cold  k6 run bin/load-test/launch.js   # every page rendered by Nuxt
... CACHE=mixed COLD_RATIO=0.3 k6 run bin/load-test/launch.js

# Specific pages instead of the sitemap.
... PAGES=/,/about,/blog-articles k6 run bin/load-test/launch.js
```

With Docker, pass the variables with `-e` and the script on stdin:
`docker run --rm -i -e BASE_URL=... -e CONFIRM=yes grafana/k6 run - < bin/load-test/launch.js`.
To reach the local stack from the container, share the php container's network so
`https://localhost` is the local Caddy:
`docker run --rm -i --network container:$(docker compose ps -q php) -e BASE_URL=https://localhost -e INSECURE=true grafana/k6 run - < bin/load-test/launch.js`.

## Modes

| `MODE` | What it does | Use it to |
|---|---|---|
| `smoke` (default) | 2 visitors for 30s (`DURATION`) | check the script, the target and the cache headers before anything bigger |
| `capacity` | steps the arrival rate up to `PEAK_RATE` visitors/second, `STAGE` (30s) per step, then holds | find the knee: the rate at which latency runs away. Size pods against this |
| `surge` | ramps to `PEOPLE` visitors over 60s, holds 3m (`DURATION`), ramps down | a launch moment: a URL on a screen and a room reaching for their phones |
| `soak` | `PEOPLE / 6` visitors for 15m (`DURATION`) | steady traffic, to catch leaks and slow degradation |

One visitor loads a page with its `/_nuxt` files, reads for 2-6s, then makes one
client-side navigation, which in CWA is two `/_api` calls (the route and its
resource manifest), not another server-side render. Then reads for 3-9s more.

## Environment

| Variable | Default | Meaning |
|---|---|---|
| `BASE_URL` | (required) | Site origin, e.g. `https://www.example.com` |
| `CONFIRM` | | Must be `yes` for any non-local host (see below) |
| `MODE` | `smoke` | `smoke`, `capacity`, `surge` or `soak` |
| `PEOPLE` | `100` | Simultaneous visitors for `surge`; `soak` uses a sixth, `capacity` derives `PEAK_RATE` from it |
| `CACHE` | `warm` | `warm`, `cold` or `mixed` (see below) |
| `COLD_RATIO` | `0.2` | Share of page loads that bust the cache when `CACHE=mixed` |
| `COLD_API` | `false` | `true` also busts the cache on the `/_api` calls in cold/mixed loads |
| `PAGES` | sitemap | Comma-separated paths, instead of reading the sitemap |
| `MAX_PAGES` | `50` | Most pages taken from the sitemap |
| `MAX_ASSETS` | `12` | Most `/_nuxt` files fetched per page load |
| `DURATION` | `30s` / `3m` / `15m` | Length of smoke, of the surge hold, or of soak |
| `STAGE` | `30s` | Length of each capacity step |
| `PEAK_RATE` | `PEOPLE / 7`, at least 2 | Capacity's top arrival rate, visitors per second |
| `PAGE_P95_MS` | `2000` | Threshold for page time to first byte, p95 |
| `INSECURE` | | `true` skips TLS verification. For the local self-signed stack only |
| `SUMMARY_JSON` | | Also write k6's full summary data to this file |

Pages come from `/sitemap.xml` (following its redirect to `/sitemap_index.xml`
and one level of child sitemaps), with each URL's origin replaced by `BASE_URL`,
the same way the deploy's cache warm reads it (`sitemap_pages` in
`bin/devops/k8s.sh`).

## Cached or rendered: `CACHE`

Page HTML and `/_api` responses are served by the Souin cache in front of Nuxt
and php. A test that only ever hits the cache says nothing about SSR, and the
reverse. So choose what you are measuring:

- **`warm`**: plain anonymous requests, as a visitor sends them. After the first
  request for each page these should be cache hits. This is what visitors get.
- **`cold`**: each page request carries a unique `k6cb=` query value, so every
  one is a cache miss rendered by Nuxt. This is the cost of SSR, and the worst
  case after a purge or deploy. `k6cb` is deliberately not one of the tracking
  parameters the Caddyfile strips (`uri query { -utm_source ... }`); a `utm_`
  or `gclid` buster would be stripped and served from cache.
- **`mixed`**: `COLD_RATIO` of page loads are cold, the rest warm.

The client-side navigation's `/_api` calls stay cacheable unless `COLD_API=true`.

**Cold mode fills the cache.** Every busted request is stored as its own entry
(until it expires, or the pod restarts, since the store is in memory). After a
cold test against a real site, flush it:
`kubectl exec -n <ns> deploy/<release> -- curl -s -X PURGE http://localhost:2019/souin-api/souin/flush`.

## Reading the output

The script replaces k6's default summary with this:

```
=== smoke against https://localhost (CACHE=cold) ===
Time to first byte
  Pages (HTML)         avg 116ms  med 83ms  p95 244ms  max 273ms
  API (/_api)          avg 19ms  med 1ms  p95 108ms  max 113ms
  Static (/_nuxt)      avg 6ms  med 6ms  p95 11ms  max 11ms
Souin cache
  Pages                0% hits  (hit 0, miss 6, bypass 0, no header 0)
  API                  83% hits  (hit 10, miss 2, bypass 0, no header 0)
  => page latency above is mostly SSR rendering (cache misses)
Totals
  ...
```

- **Time to first byte** is split by kind, because a cache hit, an SSR render, an
  API call and a static file differ by orders of magnitude. Read p95, not avg.
  - *Pages* is the cache when hits are high, and Nuxt's SSR when they are low.
  - *API* is php behind Souin; almost all hits once warm.
  - *Static* is Nuxt serving the build's `/_nuxt` files (not cached by Souin).
- **Souin cache** counts the `Cache-Status` header of each response: `hit`,
  `miss` (`fwd=uri-miss`), `bypass` (Souin gave up, e.g. `DEADLINE-EXCEEDED`, a
  render slower than its 10s backend timeout) and `no header` (the request never
  went through the cache: an excluded path, a cookie, or no Souin in front). The
  `=>` line says whether the page numbers measured the cache or SSR.
- **Thresholds**: pages p95 under `PAGE_P95_MS`, 99% of pages 200, API and
  static p95 under 1s, under 1% failed requests. k6 exits non-zero if any fail.
- Requests are tagged `kind=page|api|asset` (and pages `cache_mode=warm|cold`),
  so the per-kind numbers are available in any k6 output (`--out json=...`).

Known local quirks: the home page `/` is never cached on this template's fixture
data (a draft component 404s, see cwa-nuxt-module#324), and dev pages expire after
60s, so a "warm" dev run that starts more than a minute after the last shows misses.

## Traps

- **`Accept-Encoding` is pinned to `gzip`.** k6 cannot decode brotli or zstd,
  which Caddy prefers, and reports an undecodable response just like a server
  error. One run reported 89% "failed" against a perfectly healthy server. Do not
  remove the header.
- **Laptops fail first.** See above.
- **The guard.** Any host other than `localhost`, `127.x`, `[::1]`,
  `host.docker.internal`, `*.local`, `*.localhost` or `*.test` needs `CONFIRM=yes`.
  The check runs before any request is sent. A surge is a small denial of service
  by design: only test a site you are responsible for, tell its owners first,
  expect the autoscaler to add pods (and cost), and keep an eye on it while it runs.
