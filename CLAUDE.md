# CLAUDE.md — components-web-app

This is the demo/template application for `@cwa/nuxt`. It runs against the shared Docker API at `https://localhost/_api`.

History lives in the commits and in `CHANGELOG.md`. This file keeps the rules, the current setup, and the traps that aren't obvious from the code.

## Scope

This CLAUDE.md is the primary place to track demo fixes, fixture updates, and template changes needed as a result of module-side decisions. Do not modify application code directly unless explicitly asked.

## Rules and policies

- **Don't restate or override module or bundle defaults in the template** (Daniel, 2026-09-21). If a default is wrong, raise it module- or bundle-side. Example: the template sets no `pageCache` config and no `clearCachesOnSessionEnd`.
- **Docs sync.** Any change to this template must be reflected in the docs project at `/Users/danielwest/Documents/GitHub/_CWA/docs`. After completing work here, always check whether the docs need updating and flag it if so.
- **Remotes:** `origin` = GitLab (deploys the app, mirrors commits and tags to GitHub), `upstream` = GitHub (runs GitHub Actions). **Push to `origin` only.** Pushing to `upstream` can fight the mirror. If the mirror is behind: GitLab → Settings → Repository → Mirroring repositories → sync (↻).
- **Two issue trackers.** Issues are on GitHub (`gh` works against this repo), and GitLab has its own tracker too: `glab issue list -R silverback-web-apps/cwa/components-web-app`.
- **Every change to `main` gets a `CHANGELOG.md` line.** See *Releasing the template*.
- **Measure caching claims against `APP_ENV=prod` config, not just the dev stack.** Dev TTLs are deliberately short and hide problems (see *Page cache*).

## Releasing the template

**First release: `v2.0.0-alpha.1` (2026-09-24, on `85fd3e5`).** It shares the bundle's major, `2.x`, but keeps its own alpha count. **`create-cwa` shares the template's version**: `create-cwa` X downloads the template, manifest included, from tag `vX`. So every template release is also a `create-cwa` release with the same version. From now on, tag both on the same commit. Dependencies are tagged too: bundle `^2.0@alpha` and `@cwa/nuxt` `^2.0.0-alpha.1`.

**`CHANGELOG.md` is a rule (Daniel, 2026-09-25).** It lives at the repo root, so it's on GitHub:
- **Every change to `main` gets a line under `## Unreleased` before it's pushed.** One short line in the right group (Upgrade notes, Changed, Added, Fixed, Security, Removed), ending with a link to the commit on GitHub, or to the merged PR or MR that brought it. Put anything a downstream project must do by hand under *Upgrade notes*. Use the full SHA in the link.
  - **A commit can't link to itself** (its SHA doesn't exist yet), so add its line in a small follow-up commit, `Changelog: <subject>`, before pushing. Several changes can share one changelog commit. Changelog-only commits get no line of their own.
  - A merged MR or PR gets one line linking to it, not one per commit.
- **A release** renames `## Unreleased` to `## [X.Y.Z-alpha.N](…/releases/tag/vX.Y.Z-alpha.N) - <date>`, and adds a fresh empty `## Unreleased` above it. **That section is the tag's message** (`git tag -a vX -F <section file>`) **and the GitHub release notes** (`gh release create … --notes-file <section file>`).
- `create-cwa` projects don't get this file (`alwaysExclude` in `cwa-manifest.json`): it describes the template, not the new project.

To release:
1. Update everything and run the usual checks. Make sure `CHANGELOG.md`'s Unreleased section is complete, then turn it into the version's section.
2. Set `packages/create-cwa/package.json`'s version to the same `X.Y.Z-alpha.N`, then commit and push.
3. On that commit, `git tag -a vX.Y.Z-alpha.N -F <the version's CHANGELOG section>` and `git tag create-cwa/vX.Y.Z-alpha.N`, then push both tags to `origin`, and only there. **Push the template tag first, or at the same time.** A CLI published before its template tag exists fails for every user with "No CWA template found".
4. When the tag has mirrored (`gh api repos/components-web-app/components-web-app/git/ref/tags/<tag>`), run `gh release create <tag> --verify-tag --prerelease --notes-file <the version's CHANGELOG section>`. `--verify-tag` stops `gh` from creating the tag on GitHub itself, which would fight the mirror.

A plain version tag starts no deploy: every GitLab job is limited to branches or `main`, and no GitHub workflow runs on tags other than `create-cwa/v*`. A release does change what new installs get, through the matching `create-cwa`. `pnpm create cwa my-app -- --ref main` (or `--ref <any tag or branch>`) gets another version of the template. Installs from `create-cwa` 0.x still read the manifest's `branch` (`main`), so leave that field in `cwa-manifest.json`.

## Publishing `create-cwa` to npm

The CLI lives in `packages/create-cwa/`. It is published manually via a git tag; there is no automatic publishing.

1. Set the version in `packages/create-cwa/package.json` to the template release it installs (`0.1.1` was the last 0.x). The workflow publishes it as `latest`, because every release is still an alpha.
2. Commit and push to `origin`.
3. Tag `create-cwa/vx.y.z` and push the tag to `origin`.
4. GitLab mirrors the tag to GitHub → `publish-create-cwa.yml` publishes to npm via OIDC.

**No stored token.** Publishing uses npm's OIDC Trusted Publishing (configured at `npmjs.com/package/create-cwa/access`: org `components-web-app`, repo `components-web-app`, workflow `publish-create-cwa.yml`).

**A new package's first publish must be local**, because OIDC can't be configured for a package that doesn't exist yet: from the package dir, `pnpm install && pnpm run build && pnpm publish --access public --no-git-checks`. **Don't add `--provenance`** locally (it needs a GitHub Actions runner). **Don't forget `--access public`:** a scoped package's first publish is otherwise private and 404s for everyone (hit with `@cwa/nuxt`; fixed with `npm access set status=public`, then about 90s for npm's cached 404 to clear).

**When to bump:** changes to `packages/create-cwa/src/`, changes to `cwa-manifest.json` that affect the CLI, and **every template release** (since `2.0.0-alpha.1` the CLI downloads the template tag matching its own version, so template changes reach new installs only through a release).

## Dependencies

**Current:** `@cwa/nuxt` `^2.0.0-alpha.3` (a normal dependency, not an `npm:@cwa/nuxt-edge@…` alias), bundle `components-web-app/api-components-bundle` `^2.0@alpha`, locked at 2.0.0-alpha.6 (resolves to the newest alpha tag, not `main`, via `minimum-stability: dev` + `prefer-stable`), Nuxt 4.5 (Vite 8/Rolldown, unhead 3), API Platform 5, PHPUnit 13, symfony/mercure 0.8, Flysystem 3 (tagged; Flysystem 4 isn't possible yet, liip/imagine-bundle allows only `^1|^2|^3`).

**Updating the bundle:** `composer update components-web-app/api-components-bundle` inside the php container (`api/composer.json` doesn't require API Platform directly, so a plain `composer update` may move it a major). Then `bin/console doctrine:migrations:diff`, generate and commit any migration with the lock, `lint:container` in dev and prod, PHPUnit, `composer audit`, and check pages hydrate. **A `composer update` in the running dev container can cause a few minutes of 500s** while `vendor/` is rewritten; it recovers without a restart.

**Updating the module / front-end deps:** on the host use `pnpm up/remove/dedupe --lockfile-only` (a plain host `pnpm up` fails with `ERR_PNPM_UNEXPECTED_STORE`, because host `node_modules` comes from the container's store), then `docker compose restart app`. Then `pnpm run build` (runs `vue-tsc` via `typescript.typeCheck: true`) and a real-browser hydration check (see *Front end*).

**Check after every dependency change:**
```sh
grep -nE '^  vue@3\.5\.[0-9]+:' app/pnpm-lock.yaml   # must print exactly one line
grep -nE '^  typescript@' app/pnpm-lock.yaml         # must be 6.0.3 only
```

### ⚠ TypeScript is pinned to exact `6.0.3`

- Do **not** bump to 7.x. TS 7 is the native (Go) rewrite; `vue-tsc` (3.3.11) still resolves `typescript/lib/tsc` and fails with `ERR_PACKAGE_PATH_NOT_EXPORTED: ./lib/tsc`. Revisit only once `vue-tsc` officially supports TS 7.
- **`pnpm up --latest` DOES rewrite the exact pin to 7.x.** An exact pin is not protection. After it, manually revert to `6.0.3` and reinstall. Prefer `pnpm dedupe`, which doesn't touch it.

### ⚠ Duplicate `vue` copies

A split (two `vue@3.5.x` versions, or one version twice with different `typescript` peers, because vue takes typescript as an optional peer) causes:
- a huge structural `Ref<HTMLElement>`-not-assignable `vue-tsc` error (seen on `useHtmlContent(...)` in `HtmlContent.vue`/`AltHtmlContent.vue`). It can pass locally yet fail CI's `--frozen-lockfile --offline` install.
- **a broken production image at runtime**: `ERR_MODULE_NOT_FOUND … /srv/app/server/node_modules/vue/server-renderer/index.mjs`. All copies collapse onto one Nitro output path and the tracer copies files from the wrong one.
- `nuxt dev` failing with `No fs option provided to compileScript in non-Node environment` (duplicate `@vue/compiler-sfc`).

Diagnose from the lockfile, never `node_modules`. **Fix with `pnpm dedupe`**; aligning typescript to one version is often enough. A `pnpm.overrides` pin on `vue` is the fallback.

Known harmless duplicates: `nuxt` pulls its own `@nuxt/devtools` 3.x beside the 4.0 beta (the beta is loaded), `@nuxt/kit@3.21.8`, and `@nuxt/ui`'s own `@tiptap/*@3.26.1`. Dev logs `NDT_DEP_0003 extendServerRpc is deprecated` from the devtools beta; harmless.

### Module changes that constrain the template

- **`extends: ['@cwa/nuxt/layer']`** in `app/nuxt.config.ts` (#92), not a path into `node_modules`, so pnpm's symlink doesn't defeat Nuxt's page-prefetch filter. The export exists only from module `6c33a6e`: never pair it with an older module.
- **`NUXT_CWA_API_URL`** (private) replaced `NUXT_PUBLIC_CWA_API_URL` for the server's API URL (module #345), so the internal URL is no longer in page HTML. The old name still works as a deprecated fallback that warns. **Never pair the new name with an older module**: it wouldn't be read and SSR would fall back to the browser URL, which the app container can't reach. Downstream projects rename it in the same deploy as the module update (CHANGELOG upgrade note).
- **The prefetch realpath hook belongs in the module (#329).** Don't re-add a `pages:extend` hook here.
- **File API rename (module #252):** `withImage`→`withFile`, `useCwaImage`→`useCwaFile`, `useCwaImageResource`→`useCwaFileField`, `ImageOpsType`→`FileOpsType`. `useCwaResourceUpload(iri)` returns a `bind` object for `<CwaUiFormFile v-bind="bind">`; its default `fileDisplayType` is `'File'`, so pass `useCwaResourceUpload(iri, 'file', 'Image')` for "image" copy.

### Bundle changes that constrain the template

- **`user.email_links.default_origin` must be set** (bundle alpha.4, #316), or password-reset and verification emails are refused with a 400. The template sets it as `%app.email_link_default_origin%` in `services.php`: `EMAIL_LINK_DEFAULT_ORIGIN` if set, otherwise `https://%env(BROWSER_SERVER_NAME)%`. A site whose emails must link to several front ends adds `allowed_origins` by hand (an array node, not one env var).
- **`GET /_api/_/health`** returns `200 no-store, private` but still passes through Souin. Exclude it from `@use_cache` before pointing a readiness probe at it (see #62 below).
- **Mercure 0.8 changed `HubInterface`** (adds `getProtocolVersion()`, `getCookieName()`; `getUrl()` moved to `RemoteHubInterface`). `App\Mercure\SkipAwareMercureHub` implements `RemoteHubInterface` and forwards them. **Any other hub decorator needs the same, or `cache:clear` dies with a fatal error.**
- **Filters are QueryParameters (#89), not `#[ApiFilter]`** (bundle removed `OrSearchFilter`). See *API*.
- **`debug:config api_platform exception_to_status`** lists only the bundle's four entries even though API Platform's defaults are also kept. Test error mapping with a request, not the config dump.

## Local dev

- **App container.** `app/` and `app/node_modules` are bind-mounted into `app`, whose dev image runs `pnpm install; pnpm dev`. Don't run `pnpm dev` on the host (it's never reached through `https://localhost`).
- **⚠ A host `pnpm install` crashes the running dev container** (`Cannot find module 'typescript'`, missing `@nuxt/cli/dist/dev/index.mjs`, Caddy 502/503). Fix: `docker compose restart app`. Then count errors only since the container's start (`docker inspect -f '{{.State.StartedAt}}'`), or you'll read the pre-restart crash as a failure.
- **⚠ Editing `nuxt.config.ts` while `app` runs can leave it broken** (`Private field '#particles' must be declared`, a layer style URL served as JS). `docker compose restart app`.
- **Logging in locally:** `https://localhost/login` (there is no `/admin`; admin screens are under `/_cwa`). The Caddy root cert: `docker compose cp php:/data/caddy/pki/authorities/local/root.crt …`.
- **Dev JWT keys** are generated on first boot by the entrypoint (`lexik:jwt:generate-keypair --skip-if-exists`, only when `APP_ENV` isn't `prod`). The prod image never generates keys.
- `app/.dockerignore` (`node_modules`, `.nuxt`, `.output`) keeps local state out of builds, so local and CI builds match.

### ⚠ Postgres with no statistics → 30s page loads

- **Symptom:** every page ~30s (erratic: 2s / 4s / 60s), DB CPU high, yet idle-looking I/O. Idle DB CPU, tiny tables and a 99.99% cache-hit ratio are all **consistent with it**; don't "rule out the database" on those signals.
- **Cause:** autoanalyze needs `50 + 0.1×rows` changes, so small component tables stay at `reltuples = -1` forever. Doctrine's `JOINED` inheritance emits a ~30-table hydration query, estimates compound into billions of rows, and the planner (GEQO, randomised) throws parallel workers at it.
- **Diagnose:** `EXPLAIN (ANALYZE, BUFFERS)` and `SELECT relname, reltuples FROM pg_class` (look for `-1`).
- **Fix in place:** the entrypoint runs `dbal:run-sql "ANALYZE"` after migrations (non-fatal `|| echo`), and `compose.yaml` starts postgres with `-c autovacuum_analyze_threshold=0` (a server flag, because the `app` user can't `ALTER SYSTEM`). Manual: `docker compose exec database psql -U app -d app -c 'ANALYZE;'`. If plan variance ever resurfaces: `-c geqo=off -c join_collapse_limit=30 -c from_collapse_limit=30`.
- The removed `deploy.resources` CPU cap in `compose.yaml` was dead config here (the override's `limits.cpus: '1.5'` wins the merge). It had nothing to do with the slow pages.

### ⚠ Caddyfile edits: truncation, and `adapt` isn't enough

- **Single-file bind mounts truncate a longer replacement file** (#57): Caddy reports `unexpected EOF` / `unexpected token` on a file that's valid on disk. Fixed by reading the Caddyfile and entrypoint through the `./api:/app` directory mount (`entrypoint`/`command` in `compose.override.yaml`; keep `command` in sync with the `frankenphp_dev` CMD in `api/Dockerfile`). **If a parse error ever looks impossible, compare byte counts first:** `wc -c < api/frankenphp/Caddyfile` vs `docker compose exec php sh -c 'wc -c < /app/frankenphp/Caddyfile'`. A mismatch needs `docker compose up -d --force-recreate php`.
- **Quote characters in `#` comments are fine.** An old claim that they break Caddy was really the truncation.
- **⚠ CEL has no comment syntax.** A `#` line inside the backticks of `@use_cache expression` is a runtime error (`token recognition error at: '#'`, crash-looping php) that **`frankenphp adapt` reports as clean**. Keep commentary in Caddyfile comments above the block. After `adapt`, always `docker compose up -d --force-recreate php` and check it reaches `healthy`.
- `--watch` logs `unable to load latest config` on partial reads; usually noise. **Never judge a change by reading `/config/…` from the admin API** (it races the reload). Use `adapt` for syntax and `docker compose restart php` before measuring.

### ⚠ `composer update` fails with a Flex recipes 404

`The ".../symfony/recipes-contrib/flex/main/index.json" file could not be downloaded (HTTP/2 404)` is a **stale GitHub PAT** in `/config/composer/auth.json`. GitHub returns 404, not 401, for a bad token, and an unauthenticated `curl` returns 200, so manual testing misleads. It persists because `/config` is a volume and the entrypoint only clears it when `vendor/` is empty. Fix: `docker compose exec php rm -f /config/composer/auth.json` (or set a valid `GITHUB_TOKEN`).

### Cold dev renders can 504

The first request to a page after a restart can exceed Souin's 10s backend timeout (`504`, `cache-status: … detail=DEADLINE-EXCEEDED`). Retry. A freshly restarted dev server also 504s under concurrency while Vite compiles.

## Caddy and Souin (`api/frankenphp/Caddyfile`)

- **Admin API is loopback-only.** `admin localhost:2019` with an `origins` list; port 2019 isn't published and helm has no `admin` containerPort. Admin rejects any Host not in `origins` with 403, even on loopback. Use it from inside the php container: `docker compose exec php curl -s http://localhost:2019/souin-api/souin` lists stored keys (`[]` = nothing cached). `CACHE_URL` in `api/.env` and helm's `cache-url` are `http://localhost:2019/…`. Flush everything: `curl -X PURGE http://localhost:2019/souin-api/souin/flush` in the php container or API pod.
- **`@use_cache` cookie clause.** `{http.request.cookie.api_component} == ""` does **not** match an absent cookie (a missing *header* does resolve to `""`; a missing cookie doesn't). The clause is `!{http.request.header.Cookie}.matches("api_component=[^;]+")`: cache when the cookie is absent or empty, never when it has a value. Its only job is to never cache an authenticated response; keep it fail-safe.
- **Cache host key (SSR and browsers share entries).** SSR calls the API on an internal host (`php.local`, or the in-cluster service), and `@internal` rewrites Host to `BROWSER_SERVER_NAME`, but `cache` runs before that. So the key uses `{http.vars.cwa_cache_host}`: `BROWSER_SERVER_NAME` for `/_api*`, `/uploads/*`, `/bundles/*` on a dotless or `.local` host, otherwise the request's Host.
- **One entry per page, whatever the browser sends (#79).**
  - `order cache after encode`: the cache stores the uncompressed body once and `encode` compresses per client. Cost: compression on every response, and uncompressed responses carry no `Vary: Accept-Encoding`.
  - `Accept` is in the key **for `/_api` only** (`@cache_accept` + `{http.vars.cwa_cache_accept}`; use the full `{http.vars.*}` form, `{vars.*}` isn't expanded in the global block).
  - **⚠ Don't "simplify" to dropping `Accept` from the key and relying on `Vary: Accept`.** API Platform's Swagger UI HTML sends no `Vary: Accept`, so JSON-LD requests got cached HTML. Also tried and failed: Souin per-path `cache_keys` (ignored when a global `template` is set, v1.7.9) and Caddy `map` (stored the literal placeholder).
- **Tracking parameters are stripped** (`uri @tracking_query query { -utm_source … }`), so `utm_*`, `gclid`, `fbclid`, `srsltid` etc. don't split the cache for pages or the API.
  - **⚠ It must run only when the query contains a listed parameter, and never for `/_nuxt/*`.** Caddy re-encodes the whole query whenever `uri query` runs (`?vue&…&lang.css` → `?vue=&…&lang.css=`), which made Vite serve every SFC style block as raw CSS labelled JS and broke `nuxt dev` (`Unexpected token '.'`, `Private field '#particles'`). If dev ever serves style blocks as raw CSS, compare Caddy against a direct request to Nuxt first.
  - **Keep the matcher expression's parameter list identical to the `-param` lines.** No wildcards; add a `-name` line per parameter. A project needing one server-side removes it from both.
  - Caddy's access log shows the **original** URI; a `utm_` there doesn't mean the strip failed.
- **SSE must never be cached.** The Mercure exclusion is not optional: a cached SSE response never completes and connections pile up, which looks like the site falling over.
- **Purge separator.** `SouinPurger` hard-codes `', '`. API Platform's `xkey.glue` is only read by `VarnishXKeyPurger` (and is gone in API Platform 5). Check which purger class receives a parameter before assuming a mismatch.

### ⚠ Patched Souin build (#84)

Souin v1.7.9 deletes purged tags' index entries with an **unanchored regex**, so purging a tag orphans every tag that contains it (every write to one component group or position orphaned all the others; routes where one path contains another). Orphaned entries are then unpurgeable for the full prod `s-maxage` (a year). Upstream: darkweak/souin#867, fix PR #868.
- `api/frankenphp/souin/v1.7.9-purge-fix.patch` + the builder-stage `COPY`/`RUN` in `api/Dockerfile` + `--with github.com/darkweak/souin=/tmp/souin`. **Remove all three together** once a Souin release has the fix.
- `bin/test/souin-purge-isolation.sh` (in the unit-tests job on GitLab and GitHub) fails on the unpatched binary. Run it locally without an image build: `docker compose exec -T php sh -s < bin/test/souin-purge-isolation.sh`.
- A site upgrading to the patched image whose API pod wasn't recreated needs one full flush.
- Downstream copies must build the same Souin version (`frankenphp build-info | grep souin`), or the patch fails loudly.

### Caddy build pins

- `--with github.com/dunglas/mercure/caddy@v0.24.2` is pinned: `mercure/caddy@v1.0.0` declares `go 1.27`, but `dunglas/frankenphp:builder` ships Go 1.26 with `GOTOOLCHAIN=local`. **Unpinning checklist (#67), all together:** confirm the builder ships Go 1.27+ (`docker run --rm --entrypoint sh dunglas/frankenphp:builder -c 'go version'`); check the Caddyfile's mercure directives (`transport`, `publisher_jwt`, `subscriber_jwt`, `anonymous`, `subscriptions`, `cors_origins`) against Mercure 1.0; unpin or pin a tested `v1.x`.
- Comment lines inside a `RUN` continuation are safe (BuildKit strips them).

## Page cache

The module renders cacheable pages with `Surrogate-Key: cwa-html, <every resource IRI it rendered from>` and owns `Cache-Control` through its own Nitro hook. The bundle purges those keys on write. The template sets **no** page-cache config.
- A component write drops exactly the pages that rendered it; a `SiteConfigParameter` write drops every page via `cwa-html` (the bundle's `purge_rendered_html_classes` default).
- **`cwa-html` is a cross-repo contract**: `RENDERED_HTML_SURROGATE_KEY` in the module, `HttpCachePurger::RENDERED_HTML_TAG` in the bundle. A mismatch fails silently.
- **Lifetime follows the API:** pages take the lowest `s-maxage`/`Expires` of the render's API responses (module #325), falling back to 3600 only if none gave one. The API's `shared_max_age` is **60 in dev** and **31557600 (a year) in prod** (`config/packages/prod/api_platform.yaml`). Both are intended; invalidation is purge-driven. `staleWhileRevalidate` stays 0 deliberately.
- **The dev TTL masks purge bugs**: a page looks invalidated within a minute even if nothing purged it. Measure `cache-status` immediately before and after the write.
- **Exclusions** (no `cache-status` header at all): `/login`, `/forgot-password`, `/reset-password/*` (one entry per token otherwise), `/verify-email`, `/confirm-new-email` (the bundle emails tokenised links there even though the module has no pages yet), `/user-area`, `/_cwa/healthcheck`, `/.well-known/mercure`, `/_api/me`, `/_api/logout`, and anything with `api_component=<value>` or `Authorization`. **When the module adds or renames an auth page, update this matcher** (module pages: `@cwa/nuxt`'s `dist/runtime/templates/pages/`).
- **Error pages are never stored** (module #340): a 404 goes out `private, no-store` with no `Surrogate-Key`, so a scheduled route is 200 as soon as its `liveAt` passes. If a scheduled route is still 404 after its time and `cache-status` shows a Souin `hit`, that's a regression.
- A 404 on a draft nested component no longer makes the page uncacheable (module #324), and its IRI stays in the page's `Surrogate-Key`, so publishing it purges the page.
- **Admin purge buttons:** site settings → purge page cache (`POST /_/rendered_html/purge`) and "Purge all cached data" (`POST /_/http_cache/purge`). CLI: `silverback:api-components:purge-rendered-html` (pages only) and `silverback:api-components:purge-http-cache` (everything).
- The sitemap is sent with `Surrogate-Key: cwa-html, /_api/_/routes`, so route writes and the deploy purge drop it.

## Deploy and Kubernetes

### The API is capped at one replica, on purpose

- `autoscaling.maxReplicas: 1` and `AUTOSCALE_MAX` default 1. Souin's `otter` store is in-memory and purged via `localhost:2019`, so a write on a second pod never purges the first pod's cache (and with a year-long `s-maxage` that is permanent). Mercure's `bolt` transport is pod-local too. One pod served ~974 req/s cached. **Raise it only alongside a shared cache store and a clustered Mercure hub** (#85); and then every `kubectl exec deploy/…` purge must loop over every API pod.
- It also resolves the migration race between API pods.
- **Eviction protection (#78)**, because one replica makes a single eviction an outage:
  - API pod: `cluster-autoscaler.kubernetes.io/safe-to-evict: "false"`. GKE node upgrades still drain it (a brief, unavoidable outage).
  - SSR pods: `pwa-pdb.yaml` with `maxUnavailable: 1`, plus `topologySpreadConstraints` on hostname (`ScheduleAnyway`).
  - No PDB on the API (it would block every node drain until GKE force-evicts after an hour). No `minAvailable: 1` on SSR (same, with one replica).
  - **A PDB whose selector matches nothing protects nothing and raises no error.** The PDB selector must equal the SSR labels (`name=cwa-pwa`) and not match the API (`name=cwa`); recheck when labels change.
  - Open: Spot VM preemptions are involuntary; neither the annotation nor the PDB applies.

### ⚠ php readiness probe: `timeoutSeconds: 5` (#62)

The probe path `/_api/_/site_config_parameters.jsonld` goes through Souin. Souin coalesces upstream fetches through `singleflight` keyed on the cache key; a caller that disconnects mid-fetch leaves the entry stuck, so every later request on that key waits out the 10s backend timeout and 504s. With the default 1s timeout, the first probe on a cold worker was cancelled and **the pod stayed `0/1` for its whole life** (three hours in production). Deleting the pod is the only recovery.
- Keep `timeoutSeconds: 5` whatever else changes. It is the protection, not the delay.
- Readiness `initialDelaySeconds: 5` (Caddy serves at ~+6s; 30s was 24–33s of avoidable downtime per eviction). Startup probe `periodSeconds: 5`, `failureThreshold: 60` (300s boot budget for migrations and `ANALYZE`).
- Upstream: darkweak/souin#849 (fix pending).
- The PWA's `/_cwa/healthcheck` probe has no Souin in front, so an unset timeout there can only flap. `/_cwa/healthcheck` doesn't call the API; `/_cwa/readiness` does (503 when php is down).

### Scaling and sizing (#69)

- `hpa.yaml` must target the bare `cwa.fullname` (the old `-api` suffix meant the HPA never worked). An HPA's CPU target is a percentage of the **request**, so `php.resources.requests.cpu: 200m` is required; there is deliberately **no php CPU limit** (Caddy serves cached responses and should burst).
- The PWA has its own `pwa.replicaCount`/`pwa.autoscaling` and `pwa-hpa.yaml`. SSR costs ~150ms CPU per render, so a small CPU limit caps throughput at limit/150ms regardless of pods (the old 150m limit meant ~1 page/second). Now 1000m limit / 250m request. PWA HPA targets 70% CPU, `scaleUp.stabilizationWindowSeconds: 0`, `scaleDown` 600s. **No memory target on the SSR HPA** (`PWA_AUTOSCALE_MEMORY_PERCENT` defaults to `~`): Node rarely returns memory and an HPA only scales down when every metric is under target.
- **Per-track sizing in `bin/devops/k8s.sh`** (`PWA_*` mirroring `AUTOSCALE_*`, plus `PHP_CPU_REQUEST`/`PHP_MEMORY_REQUEST`/`PHP_MEMORY_LIMIT`): `stable`/`canary` → min 2 / max 6 SSR; others → min 1 / max 2 with smaller requests. **Limits are identical on every track.** An explicit env var always wins.
- **Internal API URL:** the chart's `api-url` default is the in-cluster service with `/_api`, and `k8s.sh` passes `apiUrl: ~` so it applies (SSR used to hairpin through the public load balancer over TLS). `apiUrlBrowser` gets the public URL. Keep this default in the chart (`cwa.fullname` handles `trunc 63` and the release-name edge cases).
- **`Chart.lock`**: after editing `dependencies:` in `Chart.yaml`, run `helm dependency update helm/cwa` and commit only `Chart.lock`. CI's `helm_init` rewrites the lock, so a stale one never shows in CI.
- **Rendering the chart locally** needs a scratch copy with `helm dependency build` (downloads postgresql into the gitignored `helm/cwa/charts/`) and the secret values `deploy` passes with `--set`. `helm lint` with ingress **disabled** is worth running: `NOTES.txt` had bad helper names only reachable there.

### Deploy-time page cache: purge, warm, audit

**⚠ Purge after every deploy (#71).** Cached HTML references the `/_nuxt/*` hashes of the build that rendered it; after a front-end deploy those 404 and the page never hydrates, for up to a year in prod.
- `purge_rendered_html [track]` in `k8s.sh` runs straight after `deploy` in all eight deploy steps (GitLab and GitHub, review/staging/production/canary), before fixtures. It finds deployments by **exact** name label (`cwa` = API, `cwa-pwa` = PWA), waits for `rollout status` on the PWA **then** the API (old PWA pods can otherwise render old HTML into the new API pod's empty cache), then `kubectl exec`s `purge-rendered-html` in the API pod. A missing deployment exits 1.
- **Never revert or cherry-pick the purge calls without a bundle lock that has the command** (they shipped together in `dd04960`), or every deploy fails.
- `kubectl exec deploy/…` reaches one pod; that's complete only while the API has one replica.
- Deploys use `purge-rendered-html`, not the full flush: a pod restart already empties `otter`.

**Cache warm (#80).** `warm_cache [base_url]` reads the sitemap (follows the redirect to `/sitemap_index.xml` and one level of children), rewrites each `<loc>` origin to `CI_ENVIRONMENT_URL`, and requests each page anonymously with `Accept: text/html`, 3 at a time (`WARM_CACHE_CONCURRENCY`). Any non-200 (including 3xx; redirects aren't followed) exits 1 with a `CACHE WARM FAILED` banner and a GitHub `::error`.
- **It runs as its own job/step, never inside the deploy job.** A warm failure must not fail a live deploy (the deploy job's `retry: 1` would redeploy the release). GitLab: `warm cache <track>` jobs with `allow_failure: true` and `environment: action: verify`, each installs `curl` (`alpine` has none). GitHub: a `continue-on-error` step after the fixtures step.
- **Only production is warmed by default.** `WARM_CACHE_PRODUCTION` is on unless `"false"`; `WARM_CACHE_STAGING`/`_REVIEW`/`_CANARY` are off unless `"true"`. These are per-track variables, not GitLab environment-scoped ones, because the staging job uses `environment: production`. Production doesn't wait for any warm job.
- Parsing uses `grep`/`sed` under busybox ash (no `jq`/`xmllint` in CI images; GitLab sources `k8s.sh` before `bash` exists). `WARM_CACHE_INSECURE=true` is for the local self-signed stack only.
- The sitemap must list only real 200 pages (a leftover `test-static` sitemap with a fake URL was removed for this reason).

**Lighthouse audit (#87).** `performance_audit [base_url]` runs `@lhci/cli` (pinned `0.15.1`) against cached pages.
- **Manual.** GitLab: `performance audit review|staging|production` are `when: manual` (set `PERFORMANCE_AUDIT_<TRACK>="false"` to remove one); canary is opt-in (`PERFORMANCE_AUDIT_CANARY="true"`) because it shares production's hostname. GitHub: `.github/workflows/performance-audit.yml` (`workflow_dispatch`). A missed budget never fails a deploy.
- Pages: `PERFORMANCE_AUDIT_URLS`, else the first `PERFORMANCE_AUDIT_MAX_PAGES` (default 3) sitemap pages (`sitemap_pages`, shared with `warm_cache`). 5 runs per page, real throttling (`PERFORMANCE_AUDIT_THROTTLING=devtools`; `simulate` is available), mobile by default, pages not audited in parallel on purpose.
- Budgets in `bin/devops/lighthouserc.json` (score ≥ 0.8, LCP ≤ 2.5s, CLS ≤ 0.1, TBT ≤ 200ms as errors; page weight ≤ 1.6MB warn). Output in `performance-report/` (`summary.md` via `bin/devops/lighthouse-summary.mjs`, `browser-performance.json`).
- **⚠ Any `--collect.settings.*` CLI flag replaces `lighthouserc.json`'s whole `collect.settings` block.** So all collect settings are passed on the command line and the file holds only budgets.
- **Don't chase CI's simulated scores**: they're bimodal on shared runners (0.60–0.96 for the same deploy). **Don't judge budgets on the dev stack** (unbundled Vite, ~4 MiB per page).
- GitLab runs in a pinned `cypress/browsers` image (`$PERFORMANCE_AUDIT_IMAGE`), which has no `curl`; the job installs it. Chrome needs `--headless=new --no-sandbox --disable-dev-shm-usage`. When testing in a container, mount the repo writable, or `lhci collect` crashes writing `.lighthouseci/`.

### TLS certificate rotation (#86)

Changing the stable ingress's host list in place makes cert-manager put a self-signed certificate in the live secret while it issues (minutes, or an hour of backoff if a challenge fails): a hard outage with HSTS. Let's Encrypt allows 5 certificates per identical name set per week.
- `ensure_tls_certificate` runs in `deploy` before helm (stable track, `INGRESS_ENABLED=true`, `CLUSTER_ISSUER` set). Same `dnsNames` as the live ingress's certificate → keep it (almost every deploy). Different → apply `<LETSENCRYPT_SECRET_NAME>-stable-api-<8-char sha256>`, wait for `Ready` (`TLS_CERTIFICATE_TIMEOUT`, default 600s), then helm. Not issued → the deploy fails **before helm**, live ingress untouched.
- `cleanup_tls_certificates` keeps the new and previous rotated certificates (label `cwa.rocks/tls-rotation=true`).
- **The live ingress is read by name** (`cwa_fullname` mirrors the chart's `cwa.fullname`), not by label (a site may carry a redirect ingress with the same labels, which would rotate every deploy) and not by host (at launch `DOMAIN` itself changes).
- No RBAC for `certificates.cert-manager.io` → warns and falls back. First deploy → ingress-shim issues as before.
- Only verified against stub `kubectl`/`helm`. Watch the first real hostname change.
- To retire a preview hostname, remove it from `KUBE_INGRESS_ALIAS_DOMAINS` and deploy.

### Review namespaces (GitLab #4)

`ensure_namespace` never creates namespaces (CI can't create role bindings). `skip_review_without_namespace` runs first in the GitLab review job and exits **3** (`REVIEW_NO_NAMESPACE_EXIT_CODE`) when the namespace is missing, which `allow_failure: exit_codes: [3]` shows orange. **Keep those two numbers in sync.** Only `NotFound`/`Forbidden` count as missing; any other `kubectl` error fails red. Staging, canary and production keep plain `ensure_namespace`. GitHub's `ci.yml` uses a "Check for a review namespace" step that warns and skips.

## CI

- **GitLab `workflow:rules` has `merge_request_event → when: never`** and `unit tests` has `only: branches` (#88). MR pipelines always failed (no build, missing image). **Don't switch to MR pipelines casually:** every `only:`/`except:` job would need converting to `rules:`, and review apps and image tags are keyed by branch. GitLab won't mix `rules` with `only`/`except` in one job.
- **`production` and `canary` need `build api`, `build app`, `unit tests` and `behat tests`** (all `optional`), not just `staging`, so a manual deploy can't ship the previous image or skip failing tests when `STAGING_ENABLED=false` (GitLab #1).
- **GitHub Actions** (`.github/workflows/`): `ci.yml` (push: build, PHPUnit, Behat, review or staging deploy), `production.yml` (manual canary/production), `cleanup.yml` (PR closed), `performance-audit.yml` (manual), `publish-create-cwa.yml` (this repo's npm release; excluded from generated projects). Images go to GHCR. They call the same `bin/devops/k8s.sh` functions; `install_dependencies` is replaced by `azure/setup-kubectl`/`setup-helm`.
- **GitHub doesn't export variables to jobs**: each must be mapped in `env:`. `GCLOUD_JSON`, `GCLOUD_BUCKET`, `GCLOUD_PUBLIC_URL` travel together.
- **GitHub settings.** Secrets: `KUBECONFIG`, `KUBE_CONTEXT`, `KUBE_NAMESPACE_PRODUCTION`, `JWT_PASSPHRASE`, `JWT_SECRET_KEY`, `JWT_PUBLIC_KEY`, `MERCURE_JWT_SECRET`, `DATABASE_URL`, `ADMIN_PASSWORD`, optional `GCLOUD_JSON`. Variables: `KUBE_INGRESS_BASE_DOMAIN`, `RELEASE_PRODUCTION`, `CORS_ALLOW_ORIGIN`, `TRUSTED_HOSTS`, `ADMIN_USERNAME`, `ADMIN_EMAIL`; optional `CI_DISABLED` (`"true"` in this repo on GitHub, so mirrored pushes don't run the app pipeline), `BUILD_DISABLED`, `TEST_DISABLED`, `REVIEW_DISABLED`, `STAGING_ENABLED`, `ENABLE_DATABASE_FIXTURES`, `WARM_CACHE_*`, `PERFORMANCE_AUDIT_*`, `GCLOUD_BUCKET`, `GCLOUD_PUBLIC_URL`, `KUBERNETES_VERSION`, `HELM_VERSION`.
- Validate with `glab ci lint` and `actionlint`.

## Fixtures and tests

- **⚠ Fixtures append by default.** Without `--append`, `doctrine:fixtures:load` empties every table. Locally: `docker compose exec php bin/console doctrine:fixtures:load --append`. The pipeline's `load_fixtures` appends (#74). Since bundle 2.0.0-alpha.5 (#335), `--append` with a `CwaFixtureBuilder` scaffold is **idempotent**: it creates only what's missing, keeps everything that exists (a page's content is editors' once it exists), and prints a `created …` / `kept …; skipped …` summary. A second append on the template's scaffold exits 0 with identical rows and IDs. So a new page added to a scaffold reaches a seeded site without purging.
- **`FIXTURES_PURGE` opts a fixture job into emptying the database first** (MR !11; only `load_fixtures` reads it, never a deploy or pod start, unlike `RESET_DATABASE`):
  - **review:** `"true"` (or `"force"`).
  - **production:** only `"force"`. A project-wide `"true"` meant for review apps prints a notice and appends.
  - **⚠ Staging has no fixture job at all**, on GitLab or GitHub (Daniel, 2026-09-25). Staging's GitLab jobs run under `environment: production` and get production's `DATABASE_URL`, so (whenever production has a `DATABASE_URL`) a staging load would write to production. Don't add one back.
- **Every fixture load ends by flushing the whole HTTP cache** (`silverback:api-components:purge-http-cache`). The load changes the database underneath whatever Souin cached since the deploy, and a purge load deletes rows with plain SQL, so nothing else purges the old content (served for up to a year in prod). A failed load stops before the flush.
- **Fixtures in CI:** GitLab's fixture jobs (review, production) are manual and gated by `ENABLE_DATABASE_FIXTURES`. GitHub's "Load fixtures" step runs after each review or production deploy while `vars.ENABLE_DATABASE_FIXTURES == 'true'` (no manual steps in a push workflow), so set it only for a new environment's first deploy. With `FIXTURES_PURGE` also set, **every** such deploy purges.
- **`UsersFixture` uses `overwrite: true`** (named args: `superAdmin: true, overwrite: true`). Without it, a rerun used to create a duplicate admin (columns have no unique index), and login then 500s with `NonUniqueResultException`; since bundle #254 the factory throws instead, so a rerun would fail. It **resets the admin password** to `ADMIN_PASSWORD` on every fixtures run. Sites generated before 2026-08-13 may need duplicate `"user"` rows deleted, keeping the oldest per username.
- **Never run `doctrine:fixtures:load` against the dev DB to compare with a fresh load.** Use a throwaway database. A dev DB can legitimately differ (e.g. extra blog articles; `BlogScaffoldPart` creates three).
- **⚠ Behat in the php container wipes the dev database.** The container's `DATABASE_URL` overrides `.env.test`, and `DoctrineContext` drops the schema per scenario. Always pass `-e DATABASE_URL=…/<throwaway_db>` and check `bin/console dbal:run-sql "select current_database()"` first.
- **PHPUnit runs via `vendor/bin/phpunit`** (PHPUnit 13). **Don't reintroduce `simple-phpunit` or `SYMFONY_PHPUNIT_VERSION`** (it downloads 9.6, which can't read the config).
- `bin/console lint:container` in dev and prod is a valid gate.
- `CwaFixtureBuilder` throws for an unrouted parent (bundle #245/#246): a non-template child with no `route:` under an `isTemplate: true` page without a route fails `flush()`.
- **ExampleFormType scaffold** (`/form`, `uiComponent: 'ExampleForm'`) covers every Symfony field type. Notes that matter when editing it:
  - `Form` uses `TimestampedTrait`; `createdAt`/`modifiedAt` are set manually in the fixture until the bundle's `CwaFixtureBuilder::createPositions()` timestamp bug is fixed.
  - Filter `ChoiceType` placeholder entries (`c.value !== ''`) and pass the label as `:placeholder`. **Always set `value-key="value"` and `label-key="label"`** on choice components, or Nuxt UI binds the whole `ChoiceView` and Symfony returns 422.
  - Single checkbox: `IsTrue`, not `NotBlank` (which doesn't fire on `false`). v-model `get: () => !!checkbox.value.value`, `set: (v) => { checkbox.value.value = v ? '1' : null; checkbox.onInput() }`.
  - Compound collections use `useCwaFormCollection` with `FormChildEntry`, text collections with `FormTextEntry`; repeated password uses `useCwaFormRepeated`. The `randomCheckbox` label may contain HTML (rendered via `v-html` in a `#label` slot).

## API

- **Orphaned resources (bundle 2.0.0-alpha.6, module 2.0.0-alpha.3).** The report is stored in `_acb_orphaned_resource_report` (migration `Version20260926075921`), shared between pods. `silverback:api-components:scan-orphaned` only scans (`clean-orphaned` is now an alias and deletes nothing); deleting is an admin action in `/_cwa/orphaned` through `POST /_/orphaned_resources/delete` (admin only, 401 anonymously; it expects `application/ld+json`). The scan emails `orphaned_resources.notify.recipients` when the result changes; no recipients means no email. Module alpha.3's delete needs a bundle with #353, so the two go together.
- **QueryParameters (#89).** `User`, `BlogArticleData`, `NestedPageData` declare `parameters:` on `#[ApiResource]`: `search` = `FreeTextQueryFilter(new OrFilter(new PartialSearchFilter()))`, `order[:property]` = `SortFilter`. `CollectionSearch.vue` binds `search`.
  - Old per-field parameters (`?title=`) are **ignored, not refused**: a stale client silently gets everything.
  - Resource-level parameters also filter single-item requests (`/users/{id}?search=zzz` → 404).
  - **Never use a bare `OrFilter`**: it ORs against the whole WHERE clause and drops the bundle's publication predicates.
  - Avoid `relation.field` in an OR search: `PartialSearchFilter` inner-joins it and drops rows without the relation.
- **`security.yaml`:** the catch-all `^/` rule requires `IS_AUTHENTICATED_FULLY` for writes. A new public POST route needs its own explicit rule. Password reset/update go through `^/_api/component/forms/(.*)/submit`.
- On API Platform 5: a wrong type on a constrained property returns 422, on an unconstrained one (e.g. `HtmlContent.html`) 400.

## Front end

- **`app.vue` must be `app/app/app.vue`** (Nuxt 4's source dir). A copy at `app/app.vue` was silently ignored for months, leaving no `<UApp>` and no manifest link. It holds `<UApp>`, `<VitePwaManifest />`, `<NuxtRouteAnnouncer />`. **Keep comments out of its `<template>`**: they're rendered into every page. `<UApp>` costs ~49 KB gz; kept on purpose for sites that use toasts/tooltips/overlays.
- **⚠ `unhead: { vite: { devtools: false } }` in `app/nuxt.config.ts` (#95).** Without it, on Nuxt 4.5 the dev client dies with `Identifier '__unhead_devtoolsPlugin' has already been declared` and nothing hydrates (production is unaffected, so CI stays green). Cause: `@unhead/bundler` 3.4.1 registers its devtools runtime plugin in `configResolved`, which runs twice (client and SSR Vite servers). **Remove it once an unhead release de-duplicates the registration.** Rejected: disabling Nuxt devtools, `treeShakeUseSeoMeta: false`, `compatibilityVersion: 5`/`viteEnvironmentApi`.
- **Catching dev-only hydration breaks:** after any bump touching Nuxt, Vite or unhead, load pages in a real browser; a `curl` 200 proves nothing. Check `document.querySelector('#__nuxt').__vue_app__` exists and there's no `pageerror`. Wait with `networkidle2`, not `networkidle0` (Mercure keeps a connection open). Expected dev noise: a refused `wss://localhost:9777/__ws` and a 401 from anonymous `/me`.
- **TipTap editor is lazy (#332).** `HtmlContent.vue`/`AltHtmlContent.vue` use `defineAsyncComponent`; a `build:manifest` hook in `nuxt.config.ts` removes the editor from every chunk's `dynamicImports` (otherwise a ~400 KB prefetch hint on every page); `useCustomHtmlComponent.ts` must use `import type` for it. The same hook collects editor- and `/_cwa`-only chunks, and `pwa.workbox.manifestTransforms` drops them from the precache (`globIgnores` can't, names are hashed).
- **Body HTML renders through the module's `v-cwa-html`** (`const { vCwaHtml } = useHtmlContent(container, html)`), not `v-html`: since Vue 3.5.39 hydration reassigns every `v-html`, recreating the LCP element. The directive uses `beforeMount`/`beforeUpdate`, not `mounted`/`updated` (a post-flush hook would overwrite the converted links).
- **`TipTapHtmlEditor.vue` `config` prop** hides buttons (`:config="{ h1: false, underline: false }"`; typed keys `h1`, `h2`, `bold`, `italic`, `underline`, `link`, `bulletList`). Hiding doesn't unregister the extension. Keep `StarterKit.configure({ link: false })` plus the explicit Link (plain StarterKit registers Link twice). StarterKit 3 already includes Underline. `:tippy-options` is a v2 prop; don't add it.
- **Testing admin against a throwaway production build:**
  - Build a scratch copy in the `app-app` image (`pnpm install --frozen-lockfile && pnpm run build`); host `node_modules` holds Linux binaries.
  - Run `.output/server/index.mjs` in a container on `components-web-app_default` with `--link components-web-app-php-1:php.local`, the dev API URL env (`NUXT_CWA_API_URL`, `NUXT_PUBLIC_CWA_API_URL_BROWSER`), and a spare port.
  - The API cookie is `SameSite=Lax`, so serve it over **HTTPS on `localhost`** (e.g. a Caddy `tls internal` proxy), or log in with `curl POST /_api/login` and set `api_component` with `SameSite=None`.
  - Bypass the service worker when checking lazy loading, or the precache hides the requests.
- Open: a CLS of ~0.16 on blog articles; an admin-only hydration mismatch in the module's `ComponentPlaceholder`; `beforeUpdate` path of `v-cwa-html` not browser-tested.

## PWA

The module ships no service worker; the template carries the reference config in `app/nuxt.config.ts` (`@vite-pwa/nuxt` in **devDependencies**). Nuxt 4 support is real though undeclared upstream.

- **⚠ `workbox.navigateFallback: null` must be written explicitly.** In the prod build `@vite-pwa/nuxt` defaults it to the base URL when the key is **absent**, serving the `/` app shell for every SSR navigation. Presence of the key, not its value, disables it in prod. In dev, `??` coalesces `null` to `/` anyway, which is one reason `devOptions.enabled` is `false` (enable it only to test the PWA). If an app ever sets a fallback, add `navigateFallbackDenylist: [/^\/_cwa\//, /^\/login/]`.
- **API runtime caching (`cwa-api`, NetworkFirst, 3s timeout)** is safe only because the bundle marks authenticated responses `Cache-Control: private, no-store` (bundle #200) and a `cacheWillUpdate` plugin drops anything `no-store`/`private` or non-200. Draft and published share URLs, so excluding by URL is impossible. NetworkFirst means the cache is read only offline.
- **⚠ The `urlPattern` must be exhaustive and anchored.** It lists `routes`, `resource_manifest`, `pages`, `layouts`, `component_groups`, `component_positions`, `page_data`, `component`. Missing `resource_manifest` silently breaks offline rendering; a broad `/_api` pattern swallows the Mercure stream and `/_api/me`. Test: must match `/_api/_/routes//x`, `/_api/_/resource_manifest//x`, `/_api/page_data/x`, `/_api/component/images/x`; must not match `/_api/.well-known/mercure` or `/_api/me`. Add new module resource types here.
- The API must keep `max-age: 0` with a long `s-maxage`: a browser-cached copy would pass through Workbox's `fetch()` and NetworkFirst would serve it stale. The API deliberately sends no `Vary: Cookie`.
- **Updates: `registerType: 'prompt'`, applied silently on the next path change** by `app/app/plugins/pwa-update.client.ts`, held while `$cwa.admin.isEditing` (an auto-update could swap assets mid-edit). No notice UI (Daniel, 2026-09-21).
  - It uses `afterEach`, not `beforeEach` + `location.assign`: in prompt mode `updateServiceWorker()` ignores its argument, posts `SKIP_WAITING`, and workbox-window reloads on `controlling`, which would race the navigation.
  - **⚠ `clientsClaim: true` is required**, or an uncontrolled page (the first load, or a Shift-reload) is never claimed and the reload never fires. Safe with `prompt` (activation still waits for `SKIP_WAITING`).
  - API traps: the composable is `usePWA()`; `$pwa` is client-only and undefined until registration; `needRefresh` and `$cwa.admin.isEditing` are plain values, not refs; inside `defineNuxtPlugin`, `nuxtApp.$pwa`/`$cwa` are `unknown` (cast via `ReturnType<typeof usePWA>`/`useCwa`) and should be read lazily in the router callback.
- **Session-end cache purge is the module's** (cwa-nuxt-module#293): `cwa.auth.clearCachesOnSessionEnd` defaults to `['cwa-api']`. **If you rename the cache, set the option to match**; otherwise leave it unset. It fires only when a session actually ended (not on an anonymous `/me` 401) and on any 401 while signed in.
- **Mercure reconnect** (module #286) re-fetches on-screen resources but only **stages** changes: admins see "The content on this page is outdated"; anonymous visitors keep stale content until they navigate. Don't describe it as "the page updates itself". Whether that's intended is unconfirmed module-side.
- If a `pwa` choice is added to `create-cwa`, gate the `pwa: {}` block with `// @cwa-if:pwa` like the other features.

## Media and uploads

- **`GCLOUD_PUBLIC_URL`** (#68) sets `app.media_public_url` for the GCS adapter's `public_url` and `FlysystemCacheResolver`. Unset or empty falls back to `https://storage.googleapis.com/<GCLOUD_BUCKET>/` (Symfony's `default:` treats empty as missing), resolved at runtime, not compile time. Wired: `api/.env` → `php.gcloud.publicUrl` → configmap `gcloud-public-url` → env, and `k8s.sh`. This template's deploy sets `https://cdn.cwa.rocks/` as a GitLab variable.
- Objects are written to the **bucket root**. The old `'prefix' => '_preview'` tag config was dead (Flysystem never reads it). A real prefix must go to the adapter constructor in `GoogleCloudStorageFactory`, and moves every existing media URL.
- In dev the local adapter has no `public_url`, so media falls back to the API URL.
- **Upload sizing:** `upload_max_filesize = 20M`, `post_max_size = 21M` (`10-app.ini`), `Assert\File(maxSize: '20M')` on `Image::$file`, `memory_limit = 512M` (a per-request ceiling). The ingress allows 30m.
- **Thumbnails are built synchronously in the upload request with GD, ~11.7 MB per megapixel**, so 512M handles ~43 MP. `Image::$file` rejects over **40 MP** with a 422 (`Assert\Image(maxPixels: 40_000_000)` inside `Assert\When`, so SVG is exempt; without the `When`, SVG is rejected). Non-images (e.g. PDF) are rejected. The module downscales in the browser by default (module #335: >2560px or >20 MP), so the limit is the safety net for direct API uploads.
- **FrankenPHP worker pool is fixed** at `num {$FRANKENPHP_WORKER_NUM:4}` in `worker.Caddyfile` (the default follows node CPUs, and with it worst-case memory).
- **php pod memory:** limit 1Gi (`PHP_MEMORY_LIMIT`), request 350Mi. If a cluster forces limits to equal requests (GKE Autopilot), lower `PHP_MEMORY_LIMIT`.

## CORS: `Retry-After` is exposed (#100)

Throttled email requests (api-components-bundle#331) return 429 with `Retry-After`, and the module's resend link counts down from it (cwa-nuxt-module#353). Browsers only let cross-origin JavaScript read CORS-safelisted headers plus those in `Access-Control-Expose-Headers`, so `nelmio_cors.yaml` exposes `Retry-After` alongside `Link`. The template's own browser calls are same-origin `/_api`, so this only matters for a site that serves the API from another origin. Don't drop it from `expose_headers`.

## Security and secrets

- **⚠ Anchor every `TRUSTED_HOSTS` alternative: `^(?:a|b|c)$`.** Symfony wraps the pattern as `{…}i` without anchoring it, so in `^a|b|c$` only `a` is anchored at the start and `c` at the end, and `b` matches anywhere (`evil-caddy.attacker.net` passed the old `api/.env` default). Fixed in `api/.env`, `k8s.sh`'s Behat default, `compose.yaml` and `helm/cwa/values.yaml`. Project CI variables must follow the same form.
- **`compose.prod.yaml` gives `app` its URLs (#98):** SSR uses `NUXT_CWA_API_URL=http://php.local/_api`, the warm uses `NUXT_CWA_PAGE_CACHE_WARM_ORIGIN=https://php.local`, the browser uses `https://$SERVER_NAME/_api`, and php gets the `php.local` network alias plus `BROWSER_SERVER_NAME=$SERVER_NAME` (required). **Not `http://php`:** only `php.local:80` is in Caddy's `SERVER_NAME`, so anything else over plain HTTP is 308'd, and so is `php.local` with the public `Host`, which is why the warm must be HTTPS. Config-rendered only; booting it is #96 Phase 2.
- **`compose.prod.yaml` requires every secret** with `${VAR:?…}`: `APP_SECRET`, `CADDY_MERCURE_JWT_SECRET`, `POSTGRES_PASSWORD`, `JWT_SECRET_KEY`/`JWT_PUBLIC_KEY`/`JWT_PASSPHRASE` (key contents). The public dev defaults in `compose.yaml` stay on purpose; they only apply on localhost. `.gitguardian.yaml` marks the required-secret placeholders as not secrets.
- **`api/.dockerignore`** keeps local JWT/database keys, Symfony decrypt keys, `public/uploads/` and local PHPUnit files out of the image. A `frankenphp_prod` build should have an empty `config/jwt` and no `public/uploads`.
- **Caddy admin is loopback-only** (see *Caddy and Souin*). A prod override can't drop a merged port without `ports: !reset`, so port 2019 has to stay out of the base `compose.yaml`.

## Load testing (k6, #93)

`bin/load-test/launch.js` (+ `README.md`) is a manual tool, deliberately not in CI.
- `BASE_URL` required; pages from the sitemap (`PAGES` overrides, `MAX_PAGES` caps). Modes: `smoke`, `capacity`, `surge` (`PEOPLE`, default 100), `soak`.
- **The guard:** any non-local host needs `CONFIRM=yes`, checked before any request.
- `CACHE=warm|cold|mixed`; cold adds `k6cb=`. **Never make that a stripped tracking parameter**, or every cold request becomes a hit. `COLD_API=true` also bypasses the cache for API calls.
- `Accept-Encoding: gzip` is pinned (k6 can't decode brotli). Run from a VM (laptops time out ~300 users). After a cold run against a real site, flush Souin in the API pod.
- Warm runs on the dev stack show misses because dev pages expire after 60s.

## Git: splitting one file's changes across commits

`git add -p` is unavailable. With `git diff -U0` + `git apply --cached --unidiff-zero`, **`git apply` places each hunk by its header line numbers**, so skipping a hunk shifts every later one. `helm lint` won't catch misplaced YAML comments.
- Recompute each chosen hunk's new-side start from only the chosen hunks before it: `c = a + offset` (`+1` for a pure insertion, `-1` for a pure deletion), where `offset` sums `(new_count - old_count)` of the chosen hunks.
- After staging, check the remaining unstaged `-U0` diff is **exactly** the hunks you left out.

## `create-cwa` CLI

`packages/create-cwa/` (`npx create-cwa my-project`, GitHub #56). Prompts for name, CI/CD (GitHub Actions / GitLab CI / none), features and fixtures; downloads the template tag matching its own version (`--ref` overrides) via `giget`, removes unselected feature files, strips `@cwa-if:feature` blocks from `nuxt.config.ts`, writes a README, and offers `docker compose up -d` and `pnpm install` (host install defaults to **No**; it's editor types only). `cwa-manifest.json` is the contract, read from the same tag. `alwaysExclude` covers `packages/`, `CHANGELOG.md` and `publish-create-cwa.yml`. `engines.node` is `>=22.13.0`.

## Decided against

- **`LOAD_DEMO_SCAFFOLD`** env flag to skip the scaffold but seed the admin. Loading fixtures *is* loading the scaffold; a site wanting an empty DB doesn't run them. Admin-only seeding belongs downstream. Don't port or re-propose it.
- **A build-time fixtures hook in `nuxt.config.ts`** (the old `LOAD_FIXTURES` `listen()` hook). It never ran and would have purged every table. Don't reintroduce one.
- **Probing a path Souin doesn't cache** for php readiness. Uncached `/_api` paths are excluded because they're auth-varying, so they either expose something or don't answer 200 anonymously. (The bundle's `/_api/_/health` could work only after excluding it from `@use_cache`.)
- **A redirect ingress for retired hostnames** (#86). Take the old hostname offline via `KUBE_INGRESS_ALIAS_DOMAINS`; the TLS rotation makes that safe. A site that needs one can take the snippet from #86.
- **Parameterising the GCS `prefix`** (#68). It would be a variable that does nothing.
- **A PDB on the single API pod, or `minAvailable: 1` on SSR** (#78). Both block node drains.
- **A PWA `postStart` hook or helm `post-upgrade` Job for the deploy purge** (#71). The hook fires on every HPA scale-up; the Job is Kubernetes-only.
- **An update notice for the service worker.** Replaced by the silent update on navigation.
- **`experimental.asyncContext`** for the old `[nuxt] instance unavailable` SSR error. It was resolved by dependency updates; nothing to apply.
- **Dropping `Accept` from the Souin key in favour of `Vary`.** See *Caddy and Souin*.
