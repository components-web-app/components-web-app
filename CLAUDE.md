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

## Planned Features

### PWA / offline support (cwa-nuxt-module #258) — vetted, not yet implemented

**This repo is where the real implementation lands.** The module deliberately ships no service worker (a module dep would force one on every consuming app — the #236 transitive-dep principle), so the template carries the reference config. The investigation was done module-side against real source; **the conclusions below overturn the original issue text, so implement from this, not from the issue.**

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
**⚠ `navigateFallback` gotcha:** `@vite-pwa/nuxt` checks `if (!('navigateFallback' in options.workbox))` and defaults it to `'/'`. **Omitting the key silently serves the `/` app shell for every SSR navigation.** *Presence of the key*, not its value, disables it. (Undocumented upstream; the module playground already does this correctly.) With it null there is no navigation interception, so `/_cwa/**` needs no denylist — but if an app ever sets a fallback it must add `navigateFallbackDenylist: [/^\/_cwa\//, /^\/login/]`.

**2. ⛔ Do NOT add `runtimeCaching` for the CWA API.** The issue asked for SWR caching of `/_/routes/`, `/_/resource_manifest/` and resource GETs "with auth/draft excluded". **That exclusion is not implementable.** Four verified reasons:
1. **Draft and published responses share an identical URL** — the primary fetch requests `/_/routes/{path}` and `/_/resource_manifest/{path}` with **no `?published=` marker**; the API decides draft-vs-published from the **auth cookie alone**.
2. **The API sends no `Vary: Cookie`** (only `Vary: path` on ComponentPosition), so the Cache API cannot partition anon from authed entries.
3. **Every CWA request is `credentials: 'include'`**, cross-origin to `apiUrlBrowser` — a readable 200 that **Workbox caches happily; Workbox does not honour `Cache-Control: no-store`.**
4. **A Workbox `urlPattern` match callback must be synchronous**, so it cannot read auth state — a SW has no `document.cookie`, and `cookieStore` is async + Chromium-only.

⇒ Admin browses drafts → SW caches them under the public URL → the next anonymous visitor on that device/profile is served the **draft**. **A URL denylist cannot fix this: there is no distinguishing URL.** Also, a broad API-origin `urlPattern` would match the **Mercure SSE stream** and break real-time updates.

**3. Offline data belongs in IndexedDB, in the page — not the SW.** The issue calls this a "lighter middle ground"; it is actually the **correct** tier, because auth state is only readable in the page (`$cwa.auth.signedIn` / the `cwa_auth` cookie). The app can therefore persist only when signed out and purge on sign-in/sign-out. It layers straight onto module #257's `routeCache` (already `markRaw`, route-path-keyed, bounded by `routeCacheLimit`, default 50 — already serialisable). Cross-ref module #259.

**4. Update UX — `registerType: 'prompt'`, not `autoUpdate`.** CWA admins edit inline, so an auto-updating SW can swap assets mid-edit. Prompt **requires UI** (none exists yet anywhere): `const $pwa = usePWA()` → `$pwa?.needRefresh` → `$pwa.updateServiceWorker(true)`, gated on `$cwa.admin.isEditing`. Note it is **`usePWA()`** (`usedPWAState`/`usePWAState` do not exist), `$pwa` is optional/client-only, and because it is `UnwrapNestedRefs`, **`needRefresh` is a plain boolean, not a ref**.

**5. Mercure offline — do not promise "revalidate on reconnect".** The module attaches **only `onmessage`** to its EventSource; there is no `onerror`, no reconnect handler and no `online`/`offline` listener. So it never error-spams, but it also never revalidates — recovery relies solely on the browser's native EventSource reconnect replaying via the `Last-Event-ID` header, which only backfills if the Mercure hub runs an event store. Otherwise events missed while offline are **lost silently and the store stays stale**. Flagged module-side as a separate follow-up; it is a prerequisite for a real offline story.

**Long-term unlock (API-side):** if `api-components-bundle` sends `Vary: Cookie` + `Cache-Control: private, no-store` on content endpoints, SW API caching becomes safe by construction. Worth raising there regardless — **without `Vary: Cookie`, any shared HTTP cache or CDN in front of the API has this same leak today, service worker or not.**

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