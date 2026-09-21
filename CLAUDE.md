# CLAUDE.md — components-web-app

This is the demo/template application for `@cwa/nuxt`. It runs against the shared Docker API at `https://localhost/_api`.

## Scope

This CLAUDE.md is the primary place to track demo fixes, fixture updates, and template changes needed as a result of module-side decisions. Do not modify application code directly unless explicitly asked.

## ⚠ Dependency pins

**`typescript` is pinned to exact `6.0.3` in `app/package.json`** (not `^6`). Do **not** bump it to `7.x`. TypeScript 7 is the native (Go) rewrite with a different package layout — `vue-tsc` (still 3.3.7 as of 2026-07-17, and still the latest) can't drive it and fails the build with `ERR_PACKAGE_PATH_NOT_EXPORTED: ./lib/tsc`. Revisit only once `vue-tsc` officially supports TS 7.

> **⚠ `pnpm up --latest` DOES bump typescript to 7.x — it does not skip it.** (This file previously claimed it "keeps reporting 7.0.2 available and skipping it"; that is wrong. Verified 2026-07-17: it rewrote the exact pin to `"typescript": "7.0.2"`.) An exact pin is **not** protection against `--latest`. After any `pnpm up --latest`, **manually revert `typescript` to `6.0.3` and re-run `pnpm install`**, then confirm the lockfile check below. A correct install prints `- typescript 7.0.2 / + typescript 6.0.3 (7.0.2 is available)` — that skip message is what you want to see.

**Watch for duplicate `vue` copies after dependency changes.** A split (e.g. `3.5.38` pulled by `@unhead/vue` / older `@nuxt/devtools` vs `3.5.39` elsewhere) makes `vue-tsc` throw a huge structural `Ref<HTMLElement>`-not-assignable error (surfaced in `HtmlContent.vue` / `AltHtmlContent.vue` on the `useHtmlContent(...)` call). It can pass a local dev build yet fail CI's `--frozen-lockfile --offline` install. If it recurs, dedupe with `pnpm up --latest` (re-resolves to one vue) or a `pnpm.overrides` pin on `vue`, then verify with `pnpm install --frozen-lockfile && pnpm run build`.

> **A vue split also breaks the production image at runtime, not just `vue-tsc`.** Confirmed in a downstream app (srnte, 2026-07-16) and reproduced from a clean `docker build --target prod`: the container boots and immediately dies with
> ```
> Error [ERR_MODULE_NOT_FOUND]: Cannot find module '/srv/app/server/node_modules/vue/server-renderer/index.mjs'
> imported from /srv/app/server/chunks/nitro/nitro.mjs
> ```
> All copies collapse onto the single Nitro output path `.output/server/node_modules/vue`, so they collide and one wins. There, `nuxt` itself resolved `vue@3.5.38` while the app and `@cwa/nuxt` resolved `3.5.40`; 3.5.38 won. Nitro's tracer had followed vue's *main* entry (copying only `dist/`, `index.js`, `index.mjs`, plus `@vue/runtime-dom`/`shared`/`compiler-dom`), while `nitro.mjs`'s `vue/server-renderer` import resolved against the *other* physical copy — so `server-renderer/` and `@vue/server-renderer` were never copied. The emitted code imports a subpath that isn't in the image.
>
> **Diagnose from the lockfile, not `node_modules`** (a stale `node_modules` is misleading): `grep -nE '^  vue@3\.5\.[0-9]+:' pnpm-lock.yaml` must print exactly one line. **Two distinct `typescript` versions are enough to cause it on their own** — vue takes typescript as an optional peer, so a ts6/ts7 split yields `vue@3.5.40_typescript@6.0.3` *and* `vue@3.5.40_typescript@7.0.2` as separate physical copies of the same version. Aligning typescript to one version fixed it without any `pnpm.overrides`.
>
> A duplicate `@vue/compiler-sfc` from the same split also breaks `nuxt dev` with `No fs option provided to compileScript in non-Node environment` (Vite loads the browser build instead of the Node one).

## ⚠ Local dev environment — findings from srnte (2026-07-16)

Diagnosed in the downstream srnte app; all of these originate in template files and so apply here. **All template-side fixes are now applied here (2026-07-17)** — see each finding.

### 1. Postgres has no statistics → 30s page loads (the big one)

**Symptom:** every page takes ~30s (seen up to 64s) in dev, on every developer's machine, on every fresh `compose up` + fixture load. Erratic — the same request varies 2.3s / 4.2s / 9.6s.

**Cause:** autoanalyze only fires after `50 + 0.1×rows` modifications. Component subclass tables hold **1–26 rows** — permanently below the hard floor of **50** — so **~40 of 46 tables sit at `reltuples = -1` ("never analyzed") forever**. Only the ~139-row parent (`_acb_abstract_component`) ever crosses it. Doctrine's `JOINED` inheritance then emits a **29 LEFT JOIN / 30 table / 105 column** hydration query; with no statistics, selectivities multiply across those joins and estimates compound geometrically — the planner estimated **2.4 billion rows** (331 billion at one node) for a query that returns **0 rows** and touches **1 buffer**. It then throws parallel workers at that estimate, saturating ~9 of 10 cores. Postgres burns the time; PHP just blocks in `ppoll()` on the DB socket. The variance is GEQO — 30 tables ≫ `geqo_threshold=12`, so plans are randomized.

**Measured fix (same data, `ANALYZE` only):** query **2332ms → 0.58ms**; page **36.5s → 1.86s**; DB CPU **585s → 1.2s**.

**Applied in srnte** — `api/frankenphp/docker-entrypoint.sh`, after the migrations block, inside the `DATABASE_URL` guard:
```sh
echo "Updating database statistics..."
php bin/console dbal:run-sql "ANALYZE" --quiet || echo "!* ANALYZE failed (non-fatal); queries may be slow until it runs"
```
Non-fatal by design (`|| …`) so it can never block startup under `set -e`. The DB lives in a persistent volume, so this re-analyzes on every `compose up`. Manual workaround: `docker compose exec database psql -U app -d app -c 'ANALYZE;'`

**Applied here (2026-07-17).** Both the entrypoint `ANALYZE` and, as defence in depth, `autovacuum_analyze_threshold=0` on the `database` service in `compose.yaml`, so any *new* small fixture table can't silently reintroduce this. It is set as a **postgres server startup flag** (`command: [postgres, -c, autovacuum_analyze_threshold=0]`) rather than `ALTER SYSTEM`/`ALTER DATABASE`, which the unprivileged `app` user has no grant for. Still optional if plan variance resurfaces: `-c geqo=off -c join_collapse_limit=30 -c from_collapse_limit=30`.

Verified on a clean `compose up`: entrypoint logs `Updating database statistics...`, `SHOW autovacuum_analyze_threshold` returns `0`, and `count(*) FILTER (WHERE reltuples = -1)` is **0 of 23** tables. The `ANALYZE` needs table ownership — the `app` user owns every table in `public`, so it succeeds; the `|| echo` guard keeps it non-fatal regardless.

> **This is why the bug is so easy to misdiagnose.** It is a pure *planner/CPU* pathology with **zero I/O**. Idle DB CPU (0.01%), tiny tables (139 rows), and a 99.99% cache-hit ratio are all true **and entirely consistent with it** — none of them can detect it. Do not "rule out the database" on those signals. Go straight to `EXPLAIN (ANALYZE, BUFFERS)` and `SELECT relname, reltuples FROM pg_class` (look for `-1`).

### 2. `compose.yaml` capped php at 0.5 CPU, and contradicted the override

The base `compose.yaml` php service carried `deploy.resources.limits.cpus: '0.5'` while `compose.override.yaml` set `reservations.cpus: 0.6` — a reservation **above** the limit. The limit was genuinely applied (verified `NanoCpus: 500000000`, cgroup `cpu.max = 50000 100000`), giving php half a core and throttling ~15% of scheduling periods. Because it was committed to the repo it hit **every** developer.

Removed the whole `deploy.resources` block from `compose.yaml` (resource limits belong in the override). `compose.prod.yaml` never set limits and real deploys are k8s/helm, so nothing there changes.

**Honest caveat:** removing this measured **~0 impact** on the 30s page — the throttling was real but PHP was blocked on the database, not starved of CPU. It's a correctness cleanup, not the performance fix. Don't let it take credit for #1.

**Applied here (2026-07-17), but this template differed from srnte — the cap was never actually in effect.** Here `compose.override.yaml` sets `limits.cpus: '1.5'` (srnte's only set `reservations`), and an override's `limits` *wins* the compose merge over the base. Verified by resolving `docker compose config` against the pre-change `compose.yaml`: effective `cpus` was already **1.5**, not 0.5. So unlike srnte there was no throttling to remove — it was dead config. Removing it is a pure tidy-up with **zero behavioural change**. Don't repeat srnte's `NanoCpus: 500000000` claim for this repo.

### 3. `app/` has no `.dockerignore`

The builder's `COPY --link . .` (`app/Dockerfile:43`) copies the entire host `app/` — including `node_modules` (~869MB / ~79k files, symlink farm and all) — into the build context, and `pnpm install` then runs on top of it. Builds inherit whatever stale state is in the local `node_modules`, so **CI (clean checkout) and local builds are not the same build**, and every local build drags ~1GB of pointless context.

**Applied here (2026-07-17):** added `app/.dockerignore` with `node_modules`, `.nuxt`, `.output`.

### 4. Souin: broken `@use_cache` cookie clause — FIXED (2026-07-17)

**This was previously recorded as "not caching in dev, expected, not a bug". That was wrong on both counts** — there is no dev-conditional anywhere (the same Caddyfile and matcher run in prod), and it was a real bug in the `@use_cache` expression.

**Root cause.** The clause `{http.request.cookie.api_component} == ""` does **not** do what it reads like. An **absent cookie does not resolve to `""`** — unlike a missing *header*, which does (`{http.request.header.Authorization} == ""` works fine; that asymmetry is the whole trap). So the clause matched **only when the cookie was present AND empty**.

Measured against the original expression, `GET /_api/docs.jsonld`:

| Request | Cached? |
|---|---|
| No `Cookie` header at all | no |
| `Cookie: other=1` (unrelated) | no |
| `Cookie: api_component=` (present, empty) | **yes** |
| `Cookie: api_component=abc123` (authenticated) | no |

**Why prod looked fine while dev looked dead:** a logged-out *browser* sends `api_component=` empty, which is the one case that matched — so prod caches. Anything sending no cookie at all (SSR, curl, health checks) silently missed the cache entirely.

**The fix** (`api/frankenphp/Caddyfile`) — cache when the cookie is absent *or* empty, never when it carries a value:
```
!{http.request.header.Cookie}.matches("api_component=[^;]+")
```
The clause's only job is to **never cache an authenticated response**, and this preserves that. It is fail-safe: any ambiguity (e.g. an unrelated cookie merely containing that substring) errs toward *not* caching.

Verified — `frankenphp adapt` clean, and: anon → **cached**; `api_component=` → **cached**; `api_component=abc123` → **not cached**; `/_api/me`, `/_api/logout`, and the Nuxt app `/` → **not cached** (caching stays API-only).

**Gotchas for anyone touching this file:**
- **`unexpected EOF` / `unexpected token` errors after an edit were [#57](https://github.com/components-web-app/components-web-app/issues/57) — FIXED 2026-07-17, see the section below.** If you ever see this again, the single-file mount has come back: check `wc -c < api/frankenphp/Caddyfile` against `docker compose exec php sh -c 'wc -c < /app/frankenphp/Caddyfile'`. A size mismatch means truncation, not a typo. It does not self-heal and `restart` is not enough — `docker compose up -d --force-recreate php`.
- **Quote characters in comments are fine.** An earlier revision of this file claimed Caddy's lexer mis-parses `"` inside a `#` comment — **that was wrong**, and was really the truncation above. Verified: a comment containing quotes added via an in-place write adapts cleanly.
- **`--watch` (dev target, `api/Dockerfile:96`) logs `unable to load latest config` on a partial read** while a file is being written, then loads fine. Those errors are usually noise. **Never read `/config/...` from the admin API to judge a change** — it races the reload and will lie. Use `frankenphp adapt` for syntax, and `docker compose restart php` before measuring.
- The Souin API is on the **admin port 2019**, not 443: `curl http://localhost:2019/souin-api/souin` lists stored keys (`[]` = nothing cached). See `api/.env:30` `CACHE_URL`.

### 7. Single-file bind mounts served a truncated Caddyfile — FIXED (issue #57, 2026-07-17)

**Symptom:** edit the Caddyfile, and Caddy reports `unexpected EOF` / `unexpected token` on a file that is **perfectly valid on disk**. Intermittent-looking, and it sends you hunting for a syntax error that does not exist.

**Cause:** a **single-file** bind mount caches the file's *size*. Replacing the file with a **longer** one (new inode — atomic IDE saves, `mv`, most editor tooling) leaves the container reading it **clipped to the old byte count**. Edits that shrink or preserve length work fine, which is what makes it look random. Measured here: host **4349 B** vs container **4119 B**, cut mid-word — and the reported `unexpected token 'h'` landed on the `http://` in `reverse_proxy`, exactly at the cut.

> **This bug is a liar, and it cost real time.** It caused a wrong conclusion to be written into this file — that quote characters in a `#` comment break Caddy's lexer. They do not. The "evidence" was that atomic edits failed and an in-place edit passed; the variable was the **write method**, never the quotes. If you are debugging a Caddyfile parse error, **compare host vs container byte counts before believing the parser.**

**The fix** (`compose.override.yaml`): stop reading these files through single-file mounts. `./api:/app` was **already** a directory mount — which is immune — so the files were always present at `/app/frankenphp/`; nothing needed rearranging. Removed all three single-file mounts and pointed the dev container at the directory-mounted copies:
```yaml
    entrypoint: /app/frankenphp/docker-entrypoint.sh
    command: ["frankenphp", "run", "--config", "/app/frankenphp/Caddyfile", "--watch"]
```
The `command:` belongs in `compose.override.yaml`, **not** the Dockerfile — the dev image alone has no `/app/frankenphp/` (`COPY --link . ./` only happens in `frankenphp_prod`), so the dependency on the bind mount lives beside the mount. It does duplicate the `frankenphp_dev` CMD in `api/Dockerfile:96`; keep them in sync.

**Verified:** atomic lengthening edit now gives host **4355** = container **4355**; `frankenphp adapt` clean; **`--watch` still hot-reloads over the directory mount** (a header added by an atomic edit appeared in ~1s with no restart, and disappeared again when reverted) — so this strictly *improves* `--watch`, which previously reloaded truncated files. Souin matrix and the entrypoint `ANALYZE` both still pass.

**Bonus — a dead mount removed.** `./api/frankenphp/conf.d/app.dev.ini` **did not exist in git**. Docker's auto-create-missing-source therefore made it on the host as an **empty directory** (dated Jan 2 2025), which is untracked and invisible to `git status` (git cannot track empty dirs). It was mounted over `/usr/local/etc/php/conf.d/app.dev.ini`, where PHP ignored it — `conf.d` only loads `.ini` **files**, not directories. The real dev ini is `20-app.dev.ini`, baked in at `api/Dockerfile:94`. The mount had been silently doing nothing; both it and the stray host directory are gone.

**Production is unaffected** — the Dockerfile bakes the Caddyfile into the prod image; only dev bind-mounts it. CI only builds `--target frankenphp_prod`.

### 6. `composer update` fails with a Flex recipes 404 — stale token in the `/config` volume

**Symptom:** `composer update` dies with
```
The "https://raw.githubusercontent.com/symfony/recipes-contrib/flex/main/index.json"
file could not be downloaded (HTTP/2 404)
```
It looks like a transient GitHub outage or a dead endpoint. **It is neither, and it does not fix itself.**

**Cause:** a **stale GitHub PAT** in the container's `/config/composer/auth.json`. GitHub returns **404, not 401**, for a bad token on `raw.githubusercontent.com`, which is what makes this so misleading. `curl` from the same container returns **200** because it sends no auth — so testing the URL by hand "proves" the network is fine and sends you the wrong way. Test with the token to see it:
```sh
docker compose exec php curl -s -o /dev/null -w "%{http_code}\n" \
  -H "Authorization: token <the-token-from-auth.json>" \
  "https://raw.githubusercontent.com/symfony/recipes-contrib/flex/main/index.json"   # -> 404
```

**Why it persists:** the entrypoint only clears `auth.json` (when `GITHUB_TOKEN` is empty) **inside the `if vendor/ is empty` block**, so once `vendor/` is populated it never runs again — and `/config` is a **persistent volume** (`caddy_config`), so the bad token outlives `compose down`/`up`.

**Fix:** `docker compose exec php rm -f /config/composer/auth.json` (or set a valid `GITHUB_TOKEN`), then re-run `composer update`.

### 5. `[nuxt] instance unavailable` in SSR — RESOLVED, no longer current

Fired from `Fetcher.fetchResource` in production SSR logs; traced to `useRequestHeaders(["cookie"])` being called inside an ofetch `onRequest` interceptor, which ofetch invokes **asynchronously**, after Nuxt's async context is gone.

**Resolved in srnte through dependency updates — do not re-apply anything for this.** No mitigation is present in this template's `nuxt.config.ts` (there is no `experimental: { asyncContext: true }` here) and none is needed. Kept only so the old advice isn't actioned again.

## ⚠ Kubernetes probes — a 1s readiness timeout can brick a pod for good (fixed 2026-08-14)

**Applied here 2026-08-14** — `timeoutSeconds: 5` on the php `readinessProbe`
(`helm/cwa/templates/deployment.yaml`), matching the downstream fix. Issue
[#62](https://github.com/components-web-app/components-web-app/issues/62).
Keep the reasoning: the consequence is far worse than "a probe sometimes fails",
and the git history shows probes being added and removed repeatedly over the
years by people who never got to the bottom of it.

**What happened** (six-site smoking/alcohol project, `alcohol-scotland`,
2026-08-14): a pod sat `0/1 Running` for **three hours** after a GKE node
upgrade rescheduled it overnight. Nothing had deployed — the deployment was
seven days old. The pod was healthy: the probe URL returned **200 in 7ms** when
requested with any other cache key, and `var/prod.log` was empty because the
requests never reached PHP.

| request | result |
|---|---|
| probe's exact key | **504 after 10.0s, every time** |
| same host, `?cb=44219` appended | 200 in 7ms |
| same host, different path | 200 in 0.3s |

10.0s is Souin's backend timeout, logged at startup as `Set backend timeout to 10s`.

**The mechanism.** Souin coalesces upstream fetches through `singleflight`,
keyed on the cache key. A goroutine dump showed the owning call —
`singleflight.doCall` → `Upstream.func2` → FrankenPHP — blocked in `select` for
**177 minutes** (i.e. since pod start) with **1127 later requests parked behind
it** in `wg.Wait()`. That entry never completes, so every subsequent request on
that key waits out the backend timeout and 504s.

The stuck call was **the first probe**. `timeoutSeconds` was unset, so it was
Kubernetes' default of **1 second**. The container waits for the database, runs
migrations and `ANALYZE` before Caddy listens, so by the time it serves anything
the probe's `initialDelaySeconds: 30` has already elapsed and the kubelet polls
immediately — logs show the first probe arriving **0.8s after** `serving initial
configuration` and being cancelled at the 1s mark. That cancelled request is the
goroutine that never returned.

So the chain is: **cold start slower than the initial delay → first probe hits a
cold worker → 1s timeout cancels it → that cache key is dead for the life of the
pod → readiness never succeeds → the pod never joins the Service and never
recovers.** Deleting the pod is the only fix, and only because the replacement
starts with an empty cache. It is a race; five sibling pods happened to win it,
and any pod can lose it on any reschedule.

**Why this template is affected and not just that app:** the probe path
`/_api/_/site_config_parameters.jsonld` matches `@use_cache` in
`api/frankenphp/Caddyfile` (GET, `/_api` prefix, no `api_component` cookie, no
`Authorization`), so it goes through Souin by design.

**The rejected alternative — probe a path Souin does not cache.** It removes the
failure mode rather than narrowing the window, and the matcher already carries
path exclusions (`/_api/logout`, `/_api/me`) so it is easy to add. **Do not do
it.** Those paths are excluded *because* they are auth-varying: an uncached
endpoint here either exposes something that should not be public or does not
answer 200 to an anonymous request, so it cannot serve as a readiness check.
The upstream defect is Souin's — a stalled call should not render its key
permanently unusable — raised as
[darkweak/souin#849](https://github.com/darkweak/souin/issues/849), **where a fix
is now pending**.

**Not changed:** `helm/cwa/templates/pwa-deployment.yaml` also leaves
`timeoutSeconds` unset on its `/_cwa/healthcheck` readiness probe, but that goes
straight to Nuxt with no Souin in front, so a cancelled probe can only flap — it
cannot poison anything.

## ✅ Capacity, autoscaling and build fixes — issue [#69](https://github.com/components-web-app/components-web-app/issues/69) (2026-09-21)

Ported from an srnte deployment that was serving **~1 page/second, flat from 1
to 15 concurrent visitors**. Every item was a template bug, not anything
project-specific. Keep the reasoning: several of these had been wrong for
months while looking fine.

### The HPA had never once worked

`hpa.yaml` targeted `{{ include "cwa.fullname" . }}-api`; `deployment.yaml`
creates the bare `{{ $fullName }}` with **no suffix**. The autoscaler therefore
reported `AbleToScale False / FailedGetScale — deployments.apps
"production-cwa-api" not found` and retried forever — **42,746 events over 161
days** on that cluster. Suffix dropped.

**And fixing the name alone would not have been enough:** `php.resources` had
both CPU lines commented out, and an HPA expresses CPU as a *percentage of the
request*. With no request it reports `cpu: <unknown>` and still never scales.
Added `requests.cpu: 200m`, and deliberately **no CPU limit** — Caddy serves
cached responses on the same thread as everything else and should be free to
burst.

### The PWA could not be scaled at all, and was capped at ~1 render/second

Two separate defects that hid each other:

- `pwa-deployment.yaml` read **`.Values.autoscaling.enabled`** — the *API's*
  flag — to decide whether to emit `replicas:`. With autoscaling on (the
  default) it emitted none, K8s defaulted it to 1, and there was no knob
  anywhere that could change it. It now has its own `pwa.replicaCount` /
  `pwa.autoscaling`, and a new **`pwa-hpa.yaml`**.
- `pwa.resources.limits.cpu: 150m` was the single worst number in the chart. A
  page render costs roughly **150ms of CPU**, so a 0.15-core limit *is* one
  request per second however many pods or visitors there are — the container
  just gets throttled. Now `1000m` limit / `250m` request, memory `1Gi` /
  `256Mi` (an OOMKill mid-render is worse than being slow).

PWA autoscaling targets **70%**, not the API's 90%: SSR is CPU-bound per
render, so at 90% the queue has already formed and the latency is already gone.
The `behavior` block matters as much as the threshold —
`scaleUp.stabilizationWindowSeconds: 0` because a launch spike arrives inside a
minute and the default 5-minute window adds pods *after* it has passed, and a
slow `scaleDown` (600s) so a lull does not leave the next burst cold. Measured
2→4→6 in about two minutes.

### The API is capped at one replica on purpose

`autoscaling.maxReplicas` is now **1** (was 3), and `AUTOSCALE_MAX` in
`bin/devops/k8s.sh` defaults to 1 to match. This is a **behaviour change** for
anyone who was relying on the old default.

It is the stateful tier. Souin's default `otter` store is **in-memory**, and
API Platform purges it at `cache-url: http://localhost:2019/...` — so a write
handled by a second pod never purges the first pod's cache, and with a long
`s-maxage` that staleness is effectively permanent. Mercure's `bolt` transport
is pod-local for the same reason. It also does not *need* to scale: one pod
served **974 req/s** of cached responses. Raise it only alongside a shared cache
store and a clustered Mercure hub.

### `api-url` defaulted to something unusable, so CI overrode it with the worst option

The default was `http://<fullname>` with **no `/_api` prefix** — the API lives
under `/_api` (see `@api_handle` in the Caddyfile), so nothing could use it, and
`bin/devops/k8s.sh` overrode it with the **public** URL. Every SSR render then
hairpinned pod → load balancer → ingress → Caddy → PHP **over TLS, per API
call**. `mercure-url` sitting right beside it in the same configmap already used
the internal service.

Both defaults now carry `/_api`, and `k8s.sh` passes `apiUrl: ~` so the
in-cluster default applies. `apiUrlBrowser` still gets the public URL — that one
genuinely needs it. The Caddyfile's `@internal` matcher + `BROWSER_SERVER_NAME`
exist precisely to rewrite `Host` on these, so generated IRIs still come back
with the public hostname.

**Keep this in the chart, not `k8s.sh`** — `cwa.fullname` handles `trunc 63` and
the "release name already contains the chart name" case, which a shell string
would get wrong.

### `NOTES.txt` called helpers that do not exist

Four calls to `api-platform.name` / `api-platform.fullname` — leftovers from the
api-platform chart this was forked from; there is no such helper in
`_helpers.tpl`. Harmless in CI only because they sit in `else` branches and CI
sets `ingress.enabled=true`. Any `helm lint` or `helm template` with ingress
**disabled** failed outright. Verified both ways: with the old names `helm lint`
fails on `NOTES.txt:18`, with the new ones it passes.

### The Caddy build was broken, and had a duplicate plugin

`--with github.com/dunglas/mercure/caddy` was listed **twice** in
`api/Dockerfile`, and unpinned. `mercure/caddy@v1.0.0` declares `go 1.27`, but
`dunglas/frankenphp:builder` ships **Go 1.26.8 with `GOTOOLCHAIN=local`** so the
toolchain will not self-upgrade — the build dies with `module requires go >=
1.27`. Verified against the module proxy and the image itself:

```
$ docker run --rm --entrypoint sh dunglas/frankenphp:builder -c 'go version; go env GOTOOLCHAIN'
go version go1.26.8 linux/arm64
local                                    # FrankenPHP v1.12.7, Caddy v2.11.4
```

Pinned to **`@v0.24.2`**, the last release declaring `go 1.26`. Checked all
eight plugins against the proxy — mercure is the only one above 1.26, so
nothing else needs pinning. Verified by a real `docker build --target
frankenphp_prod`: it succeeds, and the image carries all eight plugins
(`http.handlers.mercure` with `.bolt`/`.local`, `http.handlers.cache`,
`storages.cache.{otter,badger,nuts}`, `http.handlers.vulcain`).

> **Unpinning checklist — carried over from issue
> [#67](https://github.com/components-web-app/components-web-app/issues/67),
> which was closed once the pin landed. Do all three together:**
> 1. Confirm `dunglas/frankenphp:builder` ships Go 1.27+
>    (`docker run --rm --entrypoint sh dunglas/frankenphp:builder -c 'go version'`).
> 2. Check `api/frankenphp/Caddyfile`'s mercure directives against Mercure 1.0 —
>    `transport`, `publisher_jwt`, `subscriber_jwt`, `anonymous`,
>    `subscriptions`, `cors_origins`. A major bump can rename or drop these.
> 3. Unpin, **or pin to a tested `v1.x`** so a future Mercure major cannot break
>    builds unattended again.

> The explanatory comment sits *inside* the `RUN` line continuation. That is
> safe — BuildKit strips comment lines within a continued instruction, even
> tab-indented ones. Verified with a probe build; this Dockerfile
>
> ```dockerfile
> RUN echo \
> 	a \
> 	# a comment line with a tab indent
> 	b \
> 	c
> ```
>
> executes as `RUN echo a b c`, printing `a b c`.

### `bin/devops/k8s.sh` — per-track sizing

New `PWA_*` knobs mirroring the existing `AUTOSCALE_*` naming
(`PWA_REPLICA_COUNT`, `PWA_AUTOSCALE`, `PWA_AUTOSCALE_MIN`/`_MAX`,
`PWA_AUTOSCALE_CPU_PERCENT`/`_MEMORY_PERCENT`, `PWA_CPU_LIMIT`/`_REQUEST`,
`PWA_MEMORY_LIMIT`/`_REQUEST`).

Review apps and staging must **not** inherit production's pod floor — there are
many of them at once and they exist to be correct, not fast. `deploy` switches
on its `track` argument (`stable`/`canary` → min 2 / max 6; everything else →
min 1 / max 2). An explicit env var always wins; the defaults only fill a gap.
Verified by generating `values.tmp.yaml` for all four tracks.

### Page HTML caching — landed 2026-09-21

Unblocked the same day by the module and bundle updates below, so the two items
#69 left open here are now done:

- **`app/server/plugins/nitroCacheControlPlugins.ts` — deleted.** The module now
  owns response `Cache-Control` through its own Nitro `beforeResponse` hook, so
  the app-side plugin is superseded, not merely dead. It never fired anyway
  (`event.headers` is the *request* headers in h3), and "fixing" it would have
  put an unpurgeable `max-age=7200` in browser caches, where stale HTML
  referencing a previous build's `/_nuxt` hashes 404s and leaves a blank page
  for two hours per visitor.
- **`@use_cache` widened** with a second branch for page HTML. See below.

### ⚠ The CEL expression has no comment syntax, and `frankenphp adapt` will not tell you

Caddy treats everything between the backticks of `@use_cache expression` as an
opaque string and hands it to CEL. **CEL has no `#` comments.** A `#` line in
there is a parse error that `frankenphp adapt` reports as **clean**, because
adapt only checks Caddyfile syntax. It surfaces at runtime as a **crash-looping
php container** (`token recognition error at: '#'`). Hit while writing this;
all commentary now lives in Caddyfile `#` comments *above* the block, and there
is a warning in the file saying so.

`adapt` is necessary but not sufficient — always follow it with
`docker compose up -d --force-recreate php` and check the container reaches
`healthy`.

### What the two-tier purge actually does — verified end to end

**The template sets no page-cache config at all.** From edge
`0.0.0-29833462.0f360ce` (module `930295c`/`f915f27`), `pageCache` defaults to
`enabled: true` and `sharedMaxAge: 3600`. The template briefly carried
`pageCache: { enabled: true }` while the installed edge still defaulted to off, and
removed it on that bump, so `app/nuxt.config.ts` is back to its pre-#69 state.
**Policy (Daniel, 2026-09-21): do not restate or override module or bundle
defaults in the template.** Verified after removing the flag: `/form` is still
`stored` and still carries `cwa-html`. The module tags each cacheable render with
`Surrogate-Key: cwa-html, <every resource IRI it rendered from>`; the bundle
purges those keys on write. Measured on a running stack:

| Action | `/form` | `/blog-articles` |
|---|---|---|
| warm both | `hit` | `hit` |
| `PATCH` the Form component (only on `/form`) | **`uri-miss; stored`** | `hit` |
| `POST` a `SiteConfigParameter` | **`uri-miss; stored`** | **`uri-miss; stored`** |

So a component write drops exactly the pages that rendered it, and a
site-config write drops every page at once through the constant `cwa-html` tag.
That constant is a **cross-repo interface contract** — `RENDERED_HTML_SURROGATE_KEY`
in the module, `HttpCachePurger::RENDERED_HTML_TAG` in the bundle. A mismatch
fails silently by matching nothing. The bundle's
`http_cache.purge_rendered_html_classes` already defaults to
`[SiteConfigParameter]`, so this template needs no API-side config.

Exclusions verified individually — `/login`, `/password-reset`, `/user-area`,
`/_cwa/healthcheck` and `/.well-known/mercure` all return **no `cache-status`
header at all**, meaning the matcher never handed them to Souin, and `/form`
with `Cookie: api_component=abc123` is likewise not cached.

> The Mercure exclusion is the one that is not optional. It is SSE: a cached SSE
> response never completes, connections pile up behind it, and it looks exactly
> like the site falling over.

### ⚠ Two things to know before trusting this in dev

**1. A 404 from any API call makes the whole page uncacheable — the home page is
currently affected.** `CwaFetch`'s `onResponse` accumulates cache directives from
**every** response, including errors. An anonymous SSR render fetches component
IRIs advertised by the resource manifest; a component with `published_at IS NULL`
404s, and that 404 carries Symfony's default `Cache-Control: no-cache, private`.
`readResponseCacheDirectives` sees `private`, sets `storable: false`, and
`buildPageCacheHeaders` returns `{unstorable: true}` — so the page goes out
`private, no-store` and is never stored.

Confirmed on this fixture data: `/` fetches `html_contents/e7a42038…` and
`images/3520e0ba…`, both `published_at = NULL`, both 404, and `/` is never
cached — while `/form`, `/blog-articles` and the rest cache normally. **Do not
read an uncached `/` as the feature being broken.** Raised module-side; a 404 on
a draft component is the normal anonymous path, not evidence of private content.

**2. Dev pages go out `s-maxage=60`; prod pages get the module's one-hour backstop.** `buildPageCacheHeaders` takes `min(pageCache.sharedMaxAge, lowest s-maxage/Expires across the render's API responses)`. The API's `shared_max_age` is **60 in dev** (`config/packages/api_platform.yaml`) and **31557600, a year, in prod** (`config/packages/prod/api_platform.yaml`, confirmed with `APP_ENV=prod debug:config api_platform defaults.cache_headers`). So in prod the module's `sharedMaxAge` (3600 from edge `0f360ce`) is what binds, and the dev value is deliberately short and fine. **An earlier revision of this section, measured only on the dev stack, called the 60 "the real dial" for prod and said it needed deleting. That was wrong; nothing needs changing.** Measure caching claims against `APP_ENV=prod` config, not just the dev stack.

The short dev TTL does **mask purge bugs in testing**: a page will look correctly invalidated within a minute even if nothing purged it. Measure purges immediately before and after the write, as in the table above.

The one limitation that still matters in prod is named in
[api-components-bundle#227](https://github.com/components-web-app/api-components-bundle/issues/227):
a *scheduled* transition only invalidates a page if the scheduled resource was in
the set that rendered it. Cascade invalidation through a nav happens to be covered
in practice, but by accident rather than by design.

**3. A cold dev render can exceed Souin's 10s backend timeout.** The first
request to a page after a restart returned `504 / cache-status: Souin;
fwd=bypass; detail=DEADLINE-EXCEEDED`. It recovered on retry here, but this is
the same backend-timeout surface as the readiness-probe incident (#62), now
extended to page HTML. Worth remembering if a first hit 504s in dev.

## ✅ Dependency update — module + bundle, 2026-09-21

`@cwa/nuxt-edge` `0.0.0-29738617.f442ed3` → `0.0.0-29833297.27a2184` →
`0.0.0-29833462.0f360ce` → `0.0.0-29833650.80c32cb` (admin "purge page cache" button in site settings, verified against the bundle's `POST /_/rendered_html/purge`: admin 204 and pages purged, anonymous 401; admin edits now send only changed fields) → `0.0.0-29833659.4f1d4bb` (session-end cache purge, #293) → **`0.0.0-29833694.0536f7c`** (module fixes #298 dot-path merge, #299 repeated password honours `realtime_validate_disabled`, #300 query-bound fallback, #301 form success resets on a new submit, #302, #303 `allowedComponents` untouched when the prop is omitted, #304 site name on the default OG image, #307 `/_cwa` redirects to the pages listing; previously `4f1d4bb`: the npm package listing lagged the publish by several minutes, but the exact version resolved; earlier, the second bump, same day, brings page caching on by
default, the one-hour page backstop, and the route-binding fix #292; the lockfile
still holds one `vue@3.5.43`, and `pnpm run build` passes), and
`components-web-app/api-components-bundle` `dev-main c629748` → `20aabaf` → `6f86229` → `3cd5034` → **`d6c4213`** (#248: `make:rename-component` wired; `lint:container` now passes).
The second bump brought in the `purge-rendered-html` command (#247). The third
brought in api-components-bundle#245/#246: `RouteGenerator` now throws
`UnroutedParentException` for a page whose parent has no route, and
`CwaFixtureBuilder` throws from `flush()` for a non-template child with no
`route:` under an `isTemplate: true` page that has no `route:` either. **The
template's fixtures are unaffected.** Its only template page
(`nested-topic-template`) has no children; the chapter pages nest under the
*page data* `topic-1`, which is routed. **Verified by loading the whole scaffold
into a throwaway database** on `3cd5034`: exit 0, and `/topic-1` →
`/topic-1/chapter-one` plus both chapters are present. Neither bump changed the
schema.

> A local dev DB can differ from a fresh load without that being a regression.
> This one had blog articles 1–10, but `BlogScaffoldPart` creates exactly three
> (`$i < 3`, unchanged since `44ef21c`). Compare against a fresh load in a
> throwaway database, **never** by running `doctrine:fixtures:load` against the
> dev DB, which purges it.
Carried along by the composer resolve: **api-platform/core 4.3.17 → 4.4.0**,
**doctrine/orm 3.6.7 → 3.7.1**, **doctrine/collections 2.6.0 → 3.1.0**,
doctrine/doctrine-bundle 3.2.4 → 3.3.2.

**One migration generated and applied** — `Version20260921141436`, adding
`_acb_route.live_at` for the bundle's route-level scheduled publication
(api-components-bundle#224). `migrations:diff` is clean afterwards.

### ⚠ The update split `vue` in two, and `pnpm install` alone does not fix it

After `pnpm install` the lockfile held **`vue@3.5.40` and `vue@3.5.43`** where it
had held exactly one copy before — `nuxt@4.4.8` itself stayed on 3.5.40 while the
app and `@cwa/nuxt` moved to 3.5.43. That is the failure mode documented under
*Dependency pins* above: it breaks `vue-tsc` with a structural `Ref<HTMLElement>`
error, and it breaks the **production image at runtime**, because every copy
collapses onto the single Nitro output path and one wins.

**`pnpm dedupe` fixed it cleanly** — one `vue@3.5.43`, and **typescript stayed at
`6.0.3`**. Prefer it to `pnpm up --latest`, which resolves the split too but
rewrites the typescript pin to 7.x and needs a manual revert.

Always check after any dependency change:

```sh
grep -nE '^  vue@3\.5\.[0-9]+:' app/pnpm-lock.yaml   # must print exactly one line
grep -nE '^  typescript@' app/pnpm-lock.yaml         # must be 6.0.3 only
```

`pnpm dedupe` also moved `@nuxtjs/sitemap` 8.2.2 → 8.5.1, within its `^8.2.2`
range. `pnpm run build` passes with `typescript.typeCheck: true`, so `vue-tsc`
is covered.

### Already-applied template change this confirms

`HtmlContent.vue` and `AltHtmlContent.vue` pass a second argument to
`useHtmlContent(htmlContainer, htmlContent)`. That edit predates this session and
was uncommitted; it type-checks and builds against this module version, so it is
correct for the new signature, not a stray.

## ✅ Media CDN URL via `GCLOUD_PUBLIC_URL` — issue [#68](https://github.com/components-web-app/components-web-app/issues/68) (2026-09-21)

`api/config/services.php` used to hardcode `https://cdn.cwa.rocks/` twice — the
GCS adapter's `public_url` and `FlysystemCacheResolver`'s `$rootUrl` — so every
project had to edit it, and any project that forgot served media from *this
template's* CDN. Both now read one parameter:

```php
->set('env(GCLOUD_PUBLIC_URL)', '')
->set('app.gcloud_bucket_public_url', 'https://storage.googleapis.com/%env(GCLOUD_BUCKET)%/')
->set('app.media_public_url', '%env(default:app.gcloud_bucket_public_url:GCLOUD_PUBLIC_URL)%')
```

**The fallback is the bucket's own public URL, not `cdn.cwa.rocks`.** A project
that never sets the variable gets URLs that actually resolve, never somebody
else's domain. Symfony's `default:` processor treats an **empty** value as
missing, so the `""` the chart passes by default falls back correctly.

Wired the same way as `GCLOUD_BUCKET`: `api/.env`, `php.gcloud.publicUrl` in
`helm/cwa/values.yaml` → `gcloud-public-url` in the configmap → the php
container env, and `bin/devops/k8s.sh`. The template's own deploy has
**`GCLOUD_PUBLIC_URL=https://cdn.cwa.rocks/`** set as a GitLab project CI/CD
variable (scope `*`, unprotected, unmasked — matching `GCLOUD_BUCKET`; it is a
public URL, not a secret), so its behaviour is unchanged.

**Verified at runtime, in prod, from the real kernel** — not by reading config:

| `GCLOUD_PUBLIC_URL` | resolved `app.media_public_url` |
|---|---|
| unset | `https://storage.googleapis.com/my-bucket/` |
| `""` | `https://storage.googleapis.com/my-bucket/` |
| `https://cdn.cwa.rocks/` | `https://cdn.cwa.rocks/` |

Cases 2 and 3 reused the container compiled in case 1, which proves the value is
resolved from the environment **at runtime rather than baked in at compile
time**. That is the property that matters: CI builds the image once and k8s
supplies the env. The compiled `api_components.filesystem.gcloud` definition
carries `public_url` as an env placeholder in its constructor arguments — the
bundle's `FlysystemCompilerPass` copies the tag's `config` into
`setArguments()`, which is why `%env()%` works inside a tag attribute here at all.

### The `_preview` prefix never did anything — removed, not parameterised

The adapter tag also carried `'prefix' => '_preview'`. **It was dead config.**
That `config` array becomes League Flysystem's `Filesystem` config, which reads
`public_url` (`Filesystem.php:242`) and never reads `prefix`. The GCS adapter
takes its prefix **only** from its constructor (`GoogleCloudStorageAdapter`
`__construct(string $prefix = '')` → `PathPrefixer`), and
`App\Flysystem\GoogleCloudStorageFactory` never passes one. So objects have
always been written to the **bucket root**.

#68 suggested parameterising the prefix too. Doing that would have created a
variable that silently does nothing, so the key was dropped instead — a
provably zero-behaviour change. A project that genuinely wants a bucket path
prefix must pass it to the adapter constructor in `GoogleCloudStorageFactory`,
and should expect every existing media URL to move when it does.

### GitHub Actions never received any of the media variables

GitLab exports CI/CD variables to jobs automatically; **GitHub Actions does
not** — each must be mapped in the job's `env:`. `GCLOUD_JSON` and
`GCLOUD_BUCKET` were never mapped in `ci.yml` or `production.yml`, so every
GitHub-driven deploy has fallen back to the `no-gcloud-bucket` placeholder. All
three are now mapped in the review, staging and production deploy jobs. They
have to travel together: the new URL fallback is derived from the bucket.

New GitHub settings to document: `secrets.GCLOUD_JSON`, `vars.GCLOUD_BUCKET`,
`vars.GCLOUD_PUBLIC_URL` — all optional, all safely defaulted.

## ✅ Fixed — `make:rename-component` crashed on every run (bundle #248, `d6c4213`)

Found while linting the container for #68, and **unrelated to it**:
`bin/console lint:container` fails in both dev and prod on
`silverback.api_components.maker.make_rename_component`, and the command itself
dies with `Too few arguments to function MakeRenameComponent::__construct(), 0
passed ... exactly 2 expected`.

`services_maker.php` registers it with no `->args()` and no autowiring, but its
constructor needs `IriConverterInterface` and `ManagerRegistry`. The sibling
makers get away with the same registration because their constructors take
nothing. **Pre-existing** — reproduced with the original `services.php`, and the
command was added in bundle `f48eec0` (2026-06-26), long before the previous
lock ref. **Fixed in bundle `d6c4213` (#248)**, which wires both arguments by interface. Verified in this app's real container: `lint:container` passes, and the command runs. It can now serve as a CI gate. It does not affect the running app (the service is only built when
that command runs), but it does mean `lint:container` cannot be used as a CI
gate until it is fixed bundle-side.

## ✅ Purge cached page HTML when the front end deploys — issue #71 (2026-09-21)

Enabling `cwa.pageCache` (#69) created a new deploy-time hazard. Cached page HTML
references the `/_nuxt/*` bundle hashes of the build that rendered it. After a
front-end deploy the new pods serve only the new hashes, so a cached page from the
old build loads scripts and stylesheets that now **404**. The visitor gets an
unstyled page that never hydrates, and it lasts until that cache entry expires.
**In prod that is up to an hour** (the module's `sharedMaxAge` of 3600 binds,
because prod's API `shared_max_age` is a year), plus any `stale-while-revalidate`,
which defaults to 0. In dev it is 60s, which is why it is easy to miss locally.
**This window exists on every front-end deploy until the pipeline purge below is
in place.**

**The API side's answer is
[api-components-bundle#247](https://github.com/components-web-app/api-components-bundle/pull/247)**
(closes #243). It adds a console command,
`silverback:api-components:purge-rendered-html`, which purges exactly `cwa-html`
and nothing else. It also adds `POST /_/rendered_html/purge` (`ROLE_ADMIN`, for an
admin button). The deploy path is the command, run with `kubectl exec` in the php
pod, the same way `load_fixtures()` runs its command. That needs no new credential,
because the pipeline already has exec access. On an app with no purger configured,
the command prints a message and **still exits 0**, so it cannot fail a deploy.
The PR records three rejected alternatives: a helm `post-upgrade` Job (Kubernetes-only),
a PWA `postStart` hook (it fires on every HPA scale-up and would drop the whole HTML
cache under load), and an API-pod startup hook (it never fires on a front-end-only
deploy).

**Implemented and verified (#71).** api-components-bundle#247 merged as `6f86229`,
and the bundle is updated `20aabaf` → `6f86229` (`migrations:diff` clean).
`purge_rendered_html [track]` in `bin/devops/k8s.sh` runs straight after `deploy`
in all eight deploy steps (GitLab review/staging/production/canary, and the same
four in GitHub `ci.yml`/`production.yml`), before `load_fixtures`. It finds each
deployment by its **exact** name label (`cwa` is the API, `cwa-pwa` the PWA; label
selectors never prefix-match), runs `rollout status` on the **PWA** then the
**API**, and `kubectl exec`s the command in the API pod. If either deployment is
missing it exits 1 rather than skipping.

Verified on the running stack. `/form` and `/blog-articles` go `hit` → **miss**
after one run, and `/_api/docs.jsonld` stays **`hit`**, because it is not tagged
`cwa-html`. The pipeline function itself was checked against a stub `kubectl`
for ordering, the stable/canary release names and the failure path.

**Shipped in one commit (`dd04960`): `api/composer.lock` at `d6c4213` together with
the `k8s.sh`/CI calls.** Against an older lock the command does not exist and every
deploy would fail, so **never revert or cherry-pick one without the other.**

**Why the purge is needed even though every deploy restarts the API pod:**
`k8s.sh` sets `podAnnotations.timestamp`, so every `helm upgrade` recreates both
pods and drops the in-memory store. While the PWA is rolling, though, old PWA pods
can render old-build HTML into the **new** API pod's empty cache. Waiting for the
PWA rollout before purging closes that. (#70/#71 originally reasoned that "the API
and PWA deploy separately" here. They don't; the correction is posted on #71.)

`kubectl exec deploy/...` reaches one pod, which is complete only because the API
is capped at one replica. Souin's store is per pod, so raising the cap means
looping over every API pod.

Until then, every front-end deploy leaves the one-hour window described above.

## ✅ Small template fixes — 2026-09-21

These were found by a docs audit on 2026-08-12 and never filed, because the audit
wrongly believed `gh` could not reach this repo. It can: issues live on GitHub, and
GitLab only mirrors the code.

- **`create-cwa`'s instructions were wrong in four ways (#76).** The fixes: `/admin` → `/login`; no host `pnpm dev`, because the `app` container's dev image already runs `pnpm install; pnpm dev` with `app/` and `app/node_modules` bind-mounted, and a host server would never be reached through `https://localhost`; the cert path `api/frankenphp/caddy/certs/` (which does not exist) → `docker compose cp php:/data/caddy/pki/authorities/local/root.crt …` (verified: it yields the Caddy Local Authority root); and `engines.node` `>=18` → `>=22.13.0` (Nuxt needs `^22.12 || ^24.11 || >=26`, pnpm 11 `>=22.13`). Its fixture command now uses `--append`. The host `pnpm install` prompt defaults to **No**, as editor-types-only. Still `0.1.1`, unreleased.
- **`create-cwa` pointed users at a non-existent `/admin`.** It appeared in both the
  generated README's URL table and the CLI's closing output. There is no `/admin`
  route: the layer provides `/login`, and the admin screens live under `/_cwa`.
  Both now say `https://localhost/login`. Because this is in
  `packages/create-cwa/src/`, **the CLI is bumped to `0.1.1`** and needs a release
  (tag `create-cwa/v0.1.1`, see *Publishing* below) to reach users.
- **`publish-create-cwa.yml` leaked into generated projects.** It is this repo's
  release workflow: it publishes `create-cwa` to npm via OIDC on a
  `create-cwa/v*` tag. `packages/` was always excluded, but `.github/` was only
  dropped for the GitLab and "none" CI choices, so every GitHub Actions project
  inherited a workflow with nothing to build and an `id-token: write` grant. It is
  now in `alwaysExclude` in `cwa-manifest.json`. The CLI fetches the manifest from
  `main` at runtime, so **this takes effect for new installs as soon as `main` is
  pushed**, with no CLI release needed.
- **A dead `access_control` rule was removed from `security.yaml`:**
  `{ path: ^/_api/password/(reset|update), roles: PUBLIC_ACCESS, methods: [POST] }`.
  In both dev and prod, the only route under `/_api/password/` is
  `GET /_api/password/reset/request/{username}`, which a POST-only rule can never
  match. Password reset and update actually go through form submissions,
  `^/_api/component/forms/(.*)/submit`, which keeps its own public rule. **Take
  care if you ever add a POST route under `/_api/password/`:** the catch-all
  `^/` rule below requires `IS_AUTHENTICATED_FULLY` for every write, so the new
  route will be auth-only unless you add an explicit public rule for it.

- **Dead `xkey.glue: ' '` removed from `api_platform.yaml` (#72).** It looked as if it
  clashed with the `', '` separator used by Souin and the module, but it was
  never read. API Platform passes `invalidation.xkey.glue` only to
  `VarnishXKeyPurger`. `SouinPurger`, which is the purger wired here, has the
  separator hard-coded (`SEPARATOR = ', '`). Verified live: responses use `', '`,
  and every purge path still works after the removal. If a separator question
  comes up again, check which purger class actually receives the parameter
  (`http_cache_purger.php`) before assuming a mismatch.

Also found and **not** actioned: the migration-race finding from the same audit is
now resolved by default by the php `maxReplicas: 1` cap (#69).

## ⚠ Splitting one file's changes across commits non-interactively (learnt 2026-09-21)

`git add -p` is unavailable here, so today's work was split into commits per
issue with `git diff -U0` and `git apply --cached --unidiff-zero`, keeping only
chosen hunks. **With zero context, `git apply` places each hunk by the line
numbers in its header.** Keep the full diff's numbers after skipping a hunk, and
every later insertion lands shifted by the skipped hunk's size. The first
attempt moved comments in `values.yaml` 4 lines down, into the middle of the
`autoscaling:` block, and made a staged `ci.yml` invalid. `helm lint` still
passed, because comments do not change YAML, so lint cannot catch this.

Two rules if you do this again:
- **Recompute each chosen hunk's new-side start** from only the chosen hunks
  before it: `c = a + offset`, `+1` for a pure insertion, `-1` for a pure
  deletion, where `offset` sums `(new_count - old_count)` of the chosen hunks.
- **Verify after staging** that the file's remaining unstaged `-U0` diff is
  *exactly* the hunks you left out. A misplaced hunk shows up as an extra move
  in that diff, so the check fails loudly instead of committing mangled text.

## ✅ Completed migration — cwa-nuxt-module #252: File API rename (Image → File)

Done (module edge `0.0.0-29725175.a5bb3b4`). All three files migrated and the app builds clean:

- **`app/app/cwa/components/Image/Image.vue`** — `withImage` → `withFile`; template now reads the `files.file.*` map (`files.file.contentUrl`/`displayMedia`/`handleLoad`/`loaded`), guarded with `v-if="files.file?.displayMedia"`, `ref="file"`.
- **`app/app/components/CollectionImage.vue`** — `useCwaImageResource(toRef(props,'iri'), …)` → `useCwaFileField(props, …)` (same flat refs, resolves the resource itself), `<img ref="image">` → `ref="file"`.
- **`app/app/cwa/components/Image/admin/ImageTab.vue`** — collapsed the individual `useCwaResourceUpload` bindings to the new `bind` object: `const { bind } = useCwaResourceUpload(iri)` + `<CwaUiFormFile v-bind="bind" …>`. Note `bind` landed in edge `a5bb3b4` — earlier `72c2b45` did not have it. Default `fileDisplayType` also changed `'Image'` → `'File'`, so delete-confirm copy now says "file" unless you pass `useCwaResourceUpload(iri, 'file', 'Image')`.

Renames for reference: `withImage`→`withFile`, `useCwaImage`→`useCwaFile`, `useCwaImageResource`→`useCwaFileField`, `ImageOpsType`→`FileOpsType`. `fileOps` = `{ fileProp?, imagineFilterName?, imageRef? }`.

## Publishing `create-cwa` to npm

The CLI lives in `packages/create-cwa/`. It is published manually via a git tag — there is no automatic nightly publishing.

**Remotes:** `origin` = GitLab (deploys the application, mirrors to GitHub), `upstream` = GitHub (runs GitHub Actions). Always push to `origin` only — GitLab mirrors commits and tags to GitHub automatically, which triggers the Actions workflow. Do not push directly to `upstream` as it can conflict with the mirror.

**To release a new version:**

1. Bump the version in `packages/create-cwa/package.json` (stays on `0.x.x` until CWA v1)
2. Commit and push: `git commit -m "Bump create-cwa to x.y.z" && git push origin`
3. Tag and push: `git tag create-cwa/vx.y.z && git push origin --tags`
4. GitLab mirrors the tag to GitHub → GitHub Actions workflow triggers → publishes to npm via OIDC

**If the mirror is behind:** Go to GitLab → Settings → Repository → Mirroring repositories and click the sync button (↻) to force an immediate sync.

**No stored token needed for CI.** Publishing uses npm's OIDC Trusted Publishing — GitHub Actions mints a short-lived identity token automatically. Before the first publish, configure the trusted publisher once on npmjs.com: go to `npmjs.com/package/create-cwa/access`, add a Trusted Publisher, set org `components-web-app`, repo `components-web-app`, workflow `publish-create-cwa.yml`.

**First publish (one-time, local):** The package must exist on npm before OIDC can be configured. Run once from inside `packages/create-cwa/`:
```bash
pnpm install && pnpm run build && pnpm publish --access public --no-git-checks
```
Do NOT add `--provenance` here — provenance requires a GitHub Actions runner and will error locally.

**When to bump the version:**
- Changes to `packages/create-cwa/src/` (CLI logic, prompts, post-creation flow)
- Changes to `cwa-manifest.json` that affect what the CLI does (new features, new excludes, new questions)
- Template file changes do NOT need a version bump — the CLI always fetches `main` at runtime, so users get the latest template without a CLI release

## Docs

Any change made to this template application must be reflected in the docs project at `/Users/danielwest/Documents/GitHub/_CWA/docs`. After completing work here, always check whether the docs need updating and flag it if so.

## ✅ Fixed — `UsersFixture` was not idempotent, a second run broke login

**Fixed 2026-08-13** in `api/src/DataFixtures/UsersFixture.php`. Keep the
diagnosis: it is non-obvious, and any site generated from this template before
that date still needs the duplicate-row cleanup at the end.

The fixture used to call the factory with `$overwrite` left at its default:

```php
$this->factory->create($this->adminUsername ?: 'admin', $this->adminPassword ?: 'admin', $this->adminEmail ?: 'hello@cwa.rocks', false, true);
```

`UserFactory::create()` only looks up the existing user when `$overwrite` is
true; otherwise it unconditionally constructs a new one. So every run after the
first persists **another** user with the same username. Nothing at the database
level prevents it — `AbstractUser` declares `#[UniqueEntity]` for `username` and
`emailAddress`, but those are validator constraints and the columns are plain
`#[ORM\Column(length: 255)]` with no `unique: true`; `UserFactory` calls
`$this->validator->validate($user)` and discards the result, so the violation is
computed and thrown away.

The failure surfaces at login, not at fixture load. `UserRepository::loadUserByIdentifier()`
ends in `getOneOrNullResult()`, so two rows raise
`Doctrine\ORM\NonUniqueResultException` and `POST /_api/login` returns a 500.

The fix applied — pass `overwrite: true`, with named arguments so the flags are
readable (the signature is
`create($username, $password, $email, $inactive, $superAdmin, $admin, $overwrite)`,
so the old trailing `false, true` was `inactive: false, superAdmin: true`):

```php
$this->factory->create(
    $this->adminUsername ?: 'admin',
    $this->adminPassword ?: 'admin',
    $this->adminEmail ?: 'hello@cwa.rocks',
    superAdmin: true,
    overwrite: true,
);
```

Note the behaviour this buys: `overwrite: true` **resets the admin password** to
`ADMIN_PASSWORD` on every fixtures run. That is the right trade for a seed
fixture, but it means a password changed through the admin UI will not survive a
reload.

Applied downstream in the smoking/alcohol six-site project (2026-08-10) after a
`doctrine:fixtures:load --append` on `preview.smokinginwales.info` produced a
duplicate admin and 500s on login. Any site already generated from this template
needs both the code fix *and* a cleanup of the duplicate rows —
`DELETE FROM "user"` keeping the oldest row per username.

## ✋ Decided against — `LOAD_DEMO_SCAFFOLD`

The downstream six-site project added a `LOAD_DEMO_SCAFFOLD` env flag on
2026-08-10 so `AppScaffold::build()` could be skipped while `UsersFixture` still
seeded the admin. **Do not port it here, and do not re-propose it.**

Loading fixtures *is* loading the scaffold — that is what the fixtures are. A
site that wants an empty database simply does not run
`doctrine:fixtures:load`, so a second flag to half-run them adds a config
surface (env → `services.php` → `k8s.sh` → helm values → deployment template)
that duplicates a decision the operator already makes by choosing whether to
run the command at all.

If a downstream project genuinely needs admin-only seeding, that belongs there,
not in the template.

## Planned Features

### PWA / offline support (cwa-nuxt-module #258) — ✅ implemented 2026-07-17

**This repo is where the real implementation lands.** The module deliberately ships no service worker (a module dep would force one on every consuming app — the #236 transitive-dep principle), so the template carries the reference config. **The one blocker (safely caching auth-varying API responses) was solved API-side in [api-components-bundle #200](https://github.com/components-web-app/api-components-bundle/issues/200), merged to `main`** — so SW API caching is now safe and is part of this recommendation. Implement from here, not from the original issue text.

> **Implementation status (2026-07-17).** Applied to `app/nuxt.config.ts` and verified with a real `nuxt build`: the generated `.output/public/sw.js` contains the anchored `cwa-api` NetworkFirst route, the `no-store`/`private` `cacheWillUpdate` gate, and `manifest.webmanifest` with the icons. This **replaced a stale parked block** that had been left disabled after PWA "caused issues" — the reconciliation, point by point:
> - `selfDestroying: true` (a kill-switch that unregistered the SW) — **removed**.
> - `registerType: 'autoUpdate'` → **`'prompt'`** (see §4).
> - `runtimeCaching` was commented out; the commented draft was a broad `^${API_URL_BROWSER}/.*` pattern — the exact **over-match anti-pattern** §2 warns against — plus a leftover **Cloudinary** rule from another app. Both **dropped**, replaced with the anchored + gated config in §2.
> - `devOptions.enabled: true` → **`false`**. Running the SW in dev is a prime suspect for the original "issues" (a SW intercepting requests mid-development), and it sidesteps the dev-only `navigateFallback` coalesce below. Enable it deliberately only to test the PWA.
> - `@vite-pwa/nuxt` moved from `dependencies` → **`devDependencies`** (it's a build-time Nuxt module).
> - Manifest (name/short_name/theme_color/icons) was already correct — **kept**.
>
> **Status of the two follow-ups:** both are done. The §4 update UX was built as a notice on 2026-08-14 and **replaced on 2026-09-21 by a silent update on the next navigation** (#73, see §4); the notice component and `app/app/app.vue` are gone. The §6 cache purge when a session ends is **done by the module** (cwa-nuxt-module#293), and the template needs no config for it (see §6).

**Fits the CLI feature system:** add a `pwa` choice to the `features` multiselect in `cwa-manifest.json` and gate the `pwa: {}` block in `app/nuxt.config.ts` with `// @cwa-if:pwa`, matching the existing `navigation`/`image`/`forms` pattern. `@vite-pwa/nuxt` goes in `app/package.json` **devDependencies** (as in the module playground), never a runtime dep.

**Verified stack:** `@vite-pwa/nuxt@1.1.1`. Nuxt 4 works but is **undeclared** — README/npm still say "Zero-config PWA for Nuxt 3"; Nuxt 4 support is real in source (`compatibility: { nuxt: '>=3.6.5' }` since v0.9.0). The only "broken on Nuxt 4" report was a stale-version mistake, since retracted.

**1. App shell precache — safe, do this.**
```ts
pwa: {
  registerType: 'prompt',
  workbox: {
    navigateFallback: null, // MUST be written explicitly — see gotcha
    globPatterns: ['**/*.{js,css,html,png,svg,ico,woff2}'],
  },
}
```
**⚠ `navigateFallback` gotcha:** in the **production** build `@vite-pwa/nuxt` runs `if (!('navigateFallback' in options.workbox)) → default nuxt.options.app.baseURL ?? '/'`. **Omitting the key silently serves the base-URL (usually `/`) app shell for every SSR navigation.** In the prod build *presence of the key*, not its value, disables it — so `navigateFallback: null` works. (Undocumented upstream; the module playground does this correctly.) With it null there is no navigation interception, so `/_cwa/**` needs no denylist — but if an app ever sets a fallback it must add `navigateFallbackDenylist: [/^\/_cwa\//, /^\/login/]`.

> **Precise mechanic (verified in the package source, 2026-07-17):** there are **two** code paths. Prod uses the `in` check above (value-agnostic). But a **dev-only** line runs first — `navigateFallback = navigateFallback ?? baseURL ?? '/'` — and `??` treats `null` as absent, so in **dev the value is coalesced to `/` regardless**. So the "presence, not value" rule holds only for the shipped prod SW; if you ever set `devOptions.enabled: true`, `navigateFallback: null` will *not* disable it in dev. This template sets `devOptions.enabled: false`, so the dev path never runs.

**2. CWA API runtime caching — now safe, via NetworkFirst + a `no-store` gate.** The original issue asked to cache `/_/routes/`, `/_/resource_manifest/` and resource GETs "with auth/draft excluded". Excluding by **URL** is impossible — draft and published share an identical URL (no `?published=` marker; the API picks from the auth cookie alone), the SW can't read auth state (`urlPattern` callback is synchronous; no `document.cookie`; `cookieStore` async + Chromium-only), and Workbox doesn't honour `Cache-Control: no-store` for a configured route. **The fix is not a URL denylist — it's the API marking each response.** As of #200 (`CacheHeadersEventListener`), an authenticated GET of an affected resource (`Route`, `ResourceManifest`, `ComponentPosition`, any Publishable) returns **`Cache-Control: private, no-store`**; anonymous / unaffected responses stay **`public`**. A `cacheWillUpdate` plugin drops anything carrying `no-store`, so the SW cache only ever holds public data — the same rule Souin enforces at the edge.

```ts
runtimeCaching: [
  {
    // anchored to the /_api content paths so the Mercure SSE stream is NOT matched
    // (a broad API-origin pattern would swallow it and break real-time updates)
    urlPattern: ({ url }) => /\/_api\/(?:_\/(?:routes|resource_manifest|pages|layouts|component_groups|component_positions)|page_data|component)\b/.test(url.pathname),
    handler: 'NetworkFirst', // cache is READ only offline; online the network always wins
    options: {
      cacheName: 'cwa-api',
      networkTimeoutSeconds: 3,
      plugins: [{
        cacheWillUpdate: async ({ response }) => {
          const cc = response.headers.get('cache-control') || ''
          if (/no-store|private/.test(cc)) return null // the authoritative gate
          return response.status === 200 ? response : null
        },
      }],
      expiration: { maxEntries: 100, maxAgeSeconds: 60 * 60 * 24 },
    },
  },
]
```

> **⚠ `urlPattern` gotcha — the pattern must be exhaustive AND anchored. Two ways to get it wrong, both silent:**
> - **Under-match:** it must list **every** content endpoint, or offline breaks in a way that's easy to miss. In an early draft of this config the pattern **omitted `resource_manifest`** — and that is the endpoint the primary fetch needs to lay out a page (module #250). Cached routes without their manifest ⇒ **the page cannot render offline**, while the home page (whose manifest happened to be precached differently) still worked — so it looks like "offline mostly works" rather than an outright failure. The current pattern lists `routes`, `resource_manifest`, `pages`, `layouts`, `component_groups`, `component_positions`, `page_data`, `component`. If the module adds a resource type, add it here.
> - **Over-match:** a broad API-origin pattern (e.g. `url.pathname.startsWith('/_api')`) also swallows the **Mercure SSE stream** and `/_api/me`, breaking real-time updates and re-caching auth checks. Keep it anchored to the content paths above. Verify a new pattern against both lists: it MUST match `/_api/_/routes//x`, `/_api/_/resource_manifest//x`, `/_api/page_data/x`, `/_api/component/images/x`; it MUST NOT match `/_api/.well-known/mercure` or `/_api/me`.

**Why NetworkFirst is load-bearing:** the SW cache is only ever *read offline*, so an anonymous visitor can't be served a cached draft online even before the marker is seen. The one residual window — a cache outliving a **logout / cookie expiry** on one device — is closed by **purging the caches on sign-out and on any 401** (see §6). Also mind the HTTP-cache layer: the API must set long **`s-maxage`** (shared/Souin, purgeable) with **`max-age: 0`** — a long `max-age` puts an un-purgeable copy in the browser HTTP cache that a Workbox `fetch()` passes through, so NetworkFirst would serve it stale without reaching Souin.

**3. IndexedDB is a complementary data tier, not a replacement.** The SW now gives app-shell + public-API offline. Page-side IndexedDB persistence of module #257's `routeCache` (already `markRaw`, route-keyed, bounded, serialisable) is still worth having for **auth-aware** data the SW must not hold — the page can read `$cwa.auth.signedIn` / the `cwa_auth` cookie, so it persists only when appropriate. Not either/or. Cross-ref module #259.

**4. Update UX — `registerType: 'prompt'`, applied silently on the next navigation (#73, 2026-09-21).** CWA admins edit inline, so an auto-updating service worker could swap assets mid-edit; with `prompt`, a new worker installs and **waits**. On 2026-08-14 a notice component (`PwaUpdatePrompt.client.vue`, mounted from an `app/app/app.vue` written only for it) asked visitors to reload. **Daniel decided on 2026-09-21 to drop the notice.** `app/app/plugins/pwa-update.client.ts` now applies a waiting worker silently on the next change of path, still held while `$cwa.admin.isEditing`. The component and `app.vue` were both deleted. With no `app.vue`, Nuxt falls back to its built-in default, which is what that file reproduced apart from the notice. Verified: `/`, `/form` and `/login` (which has no CWA layout) all render.

**Why `afterEach`, not srnte's `beforeEach` + `location.assign` (`67e787b`).** In prompt mode `updateServiceWorker()` **ignores its argument**. It only posts `SKIP_WAITING`, and `@vite-pwa/nuxt` registers without `onNeedReload`, so workbox-window's `controlling` listener then calls `window.location.reload()` itself (`vite-plugin-pwa/dist/client/build/register.js`). Started from `beforeEach`, that reload races the `location.assign(to)` navigation and can cancel it, leaving the visitor on the page they were leaving. By `afterEach` the URL is already the destination, so the plugin's own reload lands in the right place. The cost is one extra full load, straight after the navigation. Only a change of **path** counts, so an in-page anchor or a query change never triggers a reload.

API details that are each easy to get wrong, all verified against the installed packages:
- The composable is **`usePWA()`** — `usedPWAState`/`usePWAState` do not exist. `$pwa` is client-only, and undefined until the worker registers.
- The plugin provides a `reactive({…})`, so **`needRefresh` is a plain boolean, not a ref** — no `.value`.
- **`$cwa.admin.isEditing` is also not a ref.** It is a getter over reactive store state (`runtime/admin/admin.d.ts`).
- **Inside `defineNuxtPlugin`, `nuxtApp.$pwa` and `nuxtApp.$cwa` are typed `unknown`**, which fails `vue-tsc`. Type them through the composables: `nuxtApp.$pwa as ReturnType<typeof usePWA> | undefined`, `nuxtApp.$cwa as ReturnType<typeof useCwa>`. Read them lazily inside the router callback, not at plugin setup, so plugin order does not matter.

**⚠ `clientsClaim: true` is required (#73).** The reload that finishes an update fires only when the new worker takes **control** of the page. When the new worker activates, a page the old worker controlled is handed over automatically, but an **uncontrolled** page (the first load that registered the worker, or a Shift-reload) is never claimed without `clientsClaim`, so nothing happens. With the old notice this meant Reload spun forever (found on srnte's production after `075610d`). It is safe with `prompt` because it runs on activation, and activation still waits for `SKIP_WAITING`. Verified in the build: `sw.js` calls `clientsClaim()`, and `self.skipWaiting()` appears only inside the `SKIP_WAITING` message handler.

**5. Mercure offline — ✅ revalidates on reconnect since cwa-nuxt-module#286.** This section used to say the module attached only `onmessage` and never revalidated. **That is no longer true** — verified against the installed edge `0.0.0-29833297.27a2184`, `runtime/api/mercure.js`:
- `onerror` → `handleConnectionLost()` marks `mercureStore.connected = false` and logs a warning.
- `onopen` after a loss → `handleConnectionOpen()` re-fetches **every id in `resourcesStore.current.currentIds`** and saves them. It waits for `requestsInProgress` to clear first.
- The browser's `online` event also triggers the same revalidation if the store is still disconnected.

Because it re-fetches, recovery **no longer depends on the hub running an event store** or on `Last-Event-ID` replay.

**It re-fetches but does not apply.** Each result goes through `saveResource({ isNew: true })`: an unchanged resource is discarded (`isCwaResourceSame`), a changed one is **staged** in `resources.new`, which sets `hasNewResources`. The only thing that reads that is `OutdatedContentNotice` ("The content on this page is outdated") inside the **admin header**, which `CwaRootLayout` renders only when `$cwa.auth.isAdmin`. So after a reconnect **admins are prompted; anonymous visitors see nothing and keep the stale content** until they navigate or reload. Do not describe this as "the page updates itself".

Two further limits: it revalidates only resources **currently on screen** — other pages in the route cache (#257) are not refreshed until fetched again — and the visitor-facing silence above may be a deliberate "don't swap content under a reader" choice or a gap. Unconfirmed; ask module-side before documenting it as either.

**6. Purge the SW caches when a session ends — ✅ done by the module, and the template needs no config** (cwa-nuxt-module#293, edge `0.0.0-29833659.4f1d4bb`; #63 closed in favour of it). When `@vite-pwa/nuxt` is installed and not disabled, the module adds a client plugin with `cwa.auth.clearCachesOnSessionEnd` **defaulting to `['cwa-api']`**, which is this template's runtime cache name (`module.mjs`, `resolveSessionEndCaches`). Verified in the build: the client bundle carries `clearCachesOnSessionEnd:["cwa-api"]`. **Rename the cache in `nuxt.config.ts` and the option has to follow**; otherwise leave it unset, per the no-restating-defaults policy.

What the module does, checked in `runtime/api/auth.js` and `session-caches.js`:
- **It only fires when a session actually ended.** `clearSession()` captures `authCookie === '1'` *before* resetting it. An anonymous visitor's first `/me` 401 also goes through `clearSession()`, so an unconditional purge there would wipe the offline cache on every anonymous visit.
- **It fires on any 401 while signed in**, via `cwaFetch.onUnauthorised`, not only at the next `/me` check. A session that ends during server rendering is carried to the client through `authStore.sessionEnded`.
- **It checks only `'caches' in globalThis`, never whether a service worker is running.** `serviceWorker.controller` is `null` on a first load or a Shift-reload even when the cache exists.
- It deletes from the page with `caches.delete()`. No service-worker code, `postMessage` or `injectManifest` is involved. That is possible because `caches` is exposed on `WindowOrWorkerGlobalScope` and Workbox uses a supplied `cacheName` verbatim.

The actual deletion was **not** exercised in a browser here; the module's unit tests (`session-caches.spec.ts`, `auth.spec.ts`) cover it. Leftover: `ExpirationPlugin`'s IndexedDB (`workbox-expiration`) keeps rows keyed to deleted URLs. That is cosmetic, and they are rewritten when an entry is cached again. `maxAgeSeconds` (4h) stays as a backstop, not the fix.

**API relationship (done):** the `Cache-Control: private, no-store` marker this config depends on is emitted by `api-components-bundle` #200 (merged). Note the API deliberately does **not** send `Vary: Cookie` — it would collapse the static cache-hit rate (cookie cardinality is high and cookies churn), and moving the token to a JS-readable header to `Vary` on instead would trade httpOnly security for cacheability. Marking authenticated responses `no-store` sidesteps `Vary` entirely: the unsafe responses simply aren't stored, so there's no variant to partition.

---

### Project Installer / Scaffolder CLI ✅

`packages/create-cwa/` — published to npm as `create-cwa` (`npx create-cwa my-project`).

Prompts: project name, CI/CD (GitHub Actions / GitLab CI / none), feature multiselect, include fixtures. Fetches `main` via `giget`, removes unselected feature files, strips `@cwa-if:feature` blocks from `nuxt.config.ts`, generates a README, then offers to run `docker compose up -d` and `pnpm install` interactively.

`cwa-manifest.json` at the repo root is the contract between the CLI and the template. Template file changes (entities, components, fixture parts) take effect immediately for new installs without a CLI release. Only changes to CLI logic or the manifest itself need a version bump — see **Publishing `create-cwa` to npm** above.

Two install paths are documented in the repo README:
- `npx create-cwa` — tailored, picks features, clean output
- Clone the repo — full example; users delete `packages/` afterwards

**GitHub issue:** [#56](https://github.com/components-web-app/components-web-app/issues/56)

---

### API Fixture: ExampleFormType scaffold ✅

`AppScaffold.php` has a `/form` page with a `Form` entity wired to `ExampleFormType`. `uiComponent` is set to `'ExampleForm'` so the module resolves `CwaComponentExampleForm`. A "Form Demo" nav link points to the page.

**`ExampleFormType` covers every Symfony form field type:**
- `TextType` — plain text, no validation
- `RepeatedType` + `PasswordType` — password + confirm (use `useCwaFormRepeated`)
- `ChoiceType` (select, not expanded) — "Regarding" subject dropdown
- `EmailType` — email with NotBlank + Email constraints
- `TextareaType` — message with NotBlank constraint
- `ChoiceType` (expanded, single = radio) — yes/no developer question
- `CheckboxType` — single boolean checkbox with `IsTrue` (`NotBlank` does not fire on `false`; see checkbox bug in module CLAUDE.md)
- `ChoiceType` (expanded, multiple = checkbox group) — food interests
- `ChoiceType` (not expanded, multiple = multi-select) — other interests
- `CollectionType` + `ChildType` (compound — `name` sub-field) — use `useCwaFormCollection` with `FormChildEntry`
- `CollectionType` + `TextType` (simple text entries) — use `useCwaFormCollection` with `FormTextEntry`
- `SubmitType` — handled by `useCwaForm.submit()`, no composable needed

**Implementation notes:**

- **Timestamp workaround:** `Form` uses `TimestampedTrait`. Until the `CwaFixtureBuilder::createPositions()` timestamp bug is fixed in the API bundle, `createdAt` and `modifiedAt` are set manually in the fixture before adding to the group.

- **`choices` shape and placeholders:** Symfony `ChoiceType` emits placeholder entries as `{ value: '', label: 'Choose…' }`. These are filtered in the template (`c.value !== ''`) and the label is passed as `:placeholder`. Always add `value-key="value"` and `label-key="label"` to all choice components — without them Nuxt UI binds the full `ChoiceView` object and Symfony rejects it with 422.

- **Checkbox v-model:** Use `get: () => !!checkbox.value.value` / `set: (v) => { checkbox.value.value = v ? '1' : null; checkbox.onInput() }`. The module now initialises unchecked checkboxes to `null` (not `''`), so this pattern is correct and avoids snap-back.

- **Checkbox label HTML:** The `randomCheckbox` label may contain HTML. The template renders it via `v-html` in a `#label` slot.

---

### GitHub Actions CI/CD ✅

Four workflow files have been added to `.github/workflows/`, each calling the same `bin/devops/` shell functions as the GitLab CI:

| File | Trigger | Purpose |
|---|---|---|
| `ci.yml` | Push to any branch | Build API + app images, PHPUnit, Behat, deploy review (non-main) or staging (main) |
| `production.yml` | Manual (`workflow_dispatch`) | Canary or full production deploy via action dropdown |
| `cleanup.yml` | PR closed | Tears down the review environment |
| `performance.yml` | Manual (`workflow_dispatch`) | Sitespeed performance test against any URL |

Images are pushed to GHCR (`ghcr.io/<repo>`). `install_dependencies` (Alpine/`apk`) is skipped in favour of `azure/setup-kubectl` and `azure/setup-helm` actions. All other `bin/devops/k8s.sh` functions are called directly.

**Required secrets:** `KUBECONFIG`, `KUBE_CONTEXT`, `KUBE_NAMESPACE_PRODUCTION`, `JWT_PASSPHRASE`, `JWT_SECRET_KEY`, `JWT_PUBLIC_KEY`, `MERCURE_JWT_SECRET`, `DATABASE_URL`, `ADMIN_PASSWORD`

**Required variables (`vars.`):** `KUBE_INGRESS_BASE_DOMAIN`, `RELEASE_PRODUCTION`, `CORS_ALLOW_ORIGIN`, `TRUSTED_HOSTS`, `ADMIN_USERNAME`, `ADMIN_EMAIL`

**Optional flags (`vars.`):** `CI_DISABLED` (set to `"true"` in this repo on GitHub to prevent mirrored pushes triggering the app pipeline), `BUILD_DISABLED`, `TEST_DISABLED`, `REVIEW_DISABLED`, `STAGING_ENABLED`, `PERFORMANCE_DISABLED`, `ENABLE_DATABASE_FIXTURES`, `KUBERNETES_VERSION`, `HELM_VERSION`

**GitHub issue:** [#55](https://github.com/components-web-app/components-web-app/issues/55)

---

## ✅ Fixed — fixture loading could wipe a live database (#74, 2026-09-21)

**Severity: high for any project deploying with GitHub Actions.** Two faults
combined:
- `load_fixtures` in `bin/devops/k8s.sh` ran `doctrine:fixtures:load
  --no-interaction` **without `--append`**. That empties every table before
  loading. The section below claimed this path "must leave existing content
  alone"; the code never did.
- The GitHub workflows called `load_fixtures` **inside the deploy step, on every
  deploy**, with no `ENABLE_DATABASE_FIXTURES` check. That covered review and
  staging in `ci.yml` and **production** in `production.yml`. GitLab always gated
  its fixture jobs behind the variable and made them manual, but triggering one
  on a live site would still have wiped it.

Fixed:
- `load_fixtures` now passes `--append`.
- GitHub loads fixtures only in a separate **Load fixtures** step with
  `if: vars.ENABLE_DATABASE_FIXTURES == 'true'` (plus `inputs.action ==
  'production'` in production) and `continue-on-error: true`, matching GitLab's
  `allow_failure`.
- **Remaining difference:** GitLab's job is manual. GitHub has no manual step in
  a push-triggered workflow, so the GitHub step runs after each deploy while the
  variable is set. Set it only for a new environment's first deploy.

**Proven in a throwaway database, not just reasoned:**
- **The old command deletes real content.** A marker row, standing in for
  content an editor made, is **gone** after the old command and **kept** after
  `--append`.
- **On a seeded database, `--append` writes nothing.** The scaffold stops on the
  first page route that already exists (exit 7). Routes, pages, components,
  positions and users are **all unchanged**, because the failed load rolled
  back. `UsersFixture` is idempotent (`overwrite: true`).

**Downstream:** srnte's GitHub `ci.yml` has the same unconditional review and
staging calls, and its `k8s.sh` has no `--append`. srnte deploys through GitLab,
so its production is not exposed, but it needs the same fix. No other local
downstream repo carries these GitHub workflows.

## ✅ Removed — the `LOAD_FIXTURES` hook in `app/nuxt.config.ts`

**Removed 2026-08-13.** Do not reintroduce a build-time fixtures hook.

It gated a Nuxt `listen()` hook on `process.env.LOAD_FIXTURES === 'true'`, which
nothing in this repository ever set — absent from `compose.yaml`,
`compose.override.yaml`, the app `Dockerfile`, `package.json` and CI. The hook
had never run, and would not have done the right thing if it had: the body
returned early when `/.dockerenv` existed, and the app only ever runs in a
container here, so the guard disabled it exactly where it would be invoked. It
also shelled out to `doctrine:fixtures:load` **without** `--append`, purging
every table — the opposite of the supported path (`load_fixtures` in
`bin/devops/k8s.sh`, wired to the manual CI jobs), which must leave existing
content alone because a fixtures run against a real site exists to seed its
first admin user.

Loading fixtures locally is
`docker compose exec php bin/console doctrine:fixtures:load --append` — no
build-time configuration needed. The pipeline's `load_fixtures` also appends (#74). The `resolve`/`execSync` imports went with it.

Found in smoking-in-england-cwa (2026-08-12), which inherited the same block from
this template and removed it there first.
