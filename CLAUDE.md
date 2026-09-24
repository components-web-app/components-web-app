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

### 8. SSR and browsers did not share API cache entries — FIXED (2026-09-21)

SSR calls the API on an internal hostname (`php.local` here, the in-cluster
service name on k8s since #69), and `@internal` in `handle @api_handle` rewrites
that Host to `BROWSER_SERVER_NAME` before php runs, so the response is identical
to a browser's. But `cache` runs **before** that rewrite and the key used the raw
`{http.request.host}`, so every SSR-fetched resource was stored under the
internal name. A visitor's first client-side fetch of the same resource missed
and reached php, however well the cache was warmed. Measured: the same resource
was a hit on Host `php.local` and a miss on `localhost`.

**Fix** (`api/frankenphp/Caddyfile`): the key reads `{http.vars.cwa_cache_host}`,
set by two complementary `vars` matchers. For `/_api*`, `/uploads/*` and
`/bundles/*` on a dotless or `.local` host it is `BROWSER_SERVER_NAME`; otherwise
it is the request's own Host. Verified: after one SSR render every stored key uses
`localhost`, and the browser's **first** request for a resource is a hit. Page HTML
is still keyed on its own host, and `api_component=<value>` still bypasses.

`Origin` (in the API's `Vary`) and `Accept` do not split the cache in practice:
the module sends the same `Accept` from SSR and the browser, and same-origin
browser GETs send no `Origin`.

**Fixed module-side in `0fd23d7` (#318). Before that,** the module appended the **whole page query** to every
API fetch, so `?utm_source=…` (or any query) duplicates every API entry for that
render, and a valueless `?k` becomes `k=null`.
[cwa-nuxt-module#318](https://github.com/components-web-app/cwa-nuxt-module/issues/318).

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

**Memory requests trimmed (2026-09-21).** Measured on production just after a
deploy: the API used 192Mi of its 350Mi request, and SSR about 70-80Mi of its
256Mi. srnte reports SSR at about 125Mi under normal load.
- **SSR request 256Mi → 160Mi**, and **no memory target on the SSR HPA** (`~` in
  `values.yaml`, `PWA_AUTOSCALE_MEMORY_PERCENT` defaults to `~`). SSR is
  CPU-bound, and another pod doesn't relieve memory: each holds its own copy of
  the caches. Node rarely returns memory after GC, and an HPA scales down only
  when *every* metric is under target, so the 80% memory target would have added
  pods under normal load at 160Mi (80% is 128Mi) and then kept them. Set the
  variable to re-enable it.
- **API request left at 350Mi.** srnte's suggestion of 512Mi → 384Mi was for its
  own values; the template was already below that.
- **Staging and review apps request less.** CPU is 100m for both tiers, memory
  128Mi for SSR and 256Mi for the API, via `PWA_CPU_REQUEST`/`PWA_MEMORY_REQUEST`
  and the new `PHP_CPU_REQUEST`/`PHP_MEMORY_REQUEST`. Staging keeps a full copy
  running from each push to main until the next production deploy deletes it.
  **Limits are identical on every track**, so the OOM ceiling doesn't change.
  Requests only decide what the scheduler reserves.

The old comment "generous on purpose: an OOMKill mid-render is worse than being
slow" was on the SSR memory *request*, which has no effect on OOMKills; the
limit (1Gi) does.

Rendering the chart locally needs a scratch copy with `helm dependency build` (it
downloads the postgresql chart into `helm/cwa/charts/`, which is gitignored), plus the
secret values `deploy` passes with `--set` (JWT, passphrase, mailer DSN, Mercure keys).

**`Chart.lock` was regenerated on 2026-09-23.** It had been out of sync since March 2023:
it pinned postgresql `12.1.15` from `https://charts.bitnami.com`, while `Chart.yaml` asks
for `~14.3.1` from `oci://registry-1.docker.io/bitnamicharts`, so `helm dependency build`
failed. CI never noticed, because `helm_init` runs `helm dependency update` first, which
rewrites the lock. It now pins **14.3.3**, the version CI was already resolving, so deploys
are unchanged. **After editing `dependencies:` in `Chart.yaml`, regenerate and commit the
lock** (`helm dependency update helm/cwa`, then commit only `Chart.lock`).


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

**Fixed 2026-09-23 (spotted from CK):** that list said `/password-reset`, which
isn't a page. The 404 was simply never cached. The module's real pages,
`/forgot-password` and `/reset-password/<username>/<token>` (the bundle emails that
second path, see `silverback_api_components.yaml`), **were being stored** in the
page cache, including one entry per reset token. They are excluded now. Verified
with fresh URLs: neither returns a `cache-status` header, and `/login` and `/form`
behave as before. `/verify-email` and `/confirm-new-email` stay excluded: the bundle
emails links to them with tokens in the path, even though the module ships no pages
for them yet (they 404 here). **When the module adds or renames an auth page, check
this matcher;** the module's pages are under `@cwa/nuxt`'s `dist/runtime/templates/pages/`.

> The Mercure exclusion is the one that is not optional. It is SSE: a cached SSE
> response never completes, connections pile up behind it, and it looks exactly
> like the site falling over.

### ⚠ Two things to know before trusting this in dev

**1. FIXED in edge `385de21` (cwa-nuxt-module#324, 2026-09-23), and `/` now caches. Kept as history:
a 404 from any API call made the whole page uncacheable, and the home page was
affected.** `CwaFetch`'s `onResponse` accumulates cache directives from
**every** response, including errors. An anonymous SSR render fetches component
IRIs advertised by the resource manifest; a component with `published_at IS NULL`
404s, and that 404 carries Symfony's default `Cache-Control: no-cache, private`.
`readResponseCacheDirectives` sees `private`, sets `storable: false`, and
`buildPageCacheHeaders` returns `{unstorable: true}` — so the page goes out
`private, no-store` and is never stored.

Confirmed on this fixture data: `/` fetches `html_contents/e7a42038…` and
`images/3520e0ba…`, both `published_at = NULL`, both 404, and `/` is never
cached — while `/form`, `/blog-articles` and the rest cache normally. **Do not
read an uncached `/` as the feature being broken.** Re-checked 2026-09-22: `e7a42038`
is a draft of the published `f9b9f1f6`, and `3520e0ba` was never published. Raised
as [cwa-nuxt-module#324](https://github.com/components-web-app/cwa-nuxt-module/issues/324):
a 404 on a draft component is the normal anonymous path, not evidence of private
content. The 404'd IRI stays in the page's `Surrogate-Key`, so publishing it would
still purge the page once it is cacheable.

**2. Pages follow the API's cache lifetime: `s-maxage=60` in dev, a year in prod (module edge `636e924`, cwa-nuxt-module#325, 2026-09-23).** `buildPageCacheHeaders` now takes the lowest of `pageCache.sharedMaxAge`, which is **unset by default**, and the lowest `s-maxage` or `Expires` across the render's API responses. It falls back to 3600 only when no API response gave a lifetime (`FALLBACK_SHARED_MAX_AGE` in `runtime/api/http-cache.js`). The rest of this paragraph is from before that change: *prod pages got the module's one-hour backstop, because `sharedMaxAge` defaulted to 3600.* The API's `shared_max_age` is **60 in dev** (`config/packages/api_platform.yaml`) and **31557600, a year, in prod** (`config/packages/prod/api_platform.yaml`, confirmed with `APP_ENV=prod debug:config api_platform defaults.cache_headers`). So in prod the module's `sharedMaxAge` (3600 from edge `0f360ce`) is what binds, and the dev value is deliberately short and fine. **Daniel (2026-09-22): pages can follow the API's year-long TTL**, because invalidation is purge-driven. Proposed as the module default in [cwa-nuxt-module#325](https://github.com/components-web-app/cwa-nuxt-module/issues/325), not as a template override (policy above). **`staleWhileRevalidate` stays 0**, which was a deliberate decision. **An earlier revision of this section, measured only on the dev stack, called the 60 "the real dial" for prod and said it needed deleting. That was wrong; nothing needs changing.** Measure caching claims against `APP_ENV=prod` config, not just the dev stack.

The short dev TTL does **mask purge bugs in testing**: a page will look correctly invalidated within a minute even if nothing purged it. Measure purges immediately before and after the write, as in the table above.

The scheduled-transition gap
([api-components-bundle#227](https://github.com/components-web-app/api-components-bundle/issues/227),
where a scheduled change only invalidated pages that had rendered that resource) is
**fixed** (closed 2026-09-21). It was the main reason for the one-hour backstop.

**Error pages are never stored (module edge `ee17204`, cwa-nuxt-module#340, 2026-09-24).** Before it, any
page 404 (an unrouted URL, or a route whose `liveAt` is still in the future) went out
`public, s-maxage=3600` with a `Surrogate-Key` and was stored, so a scheduled route
stayed a cached 404 for an hour after going live unless something purged it. Now a
404 goes out `private, no-store` with no `Surrogate-Key`, and a scheduled route is 200
as soon as its time passes. **If a scheduled route is still 404 after its time, check
`cache-status`: a Souin `hit` on a 404 means this has regressed.**

**3. A cold dev render can exceed Souin's 10s backend timeout.** The first
request to a page after a restart returned `504 / cache-status: Souin;
fwd=bypass; detail=DEADLINE-EXCEEDED`. It recovered on retry here, but this is
the same backend-timeout surface as the readiness-probe incident (#62), now
extended to page HTML. Worth remembering if a first hit 504s in dev.

## ✅ Front-end dependency update (2026-09-23)

Updated: `@nuxt/image` 2.1, TipTap 3.28 → 3.31.3 (and `y-tiptap` 3.0.9), `vue-tsc` 3.3.11,
`@types/node` 26.6, **`satori` 0.33.5** (the peer for nuxt-og-image 6.8; the OG image renders
the same) and **`@vite-pwa/assets-generator` 2**. The only breaking change is ESM-only; the
template uses it only through the `generate-assets` CLI, which works. There's a harmless peer
warning against `vite-plugin-pwa`'s `^1.0.0`. `@types/luxon` is removed: nothing uses luxon,
and the module uses dayjs.

Checks:
- The lockfile holds one `vue@3.5.43`, only `typescript@6.0.3` and one Vite (7.3.6).
- The build passes with 0 vue-tsc errors, and a planted error fails it.
- Entry prefetch is still 24, the editor stays out of the hints, and `sw.js` still excludes
  its chunk.
- A browser check passed: anonymous pages are clean, and the admin editor works with
  Underline.

**Nuxt 4.5 is now in (2026-09-23, unblocked by module `63b28a4`, cwa-nuxt-module#336):** `nuxt` 4.5.2,
`@nuxt/ui` 4.11.2 and `@nuxt/devtools` 4.0.0-beta.1. They bring Vite 8.3 (Rolldown) and unhead 3.4. The lockfile holds one
`vue@3.5.43`, only `typescript@6.0.3`, one `vite@8.3.0` and one `@unhead/vue@3.4.1`. No template code changes were
needed. They had been held because under Rolldown the module's `CwaRootLayout` became a
prefetch root, and its admin-only lazy chunks were hinted to every visitor (34 → 60 prefetch
on `/`). The module now strips admin edges from non-admin chunks.

Measured on 4.5 from rendered anonymous HTML:
- **Prefetch:** `/` has 22 files (142 KB), `/login` 23 and `/blog-articles` 23.
- **No admin chunks are hinted**, apart from the two tiny route middlewares and `ConfirmDialog`.
- **The TipTap editor is in no hint.**
- **Modulepreload doubles** (24 → 48 on `/`), because Rolldown splits into more, smaller chunks. That's only about 30 KB more in total.
- **`sw.js`:** 156 entries / 1,628 KiB, with the editor and every `/_cwa` chunk still excluded.
- **The precomputed manifest has moved** to `.output/server/chunks/virtual/precomputed.mjs`.

**Simulated Lighthouse** comes out about 0.7s worse on FCP locally, because of the extra requests. Real devices don't notice: the first-paint investigation (below) showed first paint happens as soon as the CSS arrives, before any JS runs.

**Dev noise:** devtools beta logs `NDT_DEP_0003 extendServerRpc is deprecated`. It's harmless.

**⚠ Fixed 2026-09-23 (#95, reported by hbcp): on 4.5 the dev server never hydrated.** The
client died with `SyntaxError: Identifier '__unhead_devtoolsPlugin' has already been
declared` in `nuxt/dist/head/runtime/plugins/unhead.client.js`. Every page stayed static SSR
HTML, and **Sign In** did a native submit to `/login#`. Production builds were unaffected,
because the plugin is `apply: 'serve'`, so CI stayed green.
- **Why it appeared with 4.5:** the bump moved unhead from 2 to 3. nuxt-seo-utils 8.5.1
  (`treeShakeUseSeoMeta`, on by default) skips unhead's Vite plugin on unhead 2, and
  registers it on unhead 3, because Nuxt itself only does so with `compatibilityVersion >= 5`.
- **The bug is in `@unhead/bundler` 3.4.1** (the latest). Its DevTools plugin calls
  `ctx.addRuntimePlugin(...)` in `configResolved` (`dist/chunks/vite.mjs`), and
  `addRuntimePlugin` just pushes onto an array (`dist/shared/bundler.*.mjs`). Without
  `experimental.viteEnvironmentApi`, Nuxt's dev server runs **two** `vite.createServer`
  calls, client and SSR, over the same plugin instances. So `configResolved` runs twice on
  one context. The served file had `__unhead_validate` imported once (registered at
  construction) and `__unhead_devtoolsPlugin` twice.
- **Fix:** `unhead: { vite: { devtools: false } }` in `app/nuxt.config.ts`. nuxt-seo-utils
  merges `nuxt.options.unhead.vite` into its `Unhead()` call. It turns off only unhead's own
  panel in Vite DevTools. Nuxt DevTools and the `useSeoMeta` transform stay. **The production
  output is unchanged:** a before/after build gave the same 172 client files, byte for byte,
  and differed only in build IDs, timestamps and the order of entries in `styles.mjs`. Remove
  it once an unhead release de-duplicates the registration.
- **Rejected:** `devtools.enabled: false` loses Nuxt DevTools. `treeShakeUseSeoMeta: false`
  drops the production transform. `compatibilityVersion: 5` or `viteEnvironmentApi` would
  avoid the double `configResolved`, but they change the whole build.

**To catch a dev-only hydration break,** load a page in a real browser after any bump that
touches Nuxt, Vite or unhead. A 200 from `curl` proves nothing. Check that
`document.querySelector('#__nuxt').__vue_app__` exists and that there is no `pageerror`.
Wait with `networkidle2`, not `networkidle0`: once the app hydrates, the Mercure stream
keeps a connection open, and `networkidle0` never settles. In dev, the console also shows a
refused `wss://localhost:9777/__ws` (the devtools socket, which isn't exposed through Caddy)
and a 401 from the anonymous `/me`. Both are expected.

**Duplicates that predate this change:** `nuxt` still pulls its own `@nuxt/devtools` 3.x alongside our beta (the beta is the one loaded), plus `@nuxt/kit@3.21.8` and `@nuxt/ui`'s own `@tiptap/*@3.26.1` extensions.

**Lighthouse CI scores are bimodal on shared runners (investigated 2026-09-23).** The same page on the same deploy
scored anywhere from 0.60 to 0.96. In the slow runs, the CI browser paints late while its main thread is idle,
and Lighthouse's simulator then counts hydration, `/me` and Mercure toward FCP and LCP. With 3 runs per page, one
slow run flips the median. That is why `/blog-articles` "dropped" from 94 to 65.
- From a Mac with the same Lighthouse, the same deploy scores 0.96–0.98 (LCP about 2.0s).
- **Real throttled first paint equals LCP:** about 0.56s on a mid-range profile (2× CPU, fast 4G), and about 2.0s on Lighthouse's own low-end profile.
- **A/B builds moved the score by at most about 0.03:** `<UApp>`, `<VitePwaManifest>` and today's dependency updates.
- **`<UApp>` costs about 49 KB gzipped of entry JS** (reka-ui's config, tooltip, toast and overlay providers). The template doesn't use toasts, tooltips or overlays yet. It makes hydration slightly later but has no effect on paint. Kept on purpose, for sites that will use them.

Don't chase CI's simulated numbers. **Changed the same day:**
- **The audit defaults to real throttling** (`PERFORMANCE_AUDIT_THROTTLING=devtools`; `simulate` is still available).
- **5 runs per page and at most 3 pages** (`PERFORMANCE_AUDIT_RUNS`, `PERFORMANCE_AUDIT_MAX_PAGES`), so it's still 15 loads.
- **Pages aren't audited in parallel on purpose:** concurrent Lighthouse runs share the runner's CPU and network, which skews every metric.
- **An aligned text table in the job log**, with ✓/✗/⚠ against each budget, read from `lighthouserc.json` so the marks match `lhci assert`. `summary.md` holds the Markdown for GitHub.
- **Found while doing it:** any `--collect.settings.*` flag on the command line **replaces** `lighthouserc.json`'s whole `collect.settings` block. So the file's `onlyCategories: ["performance"]` never applied, and every audit since #87 ran all four categories. All collect settings are now passed on the command line, and the file holds only the budgets.
- Verified against `preview.cwa.rocks`: `/blog-articles` scored 97 with an LCP of 2.04s (devtools throttling, performance only), matching the investigation's real-throttling measurement. The summary script also reads downloaded CI artifacts: it falls back to the report file's name when the manifest's absolute `/builds/…` path doesn't exist.

- **TypeScript stays at 6.0.3.** `vue-tsc` 3.3.11 still resolves `typescript/lib/tsc`, so it
  can't drive TS 7 (its only TS 7 path is a `@typescript/typescript6` alias).
- **A host `pnpm up` fails with `ERR_PNPM_UNEXPECTED_STORE`,** because the host `node_modules`
  comes from the container's store. Use `pnpm up/remove/dedupe --lockfile-only`, then
  `docker compose restart app`. That also avoids the "host install crashes the dev
  container" problem.

## ✅ Dependency update — module + bundle, 2026-09-21

`@cwa/nuxt-edge` `0.0.0-29738617.f442ed3` → `0.0.0-29833297.27a2184` →
`0.0.0-29833462.0f360ce` → `0.0.0-29833650.80c32cb` (admin "purge page cache" button in site settings, verified against the bundle's `POST /_/rendered_html/purge`: admin 204 and pages purged, anonymous 401; admin edits now send only changed fields) → `0.0.0-29833659.4f1d4bb` (session-end cache purge, #293) → `0.0.0-29833694.0536f7c` → `0.0.0-29833722.a6d5fe9` (form fixes #310, #311, #312) → `0.0.0-29833778.72df02b` → `0.0.0-29833817.42e17f8` → `0.0.0-29833843.0fd23d7` → `0.0.0-29833914.462bc32` → `0.0.0-29834629.339047a` → `0.0.0-29835964.385de21` → `0.0.0-29836053.fe1954c` → `0.0.0-29836164.636e924` → `0.0.0-29836337.fbe401d` → `0.0.0-29836407.6c33a6e` → `0.0.0-29836468.c26c4ed` → `0.0.0-29836514.8704582` → `0.0.0-29836565.63e02d4` → `0.0.0-29836598.63b28a4` (#336, with Nuxt 4.5) → **`0.0.0-29837279.ee17204`** (#340: **error pages are no longer stored in the page cache.** Nuxt renders an error through an internal `/__nuxt_error` request that returns 200, so the module's non-200 check never saw it and the outer 404 inherited `public, s-maxage` and a `Surrogate-Key`; a route scheduled with a future `liveAt` then stayed a cached 404 after going live, because a scheduled go-live involves no write to purge it. #341: choosing **Live** on a route that is already live keeps its stored `liveAt` instead of stamping the current time over it (which also moved every descendant's effective date), and the Routes tab shows "Live since <date>". Verified on the dev stack, anonymously: an unrouted URL and a route scheduled 80s ahead both 404 with `private, no-store`, no `Surrogate-Key` and a Souin `uri-miss` on repeat; 3s after `liveAt` the page is 200 `stored`, then `hit`, with no purge; a second route made live by PATCHing `liveAt` is 200 at once. In headless Chrome as admin, the Routes tab of a route past its `liveAt` read "Live since …" with the stored time, re-choosing Live left it unchanged, and Save Route sent no request (the route's `liveAt` in the API was unchanged). Production build passes with 0 TS errors, the lockfile only changes the module version, and after restarting `app` the dev stack serves `/`, `/form`, `/blog-articles`, `/login` and `/_cwa/pages`, all hydrating), after `c74ef41` (#338: Back/Forward and cross-page `#hash` links wait for the page's content before restoring the scroll position, instead of landing short. Production build passes with 0 TS errors, the lockfile only changes the module version, and the dev stack serves all pages with style blocks as JS modules), after `63e02d4` (opens a new page at the top instead of the previous page's scroll position. Production build passes with 0 TS errors, the lockfile only changes the module version, and the dev stack serves all pages), after `8704582` (cwa-nuxt-module#335: **uploads downscale large images in the browser by default**, through `cwa.upload.image`. It applies to JPEG, PNG and WebP, above a 2560px longest edge or 20 MP, resized to those limits at quality 0.85. The template keeps the defaults, per the no-overrides policy. A 2560px photo is about 6.5 MP, around 80 MB of GD memory, so admin uploads stay far inside the 512M `memory_limit` and the 40 MP `Image::$file` cap, which remain the safety net for direct API uploads. Production build and type check pass, and the dev stack serves `/`, `/form`, `/login` and `/_cwa/pages`), after `c26c4ed` (keeps the admin selection overlay mounted while it's being replaced. The production build and type check pass, the lockfile only changes the module version, and after restarting `app` the dev stack serves `/`, the blog, `/login` and `/_cwa/pages`, with style blocks as JS modules), after `6c33a6e` (#329 and #92. The module now realpaths its layer pages in production (`9a506f8`) and exports the layer as `@cwa/nuxt/layer` (`6c33a6e`). **`app/nuxt.config.ts` now uses `extends: ['@cwa/nuxt/layer']`**, not the path into `node_modules`: Node resolves a package name through the real path, so pnpm's symlink no longer defeats Nuxt's page-prefetch filter (nuxt/nuxt#36401). The export exists only from `6c33a6e`, so never pair that `extends` with an older module. Verified with a production build: the entry's prefetch hints went from 85 to **24**, and none of them are `/_cwa` or auth pages any more. The dev stack serves `/`, the blog, `/login` and `/_cwa/pages`. Lockfile: one `vue@3.5.43`, only `typescript@6.0.3`), after `fbe401d` (#328: the admin lists and the route picker send one `search` parameter, which API Platform 5 and the bundle's QueryParameters need. **This is what lifts the deploy hold on the API Platform 5 commit.** #333: `useHtmlContent` returns `vCwaHtml`, which the template adopts in #90. #332: the playground editor is lazy. It also drops luxon, part of #331. Verified against the local API Platform 5 stack as an admin: `users?search=`, `_/routes?search=` with the picker's old parameters alongside, `_/pages?search=` and `blog_article_datas?search=` all filter. Pages and `/_cwa` render, the throwaway production build passes its type check, and the lockfile holds one `vue@3.5.43` and only `typescript@6.0.3`), after (#325: pages follow the API's cache lifetime instead of being capped at an hour; the 3600 is now only a fallback when no API response gives a lifetime. Dev pages still go out `s-maxage=60`, the dev API's value, and still cache (`/` and `/form`: stored, then hit). In prod they now get the API's year. The deploy purge (#71) and the flush command are what keep that safe. `pnpm run build` passes, the lockfile holds one `vue@3.5.43` and only `typescript@6.0.3`, and `app` was restarted), after (#326: site settings gains **Purge all cached data**, behind a confirmation, calling the bundle's `POST /_/http_cache/purge` through `SiteConfig.purgeHttpCache()`. It is available whether or not page caching is on. This edge was published from the module's `dev` branch before it was merged to `main`, so check the npm dist-tag, not only `main`, for a newer edge. `pnpm run build` passes, the lockfile holds one `vue@3.5.43` and only `typescript@6.0.3`, and pages render after restarting `app`. The button itself was not clicked in a browser; the endpoint it calls was verified on the bundle bump), after (#324: a nested resource that is not public yet no longer makes the whole page uncacheable, so `/` should now cache; also re-reads a component's elements when its root changes without a remount. Verified on the dev stack: `/` is now `stored` then `hit`, and its `Surrogate-Key` still carries the two draft IRIs (`e7a42038…`, `3520e0ba…`), so publishing either still purges it. `pnpm run build` passes, the lockfile holds one `vue@3.5.43` and only `typescript@6.0.3`, and the app was restarted after the host install. The #326 button was not in this edge), after (#322: the Add component dialog shows an error instead of spinning forever when the API docs fetch fails, and reopening it retries. Found through #83. `pnpm run build` passes, the lockfile holds one `vue@3.5.43` and only `typescript@6.0.3`, and pages render after restarting `app`. The failure path was not exercised in a browser), after (#319: choosing styles on a component still being added no longer repeats or ignores them. Checked with `nuxi typecheck` and the lockfile checks only: the local stack was down, so not exercised in a browser), after (#318: the page query is forwarded only to collection fetches, encoded, with no `=null`. Verified: a render with a fresh `?utm_source=…` query stored no new API entries), after (#317: `<CwaComponentGroup>` resolves `location` to the published IRI itself, so `:location="iri"` keeps a nested group's children when its component has a draft. The template's groups sit in layouts and pages, which aren't publishable, so they are unaffected, but component-level groups added later are now safe. #316: a reordered component no longer lands in the wrong position), after (the concurrent SSR fixes #313/#314. Verified on the template: the concurrent 404-swap test is **0/12 wrong on a production build** (was 3/8) and 0/12 on the warm dev server (was 8/8); a freshly restarted dev server times out with 504s under concurrency while Vite compiles, and that is not the bug), after (module fixes #298 dot-path merge, #299 repeated password honours `realtime_validate_disabled`, #300 query-bound fallback, #301 form success resets on a new submit, #302, #303 `allowedComponents` untouched when the prop is omitted, #304 site name on the default OG image, #307 `/_cwa` redirects to the pages listing; previously `4f1d4bb`: the npm package listing lagged the publish by several minutes, but the exact version resolved; earlier, the second bump, same day, brings page caching on by
default, the one-hour page backstop, and the route-binding fix #292; the lockfile
still holds one `vue@3.5.43`, and `pnpm run build` passes), and
`components-web-app/api-components-bundle` `dev-main c629748` → `20aabaf` → `6f86229` → `3cd5034` → `d6c4213` → `1ae433f` → `b753b92` → `5978fe8` → `9035b78` → `3abfcfa` → `968164e` → `d1cfc01` → `df7d78d` → `6825d1c` → **`9432387`** (#304/#305: Mercure subscribe topics are built from the operation's registered route, so they include the app's `/_api` prefix. Before this, the admin's `mercureAuthorization` cookie listed 16 topics and none of them had `/_api`, so they never matched the published `/_api/…` IRIs, and admins could miss live draft updates. Verified by decoding the cookie after the update: 16 of 16 topics now carry `/_api`. `migrations:diff` clean, `lint:container` passes in dev and prod, PHPUnit and `composer audit` clean), after `6825d1c` ( (#303 removes `OrSearchFilter`, which the template stopped using in #89, so this is a no-op here. Any other application still declaring `#[ApiFilter(OrSearchFilter::class, …)]` must migrate to QueryParameters before taking this. `migrations:diff` clean, `lint:container` passes in dev and prod), after `df7d78d` (**API Platform 4.4.0 → 5.0.0**, doctrine/orm 3.7.1 → 3.7.2. The bundle now accepts `^4.4 || ^5.0` (#296, then #302). Daniel chose 5.0 on 2026-09-23. Its fixes since release were routine, and none touched what the template uses. Also brings #297 (the bundle's resources take `search=`), #300 and #301. `migrations:diff` clean, `lint:container` passes in dev and prod, and `reference.php` was regenerated (API Platform 5 removed `varnish_urls`, `xkey`, `query_parameter_validation`, `enable_link_security`, `resource_class_directories` and `graphql_playground`, none of which the template uses). PHPUnit, Behat in a throwaway database, and the Souin purge test pass. **It ships in the same commit as #89's filter migration.** Without that, the blog search box sends `?title=`, which is now silently ignored. **Deploy hold:** not pushed until cwa-nuxt-module#328 lands. The module's admin list searches and the route "forward to" picker still send per-field parameters, which are now ignored, so they return everything), after `d1cfc01` (#293/#295: API Platform's default `exception_to_status` mappings are kept alongside the bundle's. Before, the bundle's prepend replaced them, so invalid input and serializer errors returned 500. Verified on the dev stack as an admin: a malformed JSON body and a wrongly-typed field on `POST /_api/component/html_contents` both return **500 on `968164e` and 400 on `d1cfc01`**, with "The type of the \"html\" attribute must be…". `debug:config api_platform exception_to_status` lists only the bundle's four entries even so, so test with a request, not the config dump. Also carries #288 (`OrSearchFilter` 400s instead of 500s on an invalid integer value, which this template's string-only `User` filter never hit, plus removed-class clean-ups) and CI-only changes (#292, #294). `migrations:diff` clean, `lint:container` passes in dev and prod, and pages render. The bundle can now support API Platform 5.0 (#296, open). `api/composer.json` doesn't require API Platform directly, so a plain `composer update` could take this template to 5.0; update the bundle alone with `composer update components-web-app/api-components-bundle`), after `968164e` (#290/#291: `silverback:api-components:purge-http-cache` and `POST /_/http_cache/purge` flush the whole Souin cache, API and HTML together. Verified on the dev stack: `purge-rendered-html` still drops only pages; `purge-http-cache` exits 0 and drops pages and `/_api/docs.jsonld`; the endpoint returns 401 anonymously and 204 for an admin, and clears the API cache. `migrations:diff` clean, `lint:container` passes in dev and prod. Deploys still use `purge_rendered_html`: an API pod restart already empties `otter`, so the full flush waits for scaled mode, #85. `composer audit` reported 5 guzzlehttp/guzzle advisories, which predated this bump. **They're cleared as of 2026-09-23 by guzzle 7.15.0 → 7.15.5**, taken with patch-level Symfony (`browser-kit`, `dotenv`, `phpunit-bridge`, `web-profiler-bundle`, `yaml`, `monolog-bundle` 4.1), `maker-bundle` 1.68 and `roave/security-advisories`. After it, `composer audit` is clean, `lint:container` passes in dev and prod, and PHPUnit passes. **The major upgrades were done later that day, each as its own commit:**
- **Flysystem to tagged releases (`a58bbf9`).** The pin was the `3.x-dev` branch, added in May 2025 for an unreleased fix. The old dev commit is 0 commits ahead of 3.36.0, so nothing is lost; the GCS adapter's dev commit is identical to 3.34.0. Constraints are now `^3.0`. It also pulls newer google/* packages and **guzzle 8** (google/auth and cloud-core accept `^7.8.2||^8.0`). Verified: an image upload through the local adapter serves the original and its imagine thumbnail, and a delete removes both.
- **doctrine-migrations-bundle 4.0.1 (`18c5228`).** 4.0 only drops old PHP, ORM and DoctrineBundle versions and container-aware migrations, none of which apply. A full migrate from empty in a throwaway database passes, as does `schema:validate`.
- **mercure-bundle 0.5 with symfony/mercure 0.8 (`3a649ad`).** **Mercure 0.8 changes `HubInterface`:** it adds `getProtocolVersion()` and `getCookieName()`, and moves `getUrl()` to `RemoteHubInterface`. `App\Mercure\SkipAwareMercureHub` now implements `RemoteHubInterface` and forwards them, as the bundle's `PublishableAwareHub` does. **Any other hub decorator needs the same change, or `cache:clear` dies with a fatal error.** `mercure.yaml` is unchanged (protocol 0.x). Verified: create, patch and delete each publish, and fixtures with `SKIP_MERCURE_PUBLISH=true` publish nothing.
- **PHPUnit 13 (`9f3b7d8`).** `simple-phpunit` downloads its own PHPUnit 9.6, which can't read the new config. So `run_test_phpunit` in `k8s.sh` now runs **`vendor/bin/phpunit`**, `api/bin/phpunit` is removed, and `phpunit.xml.dist` is migrated (`<source>`, the bridge's `SymfonyExtension`, and `.phpunit.cache/` gitignored). **Don't reintroduce `simple-phpunit` or `SYMFONY_PHPUNIT_VERSION`.**
- **Flysystem 4 is not done:** only `4.x-dev` exists. liip/imagine-bundle allows only `^1|^2|^3`, and the bundle's dev requirements pin `^3.36`.

**A `composer update` inside the running dev container can cause a few minutes of 500s** while `vendor/` is rewritten (a stale opcache or autoloader, such as a fatal error on a removed `getallheaders.php`). It recovers without a restart.), after (#285: raised dependency floors; carries phpdocumentor/reflection-docblock 5 → 6, phpdocumentor/type-resolver 1 → 2, ramsey/collection 1 → 2, and drops symfony/polyfill-php81. `lint:container` passes in dev and prod and the 134 `_api` routes load. **Not yet checked with the stack up** (no `migrations:diff`, no page smoke test): it was down), after (#284: a failed Mercure publish is logged instead of turning a saved write into a 500; no dependency changes, `lint:container` passes in dev and prod, `migrations:diff` clean, pages render), after (#281: Mercure is required at runtime and symfony/mercure 0.8 is supported; carries mercure-bundle 0.4.2 → 0.4.3 and http-client 8.1.1 → 8.1.7. `lint:container` passes in dev and prod, `migrations:diff` finds no changes, pages render), after (#254: `UserFactory` now throws `ValidationFailedException` instead of silently saving an invalid user. Verified in a throwaway DB: `UsersFixture` still loads fresh, and `--append --group=UsersFixture` twice over the existing admin gives exit 0 with still 1 user; the default password `admin` passes; a real duplicate via `user:create` is rejected with exit 1), previously (21 commits; no schema changes; fixtures give the same 9 routes in a throwaway DB; `lint:container` OK. `66723b4` now asks the Filesystem for a public URL before falling back to the api URL. That changes nothing here: in prod `GoogleCloudStorageAdapter` implements `PublicUrlGenerator`, so media already used `GCLOUD_PUBLIC_URL`, and in dev the local adapter has no `public_url`, so it still falls back to the api URL) (#248: `make:rename-component` wired; `lint:container` now passes).
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

### ⚠ A host `pnpm install` crashes the running dev container until it is restarted

`app/` **and** `app/node_modules` are bind-mounted into the `app` container
(`compose.override.yaml`), whose dev image runs `pnpm install; pnpm dev`. Running
`pnpm install` (a dependency bump, say) on the **host** rewrites that shared
`node_modules` underneath the container's running dev server. It then crash-loops
with `Cannot find module 'typescript'`, a missing `@nuxt/cli/dist/dev/index.mjs` and
`Cannot resolve module "@nuxt/kit"`, and Caddy returns 502/503 for every page. **The
fix is `docker compose restart app`**, which reinstalls inside the container. Seen
twice on 2026-09-21. After any host-side install, restart `app`, then count errors only
since the container's start time (`docker inspect -f '{{.State.StartedAt}}'`), because
a wider log window picks up the pre-restart crash and reads as a failure.

### Already-applied template change this confirms

`HtmlContent.vue` and `AltHtmlContent.vue` pass a second argument to
`useHtmlContent(htmlContainer, htmlContent)`. That edit predates this session and
was uncommitted; it type-checks and builds against this module version, so it is
correct for the new signature, not a stray.

## ✅ Entity filters moved to QueryParameters — #89 (2026-09-23)

`User`, `BlogArticleData` and `NestedPageData` declare `parameters:` on `#[ApiResource]`
instead of `#[ApiFilter]`:
- `search` uses `FreeTextQueryFilter(new OrFilter(new PartialSearchFilter()))` over
  `username` and `emailAddress`, or over `title`.
- `order[:property]` uses `SortFilter`, over `createdAt`/`username` and `title`/`createdAt`.
- `app/app/components/CollectionSearch.vue` binds `search`, where it used to bind `title`.
- No `#[ApiFilter]` is left in `api/src`.

Behaviour, verified on the local stack:
- Search is case-insensitive, and ORs across the fields.
- The old per-field parameters (`?title=`, `?username=`) are **ignored, not refused**, so
  a stale client silently gets everything back.
- An invalid sort direction returns **422**.
- **Resource-level parameters also filter single-item requests**: `/users/{id}?search=zzz`
  returns 404. That's harmless, because since #318 the module forwards the page query
  only to collection fetches.
- Never use a bare `OrFilter`: it ORs against the whole WHERE clause and drops the
  bundle's publication predicates (bundle #237).
- Avoid `relation.field` in an OR search: `PartialSearchFilter` inner-joins it, and that
  drops rows without the relation.

On API Platform 5:
- `/me` returns `@type`/`@context` `User`.
- A wrong type on a *constrained* property returns a 422 ConstraintViolation.
- An unconstrained one (such as `HtmlContent.html`) still returns a 400 Error.
- A form submit's 422 shape is unchanged.

### ⚠ Running Behat in the php container can wipe the dev database

The container's real `DATABASE_URL` points at the dev `app` database and overrides
`.env.test`. `DoctrineContext` drops and recreates the schema before every scenario. So a
plain `APP_ENV=test behat` in the dev container **wipes the dev database**.
- Always pass `-e DATABASE_URL=…/<throwaway_db>`.
- Before running, check with `bin/console dbal:run-sql "select current_database()"`.
- To run the Souin purge test without building an image:
  `docker compose exec -T php sh -s < bin/test/souin-purge-isolation.sh`.

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
**In prod that is now up to a year**, because pages follow the API's `shared_max_age`
since module edge `636e924` (#325). It was an hour while the module capped pages at
3600. Add any `stale-while-revalidate`, which defaults to 0. **So the deploy-time purge
below is no longer a nicety: without it, stale HTML would outlive every deploy.** In dev it is 60s, which is why it is easy to miss locally.
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

## ✅ Warm the page cache from the sitemap after each deploy — issue #80 (2026-09-21)

`warm_cache [base_url]` in `bin/devops/k8s.sh` runs straight after
`purge_rendered_html` in all eight deploy steps (same places as #71). It reads
`/sitemap.xml` (following the redirect to `/sitemap_index.xml`, and one level of
child sitemaps), rewrites each `<loc>`'s origin to `CI_ENVIRONMENT_URL` (Souin keys
on Host; in dev the sitemap says `http://localhost:3000`), and requests every page
**anonymously** with `Accept: text/html`, 3 at a time (`WARM_CACHE_CONCURRENCY`).
It prints each page's status and TTFB and a `CACHE WARM FAILED` banner, plus a
GitHub `::error` annotation, if any page is not 200. Pages' redirects are not
followed, so a 3xx in the sitemap counts as a failure. XML is parsed with
`grep`/`sed` because the CI images have no `jq`/`xmllint`; it runs under busybox
ash (GitLab sources k8s.sh before `bash` exists), which was verified in `alpine`.
`WARM_CACHE_INSECURE=true` is for testing against the local self-signed stack only.

**Only production is warmed by default** (Daniel, 2026-09-21: warming exists for
production). Per-track variables work on both GitLab and GitHub:
- `WARM_CACHE_PRODUCTION`: **on** unless set to `"false"`.
- `WARM_CACHE_STAGING`, `WARM_CACHE_REVIEW`, `WARM_CACHE_CANARY`: **off** unless set to
  `"true"`.

These are per-track variables, **not GitLab environment-scoped ones**, because the
`staging` deploy job uses `environment: production`, so an environment scope cannot
tell staging from production. On GitLab the warm jobs use `rules:`, since GitLab won't
mix `rules` with `only`/`except`. Each rule restates its deploy job's conditions plus
the flag, and the file passes `glab ci lint`. On GitHub the step `if:` reads
`vars.WARM_CACHE_*` directly, so no `env:` mapping is needed. **Production does not
wait for any warm job:** `production` needs only the `staging` deploy job.

**It runs as its own job or step, never inside the deploy job** (Daniel's choice,
2026-09-21). `warm_cache` exits 1 on any non-200. The release is already live by then,
so that must not fail the deploy: that would mark a good deploy red, skip what follows
(production's canary/staging deletes and `environment_url.txt`), and make the deploy
job's `retry: 1` **redeploy the whole release**.
- **GitLab:** `warm cache review|staging|canary|production` each `needs` their deploy
  job, copy its `only`/`except` exactly, and set `allow_failure: true`. A failure shows
  the pipeline as orange "passed with warnings", with the failed pages in the job log.
  They use `environment: action: verify`, so they attach to the environment without
  recording a deployment. The URL is passed explicitly. `alpine` has no `curl`, so each
  runs `apk add curl` first. The first version called `warm_cache || echo` inside the
  deploy script, where a failure was visible only in the log.
- **GitHub:** a separate "Warm the page cache" step with `continue-on-error: true`,
  plus warm_cache's `::error` annotation. It runs **after** the fixtures step (after
  the deploy step for canary, which has no fixtures step), so a new environment is
  warmed once its content exists.

It replaced the `performance` job: `bin/devops/performance.sh`, `.gitlab-urls.txt`,
`.github/workflows/performance.yml` and `PERFORMANCE_DISABLED` are gone.

The template's leftover `test-static` sitemap (`sitemap.sitemaps['test-static']` in
`app/nuxt.config.ts` plus `app/server/api/sitemap-urls.ts`, from `ac7327a`,
"simulate same sitemap config as CK") listed `/does-not-exist-just-a-test`, which
would have failed every warm. Removed, with `sitemap.debug: true`. The module's
own `cwa` sitemap (`@cwa/nuxt` `moduleDependencies` defaults) is unaffected.

Since #79, each page is stored once whatever the browser sends, so one warm request
per page fills the cache for every visitor.

**The warm step exposed a real module bug:** under concurrent SSR, one request's 404
status can land on a different request's response. It's
[cwa-nuxt-module#313](https://github.com/components-web-app/cwa-nuxt-module/issues/313),
reproduced 8/8 on `nuxt dev` and 3/8 on a production build, and correct when requests
are sequential. The warm only requests sitemap pages, which are all 200, so it cannot
trigger this itself. Any stray 404 rendered alongside real pages can, though, and
behind Souin the wrongly-404'd page was cacheable (#313 is fixed, and since module #340 no 404 is stored). The warm's non-200 check is what
exposes it after a deploy.

## ✅ Front-end performance: lazy editor, hydration-safe HTML, fewer hints (2026-09-23)

Found by a Lighthouse audit of `preview.cwa.rocks` (#87): simulated mobile LCP was
9–12s on pages with body text. The module issues it raised are cwa-nuxt-module#329–#334.
These are the template's own fixes:
- **The TipTap editor loads only when an admin edits (#332).**
  - `HtmlContent.vue` and `AltHtmlContent.vue` use `defineAsyncComponent`.
  - A `build:manifest` hook in `nuxt.config.ts` removes the editor from every chunk's
    `dynamicImports`. Without that, it becomes a 402 KB prefetch hint on every page.
  - `useCustomHtmlComponent.ts` imports it with `import type`. A value import kept it in
    every dev page.
- **Body text renders through `v-cwa-html` instead of `v-html` (#333).** Since #90 it's the
  module's directive, `const { vCwaHtml } = useHtmlContent(container, html)` (module
  `fbe401d`). The template's short-lived local copy is deleted.
  - Since Vue 3.5.39, hydration re-assigns `innerHTML` for every `v-html`, even when it's
    identical. That recreated the LCP paragraph after hydration.
  - The directive uses `beforeMount`/`beforeUpdate`, **not** `mounted`/`updated`. A
    post-flush hook can run after `useHtmlContent`'s post watch and overwrite the links it
    converted.
  - The module's directive is pinned by tests that fail against the `updated` ordering.
    It saves the redraw whenever the stored HTML serialises the way the browser does.
    TipTap's output always does. Hand-written or API-written HTML may be re-assigned once
    on mount, which is no worse than `v-html`.
- **The prefetch hints for `/_cwa` and auth pages were the module's to fix (#329), not the
  template's. Fixed: module `9a506f8`/`6c33a6e`, plus `extends: ['@cwa/nuxt/layer']` (#92). 85 → 24 hints.** The layer's pages come through a pnpm symlink, so Nuxt's filter that keeps
  page chunks out of the prefetch hints never matches, and every public page sends about 80
  hints. A `pages:extend` realpath hook fixes it (80 → 23). Daniel decided on 2026-09-23 that
  the hook belongs in the module, because every site has the bug. The template briefly
  carried it and it was removed before release. It's proposed on #329 with the
  measurements. **Don't re-add it here.** Until the module ships it, the template still
  sends those hints.
- **The service worker no longer precaches admin-only chunks.**
  - The same `build:manifest` hook collects the files reachable only from the editor or
    `/pages/_cwa/`: anything shared with a visitor-reachable chunk stays.
  - `pwa.workbox.manifestTransforms` removes those files from the precache list.
  - `globIgnores` can't do this, because chunk files are named by hash.

Measured on a local production build:

| | Before | After |
|---|---|---|
| Modulepreload on `/` and blog articles | 1,083 KB (365 KB gz) | 659 KB (231 KB gz) |
| Prefetch hints | 80 files (243 KB) | 23 files (56 KB) with the #329 hook, which is now left to the module; about 80 again without it |
| Second LCP entry (the redraw) | 7 of 8 loads | 0 of 8 |
| Lighthouse mobile LCP on `/` | 9.3–12.1s | 7.1–7.2s |
| Requests | 119 | 60 |
| Service-worker precache | 140 entries (2,069 KiB) | 117 entries (1,594 KiB), editor chunk excluded |

Checked in a browser against a production build:
- Anonymous visitors never load the editor, their prose links still navigate within the
  app, and routing is unchanged, `/_cwa` included.
- As an admin, clicking Edit fetches the editor on demand, and typing sends the `PATCH`.

Still open:
- The update path of `beforeUpdate`, where content changes while the component stays
  mounted, wasn't exercised in a browser.
- A pre-existing CLS of about 0.16 on blog articles, where something above the body text
  collapses.
- An admin-only hydration mismatch in the module's `ComponentPlaceholder`.

**⚠ Editing `nuxt.config.ts` while the dev `app` container runs can leave it broken.** Nuxt
logs `nuxt.config.ts updated. Restarting Nuxt...`, and then the client dies with `Private
field '#particles' must be declared`: a layer `BackgroundParticles.vue` style URL is served
as JS. `docker compose restart app` fixes it, as it does after a host `pnpm install`.

**Testing admin against a throwaway production build needs HTTPS on `localhost`** (a
Caddy `tls internal` proxy on `https://localhost:<port>`, for example). The API's cookie is
`SameSite=Lax`, and `http://localhost:<port>` counts as cross-site to `https://localhost`.
Bypass the service worker when checking lazy loading, or the precache hides the requests.
The host's `node_modules` holds the container's Linux binaries, so build a scratch copy in
the `app-app` image: `pnpm install --frozen-lockfile && pnpm run build`.

## ✅ TipTap editor: per-use button config and Underline — #66 (2026-09-23)

Ported from srnte into `app/app/components/TipTapHtmlEditor.vue`:
- **`config` prop:** `:config="{ h1: false, underline: false }"` hides menu buttons.
  - Every button shows unless its style is set to `false`.
  - The keys are a typed union, `h1`, `h2`, `bold`, `italic`, `underline`, `link` and
    `bulletList`, so a typo fails `vue-tsc`, even through the `defineAsyncComponent` import.
  - The floating menu hides when `h1`, `h2` and `bulletList` are all off.
  - Hiding a button doesn't unregister its extension, so pasting and keyboard shortcuts
    (Ctrl+U) still apply the style.
- **An Underline button.** StarterKit 3.x already registers Underline, so no package was
  added.

**Deliberately not ported from srnte:**
- Plain `StarterKit`. The template keeps `StarterKit.configure({ link: false })` plus its
  explicitly configured Link; plain StarterKit would register Link twice.
- `:tippy-options`, a TipTap v2 prop that v3 ignores.

The #82 focus/`emitUpdate` logic is unchanged. `HtmlContent.vue`/`AltHtmlContent.vue` pass no
`config`, so they behave exactly as before.

Verified in a browser against a production build:
- Anonymous pages never load the editor chunk.
- Admins load it on Edit.
- The bubble menu shows H1, H2, Bold, Italic, Underline and Link.
- Underline produces `<u>` in the (blocked) `PATCH`.
- The floating menu appears on an empty line.
- Two temporary configs hid exactly the right buttons.

**Browser-testing a production build without touching the dev stack:**
- Run the scratch build's `.output/server/index.mjs` in a container on
  `components-web-app_default` with `--link components-web-app-php-1:php.local`, the dev
  `NUXT_PUBLIC_CWA_API_URL*` env, and a spare host port.
- Log in with `curl POST /_api/login` and set the `api_component` cookie with
  `SameSite=None`. A form login from an http origin loses the Secure cookie.

## ✅ k6 load-test harness — #93 (2026-09-23)

`bin/load-test/launch.js` and its `README.md`, ported from srnte and made generic, so clients
can stress test their sites. **A manual tool, deliberately not in CI.**
- **Pages:** `BASE_URL` is required. Pages come from the sitemap, read the way `sitemap_pages`
  does; `PAGES` overrides them and `MAX_PAGES` caps them.
- **One visitor:** a page, its `/_nuxt` assets, a pause, then a client-side navigation
  through the module's real fetch paths (`/_api/_/routes/{path}` and
  `/_api/_/resource_manifest/{path}`).
- **Modes:** `smoke`, `capacity` (stepped arrival rate), `surge` (`PEOPLE`, **default 100**,
  over 60s, held 3m) and `soak`.
- **Report:** time to first byte for pages, API calls and assets separately, plus counts of
  `Cache-Status` hits and misses, so a run says whether it measured the cache or the servers.
- **`CACHE=warm|cold|mixed`.** Cold adds `k6cb=`. **Never make that a stripped tracking
  parameter** (`utm_*`, `gclid`, …), or every "cold" request becomes a cache hit.
  `COLD_API=true` also bypasses the cache for the API calls.
- **The guard:** any host that isn't local needs `CONFIRM=yes`. It's checked at startup,
  before any request is sent.
- **`Accept-Encoding: gzip` is pinned**, because k6 can't decode brotli and reports it like a
  server error.
- **Run it from a VM, not a laptop.** Laptops time out around 300 users.
- **After a cold run against a real site, flush Souin:**
  `curl -X PURGE localhost:2019/souin-api/souin/flush` in the API pod.
- **Warm runs on the dev stack can show misses**, because dev pages expire after 60s.
  (`/` caches normally since module #324.)
- Verified only with small smoke, capacity and cold runs against the local stack. Full-size
  runs and remote targets were not tested.

## ✅ Opt-in Lighthouse CI audit after the cache warm — #87 (2026-09-23)

`performance_audit [base_url]` in `bin/devops/k8s.sh` runs `@lhci/cli` (pinned
`0.15.1`, still the latest release) against a few pages after each deploy's cache
warm. The pages are cached by then, so it measures what visitors get. `warm_cache`
only reports time to first byte; this adds LCP, CLS, TBT, FCP, Speed Index and page
weight.

- **A manual job, on by default (Daniel, 2026-09-23).** It never runs by itself: someone
  starts it after a deploy. An unrun manual job costs nothing and never blocks a pipeline.
  - GitLab: `performance audit review|staging|production` are `when: manual` jobs.
    Setting `PERFORMANCE_AUDIT_REVIEW`, `_STAGING` or `_PRODUCTION` to `"false"` removes
    one. `performance audit canary` stays opt-in (`PERFORMANCE_AUDIT_CANARY="true"`),
    because canary shares production's hostname and would measure whichever pod answers.
  - GitHub has no manual steps inside a push-triggered workflow, so there is a separate
    `workflow_dispatch` workflow, `.github/workflows/performance-audit.yml`, with an
    environment choice (production, staging or review) and a form-factor choice. A
    review app is audited by running it from that branch; the URL uses `ci.yml`'s slug.
    `vars.PERFORMANCE_AUDIT_<ENV>="false"` disables an environment. A missed budget
    fails that run, which is only ever the audit.
  - The first version ran automatically when opted in. That was changed the same day.
  - Other defaults agreed with Daniel on 2026-09-23: mobile only, no query parameter on
    audit requests (a plain anonymous request is exactly what should hit the cache), and
    no `create-cwa` prompt.
- **Pages:** `PERFORMANCE_AUDIT_URLS` (paths or URLs, comma or space separated), or
  otherwise the first `PERFORMANCE_AUDIT_MAX_PAGES` (default 5) pages in the sitemap.
  The sitemap reading was moved out of `warm_cache` into `sitemap_pages`, which both
  functions share.
- **Tuning:** `PERFORMANCE_AUDIT_FORM_FACTORS` (`mobile`, `desktop` or
  `mobile,desktop`), `PERFORMANCE_AUDIT_RUNS` (default 3; budgets use the median run),
  `PERFORMANCE_AUDIT_CONFIG` and `PERFORMANCE_AUDIT_LHCI_VERSION`.
- **Budgets** are in `bin/devops/lighthouserc.json`: performance score ≥ 0.8, LCP ≤
  2.5s, CLS ≤ 0.1 and TBT ≤ 200ms (Lighthouse's "good" thresholds), all `error`, plus
  page weight ≤ 1.6MB as a `warn`. A missed `error` budget fails the job.
  - GitLab: `allow_failure: true`, so it shows as "passed with warnings".
  - GitHub: the manual audit run fails, with a `::warning`.

  A missed budget never fails a deploy.
- **Output** goes to `performance-report/`:
  - Lighthouse's HTML and JSON for each page and form factor;
  - the assertion results;
  - `summary.md`, a table built by `bin/devops/lighthouse-summary.mjs`, which is also
    printed and added to the GitHub step summary;
  - `browser-performance.json` in GitLab's `browser_performance` report format. The
    merge request comparison it feeds is a paid GitLab feature; on Free the artifact
    is simply kept.
- **GitLab:** the `performance audit <track>` jobs run in `$PERFORMANCE_AUDIT_IMAGE`,
  a pinned `cypress/browsers` image with Node 24 and Chrome 153. LHCI's own
  `patrickhulce/lhci-client` image dates from 2025 and has an old Chrome. Each job
  `needs` its deploy job, plus its warm job with `optional: true`, so it runs after the
  warm whenever warming is on. `glab ci lint` passes.
- **GitHub:** see the manual workflow above. `ubuntu-latest` has Node and Chrome, and
  the repository's `PERFORMANCE_AUDIT_*` variables are passed through. actionlint passes.
- Chrome runs with `--headless=new --no-sandbox --disable-dev-shm-usage`, because CI
  containers run as root with a small `/dev/shm`. `PERFORMANCE_AUDIT_INSECURE=true` is
  for the local stack only.

**Verified:** a real run against the local stack with host Chrome (2 pages, mobile and
desktop) produced the reports, the table and a well-formed `browser-performance.json`,
and returned 1 on the missed budgets. `warm_cache` still warms all 15 pages after the
refactor. The script parses and sources in busybox ash. A stubbed `npx` confirmed the
URL list handling and the unknown form factor error.

**`cypress/browsers` has no `curl`** (found on the first real GitLab run: `curl:
command not found` from `sitemap_pages`). Each audit job now installs it with `apt-get`
when it's missing. Verified by running the job's steps in the pinned image itself: the
`before_script`, the install, then `performance_audit`. The container shared the php
container's network, so `https://localhost` reached the local Caddy. It read the sitemap,
audited 2 pages and wrote every report. **When testing in a container, mount the repo
writable:** with a read-only mount, `lhci collect` crashes writing `.lighthouseci/`,
which looks like a Lighthouse failure. Not yet run on a real GitHub runner.

**Don't judge the budgets on the dev stack.** It serves Vite's unbundled dev build,
about 4 MiB per page, so mobile LCP there was 7–24s. Only a production build gives
meaningful numbers.

## ✅ Page cache stored once per page, not per browser — #79 (2026-09-21)

Souin was keeping a separate copy of each page per browser, so one browser's cached
page was a miss for the next. That multiplied SSR renders and made warming (#80)
fill only one variant. There were two causes, both in `api/frankenphp/Caddyfile`:

1. **`{http.request.header.accept}` was in the cache key**, and each browser sends a
   different `Accept` for the same HTML.
2. **`Vary: Accept-Encoding` from Caddy's `encode`.** Nuxt and php send no `Vary`.
   Souin orders `cache` before `rewrite`, so it sat **outside** `encode`, stored the
   already-compressed body, and honoured `encode`'s `Vary`, which gave one entry per
   `Accept-Encoding` string.

The fix has two parts:

- **`order cache after encode`.** The cache now stores the uncompressed body once, and
  `encode` compresses per client on the way out.
- **`Accept` stays in the key for the API only**, via
  `@cache_accept path /_api*` + `vars @cache_accept cwa_cache_accept {http.request.header.accept}`,
  and `{http.vars.cwa_cache_accept}` in the key template (the full `{http.vars.*}` form:
  the `{vars.*}` shorthand is not expanded in the global block).

**⚠ Do not "simplify" this by dropping `Accept` from the key and relying on `Vary:
Accept`.** API Platform's HTML docs response (Swagger UI, on `/_api` and `/_api/docs`)
sends **no** `Vary: Accept`. The worker tried it: after warming with `text/html`,
`application/ld+json` and `application/json` requests were **hits serving HTML**. The
API is split by its key, not by `Vary`. Two approaches that do **not** work:

- Souin's per-path `cache_keys`: in Souin v1.7.9, `computeKey()` returns early when a
  global `template` is set.
- Caddy's `map`: its output was stored as the literal placeholder text.

**Verified on the local stack**, with a fresh query string for each experiment:
- A page warmed with Chrome's headers is a hit for Safari's `Accept`, for any
  `Accept-Encoding`, and for none. Each client gets its own correct encoding, and the
  decoded body is identical.
- Exactly one stored key per page, with no `{-VARY-}` suffix.
- The API returns HTML / JSON-LD / JSON each with its own `content-type` **on cache
  hits**. That was re-checked independently before committing.
- The cookie, `Authorization`, Mercure, `/_cwa/healthcheck`, `/login` and `/_api/me`
  exclusions all hold, and both purge paths still drop pages.

**Costs, and what's left:**
- Compression now runs on every response, hits included.
- Uncompressed responses no longer carry `Vary: Accept-Encoding`, because `encode` only
  adds it when it compresses. A CDN in front could store the uncompressed variant and
  serve it to everyone. That's safe, but less efficient.
- The API is still split per exact `Accept` string, as before.
- Not tested: a production build, HEAD requests, and a real CDN.


## ✅ Tracking parameters no longer split the cache (2026-09-22)

The query string is in the Souin key, so every `?utm_source=…`, `gclid`, `fbclid` or
`srsltid` value used to render and store its own copy of a page. The API was split too,
because the module passes the page query on to collection fetches
(`fetcher.ts`, #318). Ad clicks and shared links were therefore always misses.

A `uri query { -utm_source … }` block in `api/frankenphp/Caddyfile` now drops a fixed
list of tracking parameters. `uri` runs before `cache`, so the key, Nuxt and php all see
the stripped query. It applies to every path, `/_api` included. Analytics scripts are
unaffected because they read the browser's address bar. Nuxt's collection plugin only
reacts to query *changes*, so a browser URL that differs from the SSR query does not
cause a refetch on hydration.

Verified on the dev stack:
- `/form?k=1&utm_source=…&utm_campaign=…` and `/form?utm_medium=…&k=1&fbclid=…&gclid=…&srsltid=…`
  are **hits** on the `/form?k=1` entry, and `/form?k=2&utm_source=x` is still a separate
  entry.
- `/blog-articles?utm_source=a` then `?utm_source=b&fbclid=zz` gives a miss, then a hit.
- `/_api/_/routes//form?k=1&utm_source=x&gclid=y` is a hit on the entry without them.
- In a render of `/blog-articles?z=1&utm_source=leak`, the collection fetch was
  `…/collections/…?z=1` and the HTML contains no `leak`, so Nuxt never saw it.

**⚠ Fixed 2026-09-23: the strip broke `nuxt dev` for a day.** As first written, `uri query`
ran on every request, and Caddy re-encodes the whole query whenever it runs, even with
nothing to remove, turning a valueless key `k` into `k=`. Vite's
`?vue&type=style&index=0&lang.css` reached Vite as `?vue=&…&lang.css=`, so Vite no longer
treated it as CSS and served every SFC style block as raw CSS labelled
`text/javascript`. In the browser that meant `Unexpected token '.'` and
`Private field '#particles'`, and the client app, admin UI included, never mounted.
Production builds were unaffected, because they never request those URLs. Now:
- `uri @tracking_query query {…}` runs only when the query contains a listed parameter.
- It never runs for `/_nuxt/*`.
- **Keep the expression's parameter list identical to the `-param` lines.**

Found by bisecting: the Nuxt dev server answered correctly when requested directly and
wrongly through Caddy, and the rewritten query reproduced it without Caddy. **If `nuxt
dev` ever serves style blocks as raw CSS, compare Caddy with a direct request to Nuxt
before suspecting the app.** A query with both a tracking parameter and a valueless key is
still re-encoded (`k=`). That's harmless for pages.

Caddy's access log still records the **original** URI, so don't read a `utm_` in php's
log as the strip failing. A project that needs one of these parameters server-side
must remove it from the list. To add a parameter, add a `-name` line (there are no
wildcards).

## ✅ Souin purge orphaned other resources' cache entries — patched build (#84, 2026-09-22)

**Bug (Souin v1.7.9, the latest release; reported upstream as
[darkweak/souin#867](https://github.com/darkweak/souin/issues/867)):** after a
surrogate-key purge, Souin deleted the purged tags' index entries with an
**unanchored regex**. Purging a tag therefore also deleted the index entry of every
tag that *contains* it. The responses stayed cached with nothing pointing at them,
so no later purge could reach them, and they were served for the full prod
`s-maxage` of a year. API Platform always purges the collection IRI next to the
item, so **every write to one component group or position orphaned all the others**.
Routes are also hit, where one path contains another (`/2026` ⊂ `/2026/2026-programme`).
It was seen on srnte: a published accordion tab never reached anonymous visitors, and 60% of
production's API entries were orphaned. The API bundle and module send correct purges.

**Fix, carried in this template until upstream releases one:**
- `api/frankenphp/souin/v1.7.9-purge-fix.patch` makes both purge clean-up paths delete
  **exact** keys (production code only, `pkg/api/souin.go`). The same change, with Go
  tests, is ready as the upstream PR for #867.
- `api/Dockerfile`'s builder stage downloads Souin v1.7.9's source, applies the patch
  and builds with `--with github.com/darkweak/souin=/tmp/souin`. **Remove the
  patch, the `COPY`/`RUN` and the replace together** once a Souin release has the fix.
- `bin/test/souin-purge-isolation.sh` runs the image's own `frankenphp` on a throwaway
  Caddyfile (a cache in front of a stub that tags each response with its path, so no
  php or database) and runs in the unit-tests job on GitLab and GitHub.

**Verified locally:** the script fails all three checks on the unpatched binary and
passes on the patched one. On the full stack, purging group B plus the collection keeps
group A indexed, and purging A then drops it (both `Accept` variants). The
`purge-rendered-html` command still drops pages and leaves `/_api/docs.jsonld` cached.

**Each site, after its first deploy with the patched image:** entries orphaned before
it stay unpurgeable, so flush the cache once:
`kubectl exec -n <ns> deploy/<release> -- curl -s -X PURGE http://localhost:2019/souin-api/souin/flush`.
A deploy already restarts the API pod, and its in-memory `otter` store is emptied with
it, so the flush is only needed if the pod was not recreated.

**Downstream sites:** copy the patch file, the Dockerfile block, the `--with` line, the
script and both CI steps. Check that the site builds the same Souin version
(`frankenphp build-info | grep souin` should show v1.7.9). If it doesn't, the patch will
fail to apply, which fails the build loudly.

## ✅ A hostname change issues its certificate before the ingress moves (#86, 2026-09-23)

**The problem (srnte launch, 2026-09):** the stable ingress's TLS secret covers `DOMAIN`
plus every `KUBE_INGRESS_ALIAS_DOMAINS` entry. Changing that list in place, whether by
adding an alias or retiring the preview hostname, makes cert-manager put a **temporary
self-signed certificate** in the live secret while the new order runs. That took about 4
minutes on srnte. If a challenge fails, cert-manager backs off for up to an hour. With
HSTS it is a hard outage for every hostname, the live one included. Let's Encrypt also
allows only 5 certificates per identical name set per week.

**Now `ensure_tls_certificate` in `bin/devops/k8s.sh` runs in `deploy` before helm**
(stable track, `INGRESS_ENABLED=true`, `CLUSTER_ISSUER` set):
- It compares the new host list with the `dnsNames` of the Certificate behind the live
  ingress's secret. **If they match, which is almost every deploy, it keeps that secret.**
  Existing sites are not reissued, including ones on a hand-rotated `LETSENCRYPT_SECRET_NAME`.
- **If they differ,** it applies a Certificate named `<LETSENCRYPT_SECRET_NAME>-stable-api-<sha256 of the list, 8 chars>`
  and `kubectl wait`s for `Ready` (`TLS_CERTIFICATE_TIMEOUT`, default `600s`). Only then does
  helm point the ingress at it, so the switch is from one valid certificate to another.
- **If it isn't issued** (DNS not yet pointing at the cluster, say), the deploy fails
  **before helm runs**. The live ingress and secret are untouched, and the log names the
  hostnames to check.
- After a successful rotation, `cleanup_tls_certificates` deletes this release's older
  rotated Certificates and their secrets (label `cwa.rocks/tls-rotation=true`). It keeps the
  new one and the one it replaced, so a rollback lands on a valid certificate.
- If the CI account can't create `certificates.cert-manager.io`, it warns and falls back to
  the old behaviour rather than failing.
- **The live ingress is read by name** (`cwa_fullname`, which mirrors the chart's
  `cwa.fullname`; checked against `helm template`). It is not read with a label selector,
  because a site can carry other ingresses with the same chart labels. srnte has a
  redirect ingress for its retired host, and comparing against that certificate would
  rotate on every deploy and reach Let's Encrypt's weekly limit within five deploys.
  It is not read by host either: at a launch `DOMAIN` itself changes, and no ingress
  serves the new one yet. That would take the first-deploy path and reissue the live
  certificate in place, which is the outage this exists to prevent.
- First deploy of a release (no ingress yet): the old behaviour. ingress-shim issues from
  the ingress, and nothing is live to protect.

This relies on cert-manager's ingress-shim leaving a Certificate it doesn't own alone when
the ingress names its secret. srnte observed this on v1.9.1. HTTP-01 for a *new* hostname
still needs its DNS pointing at the cluster, but the solver uses its own temporary ingress,
so the hostname doesn't need to be on the site's ingress first.

Verified only against a stub `kubectl`/`helm`, under busybox ash (`alpine`) and bash:
unchanged list, reordered or differently-cased list, a change, a timeout (helm not run), no
RBAC, a non-stable track, a redirect ingress beside the main one, a launch-time `DOMAIN`
change, and cleanup keeping current and previous. **Not yet exercised on a
real cluster.** Watch the first production deploy that changes a hostname.

**Decided against — a redirect ingress for retired hostnames.** #86 proposed a second
ingress 301-ing the old preview host. Daniel (2026-09-23): take the preview hostname
offline instead, by removing it from `KUBE_INGRESS_ALIAS_DOMAINS` and deploying. The rotation
above makes that safe. A site that really needs the redirect can take the snippet from #86.

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

- **GitLab created a merge request pipeline that always failed (#88, 2026-09-23).**
  `workflow:rules` ended in a catch-all `when: always`, so each push to a branch with an
  open MR also created an MR pipeline. Every job is filtered to branches except `unit
  tests`, which had only an `except:`, so that pipeline held it alone. With no `build
  api` in it (`needs` is `optional`), it pulled `php:<branch-slug>` before any build had
  pushed it, and failed. "Pipelines must succeed" then blocked the MR (hbcp-2026 !1,
  !2). The fix: `workflow` now has `merge_request_event → when: never`, and `unit tests`
  has `only: branches`. The second part also covers pushed tags other than
  `create-cwa/*`, which the same gap affected. Every `rules:` job's positive condition
  already needs `$CI_COMMIT_BRANCH`. `glab ci lint`, with and without `--dry-run --ref
  main`, passes. **Don't switch to MR pipelines casually:** every `only:`/`except:` job
  would need converting to `rules:`, and review apps and image tags are keyed by branch.

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

## ✅ API memory sized for 20 MB photo uploads (2026-09-23)

Brought over from srnte, which needed PHP `memory_limit = 512M` for 20 MB photos. The
template was at 256M, and uploads were capped at 5 MB in three places.
- **Upload limits:** `upload_max_filesize = 20M` and `post_max_size = 21M` (in `10-app.ini`),
  and `Image::$file` `Assert\File(maxSize: '20M')`. PHP's M is MiB and Symfony's is decimal,
  so a file that passes validation always fits. The ingress already allows 30m.
- **`memory_limit = 512M`.** It's a per-request ceiling, not a reservation: ordinary API
  requests still use 20–50 MB.
- **A fixed worker pool** of `num {$FRANKENPHP_WORKER_NUM:4}` in `worker.Caddyfile`.
  - FrankenPHP defaults to 2 threads per visible CPU, and the php pod has no CPU limit, so
    the pool, and with it the worst-case memory, used to follow the node's size.
  - Verified at runtime with 1 CPU: FrankenPHP starts 4 worker threads plus 1 regular
    thread, raising its total itself, and serves normally.
- **Pod memory limit 1Gi**, with the request left at **350Mi** (Daniel, 2026-09-23). The
  scheduler and the cluster autoscaler count only the request. `PHP_MEMORY_LIMIT`
  overrides the limit in `k8s.sh`. The budget: about 190Mi baseline, plus one upload at
  512M, plus 3 ordinary requests at about 50Mi, comes to about 850Mi. The accepted risk is
  that a node short of memory during a big upload evicts this pod first, because it's the
  furthest over its request.
  - **If a cluster forces limits to equal requests** (GKE Autopilot does), the 1Gi would be
    reserved in full. Lower `PHP_MEMORY_LIMIT` there.

**Measured GD memory to build the `thumbnail` filter.** The bundle does this synchronously in
the upload request (`UploadableFileManager.php:162`). Memory scales with pixels, not file
size, at about 11.7 MB per megapixel:

| Photo | Peak |
|---|---|
| 12 MP | 140 MB |
| 24 MP | 280 MB |
| 48 MP | **563 MB, over 512M** |

So 512M handles up to about 43 MP. Photos above that used to fail with a 500, so
**`Image::$file` now rejects anything over 40 MP (about 470 MB) with a 422** and a message
asking the uploader to resize it: `Assert\Image(maxPixels: 40_000_000)`, wrapped in
`Assert\When` so SVG is exempt. Verified with a standalone validator on the entity's
attributes:
- a 48 MP JPEG is rejected with the message, and 40 MP and 12 MP JPEGs and a PNG pass;
- an **SVG passes**: without the `When`, `Assert\Image` rejects SVG, which has no pixel
  dimensions to detect;
- **a PDF is now rejected** ("This file is not a valid image"). The `Image` component used
  to accept any file.

The longer-term fixes live elsewhere:
- **cwa-nuxt-module#335**: downscale large photos in the browser before upload. The
  template's limit is the safety net for direct API uploads.
- The bundle could generate the thumbnails outside the upload request.
- libvips instead of GD streams large images in a fraction of the memory.

## ✅ Node scale-down took the site down — eviction protection (#78, 2026-09-21)

Found on srnte in production: a 503 from nginx-ingress with no deploy running.
The GKE cluster autoscaler removed a node to consolidate
(`deleting pod for node scale down`) and evicted **the only API pod and both
SSR pods at once**. Rolling-update surge protects rollouts only; **an eviction
kills the pod first**. With the API deliberately at one replica (#69: Souin's
`otter` store and Mercure's `bolt` are pod-local), the ingress had no ready
backend until the replacement booted and passed readiness, which takes at least
30–40s given `initialDelaySeconds: 30`. The `cost-optimized` compute class
consolidates actively, so this recurs on every site. **Capping the API at one
replica is what makes a single eviction fatal**, so this protection is part of
that decision.

Ported from srnte `20859f4` unchanged (`git apply` of its chart diff):
- **API pod:** `cluster-autoscaler.kubernetes.io/safe-to-evict: "false"`, so the
  autoscaler will not evict it to save a node. **GKE node upgrades still drain
  it.** That is a brief, scheduled outage, unavoidable with one replica.
- **SSR pods:** `pwa-pdb.yaml`, a PodDisruptionBudget with **`maxUnavailable: 1`**,
  plus `topologySpreadConstraints` on `kubernetes.io/hostname` with
  `ScheduleAnyway`, so replicas prefer separate nodes.

Why **not** the obvious alternatives:
- A PDB on the **API** would block every drain of its node. On a single replica,
  `minAvailable: 1` makes voluntary eviction impossible, so upgrades hang until
  GKE force-evicts it after an hour anyway. The annotation stops only the
  autoscaler's optional evictions, which is the actual trigger.
- `minAvailable: 1` for the **SSR** pods would do the same whenever there is one
  replica, which is exactly this demo's setting (`PWA_AUTOSCALE_MIN=1`).
  `maxUnavailable: 1` evicts one at a time with 2+ pods and still lets a single
  pod go. With one SSR pod, cached pages keep serving (Souin is in the API pod)
  and only uncached requests fail until it is back.

Verified by rendering: `helm lint` passes, the annotation is on the API pod
template, and the PDB's selector exactly equals the SSR pods' labels
(`name=cwa-pwa`) and does **not** match the API pod (`name=cwa`). **A PDB
whose selector matches nothing protects nothing and raises no error**, so check
this whenever labels change.

**Readiness delay: shortened after measuring against #62 (2026-09-21).** It was
first left at 30s pending a check. Then the staging API pod was rolling-restarted
twice (surge, so no outage) and its timeline read from pod status and Caddy's
access log:

| | sample 1 | sample 2 |
|---|---|---|
| Caddy serving | +6.5s | +5.9s |
| first request on the cold worker | 0.139s (the probe) | **0.162s**, fired the instant Caddy started |
| Ready | +30s | +39s (first probe only sent then, and it passed) |

The pod could serve from about +6s but stayed out of service until +30–39s: **24–33s
of avoidable downtime per eviction or node upgrade** of the single API pod. #62's
failure needs the first probe to exceed its timeout, but even a completely cold first
request took 0.16s, about 30x under 5s. So:
- readiness `initialDelaySeconds` 30 → **5**;
- `startupProbe.periodSeconds` 10 → **5** and `failureThreshold` 30 → **60**: the same
  300s boot budget, polled twice as often;
- `timeoutSeconds: 5` is **unchanged**. That, not the delay, is the #62 protection.

A bigger production database lengthens migrations and `ANALYZE`, but those run
*before* Caddy listens, where the startup probe covers them. They don't slow the first
request. srnte needs the same change. The darkweak/souin#849 root cause is still open.

**Open:** if the `cost-optimized` compute class places pods on Spot VMs,
preemptions are *involuntary*, and neither the annotation nor the PDB applies.

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
computed and thrown away. **Since bundle `b753b92` (#254) the factory throws `ValidationFailedException`
instead**, so a duplicate can no longer be written. That closes this at the source.
`overwrite: true` is still needed for idempotency: without it a rerun now *fails*
instead of duplicating.

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

**4. Update UX — `registerType: 'prompt'`, applied silently on the next navigation (#73, 2026-09-21).** CWA admins edit inline, so an auto-updating service worker could swap assets mid-edit; with `prompt`, a new worker installs and **waits**. On 2026-08-14 a notice component (`PwaUpdatePrompt.client.vue`, mounted from an `app/app/app.vue` written only for it) asked visitors to reload. **Daniel decided on 2026-09-21 to drop the notice.** `app/app/plugins/pwa-update.client.ts` now applies a waiting worker silently on the next change of path, still held while `$cwa.admin.isEditing`. The component and `app.vue` were both deleted. With no `app.vue`, Nuxt falls back to its built-in default, which is what that file reproduced apart from the notice. **Corrected 2026-09-23:** the template does have an `app.vue`, and it must be **`app/app/app.vue`**. Nuxt 4 reads it from the source directory (`app/app/`), not the project root. A copy at `app/app.vue`, added in June with `<UApp>` and `<VitePwaManifest />`, was silently ignored the whole time. So the site had **no `<UApp>`** (Nuxt UI's toast, tooltip and overlay context) and **no manifest link**, which meant the PWA couldn't be installed. It's moved now, with `<NuxtRouteAnnouncer />` kept. Verified on a production build in a browser: Nuxt UI's toaster mounts, there's one `<link rel="manifest" href="/manifest.webmanifest">`, and there are no hydration warnings on `/` or `/login`. Keep comments out of its `<template>`: template comments are rendered into every page's HTML. Verified: `/`, `/form` and `/login` (which has no CWA layout) all render.

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

Images are pushed to GHCR (`ghcr.io/<repo>`). `install_dependencies` (Alpine/`apk`) is skipped in favour of `azure/setup-kubectl` and `azure/setup-helm` actions. All other `bin/devops/k8s.sh` functions are called directly.

**`production` and `canary` wait for the builds and tests (GitLab issue #1, 2026-09-23).** They
used to need only `staging` (optional). With `STAGING_ENABLED=false` that became
`needs: []`, so the manual deploy was clickable before the images were built, deployed the
previous `:main` image, and ignored failing tests. Found on cymru-kitchens-cwa, where staging
is off because it would migrate the live database. They now also need `build api`,
`build app`, `unit tests` and `behat tests`, all `optional` because BUILD_DISABLED and
TEST_DISABLED can remove them. **GitLab has its own issue tracker for this repo**
(`glab issue list -R silverback-web-apps/cwa/components-web-app`), alongside GitHub's.

**Required secrets:** `KUBECONFIG`, `KUBE_CONTEXT`, `KUBE_NAMESPACE_PRODUCTION`, `JWT_PASSPHRASE`, `JWT_SECRET_KEY`, `JWT_PUBLIC_KEY`, `MERCURE_JWT_SECRET`, `DATABASE_URL`, `ADMIN_PASSWORD`

**Required variables (`vars.`):** `KUBE_INGRESS_BASE_DOMAIN`, `RELEASE_PRODUCTION`, `CORS_ALLOW_ORIGIN`, `TRUSTED_HOSTS`, `ADMIN_USERNAME`, `ADMIN_EMAIL`

**Optional flags (`vars.`):** `CI_DISABLED` (set to `"true"` in this repo on GitHub to prevent mirrored pushes triggering the app pipeline), `BUILD_DISABLED`, `TEST_DISABLED`, `REVIEW_DISABLED`, `STAGING_ENABLED`, `ENABLE_DATABASE_FIXTURES`, `WARM_CACHE_CONCURRENCY`, `KUBERNETES_VERSION`, `HELM_VERSION`

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
