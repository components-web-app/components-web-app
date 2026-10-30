# Changelog

All notable changes to the CWA template and `create-cwa`, which share a version. Newest first.

Every change to `main` gets a line under **Unreleased**, linking its commit or merge request, before it's pushed. A release renames that section to its version and date, and the section becomes the tag's message and the GitHub release notes.

## Unreleased

### Upgrade notes

- **Bundle 2.0.0-alpha.38 and `@cwa/nuxt` 2.0.0-alpha.31.** Take `api/composer.json` and `api/composer.lock`, and `app/package.json` and `app/pnpm-lock.yaml`; no migration, nothing else to change. The bundle answers an item URL whose id isn't a UUID with a 404 instead of a 500; the module's release updates its dependencies. [2b69ad2](https://github.com/components-web-app/components-web-app/commit/2b69ad24216875a24368b72b457a796378573767)

### Changed

- Dependencies to their latest versions: API Platform 5.0.5, Symfony 8.1.10, rokka/imagine-vips 0.42, Nuxt 4.6.3, TipTap 3.32.2, `@nuxt/devtools` 4.0.0, satori 0.63, and the browser tests' eslint 10.14.0 and typescript-eslint 8.72.1. TypeScript stays 6.0.3: vue-tsc 3.3.14 still can't run TypeScript 7. [2b69ad2](https://github.com/components-web-app/components-web-app/commit/2b69ad24216875a24368b72b457a796378573767)

## [2.0.0-alpha.50](https://github.com/components-web-app/components-web-app/releases/tag/v2.0.0-alpha.50) - 2026-10-28

### Upgrade notes

- **No bundle or module change:** api-components-bundle stays 2.0.0-alpha.37 and `@cwa/nuxt` 2.0.0-alpha.30.
- **Take `app/pnpm-workspace.yaml`, `app/pnpm-lock.yaml` and `api/composer.lock`'s phpunit** for the security fixes below. A project with its own overrides or register entries merges them into the file. [!18](https://gitlab.com/silverback-web-apps/cwa/components-web-app/-/merge_requests/18)

### Security

- **node-forge 1.4.0 → 1.4.2** for GHSA-86w9-cpqp-85rv (high, CVE-2026-85393). It's fixed in 1.4.1, although GitHub's advisory doesn't list a fixed version yet; 1.4.2 also fixes 1.4.1's `pem.decode()` regression. **postcss-selector-parser 6.0.10 → 6.1.5** for GHSA-rj75-hqrm-r3gf (moderate), and **esbuild 0.27.7 → 0.28.2** for GHSA-g7r4-m6w7-qqqr (low), each by an override. **phpunit 13.4.3 → 13.4.5** for PKSA-qhjm-rpqc-qkn6 (dev only). [!18](https://gitlab.com/silverback-web-apps/cwa/components-web-app/-/merge_requests/18)
- Still accepted, not in the server output: deepmerge 4.3.1 (GHSA-gcqx-w48m-w2h4, low), @rollup/plugin-node-resolve's at build only, with no fix released. [!18](https://gitlab.com/silverback-web-apps/cwa/components-web-app/-/merge_requests/18)

## [2.0.0-alpha.49](https://github.com/components-web-app/components-web-app/releases/tag/v2.0.0-alpha.49) - 2026-10-25

### Upgrade notes

- **No bundle or module change:** api-components-bundle stays 2.0.0-alpha.37 and `@cwa/nuxt` 2.0.0-alpha.30.
- **Delete `app/app/pages/login.vue`** unless you've changed it beyond its header: its banner tells every visitor the password is "admin", which isn't true for your site. Without the file, `/login` is `@cwa/nuxt`'s own login page. New projects no longer get the file (the preview site keeps it). [779b578](https://github.com/components-web-app/components-web-app/commit/779b578c34b953b2c5cb9b61f757d3da9009d0fc)
- **Copy `api/frankenphp/Caddyfile`, and `api/src/Http/VisitorIp.php` if you need the visitor's address** (#224, #225). A project that capped `Surrogate-Key` itself (a purger extending `SouinPurger`) removes it: `api_platform.yaml`'s purger goes back to `api_platform.http_cache.purger.souin` and its `services.php` entry goes. A project with its own `App\Http\VisitorIp` takes the template's, which keeps `of(Request): ?string`. [e8f8cdc](https://github.com/components-web-app/components-web-app/commit/e8f8cdc091a99bd9d3e7404cebd00b6d854da121)

### Security

- No new npm advisories (`pnpm audit`, 2026-10-25). Still accepted, none shipping in the server output: node-forge 1.4.0 (GHSA-86w9-cpqp-85rv, high), no fix released; postcss-selector-parser 6.0.10 (GHSA-rj75-hqrm-r3gf, moderate), pinned by @tailwindcss/typography; esbuild 0.27.7 (GHSA-g7r4-m6w7-qqqr, low), via @nuxt/fonts.

### Changed

- **An empty commit no longer starts a GitLab pipeline**, a side effect of 2.0.0-alpha.48's Markdown-only rule: to rerun CI, use Run pipeline (Build → Pipelines) or the pipelines API instead of `git commit --allow-empty`. [d17d26a](https://github.com/components-web-app/components-web-app/commit/d17d26a5b99be79e5c971e65f51024cb888eb0cb)
- The create-cwa smoke job (template CI only) skips, instead of failing, on a release commit whose `cwa-php-base` isn't published yet: orange on GitLab, a warning on GitHub. Re-run it once `publish-php-base.yml` has pushed the image. [64e2c2a](https://github.com/components-web-app/components-web-app/commit/64e2c2abdcf0dd387576a0527ad6a6c2b48f7c44)

### Added

- **`App\Http\VisitorIp`** (#225): the visitor's address for per-visitor limits, inject it instead of trusting `getClientIp()` behind Cloudflare. Caddy passes the address its rate limit counts (`CF-Connecting-IP` only from Cloudflare's ranges, `CLOUDFLARE_IP_RANGES` and `CADDY_TRUSTED_PROXIES` honoured) as the `CWA_VISITOR_IP` server variable, which no request header can set. [e8f8cdc](https://github.com/components-web-app/components-web-app/commit/e8f8cdc091a99bd9d3e7404cebd00b6d854da121)

### Fixed

- **A large API collection no longer empties the sitemap** (#224): its `Surrogate-Key` (one tag per member: 184 KB for ~1,930 routes) passed Node's and curl's header limits. Caddy now removes the header from SSR's `/_api` responses after Souin has stored the tags, so every purge stays exact; public hosts keep it and `Cache-Tag`. [e8f8cdc](https://github.com/components-web-app/components-web-app/commit/e8f8cdc091a99bd9d3e7404cebd00b6d854da121)

## [2.0.0-alpha.48](https://github.com/components-web-app/components-web-app/releases/tag/v2.0.0-alpha.48) - 2026-10-24

### Upgrade notes

- **No bundle or module change:** api-components-bundle stays 2.0.0-alpha.37 and `@cwa/nuxt` 2.0.0-alpha.30.
- **Review apps' TLS secrets are now per release** (#221): `letsencrypt-cert-<release>-api`. Each review app issues its own certificate on its next deploy; once every review app in a shared namespace has redeployed, delete the old shared secret by hand (`kubectl delete secret letsencrypt-cert-review-api -n <review namespace>`). A `CWA_CI_TLS_SECRET_NAME` set per branch as a workaround can go. [64d7152](https://github.com/components-web-app/components-web-app/commit/64d71523c2a42d8995eafbc13e387adafa7c9964)
- **Media storage is chosen at runtime by `MEDIA_STORAGE`** (`local` or `gcloud`, #211), so copy `api/config/services.php` with the new `api/src/Flysystem/MediaAdapterFactory.php` and `MediaUrlEnvVarProcessor.php`. Kubernetes deploys keep Cloud Storage (the prod default is `gcloud`) and need nothing else. A single-server site already using a bucket with `compose.prod.yaml` sets `MEDIA_STORAGE=gcloud`, because the file now defaults to `local`. A project that edited the storage block of `services.php` merges its change into the new wiring. [f6b8fe8](https://github.com/components-web-app/components-web-app/commit/f6b8fe8f2b2a156577f401bc0a5756c151fe1706)
- **`bin/devops/k8s.sh` now sources `bin/lib/site.sh`** (the sitemap and page-cache warm moved there, #212): copy both, or every deploy fails at its first line. A project with its own `stop review` job adds `bin/lib` to that job's sparse checkout, as `.gitlab-ci.yml` does. [8b4b3e9](https://github.com/components-web-app/components-web-app/commit/8b4b3e987cd863c8e8692cbc4fcd1e6cf15ac32e)
- `api/frankenphp/Caddyfile` changed (`/uploads` is static only); copy it. [f6b8fe8](https://github.com/components-web-app/components-web-app/commit/f6b8fe8f2b2a156577f401bc0a5756c151fe1706)

### Security

- **fast-uri 3.1.9 and serialize-javascript 7.1.4** clear GHSA-w74x-v6f9-j3xg, GHSA-wjr9-j795-jxcr, GHSA-xhq7-xmqj-769h, GHSA-333x-w4r6-6crp and GHSA-m5mm-p8h7-m29v (both build-only). The withdrawn braces advisory GHSA-vfj7-8cjw-p6xm leaves `app/pnpm-workspace.yaml`'s accepted register; still accepted at this release (reviewed 2026-10-24), none shipping in the server output: node-forge 1.4.0 (GHSA-86w9-cpqp-85rv, high), no fix released; postcss-selector-parser 6.0.10 (GHSA-rj75-hqrm-r3gf, moderate), pinned by @tailwindcss/typography; esbuild 0.27.7 (GHSA-g7r4-m6w7-qqqr, low), via @nuxt/fonts. Projects take `app/pnpm-lock.yaml` and `app/pnpm-workspace.yaml`. [f204977](https://github.com/components-web-app/components-web-app/commit/f204977568a1bbef0fd4ce6ebc9baeb62d172939)
- **`/uploads` is served as files only, never run as PHP** (#211). The bundle keeps an upload's own extension when it can't tell the type, so a stored `.php` under `public/uploads` (dev's media folder, and now single-server production's) would have run. [f6b8fe8](https://github.com/components-web-app/components-web-app/commit/f6b8fe8f2b2a156577f401bc0a5756c151fe1706)

### Changed

- **A deploy restarts pods only when their image or settings changed:** the per-deploy `timestamp` pod annotation is gone (the chart's checksum annotations already roll pods on a ConfigMap, Secret or site-settings change). To restart on purpose, `kubectl rollout restart` or `CWA_CI_BUILD_FORCE="true"`. [29d26a2](https://github.com/components-web-app/components-web-app/commit/29d26a26f44b63f07890670ce4085dc7fad88772)
- **An unchanged image isn't built again:** `build api`/`build app` label each image with a hash of its build context's git tree, build options and the ISO week, and reuse the branch's (or default branch's) image when it matches, so the job takes seconds and the deploy keeps the same digest and doesn't restart those pods. Base images still reach a build at least weekly; `CWA_CI_BUILD_FORCE="true"` always builds. The first build after taking this always builds (no label yet). [d17d26a](https://github.com/components-web-app/components-web-app/commit/d17d26a5b99be79e5c971e65f51024cb888eb0cb)
- **GitLab's build jobs no longer install helm and kubectl**, which they never use (`install_build_dependencies`). [fa8c9bd](https://github.com/components-web-app/components-web-app/commit/fa8c9bde77fc6aecc5873def00564a6fdf2f8f3e)
- **A push that changes only Markdown files at the root (CHANGELOG.md, README.md, …) runs no pipeline**, on GitLab (`workflow:rules`) and GitHub (`paths-ignore`). [d17d26a](https://github.com/components-web-app/components-web-app/commit/d17d26a5b99be79e5c971e65f51024cb888eb0cb)
- The create-cwa smoke job runs on `main` only when its paths change, like other branches (template CI only). [d17d26a](https://github.com/components-web-app/components-web-app/commit/d17d26a5b99be79e5c971e65f51024cb888eb0cb)

### Added

- **Single-server scripts** (#212): `bin/server/init` writes `.env.prod` (random secrets, a JWT key pair, the host and mail relay); `deploy.sh [--fixtures]` builds, backs up before pending migrations, starts the front end then the API, purges rendered HTML, warms `/_api`, generates image variants in memory-capped one-off containers and warms the sitemap; `backup.sh` keeps the newest 5 database dumps with media and Caddy's certificates in `backups/`; `restore.sh` puts one back under maintenance mode; `cron.example` has the daily backup and orphan scan. Template CI's `server scripts` job runs them end to end. Single-server stays a preview until they've run a production site. [8b4b3e9](https://github.com/components-web-app/components-web-app/commit/8b4b3e987cd863c8e8692cbc4fcd1e6cf15ac32e)
- **Single-server production stores media on the server** (#211): `compose.prod.yaml` keeps uploads in a `media_data` volume, served at `https://<SITE_HOST>/uploads/`, and no longer needs a Cloud Storage bucket. The browser tests upload an image and check it and its WebP variants are served, before and after php is recreated (local storage, or `CWA_CI_E2E_STORAGE="gcloud"`). Dev media URLs are now `https://localhost/uploads/…` too. [f6b8fe8](https://github.com/components-web-app/components-web-app/commit/f6b8fe8f2b2a156577f401bc0a5756c151fe1706)
- **`create-cwa` runs unattended:** `--yes` takes every default, `--ci` never prompts (a missing project name is an error, a failed `bin/up` exits 1), `--template-dir <path>` copies a local checkout instead of downloading, and `--pipeline`, `--features`, `--[no-]fixtures`, `--[no-]start` and `--[no-]install-deps` answer their questions. Without flags nothing changes (#215). [24c09d3](https://github.com/components-web-app/components-web-app/commit/24c09d3dfdf3d0e2b8d21d1e9a4386ecdd890f2f)
- **create-cwa smoke job** (template CI only, GitHub and GitLab): creates a project from the pushed ref, starts it through `bin/up` and signs in, with all features and with none (#215). [593ce7a](https://github.com/components-web-app/components-web-app/commit/593ce7adcc2f7e895a698d27f169166a020760c9)

### Fixed

- The TipTap editor's bubble and floating menus show again once a component is selected (#222): they stayed on the editor `build()` replaces. Projects copy `app/app/components/TipTapHtmlEditor.vue`. [e82eb69](https://github.com/components-web-app/components-web-app/commit/e82eb69a14c6ea5bf7fd3ba0641c50613e5931e6)
- The browser tests no longer fail in a project created without the image feature: `e2e/run.sh` skips its upload check when there's no `Image` component. [259055c](https://github.com/components-web-app/components-web-app/commit/259055ccd1282ccc271722b4822978eddd830479)
- Review apps sharing a namespace no longer share one TLS Certificate, which only the newest app's host matched and which stopping any of them deleted (#221). [64d7152](https://github.com/components-web-app/components-web-app/commit/64d71523c2a42d8995eafbc13e387adafa7c9964)

## [2.0.0-alpha.47](https://github.com/components-web-app/components-web-app/releases/tag/v2.0.0-alpha.47) - 2026-10-23

### Upgrade notes

- **api-components-bundle 2.0.0-alpha.37 and `@cwa/nuxt` 2.0.0-alpha.30 go together** (the editor needs `/_/collaboration_states` and sends `If-Match`). Update both in the same deploy.
- **Two bundle migrations:** alpha.36 adds a `resource_version` column to components and page data, alpha.37 a `collaboration_state` table. After `composer update components-web-app/api-components-bundle`, run `bin/console doctrine:migrations:diff` once (it covers both), delete the generated `down()`, and commit the migration with the lock. The template's are `api/migrations/Version20261022184324.php` and `Version20261022192418.php`. [ede2e9f](https://github.com/components-web-app/components-web-app/commit/ede2e9f2f59dc917783b2651ea1072543a893991) [e3cda2d](https://github.com/components-web-app/components-web-app/commit/e3cda2d26b32350e76e8955b91aa24bb7ccf3adb)
- **The TipTap editor is replaced by the module playground's Yjs co-editing editor.** Copy `app/app/components/TipTapHtmlEditor.vue`, `app/app/tiptap/` (`co-editing.ts`, `y-sync.ts`, `y-seed.ts`, `y-session.ts`, `y-state.ts`, `y-cursors.ts`), `app/app/composables/useCustomHtmlComponent.ts` and both HtmlContent components (`app/app/cwa/components/HtmlContent/HtmlContent.vue`, `ui/AltHtmlContent.vue`). The editor now takes `:model` (the field's `useCwaResourceModel`), `:iri` and `field="html"` instead of `v-model`. Add `yjs`, `@tiptap/extension-collaboration` (on your other `@tiptap/*` version) and `@tiptap/y-tiptap` to `dependencies`, and check the lock has exactly one `yjs`. [685dfdf](https://github.com/components-web-app/components-web-app/commit/685dfdf2c1d4553daf3495cfba64789d82e38cd6) [92565ad](https://github.com/components-web-app/components-web-app/commit/92565ad71a97f13769063d8704345d0d26bed3dc) [3487864](https://github.com/components-web-app/components-web-app/commit/34878641f5877421beeaa355f709bd5f99bba923)
- A site whose API is on another origin than its front end also takes `nelmio_cors.yaml`'s `If-Match` (allowed) and `ETag` (exposed). [ede2e9f](https://github.com/components-web-app/components-web-app/commit/ede2e9f2f59dc917783b2651ea1072543a893991)
- `api/frankenphp/Caddyfile` changed (#216); copy it. [8702196](https://github.com/components-web-app/components-web-app/commit/87021963044d24ef4efc47e7adb66e82ba61e781)

### Changed

- **TipTap co-editing** (`@cwa/nuxt` 2.0.0-alpha.28 to alpha.30; cwa-nuxt-module#429, #439, #440): admins in one field share a Yjs document, so simultaneous typing merges; the field is outlined with the name of another admin in it, their caret shows live, and a remote save keeps your caret and stays out of your undo history. One admin's tab saves the HTML (with `If-Match`) and the Yjs state. Tested with two admins typing at once and one save refused: 9 of 9 runs kept both texts. Selecting a component without typing still saves nothing (#167) (#219). [685dfdf](https://github.com/components-web-app/components-web-app/commit/685dfdf2c1d4553daf3495cfba64789d82e38cd6) [92565ad](https://github.com/components-web-app/components-web-app/commit/92565ad71a97f13769063d8704345d0d26bed3dc) [3487864](https://github.com/components-web-app/components-web-app/commit/34878641f5877421beeaa355f709bd5f99bba923)
- **api-components-bundle 2.0.0-alpha.36 and alpha.37** (api-components-bundle#561, #564): components and page data are sent with an `ETag`, a write with `If-Match` is refused (412) if someone saved in between, and `/_/collaboration_states` stores the collaborative-editing state. [ede2e9f](https://github.com/components-web-app/components-web-app/commit/ede2e9f2f59dc917783b2651ea1072543a893991) [e3cda2d](https://github.com/components-web-app/components-web-app/commit/e3cda2d26b32350e76e8955b91aa24bb7ccf3adb)

### Fixed

- **create-cwa projects that chose GitHub Actions got no workflows**: `.gitattributes` still had the API Platform template's `.github export-ignore`, and GitHub's tarball honours it, so `.github/` never reached a new project (since 2.0.0-alpha.1). A project created that way copies `.github/workflows/` from this release (except `publish-create-cwa.yml` and `publish-php-base.yml`). [ac42d4a](https://github.com/components-web-app/components-web-app/commit/ac42d4a3566119ec90e06a3a28104a6f79157d44)
- Caddy holds page requests for up to 5 s while the app container restarts, instead of answering 502 straight away (`lb_try_duration` on the app proxy). On Kubernetes a request that finds no ready SSR pod fails at most 5 s later (#216). [8702196](https://github.com/components-web-app/components-web-app/commit/87021963044d24ef4efc47e7adb66e82ba61e781)

### Security

- **A register of accepted npm advisories** in `app/pnpm-workspace.yaml` (`auditConfig.ignoreGhsas`), so `pnpm audit` and scans read them as known. Still accepted at this release (reviewed 2026-10-23), none shipping in the server output: node-forge 1.4.0 (GHSA-86w9-cpqp-85rv, high) and braces 3.0.3 (GHSA-vfj7-8cjw-p6xm, high), no fix released; postcss-selector-parser 6.0.10 (GHSA-rj75-hqrm-r3gf, moderate), pinned by @tailwindcss/typography; esbuild 0.27.7 (GHSA-g7r4-m6w7-qqqr, low), via @nuxt/fonts. cwa-deployment-statuses checks the register hourly and opens an issue when an entry becomes fixable; a Composer exception goes in `api/composer.json`'s `config.audit.ignore` with its reason (#220). [146f9ed](https://github.com/components-web-app/components-web-app/commit/146f9ed1efdc45fdd143e999e2d1f59fb39773d2) [5c862a6](https://github.com/components-web-app/components-web-app/commit/5c862a650ff0ccaf5693081b7b4fa34c212b98e8)
- `fflate` 0.7.5 (GHSA-px8p-9vwx-vf98, moderate: an infinite loop on a crafted ZIP64 archive) through an override in `app/pnpm-workspace.yaml`; satori's opentype.js locked 0.7.3, the only flagged npm package that ships in the server output, though only its font inflate, not the affected `unzipSync`, is used. [424492f](https://github.com/components-web-app/components-web-app/commit/424492f849bef71087c5a8b07a47467bd40050bb)

## [2.0.0-alpha.46](https://github.com/components-web-app/components-web-app/releases/tag/v2.0.0-alpha.46) - 2026-10-21

### Upgrade notes

- **Take this release promptly: it is the PHP security release.** Its `cwa-php-base:2.0.0-alpha.46` has PHP 8.5.12 (CVE-2026-109618, CVE-2026-109619). Copy `api/Dockerfile` (its `CWA_PHP_BASE` default names this release) and redeploy. If you set `CWA_CI_PHP_BASE_IMAGE` to the `2.0.0-alpha.45-r20261021` rebuild in the meantime, delete it so the Dockerfile's default applies.
- Bundle 2.0.0-alpha.35 and `@cwa/nuxt` 2.0.0-alpha.26 go together: update both in the same deploy.
- `JWT_COOKIE_SAMESITE` now defaults to `strict` (`api/.env` and `api/config/packages/lexik_jwt_authentication.yaml`). A site whose front end and API are on different registrable domains must set `CWA_API_JWT_COOKIE_SAMESITE=none`; `lax` keeps the old behaviour. [1cf48ad](https://github.com/components-web-app/components-web-app/commit/1cf48ad1f168d0d7f129f1334fcd639c12784aee)
- `k8s.sh` now runs the new App command `app:edge-cache:purge-everything` on deploys with Cloudflare: copy `api/src/Command/PurgeEdgeCacheCommand.php` with it. It uses `api/src/RedisWatch/CloudflareEdgeCache.php` and `EdgeCache.php`, already in alpha.44 and later (#218). [be7c71e](https://github.com/components-web-app/components-web-app/commit/be7c71ea80e43fbfabf1eab6de280ac12ec19260)

### Security

- `session.upload_progress.enabled = 0` in `api/frankenphp/conf.d/10-app.ini`: unused by CWA, and one of php2shell's confirmed attack paths; PHP advises keeping it off even after patching. [5e9163c](https://github.com/components-web-app/components-web-app/commit/5e9163c715c9fd0d236d5ead6f267d49fbdd41f8)
- **The login (`api_component`), Mercure and session cookies are `SameSite=Strict` by default**, so no request another site starts carries them (CSRF hardening). An admin following a link from another site gets the anonymous page and is signed back in by the app's `/me` call; a browser test checks it. [1cf48ad](https://github.com/components-web-app/components-web-app/commit/1cf48ad1f168d0d7f129f1334fcd639c12784aee)
- **PHP 8.5.12 (CVE-2026-109618, CVE-2026-109619, critical RCEs; the second affects long-running workers like FrankenPHP's).** `bin/test/php-base-smoke.sh` refuses a `cwa-php-base` below 8.5.12, so no release or rebuild can publish an unpatched PHP. [4136243](https://github.com/components-web-app/components-web-app/commit/4136243fea7a5a14499ede187ad29244b968b52e)

### Changed

- `@cwa/nuxt` 2.0.0-alpha.26: co-editing's first slices. An admin sees another admin's saved draft in place, with "Use theirs / Keep mine" on a field they're also editing, and components get `onRemoteChange`. Needs bundle 2.0.0-alpha.35 (cwa-nuxt-module#429, #219). [cb0ae4d](https://github.com/components-web-app/components-web-app/commit/cb0ae4db4be665262dd2acdbf6995035d2873510)
- Bundle 2.0.0-alpha.35: the admin real-time channel (`POST /_/realtime`) and `_metadata.lastWrite` on writes that send `X-CWA-Client-Id`; `symfony/rate-limiter` is a new dependency. No migration. Its rate limits are per API pod (`cache.app`) (api-components-bundle#559). [f539463](https://github.com/components-web-app/components-web-app/commit/f539463ea996aac3fcdc130a4ab859f093b645ab)
- CORS `allow_headers` adds `X-CWA-Client-Id`, which the module's co-editing will send on every write (cwa-nuxt-module#429). Added ahead of that module version so cross-origin admin writes keep passing their preflight; harmless until then (#219). [aca1900](https://github.com/components-web-app/components-web-app/commit/aca1900b94f690afe267ce61cc42df3485ae8682)
- **Deploys with Cloudflare no longer flush and re-warm the new API pod.** A single-pod deploy purges rendered HTML locally and everything at Cloudflare (new `app:edge-cache:purge-everything`), and keeps the pod's postStart warm; about 5 minutes off cymru-kitchens' production deploy. If the edge purge fails it falls back to the full flush and warm. Scaled mode is unchanged. The job now says the API rollout is waiting for the postStart warm, and for at most how long. (#218). [be7c71e](https://github.com/components-web-app/components-web-app/commit/be7c71ea80e43fbfabf1eab6de280ac12ec19260)

### Added

- `cwa-php-base:latest`: an alias that follows the newest release or security rebuild (same digest and attestation; never a test build, never backwards). For trying the image by hand: the Dockerfile still names its release's version. [14a77e8](https://github.com/components-web-app/components-web-app/commit/14a77e84fccf315d2cf920af8876b35fd45e8f78)
- `publish-php-base.yml` can run the security rebuild by hand (`-f tag=rebuild`), as `<newest release>-rYYYYMMDD`, attested like the weekly one, so a PHP security release reaches downstream sites without a template release. [301d8b0](https://github.com/components-web-app/components-web-app/commit/301d8b0b7d0f2bf5c2b7a379465e436bc8b43909)

### Fixed

- `bin/test/compose-prod-config.sh` finds the required values in `compose.yaml` and `compose.prod.yaml` instead of a fixed list, so a project that adds its own `${NAME:?…}` value (e.g. a Turnstile key) passes, and still fails if one of the template's required values stops being required (#207). [db6f1a0](https://github.com/components-web-app/components-web-app/commit/db6f1a0be3b72d73926ab5dd722d264dc7ed62ae)
- README's versions table: `@cwa/nuxt` 2.0.0-alpha.21 recommends bundle 2.0.0-alpha.29 rather than requiring it, and says why bundle alpha.27 and alpha.28 are skipped. [7ef9eba](https://github.com/components-web-app/components-web-app/commit/7ef9eba7452dda29edfdaffdbd95203b0f203b67)

## [2.0.0-alpha.45](https://github.com/components-web-app/components-web-app/releases/tag/v2.0.0-alpha.45) - 2026-10-21

### Upgrade notes

- `CWA_CI_MIGRATIONS_JOB_PRODUCTION` is no longer read: production always migrates in a Job. Delete the variable. Only if that Job can't run on your cluster, set `CWA_CI_MIGRATIONS_JOB_DISABLED="true"`. `CWA_CI_MIGRATIONS_JOB_STAGING`/`_CANARY`/`_REVIEW` are unchanged (#180). [407aa51](https://github.com/components-web-app/components-web-app/commit/407aa51e459184c7af03078484a8d9a366eb88f2)
- **`compose.prod.yaml` (single-server, preview) takes `SITE_HOST` (one host) and `SITE_ALIASES` (optional, space-separated) instead of `SERVER_NAME`, and now requires `MAILER_DSN` and `GCLOUD_BUCKET`.** Rename `SERVER_NAME` in the `.env` a single-server deploy uses and add the two values. Copy together: `compose.prod.yaml`, `api/frankenphp/docker-entrypoint.sh`, `api/frankenphp/site-hosts.sh` (new), `api/Dockerfile`; a project that copied `e2e/` takes `e2e/compose.yaml`, `e2e/compose.scaled.yaml`, `e2e/run.sh` and `e2e/cache-checks.sh` (new) together (#207). [5bfc71f](https://github.com/components-web-app/components-web-app/commit/5bfc71f4d89fdccb5fce3578f1c23eab69f7cabd)

### Changed

- `@cwa/nuxt` 2.0.0-alpha.25 (same bundle as alpha.24, 2.0.0-alpha.32 or later): Clone and Move outline the target and open a menu at the click point, with a reason on each disabled option; the clone and shared outlines no longer show above the admin header; the package ships its MIT licence. [eb31f50](https://github.com/components-web-app/components-web-app/commit/eb31f5068c0550edb5a87755ac6306eebc42b99d)
- **Production deploys always plan migrations, and run pending ones in a Job from the new image before the rollout**, so a failing migration stops the deploy while the old pods keep serving. It adds ~20-30 s to a production deploy; nothing else runs when nothing is pending. Pods still migrate at startup behind the lock (a no-op after the Job; it covers first deploys and rollbacks) (#180). [407aa51](https://github.com/components-web-app/components-web-app/commit/407aa51e459184c7af03078484a8d9a366eb88f2)
- The README now gives CWA's status, requirements, a quick start to the login, a screenshot of inline editing, the demo site, deploy options as they stand (Kubernetes supported, single server preview), a versions and support policy with the bundle and module pairs, and a no-telemetry statement. The S3 claim and the stray Blackfire image are gone (#209). [49dc263](https://github.com/components-web-app/components-web-app/commit/49dc26367faa2406371ddecda54955036a15c5de)
- **Staging and review apps no longer warm `/_api`** (the postStart warm and the warm after a full flush), since nobody visits them: Cymru Kitchens' staging job spent most of its 12.5 min on warms. `CWA_CI_API_WARM_HTTP_CACHE_MAX_TIME_<TRACK>` (`_PRODUCTION`, `_CANARY`, `_STAGING`, `_REVIEW`) sets a track's time; production and canary still fall back to `CWA_CI_API_WARM_HTTP_CACHE_MAX_TIME`, then 60 (#217). [1824cfb](https://github.com/components-web-app/components-web-app/commit/1824cfbd18d837ceb414a3ddfea01ff1af148517)
- Single-server production (`compose.prod.yaml`, preview: media still needs a bucket, #211; no deploy script yet, #212) sets what the Kubernetes deploy sets for its hosts: anchored, escaped `TRUSTED_HOSTS`, `CORS_ALLOW_ORIGIN` and `MERCURE_CORS_ORIGIN` (built by the php entrypoint from `SITE_HOST`/`SITE_ALIASES`; a value you set wins), `NUXT_SITE_URL`, `CWA_ENVIRONMENT`, log rotation, restart policies and a healthy-database dependency. Its `MERCURE_PUBLIC_URL` and `BROWSER_SERVER_NAME` no longer break with more than one host. The browser tests now boot `compose.yaml` + `compose.prod.yaml` with CI stand-ins and run cache checks before Playwright (stored then hit, a tag purge drops only its page, admin port closed); a new `compose config` CI job checks the required values (#207). [5bfc71f](https://github.com/components-web-app/components-web-app/commit/5bfc71f4d89fdccb5fce3578f1c23eab69f7cabd)

### Fixed

- Single-server: a comma-separated `SITE_ALIASES` stops the php entrypoint with a clear message (Caddy refuses commas in `SERVER_NAME`), and the browser tests' cache checks run on a site whose sitemap lists one page (they skip the tag-isolation check) (#207). [d6acdee](https://github.com/components-web-app/components-web-app/commit/d6acdeea7095f00093dc5241ecc6686e46495acf)
- `bin/up --skip-fixtures` no longer says the admin is unchanged on a database that has none (#206). [be18f08](https://github.com/components-web-app/components-web-app/commit/be18f085c15f67bdae587782eab74e9bf1c406a9)

## [2.0.0-alpha.44](https://github.com/components-web-app/components-web-app/releases/tag/v2.0.0-alpha.44) - 2026-10-20

### Fixed

- php image: the builder stage's Go module downloads and `xcaddy build` run through `retry-fetch`, with a time limit and up to three attempts, after uncached downstream builds failed on a sum.golang.org stream error and slowed to about 2 minutes per `go get` on GitLab SaaS runners; Go also fetches over HTTP/1.1 there, since sum.golang.org kept resetting HTTP/2 streams (#213). [21abfb0](https://github.com/components-web-app/components-web-app/commit/21abfb0efb54666e5b773c8e404143f116aa4f5e), [d1241a9](https://github.com/components-web-app/components-web-app/commit/d1241a9386b7e979abdcd1a442f9c6c2515ede4d)
- The "maintenance mode is on" notice no longer names `CWA_CI_MAINTENANCE_DURING_MIGRATIONS` when a later deploy found the window left on without it (#182). [4fd54e2](https://github.com/components-web-app/components-web-app/commit/4fd54e2d8bb64caf98b4c61d04de95ba497f0069)

### Upgrade notes

- **The default admin email is now `admin@example.com`** (was `hello@cwa.rocks`) in `UsersFixture`, `k8s.sh` and the chart's values. A site with no `ADMIN_EMAIL` gets its admin's email rewritten on the next fixtures load (`UsersFixture` overwrites the existing admin), and on Kubernetes the chart's admin Secret changes on the next deploy. Set `ADMIN_EMAIL` to keep a real address. In dev, php's `MAILER_DSN` now comes from `compose.override.yaml` (Mailpit), so a `MAILER_DSN` in `api/.env.local` is ignored in dev; set it in the root `.env` instead. To take `bin/up`, copy `bin/up`, `compose.override.yaml` and `README.md`'s local section (#206). [8e07ddd](https://github.com/components-web-app/components-web-app/commit/8e07dddbe541c8fee79d83732be2737e8f7fbf0b), [aa8334a](https://github.com/components-web-app/components-web-app/commit/aa8334af89406b6694b3b68de8b961510e37f788)
- **#208 (the prebuilt php base): take it at a release tag, not from main commits**, and copy these together: `api/Dockerfile`, `bin/test/php-base-version.sh`, `.gitlab-ci.yml` or `.github/workflows/ci.yml` (the unit-test step that runs it), `bin/devops/k8s.sh`, `compose.override.yaml`, `compose.prod.yaml`, `.env.dist`. `.github/workflows/publish-php-base.yml` and `.github/php-base/` are template-only. Custom apt packages or extensions move below `FROM ${CWA_PHP_BASE} AS frankenphp_base`. A pulling site stays on its release's base until it upgrades, or sets `CWA_CI_PHP_BASE_IMAGE` to a rebuild (#208). [bbc0c74](https://github.com/components-web-app/components-web-app/commit/bbc0c74220244919c3d8823e8462975fe775ee34), [1517c94](https://github.com/components-web-app/components-web-app/commit/1517c9434b6b9e3e0d195a075ffac3870828d60e), [cb2db5c](https://github.com/components-web-app/components-web-app/commit/cb2db5c77cab694e6d5056fd20abdfb26800bdad), [1b27aa6](https://github.com/components-web-app/components-web-app/commit/1b27aa64c7de812c4db23b314e950081ad4d08d9), [732ac45](https://github.com/components-web-app/components-web-app/commit/732ac4589b25856692054f17435c8b60a8e6c41d), [08a339f](https://github.com/components-web-app/components-web-app/commit/08a339f874c7ecff6224f8c13d3183de693766cc)
- **Copy the Caddyfile and both Dockerfiles together** for the new Docker healthchecks: php's `HEALTHCHECK` calls a loopback-only health site (`http://127.0.0.1:2080`) that the Caddyfile now adds, so the healthcheck without the site leaves php permanently unhealthy. Locally, run `docker compose build php app` to pick them up (#205). [8c771f5](https://github.com/components-web-app/components-web-app/commit/8c771f5f42384d950b76e0707f5d122a3c4ddf27)
- Deploys and fixture loads now warn when `ADMIN_PASSWORD` is unset or `admin` (the public admin/admin super-admin login, which every fixture load resets): set it as a masked CI variable or secret. The deploy still runs. `compose.prod.yaml` now requires `ADMIN_PASSWORD` (#203). [80f63f3](https://github.com/components-web-app/components-web-app/commit/80f63f3758d6951c4e26ed9eddcf7a095ce5f4fc)

### Added

- `bin/up`: one command to a signed-in-ready dev site. It runs `docker compose up -d --wait`, loads the fixtures with `--append`, waits for the first pages to compile, and prints the login. It has a 15-minute budget (`CWA_UP_TIMEOUT`), names a failed phase with its services' last log lines, and is safe to run again (`--skip-fixtures` skips the load). The dev stack also gets Mailpit: dev emails show at http://localhost:8025. `create-cwa` runs `bin/up` after starting Docker, checks port 8025, and its generated README points at it (#206). [8e07ddd](https://github.com/components-web-app/components-web-app/commit/8e07dddbe541c8fee79d83732be2737e8f7fbf0b), [aa8334a](https://github.com/components-web-app/components-web-app/commit/aa8334af89406b6694b3b68de8b961510e37f788)
- The template's own demo site (preview.cwa.rocks) reloads its scaffold every day from a GitLab pipeline schedule, through `.gitlab/ci/template-only.yml`, which `.gitlab-ci.yml` includes only when the file exists. The file is template-only: `create-cwa` leaves it out and downstream sites don't copy it (copying the `include:` block is harmless) (#181). [8f41b00](https://github.com/components-web-app/components-web-app/commit/8f41b0018ce246b3ad098e55c1344fa8e11fe6f2)
- A prebuilt php base image, `ghcr.io/components-web-app/cwa-php-base:<version>`: FrankenPHP with the template's Souin, storages and `queryallowlist` patches and Caddy plugins, the apt packages and the PHP extensions (xdebug is installed but disabled, so production images now carry its unloaded `.so`; dev enables it without a network fetch). `publish-php-base.yml` builds it for amd64 and arm64 from each release tag and tests it before pushing, with weekly `<version>-rYYYYMMDD` security rebuilds; releases are attested and tags are never overwritten. **From this release** `api/Dockerfile` pulls `cwa-php-base:2.0.0-alpha.44`, so project builds stop compiling Go (#213) and installing PHP extensions (#176). `CWA_CI_PHP_IMAGE_FROM_SOURCE="true"` builds from source (for sites that change the patches; not Protected), `CWA_CI_PHP_BASE_IMAGE` takes a rebuild tag or `X@sha256:…` pin, and `CWA_PHP_BASE=cwa_php_base` in `.env` builds from source locally. The template's own CI always builds from source (#208). [bbc0c74](https://github.com/components-web-app/components-web-app/commit/bbc0c74220244919c3d8823e8462975fe775ee34), [1517c94](https://github.com/components-web-app/components-web-app/commit/1517c9434b6b9e3e0d195a075ffac3870828d60e), [cb2db5c](https://github.com/components-web-app/components-web-app/commit/cb2db5c77cab694e6d5056fd20abdfb26800bdad), [1b27aa6](https://github.com/components-web-app/components-web-app/commit/1b27aa64c7de812c4db23b314e950081ad4d08d9), [732ac45](https://github.com/components-web-app/components-web-app/commit/732ac4589b25856692054f17435c8b60a8e6c41d), [08a339f](https://github.com/components-web-app/components-web-app/commit/08a339f874c7ecff6224f8c13d3183de693766cc)
- Docker readiness checks: php checks `/_api/_/health` (PHP and the database) through a loopback-only Caddy site, app checks `/_cwa/healthcheck`, and the health endpoint is never cached, so `docker compose up -d --wait` waits until the site is ready. app gets `restart: unless-stopped`, and the browser tests use `--wait`. Kubernetes probes are unchanged (#205). [8c771f5](https://github.com/components-web-app/components-web-app/commit/8c771f5f42384d950b76e0707f5d122a3c4ddf27)
- An MIT `LICENSE` (Silverback Internet Services Limited, as the bundle's), `SECURITY.md` (private reporting through GitHub, no warranty or guaranteed response), `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, and GitHub issue and PR templates; `.all-contributorsrc` is removed. Projects made with `create-cwa` get none of them: a client site chooses its own licence (#202). [031b006](https://github.com/components-web-app/components-web-app/commit/031b006d18c7372e8b5dc9cb4fd0d1dfd1683bd3)

### Changed

- **Scaled mode is ready to turn on** (`CWA_CI_API_SCALED_<TRACK>`), rehearsed on preview.cwa.rocks on 2026-10-20 (#85's rehearsal comment). After a scaled deploy's flush and warm, the deploy checks the API cache is a Redis hit through the API service and prints a loud error (`::error` on GitHub) if it isn't, without failing the live deploy. The deploy also prints the database connections the API pods may open (peak pods × `CWA_CI_API_WORKERS` + 5) and warns past the in-cluster PostgreSQL's limit. There's no manual scale job: for a planned spike, raise `CWA_CI_API_AUTOSCALE_MIN` and deploy (#193). [683634b](https://github.com/components-web-app/components-web-app/commit/683634bf51f680b81cca64eb9aac3c0a1e967b2b), [5c33656](https://github.com/components-web-app/components-web-app/commit/5c3365685b0a8696a0314ec7ffe6a4d167701fe7)
- `create-cwa` checks Docker, ports 80/443/3001/5432 and Docker's memory before downloading, offers the host `pnpm install` only when the stack isn't started (it crashed a running dev server), validates the project name and an empty target directory up front, shows the manifest's hints, fixes the generated README's links, prints a prerelease and no-telemetry notice, and has an npm README; `api/README.md` documents `user:create --admin` (#204). [5847944](https://github.com/components-web-app/components-web-app/commit/5847944625b125026fc43414f3fe9d573af85110)


## [2.0.0-alpha.43](https://github.com/components-web-app/components-web-app/releases/tag/v2.0.0-alpha.43) - 2026-10-20

### Upgrade notes


- `CWA_CI_API_WARM_CONCURRENCY` is now per API pod (default 2), multiplied by the pods during the warm, warm surge included; a project that set a total divides it by its pod count. Review apps must have their own database: a review deploy whose `DATABASE_URL` is production's is refused (production is looked up as `RELEASE_PRODUCTION`, default `production`, in `KUBE_NAMESPACE_PRODUCTION`, default `<project>-production`; set it where yours differs) (#195, #197). [fa94640](https://github.com/components-web-app/components-web-app/commit/fa946403dfebb701b1948f683304c824cc9f74dc), [95ce541](https://github.com/components-web-app/components-web-app/commit/95ce541d61e89815bcf4ea5a10fc20f6535fce34)
- Database backups (`CWA_CI_DATABASE_BACKUP_<TRACK>="true"`) use their own key and bucket folder: run `bin/devops/backup-bucket.sh project <CI_PROJECT_PATH_SLUG>` (once per project, with an authenticated `gcloud`), set the base64 line it prints as the project's masked `CWA_CI_DATABASE_BACKUP_GCLOUD_JSON` (GitHub: a repository secret), not Protected unless the branch that deploys is protected ([0921e60](https://github.com/components-web-app/components-web-app/commit/0921e60972524b5127437e38cf6019995925825a)), and `CWA_CI_DATABASE_BACKUP_BUCKET=silverback-db-backups` on the group. Backups go to `<project slug>/<track>/<release>/` and never use `GCLOUD_JSON` (#180). [724f51d](https://github.com/components-web-app/components-web-app/commit/724f51de3c16a079d4b548887699a8cf9fe1455f)
- Bundle 2.0.0-alpha.33: `route_security` patterns match byte for byte (case and accents matter), on top of alpha.32's whole-path matching; check your own `route` patterns. A rule on the route list refuses databases other than PostgreSQL, MySQL, MariaDB and SQLite. [f188089](https://github.com/components-web-app/components-web-app/commit/f1880899fe4b5c09ca7cf58e48cc58f8955e91f9)
- **Copy `api/frankenphp/mercure-hub.caddy` (and `mercure-hub.Caddyfile`) with the Caddyfile**, which now imports the hub settings from it; without it php doesn't start. A project that changed the hub settings in its Caddyfile moves the change there. In scaled mode (still being built) the hub runs in its own pod and php forwards `/.well-known/mercure` to it (#85). [d51851c](https://github.com/components-web-app/components-web-app/commit/d51851c8fecb429aca2702c871198eec9c663cb6), [eca4d2b](https://github.com/components-web-app/components-web-app/commit/eca4d2bdd92e21a671f99d19552d97adcf7c67e0)

### Fixed

- A migration that writes from `up()`/`postUp()` no longer fails the read-only migrations plan and blocks guarded deploys: the plan lists it without SQL and warns. The backup Job's dump space is limited (`CWA_CI_DATABASE_BACKUP_STORAGE`, default 5Gi) (#183). [e8952d5](https://github.com/components-web-app/components-web-app/commit/e8952d5acaa65799482945ce26295987bc756eea)
- A maintenance window left on by a failed deploy is ended by the next production deploy, with or without `CWA_CI_MAINTENANCE_DURING_MIGRATIONS` (marker ConfigMap `<fullname>-maintenance-window`; maintenance an admin turned on is left alone), and the printed by-hand command uses a ready pod (#182). [abcc4a1](https://github.com/components-web-app/components-web-app/commit/abcc4a116c518c493b192c70294e21ab558be7f9)
- `check_api_scaling` counts `CWA_CI_API_REPLICA_COUNT` only with the autoscaler off, and min/max only with it on, as the chart does (#184). [32e9199](https://github.com/components-web-app/components-web-app/commit/32e919996cb78408e822fddffe46877ac6a22ad8)
- The Redis watch retries a "Redis is back" email that failed to send (migration `Version20261020172842`) (#194). [e0e30c8](https://github.com/components-web-app/components-web-app/commit/e0e30c8d1b3fc6554fa813a592b6d46bba932c15)
- The deploy refuses a `CWA_API_DATABASE_BACKUP_GCLOUD_JSON` site setting, which would have put the backup key into every API pod (#180). [705d5a7](https://github.com/components-web-app/components-web-app/commit/705d5a744499c69b9893fa6587db695d6d4394d4)
- API pods stop cleanly (Completed, not Error): preStop only waits for the ingress, and Caddy's new `grace_period 15s` finishes in-flight requests and cuts open SSE subscriptions instead of `kill -QUIT` (#85). [9ce62c0](https://github.com/components-web-app/components-web-app/commit/9ce62c012508bde3cc9c0aea77598d294eba05b6)
- Scaled mode's Mercure hub pod stops cleanly (Completed, not Error) with subscribers connected: a 5 s Caddy grace period instead of waiting forever for SSE connections (#85). [05090d5](https://github.com/components-web-app/components-web-app/commit/05090d5850f1fe2d3e78e3422e6299b27c10fb10)
- php image: a sixth Souin patch gives its buffering writer a no-op `Flush()`, so a PHP `flush()` behind the cache (every dev request; a streamed response in prod) no longer logs "responseWriter is not a flusher". Nothing behaved differently; the body was always buffered (#185). [45c3e2f](https://github.com/components-web-app/components-web-app/commit/45c3e2fa170e32c4f1880dc52bfb6aafdc60fa9d)
- Staging or a canary whose external `DATABASE_URL` is production's database no longer migrates it (review apps: #197): its pods skip migrations, and with migrations pending it isn't deployed (a canary fails), leaving them to the production deploy's plan, backup and window (#180). [724f51d](https://github.com/components-web-app/components-web-app/commit/724f51de3c16a079d4b548887699a8cf9fe1455f)
- Scaled deploys flush and warm only once the old API pods are gone (warm requests failed on terminating pods), and the warm surge raises the autoscaler's maximum along with its minimum (Kubernetes refused a minimum above the maximum) (#85). [4d2ad50](https://github.com/components-web-app/components-web-app/commit/4d2ad505bdc724992f1cad89677c52f8533a4245)
- Deploys run their commands in the API (the flush and warm, fixtures, image variants) in a ready pod, not `kubectl exec deploy/…`, which straight after a rollout could pick the old pod while it terminated. In scaled mode that flushed the old pod's own cache instead of the shared Redis (#85). [ba19fb4](https://github.com/components-web-app/components-web-app/commit/ba19fb47c8ead79cc55c2b291bac596279f0a895)
- Browser tests: the password reset test waits for `/forgot-password` and the reset page to hydrate before filling them, as `logIn` does (#179). [b09d62b](https://github.com/components-web-app/components-web-app/commit/b09d62b92ed5286a31413c1b76df626bdf886aeb)
- Browser tests: `e2e/run.sh` names its compose stack `cwa-e2e-<checkout directory>` (`COMPOSE_PROJECT_NAME` overrides) and its tests container after it, so two projects' local runs on one machine no longer join or tear down each other's (#178). [21a3745](https://github.com/components-web-app/components-web-app/commit/21a3745552ac615fad28aea8df53ee105a1b9b85)

### Changed

- Scaled mode's warms through the API Service pass `--requests-per-connection=1`, so they spread across the pods (#196). [4779237](https://github.com/components-web-app/components-web-app/commit/47792375ded99d08a1f201832cdd6a112db3f058)
- Bundle 2.0.0-alpha.34: `warm-http-cache --requests-per-connection=N`, to spread a warm across the pods behind a Service (#196), and resource manifests whose query count no longer grows with publishable components or drafts. No migration. [1cb14d7](https://github.com/components-web-app/components-web-app/commit/1cb14d7035c43ef1a51f611342466260336e18f6)
- Scaled mode (still being built): a Redis watch CronJob (`app:redis-watch`, every 2 minutes) notices when php can't reach Redis, emails `MAILER_EMAIL` once, and once Redis is back flushes the cache (and, with a Cloudflare CDN config, the zone), then emails again; a Redis restart only emails, and a restart a deploy caused sends nothing. State is kept in the database (migrations `Version20261020162222`, `Version20261020171138`). On in scaled mode unless `CWA_CI_API_REDIS_WATCH="false"`; `CWA_CI_API_REDIS_WATCH_SCHEDULE` overrides the schedule (#85). [0d9f9d5](https://github.com/components-web-app/components-web-app/commit/0d9f9d519b18e2e24bebec06fc2d090b4edd6ee3), [230869d](https://github.com/components-web-app/components-web-app/commit/230869d0464fc5743b15f4c7267a3709e672ee8f)
- A database backup on demand, e.g. before risky manual work: the manual `database backup production` job (GitLab, when `CWA_CI_DATABASE_BACKUP_BUCKET` is set) or `production.yml`'s `database-backup` action (#180). [c0a0545](https://github.com/components-web-app/components-web-app/commit/c0a05455556e170236dcb8a529c8a24cf0546e15)
- The track image tag (`:production`, `:staging`, `:canary`) is copied only after the migrations and both rollouts succeeded, so a failed deploy leaves the last good build tagged; a deploy whose rollouts don't finish within `CWA_CI_DEPLOY_ROLLOUT_TIMEOUT` (900 s) now fails. `bin/devops/backup-bucket.sh` (`init`, `project`, `verify`) sets up the shared private backup bucket, one folder and service account per project (#164, #180). [724f51d](https://github.com/components-web-app/components-web-app/commit/724f51de3c16a079d4b548887699a8cf9fe1455f)
- GitLab: the staging and production deploy jobs retry once only when CI itself failed (runner, timeout, API, scheduler), no longer when the deploy failed, so a failed maintenance window isn't backed up and migrated again (#180). [3d8d9fd](https://github.com/components-web-app/components-web-app/commit/3d8d9fd688f2a005de51cecc48e8e46c840c4210)
- Bundle 2.0.0-alpha.33: `silverback:api-components:maintenance on|off|status`, which the maintenance window uses (#180), and faster cold resource manifests. No migration. [f188089](https://github.com/components-web-app/components-web-app/commit/f1880899fe4b5c09ca7cf58e48cc58f8955e91f9)
- Deploys can show production's pending migrations and their SQL before you press the production deploy (`migrations plan production`, read-only, with this pipeline's image; on unless `CWA_CI_MIGRATIONS_PLAN_PRODUCTION="false"`), back the database up first (`CWA_CI_DATABASE_BACKUP_<TRACK>="true"` with a private `CWA_CI_DATABASE_BACKUP_BUCKET`, never the media bucket; keeps `CWA_CI_DATABASE_BACKUP_KEEP`, 5), migrate in a Job before the rollout (`CWA_CI_MIGRATIONS_JOB_<TRACK>`), and, for large or breaking changes, run that pipeline with `CWA_CI_MAINTENANCE_DURING_MIGRATIONS="true"`: maintenance on, back up, migrate, roll out, flush, warm, maintenance off; a failure leaves maintenance on and prints how to restore and turn it off. All off by default; the window needs a bundle with the maintenance command (api-components-bundle#549) on the live site; a window without a backup runs with a warning (#180). [ebbb6ed](https://github.com/components-web-app/components-web-app/commit/ebbb6ed5cc9a1fe3d1194725a75663d61501c2b4), [0f417a8](https://github.com/components-web-app/components-web-app/commit/0f417a8a34eaa01812995565a6a5dacd62f66e06), [03cc5f5](https://github.com/components-web-app/components-web-app/commit/03cc5f580fa79121fc25b3acdf206b8e3520e110), [d8a2384](https://github.com/components-web-app/components-web-app/commit/d8a2384f5f4b2b883bdeb42b980f8573e8db1367), [6bc3ac7](https://github.com/components-web-app/components-web-app/commit/6bc3ac7a4810764154b74e4a24e380abb3c461cb)
- Browser tests: `E2E_SCALED=true` (CI: `CWA_CI_E2E_SCALED="true"`) runs them against two php replicas sharing scaled mode's Redis cache and Mercure hub (#85). [dd7ffe9](https://github.com/components-web-app/components-web-app/commit/dd7ffe950768ea4e09746b20ef8f6003639ade3e)
- Scaled mode (still being built): `CWA_CI_API_WARM_SURGE` runs that many extra API pods for a deploy's flush and warm, then lets them go; warms after a flush go through the API service so every pod renders a share (`CWA_CI_API_WARM_CONCURRENCY`, default 2 per pod) (#85). [a4bd818](https://github.com/components-web-app/components-web-app/commit/a4bd81836fcb436a220cbd09985eac0bd1fb2243)
- Scaled mode (still being built): API pods get a PDB (`maxUnavailable: 1`), spread across nodes, and an autoscaler on CPU only that removes pods after ten minutes; the chart refuses more than one API pod without it (#85). [9959bf3](https://github.com/components-web-app/components-web-app/commit/9959bf387d9813d01587e9972e1545c51282a81f)
- Deploys refuse more than one API pod (`CWA_CI_API_AUTOSCALE_MIN`/`_MAX` or `CWA_CI_API_REPLICA_COUNT` above 1) unless scaled mode is on for that track, since a second pod's cache is never purged. Scaled mode (`CWA_CI_API_SCALED_PRODUCTION`, `_STAGING`, `_CANARY`, `_REVIEW`) is being built and isn't ready to turn on: so far it starts a Redis per release as the shared cache and flushes on every deploy (#85). [62bfeb9](https://github.com/components-web-app/components-web-app/commit/62bfeb928ad665d29666e4569507f1f79c47172a)
- php entrypoint: migrations and `ANALYZE` run through `app:database:migrate`, under a Postgres advisory lock, so pods and CronJob pods starting together (a deploy beside the 03:00 orphan scan, or several API pods) run them once; the others wait up to 600 s (#85). [77617ca](https://github.com/components-web-app/components-web-app/commit/77617ca22aabb871c6a2db27e1748df4d70984d5)

## [2.0.0-alpha.42](https://github.com/components-web-app/components-web-app/releases/tag/v2.0.0-alpha.42) - 2026-10-19

### Upgrade notes

- Bundle 2.0.0-alpha.32: `route_security` patterns now match the whole path (case-insensitive, `*` the only wildcard). Check any `route` your project adds still matches what you mean: `/x*` is a prefix, `*/x*` matches anywhere. [d816382](https://github.com/components-web-app/components-web-app/commit/d816382770e6d7ca034d97dcb5f24bdf715abd11)
- Behind Google Cloud CDN, set each media backend bucket's caps to a year, or the long `Cache-Control` from bundle 2.0.0-alpha.15's `uploadable.cache_control` (and alpha.25's back-fill) reaches browsers as `max-age=3600`: `gcloud compute backend-buckets update <backend-bucket> --max-ttl=31536000 --client-ttl=31536000`, then `gcloud compute url-maps invalidate-cdn-cache <url-map> --host <cdn host> --path "/*"`. New sites: create the bucket with both caps. [#154](https://github.com/components-web-app/components-web-app/issues/154)

### Fixed

- php image: every step that fetches from Debian (base packages, `install-php-extensions`) runs through `retry-fetch`, a hard time limit with up to three attempts, and apt fetches deb.debian.org over HTTPS; apt also retries with 30 s timeouts and no pipelining. Uncached builds hung on plain HTTP until the 1 h job limit, or were killed, on GitLab SaaS small runners (#176). [841ea0f](https://github.com/components-web-app/components-web-app/commit/841ea0f6416e421253c11059f23cc2ec517b7c05), [7fc4ac5](https://github.com/components-web-app/components-web-app/commit/7fc4ac58a1cbef543d97886410fed8262d31b6b6), [48b5c7c](https://github.com/components-web-app/components-web-app/commit/48b5c7c21e3d50f3deb3a3048f15ab04dffaa3f3)

### Changed

- Module 2.0.0-alpha.24 (needs bundle 2.0.0-alpha.32): Move goes through `POST {component}/move`, page-data slots included; a shared component shows a "Shared · N places" badge by its publish button with the list of places, and its other copies on the page are outlined; Clone and Move usability fixes. [773ae69](https://github.com/components-web-app/components-web-app/commit/773ae694d086204c3f31501564aeec6f0510c2c3)
- Bundle 2.0.0-alpha.32: `POST {component}/move` and the locations list on `GET {component}/usage`, which is now admin only. `route_security` patterns match the whole path, case-insensitive, with `*` the only wildcard; the template's `/user-area*` is a prefix, as intended. No migration. [d816382](https://github.com/components-web-app/components-web-app/commit/d816382770e6d7ca034d97dcb5f24bdf715abd11)
- Browser tests: `logIn` waits for `/login` to hydrate before filling the form. [5b6a605](https://github.com/components-web-app/components-web-app/commit/5b6a6058fb59fc4f8c618f6ecf6f3b558d71e63c)
- Browser tests assume only what every project has, the admin user and the sitemap's pages, so they pass on a site without the sample content. The 308 redirect and the text and image publish tests are removed; the cache-hit, loading-bar and OG image tests use sitemap pages (#177). [5db12c9](https://github.com/components-web-app/components-web-app/commit/5db12c9e9992a1f02eaaf187f36ed56db965c13e)
- `create-cwa`: dependencies updated (`@clack/prompts` 1, `giget` 3, TypeScript 7); a generated project is unchanged. [bc477e8](https://github.com/components-web-app/components-web-app/commit/bc477e83122fa90287f4e013c0eb4a25d03c2ee3)
- Module 2.0.0-alpha.23: Move, in a component's menu, relocates a position through the clone workflow (not yet for page-data slots); clone-mode fixes. [5c5d873](https://github.com/components-web-app/components-web-app/commit/5c5d87372634ad1d18f94053d9043e5802b5f3a6)
- Bundle 2.0.0-alpha.31: publishing a draft of a published component no longer empties its positions or orphans its groups, and a component PATCH adding an embedded position no longer 500s. No config or migration. [8125a75](https://github.com/components-web-app/components-web-app/commit/8125a7511596c1b707d3ef87e371f1aec84a2de4)
- Helm chart: no API HPA while `autoscaling.maxReplicas` is 1 (the default); it couldn't scale and showed memory over target permanently. The next deploy removes it; raising the max brings it back. [7e0e4d2](https://github.com/components-web-app/components-web-app/commit/7e0e4d23ae5de5ea194e65c0533499ae3724f56f)
- A fixture load's full flush is followed by the same `/_api` warm as a deploy's (`warm_api_cache`). [02f653d](https://github.com/components-web-app/components-web-app/commit/02f653d7d74f2a01ea08e687a383334faa41269c)
- `liip_imagine.yaml` has a commented `driver: gd` line. gd keeps AVIF, as vips does through libheif, so switching needs no image rebuild. [4341396](https://github.com/components-web-app/components-web-app/commit/434139660c906afbc2a4a46474bef38e79fc2fa7)

## [2.0.0-alpha.41](https://github.com/components-web-app/components-web-app/releases/tag/v2.0.0-alpha.41) - 2026-10-18

### Changed

- Bundle 2.0.0-alpha.30 (placing a component that would create a cycle is a 422, api-components-bundle#503) and `@cwa/nuxt` 2.0.0-alpha.22 (clone a component into other positions, cwa-nuxt-module#157; faster navigation with many cached pages, cwa-nuxt-module#259). Update `api/composer.lock`, `app/package.json` and `app/pnpm-lock.yaml`; no migration. [52552d8](https://github.com/components-web-app/components-web-app/commit/52552d8a94849bca15b7e4962c7aa80e29be6d78)
- Dependencies: pnpm 12.14.0 (`packageManager` and the app Dockerfile's `PNPM_VERSION`), Guzzle 8.3, the app's other in-range updates, and for tests Playwright 1.64.1 (`e2e/Dockerfile` image and package), eslint 10.13.0, redis 8.10.2 and mailpit v1.31.6. [52552d8](https://github.com/components-web-app/components-web-app/commit/52552d8a94849bca15b7e4962c7aa80e29be6d78)
- CLAUDE.md: TypeScript stays pinned to 6.0.3 until vue-tsc supports TypeScript 7, now tracked by vuejs/language-tools#6170 (vue-tsc v4, a draft); every TypeScript 7 issue there is closed. [c3fc4d1](https://github.com/components-web-app/components-web-app/commit/c3fc4d14cc5dbb5568cfca438431d794448dc57b)

## [2.0.0-alpha.40](https://github.com/components-web-app/components-web-app/releases/tag/v2.0.0-alpha.40) - 2026-10-18

### Upgrade notes

- Bundle 2.0.0-alpha.29 and `@cwa/nuxt` 2.0.0-alpha.21 go together (alpha.27 and alpha.28 500 when publishing in functional tests): update `api/composer.lock`, `app/package.json` and `app/pnpm-lock.yaml` in one deploy (no migration). Public Mercure updates are now the anonymous view, anonymous visitors get no Mercure cookie from `/me` (the template's hub already allows anonymous subscribers), and the subscriber cookie and its token expire after `refresh_token.ttl` instead of `mercure.default_cookie_lifetime`. A site routing `Symfony\Component\Mercure\Update` to an async transport must also route `Silverback\ApiComponentsBundle\Message\PublishMercureUpdatesMessage`. [0dab19c](https://github.com/components-web-app/components-web-app/commit/0dab19ca6f3ce8817614ca1f4b85ed8732745e52)

### Changed

- Dependencies: API Platform 5.0.4 (includes the genid fix, api-platform/core#8681, #161), Symfony 8.1.9, Nuxt 4.6.2, `@nuxt/ui` 4.12.0, satori 0.62.0. [0dab19c](https://github.com/components-web-app/components-web-app/commit/0dab19ca6f3ce8817614ca1f4b85ed8732745e52)
- Bundle 2.0.0-alpha.26: a `br` warm without the brotli extension now fails instead of warming only routes, and a body it can't decode counts as failed (api-components-bundle#488, #175). Update `api/composer.lock`; no migration. [cb79664](https://github.com/components-web-app/components-web-app/commit/cb7966404fe4b6750eff8f03c424875a0d9f834b)

### Fixed

- Bundle 2.0.0-alpha.29: publishing no longer 500s ("Event api_platform.processor.write is not started") under a debug kernel whose profiler doesn't collect, as in functional tests (api-components-bundle#501); the bundle's skolem hotfix is gone now that API Platform 5.0.4 has the fix, and it requires `api-platform/core` ^5.0.4 (#161). Update `api/composer.lock`; no migration. [f85d1a0](https://github.com/components-web-app/components-web-app/commit/f85d1a0aa791c95739d8bd577c5d907cc86f6d92)

## [2.0.0-alpha.39](https://github.com/components-web-app/components-web-app/releases/tag/v2.0.0-alpha.39) - 2026-10-17

### Upgrade notes

- Copy `api/Dockerfile` and `api/tests/Unit/BrotliExtensionTest.php`: the php image gets the `brotli` extension, without which the postStart `br` warm only warmed route responses, never their manifests or components (#175). [c52bb7a](https://github.com/components-web-app/components-web-app/commit/c52bb7a95a52dd6a90668456f4b08e031221990b)
- Copy `bin/devops/k8s.sh`: after a deploy's full flush (sites with `provider cloudflare` in `CADDY_CACHE_CDN_CONFIG`, and after new image variants) the API pod's `/_api` is warmed again, gzip then br, so those jobs take up to 2 x `CWA_CI_API_WARM_HTTP_CACHE_MAX_TIME` (60 s) longer (#175). A large site may need a higher value: on cymru-kitchens (111 routes) 60 s didn't cover one pass. [1818110](https://github.com/components-web-app/components-web-app/commit/18181102a41d844bda3240cdc83fd1b46f4c7b9b)

### Fixed

- The deploy's Cloudflare flush emptied a new php pod's warm cache moments before visitors arrived, so the first visitor's component requests were load-shed (#175). [1818110](https://github.com/components-web-app/components-web-app/commit/18181102a41d844bda3240cdc83fd1b46f4c7b9b)

## [2.0.0-alpha.38](https://github.com/components-web-app/components-web-app/releases/tag/v2.0.0-alpha.38) - 2026-10-17

### Upgrade notes

- Update api-components-bundle to 2.0.0-alpha.25 and `@cwa/nuxt` to 2.0.0-alpha.20 together (`api/composer.lock`, `app/package.json`, `app/pnpm-lock.yaml`): the module's new "Purge this page" needs the bundle's scoped purge, and an older bundle would flush everything instead. No migration. [388425e](https://github.com/components-web-app/components-web-app/commit/388425e968d28f485c470efc1aed7a69f6d46911)
- Souin's store and backend timeout are their own settings (#170): `CADDY_CACHE_STORAGE` (default `otter`) and `CADDY_CACHE_BACKEND_TIMEOUT` (default `30s`), set on deploys as `CWA_API_CADDY_CACHE_STORAGE` / `CWA_API_CADDY_CACHE_BACKEND_TIMEOUT`. `CADDY_CACHE_EXTRA_CONFIG` is now for other directives only and no longer defaults to `otter`: **delete a `CADDY_CACHE_EXTRA_CONFIG` CI variable that only restates `otter` or a `timeout` block in the same deploy**, because the deploy now refuses a store or `timeout` there (`check_cache_config`). Copy `api/frankenphp/Caddyfile`, `api/frankenphp/worker.Caddyfile`, `compose.yaml`, `bin/devops/k8s.sh`, `helm/cwa/templates/_helpers.tpl`, `secrets.yaml`, `values.yaml`, `bin/test/souin-backend-timeout.sh`, `bin/test/cache-encoding.sh` and the unit-tests steps of `.gitlab-ci.yml` and `.github/workflows/ci.yml`. The chart's `php.caddy.storageConfig` and secret key `caddy-cache-storage-config` are renamed `php.caddy.extraConfig` and `caddy-cache-extra-config`. Local dev now uses otter too. [a728acb](https://github.com/components-web-app/components-web-app/commit/a728acbb28ddc12e9e91cb8b0b7fe362e0ae3b52)
- Copy `helm/cwa/templates/deployment.yaml`: a new php pod's postStart warm runs a second, `br` pass for browsers and Cloudflare, so a pod can take up to `CWA_CI_API_WARM_HTTP_CACHE_MAX_TIME` (60 s) longer to become ready (#170). [3d90f34](https://github.com/components-web-app/components-web-app/commit/3d90f348e732bbb3e5af886a53cf2c287f4f2147)
- The deploy tidies `GCLOUD_PATH_PREFIX` exactly as php does and fails before touching the cluster on a `.`, `..` or `review` segment (#168). Rename such a prefix first, moving its objects with it. Copy `bin/devops/k8s.sh` and `bin/test/storage-prefix-parity.sh` (and its unit-tests steps). [82438ab](https://github.com/components-web-app/components-web-app/commit/82438ab5e5f00716c94b6ab66499d0b4fa4207f7)
- Review apps deployed before 2.0.0-alpha.37 keep their uploads at the bucket root, so after their next deploy those uploads are missing and the orphan scan no longer sees them (#169). Reload their fixtures with `CWA_CI_FIXTURES_PURGE=true`, or recreate them, then delete the root objects by hand. [a354f48](https://github.com/components-web-app/components-web-app/commit/a354f4809d27a41b1f567618d8ca729f204ade96)
- The bucket lifecycle rule behind stop review needs one rule per prefixed app, `matchesPrefix: ["<GCLOUD_PATH_PREFIX>review/"]`, and its `age` counts from each object's upload, so pick one longer than your review apps live (#169). [a354f48](https://github.com/components-web-app/components-web-app/commit/a354f4809d27a41b1f567618d8ca729f204ade96)
- Review apps store under `<GCLOUD_PATH_PREFIX>review/<slug>/` without the slug's own `review-`, so `review/review-feat-x/` is now `review/feat-x/` (#173). A review app deployed on 2.0.0-alpha.37 moves path on its next deploy and its earlier uploads go missing, as in #169: reload its fixtures with `CWA_CI_FIXTURES_PURGE=true` or recreate it; its old path is then left to the lifecycle rule. One left as it is still deletes its own path when stopped, since the delete runs with the pod's prefix. Copy `bin/devops/k8s.sh` and `bin/test/storage-prefix-parity.sh`. [1a98d54](https://github.com/components-web-app/components-web-app/commit/1a98d54ac752bf23e787ffd5fa63c27f740733b3)
- GitLab: copy the `stop review` job from `.gitlab-ci.yml` (#165). It no longer checks out its branch, so merging with *Delete source branch* stops the review app instead of leaving it running. It fetches `bin/devops` from your default branch, so the stop runs that branch's `k8s.sh` and `project.sh`. An environment already stuck in *stopping* still needs the manual cleanup in #165. [e3286b4](https://github.com/components-web-app/components-web-app/commit/e3286b4a9f8f2c12faa713c7e595506bfdd66c36)

### Changed

- Bundle 2.0.0-alpha.25 and module 2.0.0-alpha.20: the admin can purge one page from the cache instead of everything, and the admin purge endpoint takes `paths` or `tags`. [388425e](https://github.com/components-web-app/components-web-app/commit/388425e968d28f485c470efc1aed7a69f6d46911)
- Souin waits 30 s for a cold render instead of 10 s, so a slow cold CMS page after a full flush or a rollout is served and cached instead of returning a 504 (#170). [a728acb](https://github.com/components-web-app/components-web-app/commit/a728acbb28ddc12e9e91cb8b0b7fe362e0ae3b52)
- The cache store is its own setting, so overriding `CADDY_CACHE_EXTRA_CONFIG` can no longer drop otter (#170). [a728acb](https://github.com/components-web-app/components-web-app/commit/a728acbb28ddc12e9e91cb8b0b7fe362e0ae3b52)
- A new php pod's postStart warm also warms the `br` keys browsers and Cloudflare use, after SSR's `gzip` ones (#170). [3d90f34](https://github.com/components-web-app/components-web-app/commit/3d90f348e732bbb3e5af886a53cf2c287f4f2147)

### Fixed

- The reserved-name error for `CWA_API_CADDY_CACHE_CDN_CONFIG` and `CWA_API_CADDY_CACHE_EXTRA_CONFIG` names the plain CI variable to set (#170). [a728acb](https://github.com/components-web-app/components-web-app/commit/a728acbb28ddc12e9e91cb8b0b7fe362e0ae3b52)
- The deploy and php now tidy `GCLOUD_PATH_PREFIX` the same way, so `site-a//` gives review apps `site-a/review/<slug>/` (#168). [82438ab](https://github.com/components-web-app/components-web-app/commit/82438ab5e5f00716c94b6ab66499d0b4fa4207f7)
- Stop review's storage warning names the app's real path (#169). [a354f48](https://github.com/components-web-app/components-web-app/commit/a354f4809d27a41b1f567618d8ca729f204ade96)
- A review app's storage path no longer says "review" twice (#173). [1a98d54](https://github.com/components-web-app/components-web-app/commit/1a98d54ac752bf23e787ffd5fa63c27f740733b3)
- `stop review` failed in `get_sources` once its branch was deleted, leaving the review app, its database volume and stored files behind (#165). [e3286b4](https://github.com/components-web-app/components-web-app/commit/e3286b4a9f8f2c12faa713c7e595506bfdd66c36)

## [2.0.0-alpha.37](https://github.com/components-web-app/components-web-app/releases/tag/v2.0.0-alpha.37) - 2026-10-17

### Upgrade notes

- Bundle 2.0.0-alpha.24 and `@cwa/nuxt` 2.0.0-alpha.19 must be deployed together (api-components-bundle#480, cwa-nuxt-module#400): the API now orders component positions and ignores a `sortValue` in a request, which is how older modules reorder. Copy `api/composer.lock`, `app/package.json` and `app/pnpm-lock.yaml`, or run `composer update components-web-app/api-components-bundle` in the php container and set `@cwa/nuxt` to `^2.0.0-alpha.19`. [da2f00a](https://github.com/components-web-app/components-web-app/commit/da2f00a750b8f41b8b389798c9abffe119c98d34)
- Migration: bundle 2.0.0-alpha.23 adds `max_components` to `_acb_component_group` (api-components-bundle#467). Copy `api/migrations/Version20261016233432.php`, or generate your own with `doctrine:migrations:diff` (delete its `down()`). [da2f00a](https://github.com/components-web-app/components-web-app/commit/da2f00a750b8f41b8b389798c9abffe119c98d34)
- Bundle breaking changes, none of which the template uses; check your own code: `sortValue` is read-only on the API (`after`/`before` anchors and `PATCH <group>/order` replace it); `ComponentPositionSortValueHelper` and `ComponentPosition::getSortCollection()` are removed; `UploadedDataUriFile`, `OrphanedFileDetector`, `ComponentPositionValidator`, `ComponentGroupNormalizer`, `ComponentPositionNormalizer` and `GenerateFixturesCommand` take different constructor arguments. `CwaFixtureBuilder` now numbers sort values 0, 1, 2… instead of 10, 20, 30…: only scaffold code that relies on the old numbers needs a change. [da2f00a](https://github.com/components-web-app/components-web-app/commit/da2f00a750b8f41b8b389798c9abffe119c98d34)
- Storage path prefix (#166): copy `api/config/services.php`, `api/src/Flysystem/`, the `GCLOUD_PATH_PREFIX` lines of `api/.env`, `bin/devops/k8s.sh` and `helm/cwa/templates/` and `values.yaml`. Review apps then store their uploads under `review/<slug>/` (inside `GCLOUD_PATH_PREFIX` if you set one), and stopping a review app deletes them (the bundle's `delete-stored-files`, api-components-bundle#477, bundle 2.0.0-alpha.24). Existing review apps' objects stay at the bucket root until you remove them. Production is unchanged while `GCLOUD_PATH_PREFIX` is unset. **Several apps on one bucket should each set a prefix** (as a CI variable), or each app's orphaned-file scan lists the others' files and "delete all" removes them. Before setting one on a live app, copy its objects under the new prefix, because the paths stored in the database are relative to it. Optionally add a bucket lifecycle rule deleting `review/` objects after about 90 days, in case a stop job fails. [!15](https://gitlab.com/silverback-web-apps/cwa/components-web-app/-/merge_requests/15)

### Changed

- Bundle 2.0.0-alpha.24 and `@cwa/nuxt` 2.0.0-alpha.19: the server places added and moved components, a reorder is one request, and a component group can take a `max-components` limit; plus `delete-stored-files`, fixture asset stores and `#[UploadedImage]` (bundle alpha.23 and alpha.24 release notes). [da2f00a](https://github.com/components-web-app/components-web-app/commit/da2f00a750b8f41b8b389798c9abffe119c98d34)

### Added

- `GCLOUD_PATH_PREFIX`: an app's uploads, image variants and orphaned-file scan stay in one path of the bucket, and media URLs include it once. Review apps get their own path automatically and empty it when stopped (the bundle's `delete-stored-files`, guarded on the pod's prefix). The browser tests run under a prefix (#166). [!15](https://gitlab.com/silverback-web-apps/cwa/components-web-app/-/merge_requests/15)

### Fixed

- Selecting a component edited with `TipTapHtmlEditor` no longer saves TipTap's re-serialised HTML as a draft (#167). [9c91f6e](https://github.com/components-web-app/components-web-app/commit/9c91f6ebb6c20b719f862996d9414198f42bfd54)

## [2.0.0-alpha.36](https://github.com/components-web-app/components-web-app/releases/tag/v2.0.0-alpha.36) - 2026-10-16

### Upgrade notes
- Bundle 2.0.0-alpha.22 (api-components-bundle#453): copy `api/composer.lock`, or run `composer update components-web-app/api-components-bundle` in the php container. No migration. Its three breaking changes are in the fixture builder; the template's scaffold needs none of these changes, but check your own scaffold and fixtures code. Run a fresh load and a second `--append` on a throwaway database and compare row counts with the previous bundle. [1b348c3](https://github.com/components-web-app/components-web-app/commit/1b348c3482c788b9177bfb60155efe1549dbfaf8)
  - **`nested()` on a page or page data adds a closure instead of replacing the last one.** If one builder calls `nested()` more than once (a later call meant to override an earlier one), every closure now runs, and the children of each are created. Keep one call per builder. `PageBuilder::nested()` now returns the builder, so it can be chained.
  - **Persist order changed.** A component builder with no groups and a draft is persisted with the positions, not in the first phase. A component builder with groups is persisted after the `nested()` closures whenever the scaffold has one. Code that reads a component's id, IRI or route in an earlier callback (between the first phase and the positions) may now see it unpersisted. Use `linkIri()`/`linkRoute()`, or read it in `onRoutesCreated()`.
  - **`GenerateFixturesCommand` takes the `ScaffoldGenerator` service** (`silverback.api_components.fixture.scaffold_generator`) instead of its six old collaborators. Only a project that decorates, extends or builds the command by hand must change; inject the generator instead.
  - Optional: re-run `generate-fixtures` for the new readable output, which uses named methods and variables, `linkRoute()`, `publish()` and `draft()`. A previously generated scaffold still loads.

### Security
- symfony/expression-language 8.1.9 (CVE-2026-109449: unbounded nesting in the expression parser could crash the process). Copy `api/composer.lock`. [1b348c3](https://github.com/components-web-app/components-web-app/commit/1b348c3482c788b9177bfb60155efe1549dbfaf8)

### Changed
- Bundle 2.0.0-alpha.22: `generate-fixtures` writes a scaffold you could maintain by hand; adds `linkIri()`, `linkRoute()`, `publish()`, `draft()` and `reachableWithoutRoute()`; fixes `--append` duplicates and a `nested()` inside a nested closure that never ran (api-components-bundle#453). The template's scaffold loads identically. [1b348c3](https://github.com/components-web-app/components-web-app/commit/1b348c3482c788b9177bfb60155efe1549dbfaf8)
- The browser tests are type-checked before they run (strict `e2e/tsconfig.json`), use a `visitor` fixture that closes its own context, and find fields by label ([43ece66d7a6a2c6e478904d45b2312a248fd634b](https://github.com/components-web-app/components-web-app/commit/43ece66d7a6a2c6e478904d45b2312a248fd634b)).
- The browser tests are linted before they run: the module's style, eslint-plugin-playwright and typescript-eslint's `no-floating-promises`, all as errors ([08b40db59ffd6f41fbdb3c716d5190bbbcd0a871](https://github.com/components-web-app/components-web-app/commit/08b40db59ffd6f41fbdb3c716d5190bbbcd0a871)).
- The browser tests' run options and the ARM Mac note moved from script comments to `e2e/README.md` ([8949efe89eb2ac19319fbc1278227fbd9d3c2610](https://github.com/components-web-app/components-web-app/commit/8949efe89eb2ac19319fbc1278227fbd9d3c2610)).

## [2.0.0-alpha.35](https://github.com/components-web-app/components-web-app/releases/tag/v2.0.0-alpha.35) - 2026-10-15

### Upgrade notes
- Pinned deploys (#164): copy `bin/devops/k8s.sh`, `.gitlab-ci.yml` (or `.github/workflows/ci.yml` and `production.yml`) and `.gitignore`. The first deploy of each track creates its `:staging`, `:canary` or `:production` tag in your registry and rolls every pod onto the pinned image. On GitHub the deploy jobs now ask for `packages: write`. [e5b2a29](https://github.com/components-web-app/components-web-app/commit/e5b2a291f7702d1723e5891026944c0fc9ee080e)

### Changed
- @cwa/nuxt 2.0.0-alpha.17: `<CwaLoadingIndicator>`'s bar no longer goes back when the page load finds more resources (cwa-nuxt-module#397). Copy `app/package.json` and `app/pnpm-lock.yaml`. [303fa05](https://github.com/components-web-app/components-web-app/commit/303fa05c9424916eb4d5657d13892a00cd610a1c)

### Fixed
- Production pods no longer run the moving `:main` tag with `pullPolicy: Always` (#164). A restart, eviction or scale-up, or the nightly orphan scan (which migrates on start), could run an undeployed build against the live database. Deploys now run `<track tag>@<digest>` of the pipeline's own build: staging, canary and production each get one tag, moved only by a deploy, so no per-commit tags pile up. [e5b2a29](https://github.com/components-web-app/components-web-app/commit/e5b2a291f7702d1723e5891026944c0fc9ee080e)
## [2.0.0-alpha.34](https://github.com/components-web-app/components-web-app/releases/tag/v2.0.0-alpha.34) - 2026-10-15

### Upgrade notes
- @cwa/nuxt 2.0.0-alpha.16 (#163): bump `@cwa/nuxt` and `@nuxtjs/sitemap` (to `^9.1.0`) in `app/package.json`, and move any other Nuxt SEO module you list yourself to its v6-family major (cwa-nuxt-module#392). Put `<CwaLoadingIndicator />` in `app/app/app.vue`, and remove `CwaUiProgressBar` and its `percent` computeds from your layouts, or two bars show. Copy `bin/devops/k8s.sh`: OG images are now signed with `NUXT_APP_SECRET` and return 500 without it. The deploy keeps one for you (generated on the first deploy, then read back from the live PWA Secret); set a CI variable of at least 32 characters only if you want to choose it. `compose.prod.yaml` now requires it. [f93a7fa](https://github.com/components-web-app/components-web-app/commit/f93a7fa12333aa5ac0fcbfefba0866218e2e6386)
- Logging (#162): copy `api/config/packages/prod/monolog.yaml`, `api/src/Monolog/ErrorMailHandler.php`, `api/tests/Unit/Monolog/`, and the `ERROR_MAIL_TO` line of `api/.env`. prod no longer writes `var/log/prod.log`; read the logs with `kubectl logs` or the cluster's log explorer. For an email on each new 5xx, set the CI variable `CWA_API_ERROR_MAIL_TO` (and a working `MAILER_DSN`). [59929e3](https://github.com/components-web-app/components-web-app/commit/59929e36166dca7543dfeab19234f32f9c4abbf9)
- Optional browser tests (#157): copy `e2e/`, `.gitlab-ci.yml` (or `.github/workflows/ci.yml`, `production.yml` and the new `browser-tests.yml`), `bin/devops/k8s.sh`, `api/config/services.php` and `api/src/Flysystem/GoogleCloudStorageFactory.php`. Nothing runs until you set the CI variable `CWA_CI_E2E_ENABLED="true"`; then review, staging, canary and production wait for the tests. Add project-specific flows under `e2e/tests/` (see `e2e/README.md`). [3fd2c01](https://github.com/components-web-app/components-web-app/commit/3fd2c01237578dd0f009de10699402b257f5bf7c) [8c36f8c](https://github.com/components-web-app/components-web-app/commit/8c36f8c89f9176495fc02f8f9480531c71eb4613)

### Changed
- @cwa/nuxt 2.0.0-alpha.16: one loading bar, `<CwaLoadingIndicator>` (Nuxt's own, driven by the CWA page load), covers CWA and plain Nuxt pages, and the scroll to top waits for the new page (cwa-nuxt-module#396). Publishing straight after typing keeps the last edit (#394), and the first publish no longer leaves a "has not been requested" box (#395). Nuxt SEO v6, with `@nuxtjs/sitemap` 9 (#392). The browser tests now publish straight after typing, and check the loading bar and a page's OG image. [f93a7fa](https://github.com/components-web-app/components-web-app/commit/f93a7fa12333aa5ac0fcbfefba0866218e2e6386)

### Added
- prod logs go to stderr as JSON in Google's structured logging shape, redacted (emails, tokens, JWTs, DSN credentials, password hashes), not to a file inside the container that every restart lost. An optional error mail sends one email per unique 5xx per hour to `ERROR_MAIL_TO`. The browser tests fail if a run sends one (#162). [59929e3](https://github.com/components-web-app/components-web-app/commit/59929e36166dca7543dfeab19234f32f9c4abbf9)
- Opt-in Playwright browser tests that gate deploys (#157). They run this commit's production images in a throwaway stack (Postgres on tmpfs, a Cloud Storage emulator, Mailpit) and cover: public pages hydrate, the page cache, the redirect, log in and out, editing and publishing text, uploading and publishing an image, and the password-reset email link. A fixture fails any test whose API write gets a 405, 406 or 415, timeouts are bounded, and the run fails unless every listed test ran. The Playwright report, traces and videos are kept for 14 days. `GoogleCloudStorageFactory` takes an optional `GCLOUD_API_ENDPOINT` (an emulator); empty is unchanged. [3fd2c01](https://github.com/components-web-app/components-web-app/commit/3fd2c01237578dd0f009de10699402b257f5bf7c) [8c36f8c](https://github.com/components-web-app/components-web-app/commit/8c36f8c89f9176495fc02f8f9480531c71eb4613)

## [2.0.0-alpha.33](https://github.com/components-web-app/components-web-app/releases/tag/v2.0.0-alpha.33) - 2026-10-14

### Changed
- Dependency updates: TipTap 3.32, `satori` 0.56 (OG images checked), vue 3.5.44, vite 8.3.4, `vue-tsc` 3.3.13, `@nuxt/devtools` 4.0.0-beta.5, `nuxt-og-image` 6.10.4, `@nuxtjs/sitemap` 8.6.2; composer: doctrine/persistence 4.2.1, google/cloud-storage 2.6.0. Copy `app/package.json`, `app/pnpm-lock.yaml` and `api/composer.lock`. TypeScript stays 6.0.3 (no TS 7 support in `vue-tsc` yet); `@nuxtjs/sitemap` 9 needs the module first. [e5cc3cc](https://github.com/components-web-app/components-web-app/commit/e5cc3cc13ae5b6020fcdc993ad4773ffe8be59cd)

## [2.0.0-alpha.32](https://github.com/components-web-app/components-web-app/releases/tag/v2.0.0-alpha.32) - 2026-10-13

### Upgrade notes
- Update api-components-bundle to 2.0.0-alpha.21 (copy `api/composer.lock`); no migration. Optionally copy `api/tests/Unit/SkolemIriConverterResetTest.php`. A project that read `ResourceMetadataProvider::$metadatas` or `getMetadatas()` must stop: both are removed ([api-components-bundle#449](https://github.com/components-web-app/api-components-bundle/pull/449)). [09f55bd](https://github.com/components-web-app/components-web-app/commit/09f55bd51d63c536443710468ebbdd46dfbc064f) [32c6a7c](https://github.com/components-web-app/components-web-app/commit/32c6a7ceaa6a9ca53b0905313c45de24c5497a35)

### Fixed
- php memory no longer grows request after request in a FrankenPHP worker. API Platform's genid IRI map ([api-platform/core#8680](https://github.com/api-platform/core/issues/8680)) and the bundle's resource metadata map each kept the other's objects alive; api-components-bundle 2.0.0-alpha.21 resets both. Measured over 300 requests to a form component: 41 → 125 MB before, 44.5 → 44.6 MB after (#161). [09f55bd](https://github.com/components-web-app/components-web-app/commit/09f55bd51d63c536443710468ebbdd46dfbc064f) [32c6a7c](https://github.com/components-web-app/components-web-app/commit/32c6a7ceaa6a9ca53b0905313c45de24c5497a35)
- A component on a live routed page is readable anonymously when it is also placed on an unrouted page; it was a 401 (api-components-bundle#447). [09f55bd](https://github.com/components-web-app/components-web-app/commit/09f55bd51d63c536443710468ebbdd46dfbc064f)

### Changed
- `@cwa/nuxt` 2.0.0-alpha.15: a server-side redirect no longer fetches the target page's resources in the background (cwa-nuxt-module#389, #160); the admin's parent page, template, layout and parent page data selects list every item, not just the first 30; a link can pre-fill the add page data form (`?parentPage=`, `?parentPageData=`, `?template=`). [131ef26](https://github.com/components-web-app/components-web-app/commit/131ef26b3429c83cd223a2737fb08b53b5e7a6b0)

## [2.0.0-alpha.31](https://github.com/components-web-app/components-web-app/releases/tag/v2.0.0-alpha.31) - 2026-10-13

### Upgrade notes
- Update api-components-bundle to 2.0.0-alpha.20 (copy `api/composer.lock`); no migration. [6f0c756](https://github.com/components-web-app/components-web-app/commit/6f0c756026f57df58a9eaa64358ffadf4248fd5f)
- Copy `helm/cwa/templates/deployment.yaml`, `helm/cwa/values.yaml` and `bin/devops/k8s.sh` (with the bundle update, which adds the command): a new php pod now warms its `/_api` cache before it takes traffic. `CWA_CI_API_WARM_HTTP_CACHE_MAX_TIME` (seconds, default 60) bounds it; `0` turns it off. No resource requests change (#160). [81c1f35](https://github.com/components-web-app/components-web-app/commit/81c1f355f676c23fb5614e30c0c687f26ec2d7a2)
- GitLab: copy `.gitlab-ci.yml` and `bin/devops/k8s.sh`. The `image variants <track>` and `warm cache <track>` jobs are now one `image variants and warm <track>` job; the `CWA_CI_IMAGE_VARIANTS_*` and `CWA_CI_WARM_CACHE_*` switches are unchanged. A project job that `needs:` either old name must use the new one (#160). [5f987be](https://github.com/components-web-app/components-web-app/commit/5f987be09ccf7ecfda261be61662020f7d72ea67)

### Added
- A new php pod warms the API cache before its probes start: a `postStart` hook waits for Caddy, then runs `warm-http-cache` for up to 60s (`CWA_CI_API_WARM_HTTP_CACHE_MAX_TIME`), never failing the container. With one replica the old pod keeps serving meanwhile, so visitors and monitors no longer meet a cold pod after a deploy or restart (#160). [81c1f35](https://github.com/components-web-app/components-web-app/commit/81c1f355f676c23fb5614e30c0c687f26ec2d7a2)

### Changed
- api-components-bundle 2.0.0-alpha.20: adds `warm-http-cache`; a redirecting route's `resource_manifest` no longer lists its `redirectPath`, so rendering a redirect no longer requests it from the API and gets a 404 (api-components-bundle#444). [6f0c756](https://github.com/components-web-app/components-web-app/commit/6f0c756026f57df58a9eaa64358ffadf4248fd5f)
- `@cwa/nuxt` 2.0.0-alpha.14: a route redirect rendered on the server sends its 308 at once, instead of loading the whole target page first (cwa-nuxt-module#389, #160). [91b583f](https://github.com/components-web-app/components-web-app/commit/91b583f32a1932112d54ba4a147de33351437084)
- GitLab runs the cache warm in the same job as the image variants, straight after them, so new pods are warmed about 50 s sooner after each deploy (a separate job waited for a runner). The order is unchanged: variants first (#153) (#160). [5f987be](https://github.com/components-web-app/components-web-app/commit/5f987be09ccf7ecfda261be61662020f7d72ea67)

## [2.0.0-alpha.30](https://github.com/components-web-app/components-web-app/releases/tag/v2.0.0-alpha.30) - 2026-10-13

### Upgrade notes
- Update api-components-bundle to 2.0.0-alpha.19 (copy `api/composer.lock`) and copy the migration `Version20261013121254`: it makes page data's `title` nullable and clears the old `'Unnamed Page'` default from pages and page data. A page or page data with no title now gets no generated route (`POST /_/routes/generate` is a 422), and a fixture page with no title and no `route:` is left without one ([api-components-bundle#440](https://github.com/components-web-app/api-components-bundle/pull/440)). [e5aaa47](https://github.com/components-web-app/components-web-app/commit/e5aaa47c866994c99a47c11789b99a3e971f9879)
- Optional: delete `import tailwindcss from '@tailwindcss/vite'` and `tailwindcss()` in `vite.plugins` from `app/nuxt.config.ts`; `@nuxt/ui` registers the plugin itself. A project without `@nuxt/ui` keeps both (#159). [e78d6f4](https://github.com/components-web-app/components-web-app/commit/e78d6f44c3f2e2bf49e15e9ef54b07c58c457633)

### Changed
- `@cwa/nuxt` 2.0.0-alpha.13: page titles skip the old `Unnamed Page` default and untitled page data falls back to its page's title (cwa-nuxt-module#388); the admin manager panel stays fixed to the bottom of the viewport whatever the app's CSS (cwa-nuxt-module#387). [b138d14](https://github.com/components-web-app/components-web-app/commit/b138d14c59f506fa3db69399977287be12b2ac48)
- api-components-bundle 2.0.0-alpha.19: page and page data titles default to `null`; renaming a route whose path is 254 or 255 characters no longer 500s; `nested()` fixture content is saved on an `--append` load where nothing else is new. [e5aaa47](https://github.com/components-web-app/components-web-app/commit/e5aaa47c866994c99a47c11789b99a3e971f9879)
- Tailwind's Vite plugin is registered once, by `@nuxt/ui`, not again by the template; the built CSS is unchanged (#159). [e78d6f4](https://github.com/components-web-app/components-web-app/commit/e78d6f44c3f2e2bf49e15e9ef54b07c58c457633)

### Fixed
- `@tailwindcss/vite` is declared in the app's devDependencies: `nuxt.config.ts` imports it, but it was installed only through `@nuxt/ui`, so a project without `@nuxt/ui` failed with a missing module (#158). [67eebe5](https://github.com/components-web-app/components-web-app/commit/67eebe53541fb6f57d7a6d7a30874cb691357bc2)

## [2.0.0-alpha.29](https://github.com/components-web-app/components-web-app/releases/tag/v2.0.0-alpha.29) - 2026-10-13

### Upgrade notes
- Update api-components-bundle to 2.0.0-alpha.18 and `@cwa/nuxt` to 2.0.0-alpha.12 in the same deploy (copy `api/composer.lock`, `app/package.json` and `app/pnpm-lock.yaml`), and copy the migration `Version20261013020000`. The bundle now stores a page's `uiComponent` as the full `CwaPage<Name>`; the migration prefixes existing pages (as the bundle's `prefix-page-ui-components` does, which is then a no-op), and module alpha.12's page admin selects and saves that form (cwa-nuxt-module#384). [33b5410](https://github.com/components-web-app/components-web-app/commit/33b5410ef7fffd0ca4aaff0ac9b03a218804c5c6) [197bce2](https://github.com/components-web-app/components-web-app/commit/197bce2108426f9658d272866e5e146f0b3e6e9b)
- Optional: delete `new Put(...)` and its `use` from `api/src/Entity/User.php`. Nothing in CWA sends it, and bundle alpha.18 already makes a user `PUT` merge instead of replacing. [cd556b1](https://github.com/components-web-app/components-web-app/commit/cd556b1dc6303ba75c98748c193996884ebbf3af)

### Changed
- `@cwa/nuxt` 2.0.0-alpha.12: the page admin saves and selects the full `CwaPage<Name>` UI component (cwa-nuxt-module#384), password-manager logins survive hydration, Nuxt 4.6.1 and `@vueuse/core` 15 (drops Node.js 20). [197bce2](https://github.com/components-web-app/components-web-app/commit/197bce2108426f9658d272866e5e146f0b3e6e9b)
- phpunit 13.4.2 and symfony/mercure-bundle 0.6.1 (publisher tokens' `aud` now includes the internal hub URL; the Caddyfile's `resource_identifier` pin is kept). [9405377](https://github.com/components-web-app/components-web-app/commit/9405377774c061a74ca961ecd513ed2efdf46f40)
- api-components-bundle 2.0.0-alpha.18: an over-long value in any writable `VARCHAR(255)` column, or a generated or cascaded route path over 255 characters, is a 422 instead of a 500; a `PUT` on a user merges into the stored user; `nested()` groups in fixtures are created. [33b5410](https://github.com/components-web-app/components-web-app/commit/33b5410ef7fffd0ca4aaff0ac9b03a218804c5c6)

### Security
- `PUT /_api/users/{id}` is removed (now 405; use `PATCH`): under API Platform 5 a standard PUT reset server-managed user state, un-verifying the email and resetting `createdAt`, and an admin PUT without `@id` blanked the password hash ([api-components-bundle#426](https://github.com/components-web-app/api-components-bundle/issues/426)). [cd556b1](https://github.com/components-web-app/components-web-app/commit/cd556b1dc6303ba75c98748c193996884ebbf3af)

### Fixed
- `NavigationLink::getUrl()`'s `#[Groups]` is read again: it imported `Symfony\Component\Serializer\Annotation\Groups`, which Symfony 8 removed, so the attribute was silently ignored (`url` was still serialized through the bundle's default group) (#156). [f80d489](https://github.com/components-web-app/components-web-app/commit/f80d489461a895079ce6204f46cc07b149a39d7b)

## [2.0.0-alpha.28](https://github.com/components-web-app/components-web-app/releases/tag/v2.0.0-alpha.28) - 2026-10-12

### Upgrade notes
- Update api-components-bundle to 2.0.0-alpha.17 (`composer update components-web-app/api-components-bundle`, or copy `api/composer.lock`) and copy the migration `Version20261012160000`, which drops variant file info written before alpha.17 (api-components-bundle#421); each row is read again from its stored variant on the next render. Nothing to run by hand: the deploy's new API pod starts with an empty cache, and a Cloudflare site's deploy already purges everything. Locally, run `bin/console silverback:api-components:purge-http-cache` after migrating. [c754732](https://github.com/components-web-app/components-web-app/commit/c754732709ae8e6b81967715cdbb93a075a5fcf7) [55e6beb](https://github.com/components-web-app/components-web-app/commit/55e6beb6f660d16e567479159a49557c7c5fbdf6)
- Copy `app/nuxt.config.ts`'s `precompressBuildAssets` helper and the module that calls it, and delete `compressPublicAssets` from its `nitro` block: `/_nuxt` assets are still precompressed, but files in `public/` no longer are, so a large file there no longer adds minutes to every app build (#155). [c9da319](https://github.com/components-web-app/components-web-app/commit/c9da31999e01bd848cd179d03ecd8aa9ac2b186f)

### Fixed
- api-components-bundle 2.0.0-alpha.17: storing an imagine variant again replaces its file info, so `_metadata.mediaObjects` reports the variant actually stored (api-components-bundle#421). [c754732](https://github.com/components-web-app/components-web-app/commit/c754732709ae8e6b81967715cdbb93a075a5fcf7)
- App builds no longer brotli-compress everything in `public/`: only `/_nuxt` assets are precompressed. A 178 MB PDF in `public/` had made a downstream site's app build take ~7 minutes instead of about one (#155). [c9da319](https://github.com/components-web-app/components-web-app/commit/c9da31999e01bd848cd179d03ecd8aa9ac2b186f)

## [2.0.0-alpha.27](https://github.com/components-web-app/components-web-app/releases/tag/v2.0.0-alpha.27) - 2026-10-12

### Upgrade notes
- Copy `helm/cwa/templates/image-variants-cronjob.yaml`, the `cronjobs.imageVariants` block of `helm/cwa/values.yaml` and `bin/devops/k8s.sh`: the image variants job now generates in its own Kubernetes Jobs (#153). It runs on production by default again; set `CWA_CI_IMAGE_VARIANTS_PRODUCTION="false"` to turn it off, and delete a `"true"` you set for alpha.26. [1c4b9f6](https://github.com/components-web-app/components-web-app/commit/1c4b9f6a89ff9a032b41a5548e331b7076d90c8f) [d400d1e](https://github.com/components-web-app/components-web-app/commit/d400d1ea431cf94f80b679c19a2da465ac7c99da) [27141f0](https://github.com/components-web-app/components-web-app/commit/27141f017e7a0348fc721617e8b769930fd8be12)

### Changed
- The image variants job generates in one-off Kubernetes Jobs with their own memory limit (`CWA_CI_IMAGE_VARIANTS_MEMORY`, default 1536Mi), repeating with `--max-memory` until nothing is missing, so it can no longer run the serving API pod out of memory (#153). [1c4b9f6](https://github.com/components-web-app/components-web-app/commit/1c4b9f6a89ff9a032b41a5548e331b7076d90c8f)

## [2.0.0-alpha.26](https://github.com/components-web-app/components-web-app/releases/tag/v2.0.0-alpha.26) - 2026-10-12

### Upgrade notes
- Update api-components-bundle to 2.0.0-alpha.16 (`composer update components-web-app/api-components-bundle`, or copy `api/composer.lock`). No migration, no config change. [30673ac](https://github.com/components-web-app/components-web-app/commit/30673ac2e83a57176a09551c59de415994ec2d07)
- **The `image variants` job is now opt-in on production** (`CWA_CI_IMAGE_VARIANTS_PRODUCTION="true"`). Its first production run ran out of memory in the serving API pod and the site returned 503s (#153). Leave it off on a site with many or large images until it runs as its own Kubernetes Job. Copy `bin/devops/k8s.sh`, `.gitlab-ci.yml` and `.github/workflows/production.yml`. If alpha.25's job already failed on your site there's nothing to undo: missing variants are generated on their first read, as before. [ab86132](https://github.com/components-web-app/components-web-app/commit/ab86132f6f5a0400330ec2ef007e4f0db04ae816)
- **Corrections to alpha.25's upgrade notes:** don't run `imagine:generate` by hand in the API pod of a site with many or large images either (the same out-of-memory risk). And to delete the old variants, remove every file under the bucket's `cache/` folder that doesn't end in `.webp`, which also covers stored names without an extension: `gcloud storage ls "gs://<bucket>/cache/**" | grep -v '\.webp$' | gcloud storage rm -I`. Do it after the alpha.25 deploy, whose purge makes pages render with the WebP variants (#153). [ab86132](https://github.com/components-web-app/components-web-app/commit/ab86132f6f5a0400330ec2ef007e4f0db04ae816)

### Changed
- api-components-bundle 2.0.0-alpha.16: `imagine:generate --limit` and `--max-memory` stop a run with exit 3 while variants are still missing, so it can be re-run in fresh processes until done; `--max-memory` counts libvips's native memory (#153). [30673ac](https://github.com/components-web-app/components-web-app/commit/30673ac2e83a57176a09551c59de415994ec2d07)

### Fixed
- The `image variants` job reports an out-of-memory kill (exit 137) as such, instead of as a failed variant (#153). [ab86132](https://github.com/components-web-app/components-web-app/commit/ab86132f6f5a0400330ec2ef007e4f0db04ae816)

## [2.0.0-alpha.25](https://github.com/components-web-app/components-web-app/releases/tag/v2.0.0-alpha.25) - 2026-10-12

### Upgrade notes
- Update api-components-bundle to 2.0.0-alpha.15 (`composer update components-web-app/api-components-bundle`, or copy `api/composer.lock`). No migration, no config change. A project's own `#[UploadableField]` can override the new bucket `Cache-Control` with `cacheControl:`/`imagineCacheControl:`, or send none with `false`; the defaults suit tokenised uploads (#151). [5e91c95](https://github.com/components-web-app/components-web-app/commit/5e91c95c93f320341f2c8c6e61457054c38b8d2b)
- Copy `api/config/packages/liip_imagine.yaml` (or add `format: webp` and `quality: 80` to each filter set of your own), so every image variant is WebP (#149), and the new post-deploy job: `generate_image_variants` in `bin/devops/k8s.sh` plus the `image variants <track>` jobs and the warm jobs' `needs` in `.gitlab-ci.yml`, or the "Generate image variants" steps in `.github/workflows/ci.yml` and `production.yml` (#152). The next production deploy then generates every image's WebP variants in the API pod and purges the HTTP cache by itself. Without the job, run it by hand after the deploy, in the API pod: `bin/console silverback:api-components:imagine:generate --dry-run` (how many are missing), `bin/console silverback:api-components:imagine:generate` (exit code 1 means a variant failed; `-v` lists which; on a large site `--filter=general` or `--class='App\Entity\Image'` narrows a run), then `bin/console silverback:api-components:purge-http-cache`. [4d36b95](https://github.com/components-web-app/components-web-app/commit/4d36b95cd2d5b55b95d2d44fde65e5bfd4dc2e6a) [eef09ea](https://github.com/components-web-app/components-web-app/commit/eef09ea786f06db0c264ccddc3a6db03f956ad35)
- Then delete the old variants: only the `.png`/`.jpg`/`.jpeg`/`.gif` files under the bucket's `cache/` folder (`liip:imagine:cache:remove` would also delete the new WebP ones). [4d36b95](https://github.com/components-web-app/components-web-app/commit/4d36b95cd2d5b55b95d2d44fde65e5bfd4dc2e6a)
- Then back-fill `Cache-Control` on the files already in the bucket, which keep GCS's one-hour default (only new writes get the header). With gcloud, in this order so variants end with the 30-day value: `gcloud storage objects update "gs://<bucket>/**" --cache-control="public, max-age=31536000, immutable"`, then `gcloud storage objects update "gs://<bucket>/cache/**" --cache-control="public, max-age=2592000"`. A CDN in front of the bucket (the `GCLOUD_PUBLIC_URL` host) keeps its copies until they expire or are purged (#151). [5e91c95](https://github.com/components-web-app/components-web-app/commit/5e91c95c93f320341f2c8c6e61457054c38b8d2b)

### Added
- After each production deploy, a new `image variants` job generates any image variants not stored yet (a new filter, or #149's WebP) in the API pod, before the cache warm, and purges the HTTP cache only if it made any, so visitors' requests no longer generate them. `CWA_CI_IMAGE_VARIANTS_PRODUCTION` is on unless `"false"`; `CWA_CI_IMAGE_VARIANTS_STAGING`, `_REVIEW` and `_CANARY` are off unless `"true"`. A failure never fails the deploy (#152). [eef09ea](https://github.com/components-web-app/components-web-app/commit/eef09ea786f06db0c264ccddc3a6db03f956ad35)

### Changed
- CI image builds keep their whole build cache (`mode=max`), so an app build with an unchanged lockfile skips `pnpm fetch` and the base setup, and a new branch's first build reuses the default branch's cache instead of starting cold. Projects get it by copying `bin/devops/k8s.sh`. [9dd4d2b](https://github.com/components-web-app/components-web-app/commit/9dd4d2bdeff09e1c4cd9f0c75e2697f009a5f5d0)
- @cwa/nuxt 2.0.0-alpha.11: the confirm dialog library, the orphan report requests, the page cache warm reader and the Mercure client no longer load in every visitor's entry, visitors' pages stop preloading admin-only components, and the default OG image's logo is white and no longer cut off. [f5b719d](https://github.com/components-web-app/components-web-app/commit/f5b719d52124d3b8495affeb8d4280ab7bda8a87)
- api-components-bundle 2.0.0-alpha.15: uploads and image variants in the bucket get a long `Cache-Control` (a year for originals, 30 days for variants), and `silverback:api-components:imagine:generate` builds missing variants ahead of time (#151). [5e91c95](https://github.com/components-web-app/components-web-app/commit/5e91c95c93f320341f2c8c6e61457054c38b8d2b)
- Every image variant (`thumbnail`, `general`, `large`) is WebP, whatever the upload's format, so PNG logos and screenshots are no longer served as PNG (a 128 KB logo variant is now 41.5 KB) (#149). [4d36b95](https://github.com/components-web-app/components-web-app/commit/4d36b95cd2d5b55b95d2d44fde65e5bfd4dc2e6a)

### Fixed
- App image builds no longer hang when Alpine's package mirror stalls: `apk add` is time-limited and retried, with a fallback mirror (copy `app/Dockerfile`). [265fa3b](https://github.com/components-web-app/components-web-app/commit/265fa3bc7efd16d0cff924247d9bd157e0cf7af7)

## [2.0.0-alpha.24](https://github.com/components-web-app/components-web-app/releases/tag/v2.0.0-alpha.24) - 2026-10-11

### Upgrade notes
- Copy `helm/cwa/templates/pwa-deployment.yaml` and `helm/cwa/templates/deployment.yaml` (or just their `lifecycle.preStop` blocks) and deploy, to stop 502s during deploys. The first deploy with them still rolls the old pods without the fix; every deploy after it is clean. [4932989](https://github.com/components-web-app/components-web-app/commit/4932989bca167be2102adce72655f14e4523417d)

### Fixed
- Deploys no longer give 502s while pods roll: the PWA holds 5s in a preStop before Nitro closes its listener, and the API's preStop waits 5s instead of 1s, so neither stops serving while it is still an endpoint (#148). [4932989](https://github.com/components-web-app/components-web-app/commit/4932989bca167be2102adce72655f14e4523417d)

## [2.0.0-alpha.23](https://github.com/components-web-app/components-web-app/releases/tag/v2.0.0-alpha.23) - 2026-10-11

### Upgrade notes
- Update api-components-bundle to 2.0.0-alpha.14 (`composer update components-web-app/api-components-bundle`, or copy `api/composer.lock`); no migration. Only a site with AVIF, HEIC or HEIF uploads is affected: their variants are generated again as WebP on first read, and the old `.avif`/`.heic`/`.heif` variant files are left in the bucket unused. To delete them, run `bin/console liip:imagine:cache:remove` in the API pod, which removes every filter's variants, so each image is regenerated on its next read (expect a burst, as after the `large` filter in alpha.22). Leaving them costs only storage. [f238cbe](https://github.com/components-web-app/components-web-app/commit/f238cbe17964c8f667c627217b0afee14d55b19a)

### Added
- The API image also builds Souin's Redis store (go-redis, patched with darkweak/storages#65 so pods sharing Redis purge every page under a tag), ready for scaled mode; nothing uses it yet, and `bin/test/souin-redis-shared-purge.sh` runs in the unit-tests job with a Redis service (#85). [70943ad](https://github.com/components-web-app/components-web-app/commit/70943ad3d95e7fc9eda84708ec3a1d6b0bdd9084)

### Changed
- api-components-bundle 2.0.0-alpha.14: variants of AVIF, HEIC and HEIF originals are WebP (vips can't encode those formats). [f238cbe](https://github.com/components-web-app/components-web-app/commit/f238cbe17964c8f667c627217b0afee14d55b19a)

### Fixed
- An image whose filter fails to generate (a codec the driver lacks, a corrupt file) is served as the original and logged, instead of a 500 for the image and every page containing it; such uploads no longer fail either (api-components-bundle#410). [f238cbe](https://github.com/components-web-app/components-web-app/commit/f238cbe17964c8f667c627217b0afee14d55b19a)
- The `Image` placeholder fades for an image that loaded before hydration, instead of covering it (#146). [fc67690](https://github.com/components-web-app/components-web-app/commit/fc67690a353c7ceee6b8184eedf92b8e29f37f80)

## [2.0.0-alpha.22](https://github.com/components-web-app/components-web-app/releases/tag/v2.0.0-alpha.22) - 2026-10-11

### Upgrade notes
- Update @cwa/nuxt to 2.0.0-alpha.10 and api-components-bundle to 2.0.0-alpha.13 in the same deploy: the module's "Publish now" sends `publishedAt: "now"`, which older bundles refuse. [5766b27](https://github.com/components-web-app/components-web-app/commit/5766b27554c931f0a2c4ccda27c1799dff52f369)
- The new `large` imagine filter is generated for each existing image the first time it's read without one, so expect a burst of generation after the deploy. A project with its own image fields adds `'large'` to their `imagineFilters` to get the same `srcset`. [1af82fa](https://github.com/components-web-app/components-web-app/commit/1af82fafc23b07ef40aa82c349e56e73e6c09500)

### Added
- The `Image` component serves a responsive `srcset` (the module's, from 2.0.0-alpha.10) with `sizes`, and a `large` filter (2400 px) so retina screens don't fetch the original upload. [1af82fa](https://github.com/components-web-app/components-web-app/commit/1af82fafc23b07ef40aa82c349e56e73e6c09500)

### Changed
- @cwa/nuxt 2.0.0-alpha.10: "Publish now" publishes by the API's clock (needs bundle 2.0.0-alpha.13, so update both together), `srcset` on `useCwaFile`/`withFile`/`useCwaFileField`, and admin fixes. [5766b27](https://github.com/components-web-app/components-web-app/commit/5766b27554c931f0a2c4ccda27c1799dff52f369)
- api-components-bundle 2.0.0-alpha.13: imagine variants with a `format` get that format's extension, an upload is stored with its content's extension, `publishedAt: "now"` publishes by the server's clock, and `liip:imagine:cache:remove` no longer throws. [82ae211](https://github.com/components-web-app/components-web-app/commit/82ae211d18d27cd8d08fb9eb892d3ccaeed5004b)
- Cached pages are stored compressed: the cache sits outside `encode` and keys on `Accept-Encoding` normalised to br, gzip or none, so a hit is never recompressed (brotli capped a php pod at ~110 page views/s); zstd is no longer offered (#145). [3add461](https://github.com/components-web-app/components-web-app/commit/3add4619edd1e7949b3baadc09e3a8abbe9a942a)

## [2.0.0-alpha.21](https://github.com/components-web-app/components-web-app/releases/tag/v2.0.0-alpha.21) - 2026-10-10

### Upgrade notes
- Remove every `generate_jwt_keys` line from your `.gitlab-ci.yml` and GitHub workflows: `deploy` now handles the secrets itself, and the function is gone. On GitHub, map an optional `APP_SECRET` secret into the deploy jobs as the template does. [816997e](https://github.com/components-web-app/components-web-app/commit/816997eaebb7cfb167172e38065042ee5a42f710)

### Fixed
- Deploys keep `APP_SECRET`, `MERCURE_JWT_SECRET` and the JWT key pair from the live Secret instead of generating new ones, so logins, signed URLs and Mercure cookies survive a deploy; `APP_SECRET` can now be set as a CI variable (#144). [816997e](https://github.com/components-web-app/components-web-app/commit/816997eaebb7cfb167172e38065042ee5a42f710)

## [2.0.0-alpha.20](https://github.com/components-web-app/components-web-app/releases/tag/v2.0.0-alpha.20) - 2026-10-10

### Upgrade notes
- Copy `liip_imagine.yaml`, `api/src/Entity/Image.php` and the `Image` component (`app/app/cwa/components/Image/Image.vue`). No regenerate step: each existing image gets its `general` file on the first read after the deploy (about 0.2 s for 12 MP, up to 1 s for a 30 MP PNG, within the imagine budget), and the deploy's cache warm usually does that. Existing thumbnails keep their old, bigger encoding; delete the bucket's `cache/thumbnail/` folder to have them re-encoded the same way. A published image with no file is left as it is until it is next published or edited. ([#143](https://github.com/components-web-app/components-web-app/issues/143), [de6075a](https://github.com/components-web-app/components-web-app/commit/de6075a46ec1c1d81f6dce7dff349b919f8cc465))
- **Lower your image upload caps to fit the memory budget:** set `Assert\Image(maxPixels: …)` on `Image::$file`, and on any other uploadable image field your project adds, to **30 MP** with the vips driver or **20 MP** if you stay on GD (was 40 MP). Larger images no longer fit the 320M imagine budget: they'd be stored with no thumbnails (the original served, a warning logged). The module downscales above 20 MP in the browser, so this mainly affects direct API uploads. ([#136](https://github.com/components-web-app/components-web-app/issues/136), [#141](https://github.com/components-web-app/components-web-app/issues/141))
- Imagine now uses libvips: copy `api/Dockerfile` (libvips, `ffi`, the `VIPS_*`/`MALLOC_*` ENVs), `conf.d/10-app.ini` and `20-app.dev.ini`, `api/config/preload.php` and `preload_vips.php`, `liip_imagine.yaml`, and `composer require rokka/imagine-vips jcupitt/vips:^2.6 ext-ffi:*`; rebuild the dev php image. Keep `preload_vips.php` while the driver is vips, or concurrent uploads segfault in worker mode. ([#141](https://github.com/components-web-app/components-web-app/issues/141), [8255e8c](https://github.com/components-web-app/components-web-app/commit/8255e8c72529a20dcd0d5106a5fa1cf7cb9b97f4))
- Bundle 2.0.0-alpha.12: take the migration `Version20261010134316`. It does what `silverback:api-components:deduplicate-file-info` does (originals get an empty filter, duplicate file-info rows are removed) before adding the unique `(path, filter)` index, so no manual step is needed; running the command first is harmless. Remove any `imagine.memory_limit: 320M` you copied from the template: it's now the bundle's default. With GD, sources over about 23 MP get no thumbnails (the original is served and a warning logged). ([11e5c7a](https://github.com/components-web-app/components-web-app/commit/11e5c7a74af4e0d7668a071462f8ed9a39923b5a))
- Copy `api/frankenphp/Caddyfile`, `conf.d/10-app.ini`, `api/config/packages/silverback_api_components.yaml` (`imagine.memory_limit`, needs bundle 2.0.0-alpha.11), `api/src/Entity/Image.php`, `bin/devops/k8s.sh` and the chart's `values.yaml`, `_helpers.tpl` and `deployment.yaml`. Replace a `CWA_API_FRANKENPHP_WORKER_NUM` CI variable with `CWA_CI_API_WORKERS` (deploys now refuse it), and check the budget fits any `CWA_CI_API_MEMORY_LIMIT` you set. ([#136](https://github.com/components-web-app/components-web-app/issues/136), [1868035](https://github.com/components-web-app/components-web-app/commit/1868035b41a4edd48d42b84c2de736026c8f5ce6))
- Bundle 2.0.0-alpha.11 adds `invalid_files` to `_acb_orphaned_file_report`: take the migration `Version20261010125853` (existing report rows get `[]`). ([84de158](https://github.com/components-web-app/components-web-app/commit/84de158ea8e8054b10714717028a56f549075e9f))
- Delete any `NUXT_SITE_URL` CI variable: deploys now set it to `https://$DOMAIN` and refuse a CI variable of that name. ([#140](https://github.com/components-web-app/components-web-app/issues/140), [45a3794](https://github.com/components-web-app/components-web-app/commit/45a379404852fc164b15f706d0aac3479c61b6ab))
- Copy `api/frankenphp/souin/v1.7.9-singleflight-5xx.patch` with its `COPY` and `patch` lines in `api/Dockerfile` (after the singleflight patch), and `bin/test/souin-coalesced-5xx.sh` with its line in the unit-tests job. ([#137](https://github.com/components-web-app/components-web-app/issues/137), [6df1b15](https://github.com/components-web-app/components-web-app/commit/6df1b15050970bbc45e8348d10d0a9787477365c))
- The per-visitor rate limit needs the ingress to keep the client address (`externalTrafficPolicy: Local`); the GKE cluster's controller now does, with 2 replicas and a PDB. A project on another cluster must set the same, or the limit never applies. ([#135](https://github.com/components-web-app/components-web-app/issues/135), [85f9c28](https://github.com/components-web-app/components-web-app/commit/85f9c286d7fc0da9610a3764623baa4f51c28800))

### Fixed
- `create-cwa`: declining fixtures removes only the sample content (`AppScaffold.php`, `Parts/`) and keeps `UsersFixture.php`, so `doctrine:fixtures:load` (and the deploy's fixtures job) still creates the admin from `ADMIN_*`. The README and closing message say so. ([#142](https://github.com/components-web-app/components-web-app/issues/142), [bc55a2f](https://github.com/components-web-app/components-web-app/commit/bc55a2fe539379c1e7b2b57e5b7aead5033aba12))
- Cached pages' canonical URL and `og:url` use the site's host, not whichever host rendered the page: deploys set `NUXT_SITE_URL` from `DOMAIN` (so `project.sh` sites and staging get their own). ([#140](https://github.com/components-web-app/components-web-app/issues/140), [45a3794](https://github.com/components-web-app/components-web-app/commit/45a379404852fc164b15f706d0aac3479c61b6ab))
- `PURGE`/`BAN` sent to the site return 405 instead of a misleading 200 (they never purged anything; the `CACHE_ACL` clause they passed through was unreachable and is gone). Purge one page by tag through Souin's admin API; see CLAUDE.md. ([#138](https://github.com/components-web-app/components-web-app/issues/138), [1c87cc0](https://github.com/components-web-app/components-web-app/commit/1c87cc0e0ea92b26c16bb846df36b5e659ca8f93))
- Requests Souin coalesces onto an upstream 5xx get that 5xx instead of an empty 200 (a new Souin patch, `v1.7.9-singleflight-5xx.patch`). ([#137](https://github.com/components-web-app/components-web-app/issues/137), [6df1b15](https://github.com/components-web-app/components-web-app/commit/6df1b15050970bbc45e8348d10d0a9787477365c))

### Changed
- Images: a `general` filter (1200 px) that the `Image` component renders (it showed the 500 px thumbnail, at most 300 px wide); filters encode JPEG at quality 82 (was 90) and PNG at level 9 (was 0, uncompressed), so a 12 MP photo's display file is 91 KB, not 172 KB; publishing an image without a file is refused (`requiredOnPublish`). ([#143](https://github.com/components-web-app/components-web-app/issues/143), [de6075a](https://github.com/components-web-app/components-web-app/commit/de6075a46ec1c1d81f6dce7dff349b919f8cc465))
- `app/.dockerignore` also leaves out local env files (`.env`, `.env.local`, `.env.*.local`, which `nuxt build` would read), `.pnpm-store/`, `node-compile-cache/`, logs, OS files, the Dockerfile and compose files, so local builds match CI's. ([#139](https://github.com/components-web-app/components-web-app/issues/139), [2e2ae16](https://github.com/components-web-app/components-web-app/commit/2e2ae160dee8e8834dc99038062b9004b494a369))
- The imagine driver is libvips (FFI, `ffi.enable = true`, untrusted loaders blocked) instead of GD: a 12 MP thumbnail takes ~200 ms and ~50 MB instead of ~320 ms and 140 MB, and large originals no longer exhaust `memory_limit`. Image uploads are accepted up to 30 MP. `driver: gd` in `liip_imagine.yaml` switches back (then lower the cap to 20 MP). ([#141](https://github.com/components-web-app/components-web-app/issues/141), [8255e8c](https://github.com/components-web-app/components-web-app/commit/8255e8c72529a20dcd0d5106a5fa1cf7cb9b97f4), [903b0a3](https://github.com/components-web-app/components-web-app/commit/903b0a3d06bcb93d838382ff1fb7d2e82a3eb873))
- `.gitignore` ignores `.claude` (Claude Code's local settings and worktrees). ([3cd1e20](https://github.com/components-web-app/components-web-app/commit/3cd1e20f4e3e80a057d52ab5fc527141c13f9b7c))
- `@cwa/nuxt` 2.0.0-alpha.9 (admin): reordering applies once per move even if a component group is mounted twice; the orphaned files page shows invalid files (needs bundle 2.0.0-alpha.11+); a failed background refresh no longer turns on-screen components into error notices; the Info tab's delete button says Delete Draft / Delete Live. ([fc37313](https://github.com/components-web-app/components-web-app/commit/fc37313f933c6b101fe67ed100349107b91f03c9))
- Bundle 2.0.0-alpha.12: a unique index on imagine file info, and `imagine.memory_limit` defaults to 320M, so the template no longer sets it. ([11e5c7a](https://github.com/components-web-app/components-web-app/commit/11e5c7a74af4e0d7668a071462f8ed9a39923b5a))
- php requests run under `memory_limit` 128M (`FRANKENPHP_MEMORY_LIMIT`; console commands 256M), imagine filters under 320M, and `GOMEMLIMIT` is what that budget leaves Go (160MiB of 1Gi) instead of 80% of the limit. `values.yaml` states the budget; `CWA_CI_API_WORKERS`, `CWA_CI_API_PHP_MEMORY_LIMIT`, `CWA_CI_API_IMAGINE_MEMORY_LIMIT` and `CWA_CI_API_RESERVED_MEMORY` set it, and the deploy fails before the cluster when it doesn't fit. ([#136](https://github.com/components-web-app/components-web-app/issues/136), [1868035](https://github.com/components-web-app/components-web-app/commit/1868035b41a4edd48d42b84c2de736026c8f5ce6))
- `Image::$file` accepts up to 30 MP (was 40): what the 320M imagine budget can thumbnail with vips (20 MP with GD). ([#136](https://github.com/components-web-app/components-web-app/issues/136), [1868035](https://github.com/components-web-app/components-web-app/commit/1868035b41a4edd48d42b84c2de736026c8f5ce6))
- Bundle 2.0.0-alpha.11: imagine filters are generated within a memory budget (oversized ones skipped, not fatal), uploadables no longer save `NULL` filenames, the orphan report lists invalid files, and `purge-http-cache --path`/`--tag` purge one page or tag. ([84de158](https://github.com/components-web-app/components-web-app/commit/84de158ea8e8054b10714717028a56f549075e9f))

## [2.0.0-alpha.19](https://github.com/components-web-app/components-web-app/releases/tag/v2.0.0-alpha.19) - 2026-10-10

### Upgrade notes
- Copy `bin/devops/setup.sh`, `k8s.sh`, the warm cache and performance audit jobs in `.gitlab-ci.yml` (they pass no URL now) and, on GitHub, `performance-audit.yml`. A deploy job with neither an environment url nor a `DOMAIN` now fails instead of deploying to `test-domain.com`. ([#132](https://github.com/components-web-app/components-web-app/issues/132), [#134](https://github.com/components-web-app/components-web-app/issues/134), [7b26140](https://github.com/components-web-app/components-web-app/commit/7b26140895c524ad5083e48470883bffd99d3410))

### Changed
- The bundle's `website_name` (the name in emails) comes from `WEBSITE_NAME`, default `New Website` in `api/.env`; set `CWA_API_WEBSITE_NAME` on deploys, or export it per site from `bin/devops/project.sh`. ([GitLab #6](https://gitlab.com/silverback-web-apps/cwa/components-web-app/-/issues/6), [c1a3201](https://github.com/components-web-app/components-web-app/commit/c1a3201e24378ef54e7bd64393110bb6b1a0cfce))

### Added
- `bin/devops/project.sh` can add reserved names (ones its own chart values set) with `SITE_ENV_RESERVED_API_EXTRA` / `SITE_ENV_RESERVED_PWA_EXTRA`. ([#133](https://github.com/components-web-app/components-web-app/issues/133), [7b26140](https://github.com/components-web-app/components-web-app/commit/7b26140895c524ad5083e48470883bffd99d3410))

### Fixed
- `.gitlab-ci.yml` loses comments the comment trim left pointing at nothing. ([a628710](https://github.com/components-web-app/components-web-app/commit/a6287100e0c3b9dee2330c6590c07c5f6d2cee7c))
- The warm cache and performance audit use `https://$DOMAIN`, so they follow a `DOMAIN` set in `project.sh`. ([#132](https://github.com/components-web-app/components-web-app/issues/132), [7b26140](https://github.com/components-web-app/components-web-app/commit/7b26140895c524ad5083e48470883bffd99d3410))
- `check_kube_domain` can fail: no `test-domain.com` fallback, and an empty `DOMAIN` or one with a leading or trailing dot (an empty `KUBE_INGRESS_BASE_DOMAIN`) stops the deploy. ([#134](https://github.com/components-web-app/components-web-app/issues/134), [7b26140](https://github.com/components-web-app/components-web-app/commit/7b26140895c524ad5083e48470883bffd99d3410))

## [2.0.0-alpha.18](https://github.com/components-web-app/components-web-app/releases/tag/v2.0.0-alpha.18) - 2026-10-10

### Changed
- Bundle 2.0.0-alpha.10, `symfony/mercure-bundle` 0.6 and `symfony/mercure` 0.9 ([api-components-bundle#384](https://github.com/components-web-app/api-components-bundle/issues/384)). `mercure.yaml` pins `cookie_name: '__Secure-mercure_access_token'`: mercure-bundle 0.6 drops the prefix when `kernel.debug` is on, and the hub wouldn't read it. ([b71fd4d](https://github.com/components-web-app/components-web-app/commit/b71fd4d1f6193ab6c80fd05c07a9cb3e576414fe))
- Comments are one or two lines; the reasoning lives in issues, this changelog and CLAUDE.md. Comment lines only, so downstream copies can take the files as they are. ([#131](https://github.com/components-web-app/components-web-app/issues/131), [5f81e4c](https://github.com/components-web-app/components-web-app/commit/5f81e4c6b80fc68f98f6e5464dbac52ce612e65e), [42b2163](https://github.com/components-web-app/components-web-app/commit/42b21638d481b87918959f85a83af4716a432f4e), [f7dfc96](https://github.com/components-web-app/components-web-app/commit/f7dfc9646db57f8c6a2bbe3dbbaf23147aa65fb5), [ac49bda](https://github.com/components-web-app/components-web-app/commit/ac49bda4657cc4ecf17bd3f53a1729e9af61fc6c), [90ca38d](https://github.com/components-web-app/components-web-app/commit/90ca38d75185d37aa47c90e5d5d587428ad13131), [a76d7a4](https://github.com/components-web-app/components-web-app/commit/a76d7a4f5e2073aae835908c17d7d5f14f9ce316))
- API Platform 5.0.3, Doctrine ORM 3.7.5, liip/imagine-bundle 2.18.1, Nuxt 4.6.1, satori 0.47 (for nuxt-og-image), `@nuxt/devtools` 4.0.0-beta.4 and patch updates. ([30ef432](https://github.com/components-web-app/components-web-app/commit/30ef432becfe328d9c57357aecf2fbca1005974b))

### Added
- Load test: `page_views` (a page load or a client-side navigation), the resource manifest's resources fetched on each navigation (`MAX_RESOURCES`, default 20), a Cloudflare `cf-cache-status` line, `RANDOM_SEED` for repeatable runs, and `ORIGIN_IP` to measure the origin without the CDN. ([!13](https://gitlab.com/silverback-web-apps/cwa/components-web-app/-/merge_requests/13))
- Deploy hooks, so a project keeps `bin/devops/setup.sh` and `k8s.sh` unedited: an optional `bin/devops/project.sh` (sourced by `setup.sh`; it can set `DOMAIN` and site settings) and its `project_values <track>` (chart values, applied last). `check_kube_domain` and `persist_environment_url` work from `DOMAIN`, and the latter also writes `environment_url.env` (`SITE_ENVIRONMENT_URL`). ([!14](https://gitlab.com/silverback-web-apps/cwa/components-web-app/-/merge_requests/14))

## [2.0.0-alpha.17](https://github.com/components-web-app/components-web-app/releases/tag/v2.0.0-alpha.17) - 2026-10-09

### Upgrade notes
- Copy `run_test_functional` again: it unsets `JWT_SECRET_KEY`, `JWT_PUBLIC_KEY` and `JWT_PASSPHRASE`, whose CI values (key contents) failed the functional tests and printed the encrypted key in the log. If that happened, erase the job log, or rotate the keypair. ([#130](https://github.com/components-web-app/components-web-app/issues/130), [c1d2581](https://github.com/components-web-app/components-web-app/commit/c1d2581a2c1478d618765474b5d5808857b98868))

## [2.0.0-alpha.16](https://github.com/components-web-app/components-web-app/releases/tag/v2.0.0-alpha.16) - 2026-10-09

### Upgrade notes
- **Rename your CI variables before or with the next deploy: the old names are no longer read.** ([3a4ab9a](https://github.com/components-web-app/components-web-app/commit/3a4ab9a2996c7b2639c93fa3f2afd9d90c157185), [1960c43](https://github.com/components-web-app/components-web-app/commit/1960c431e3688591ce1d87e5f11d6ffdb541c9c4), [151fa6f](https://github.com/components-web-app/components-web-app/commit/151fa6fb4e46b62fe711783f7f078f4064183d64), [d64c278](https://github.com/components-web-app/components-web-app/commit/d64c278997770b07fb0c2d04ed2fa7383059ab03))
  - `CWA_CI_` + the same name: `BUILD_DISABLED`, `TEST_DISABLED`, `REVIEW_DISABLED`, `STAGING_ENABLED`, `CANARY_ENABLED`, `FIXTURES_PURGE`, `RESET_DATABASE`, `HELM_UNINSTALL`, `DEPLOYMENT_BRANCH`, `TRACE`, `INGRESS_ENABLED`, `CLUSTER_ISSUER`, `TLS_CERTIFICATE_TIMEOUT`, `INGRESS_RATE_LIMIT_*`, `PWA_*` (sizing), `ORPHAN_SCAN*`, `WARM_CACHE_*`, `PERFORMANCE_AUDIT_*`.
  - `CWA_CI_API_` + the same name: `REPLICA_COUNT`, `AUTOSCALE`, `AUTOSCALE_*`.
  - `PHP_CPU_REQUEST`, `PHP_MEMORY_REQUEST`, `PHP_MEMORY_LIMIT`, `PHP_GOMEMLIMIT` → `CWA_CI_API_CPU_REQUEST`, `_MEMORY_REQUEST`, `_MEMORY_LIMIT`, `_GOMEMLIMIT`.
  - `PRODUCTION_API_DISABLED` → `CWA_CI_PRODUCTION_DISABLED`, `CI_DISABLED` (GitHub) → `CWA_CI_DISABLED`, `ENABLE_DATABASE_FIXTURES` → `CWA_CI_FIXTURES_ENABLED`, `LETSENCRYPT_SECRET_NAME` → `CWA_CI_TLS_SECRET_NAME`, `KUBE_INGRESS_WWW_REDIRECT` → `CWA_CI_WWW_REDIRECT`, `DATABASE_IMAGE_TAG` → `CWA_CI_POSTGRES_IMAGE_TAG`, `POSTGRESQL_ENABLED` → `CWA_CI_POSTGRES_ENABLED`.
  - `CWA_API_` + the same name: `CACHE_QUERY_ALLOWLIST`, `CADDY_TRUSTED_PROXIES`, `CLOUDFLARE_IP_RANGES`, `RATE_LIMIT_*`, `FRANKENPHP_MAX_WAIT_TIME`, `CLOUDFLARE_PURGE_*`, `CADDY_GLOBAL_CONFIG`, `JWT_COOKIE_SAMESITE`, `MERCURE_JWT_ALGORITHM`.
- Copy `run_test_functional` from `bin/devops/k8s.sh` **and** add `MAILER_DSN=null://null` to `api/.env.test`: the job unsets `MAILER_DSN` and `MAILER_EMAIL` so a test that sends email can't deliver it through your live relay (every CI variable reaches the test job and beats `api/.env.test`), and the null transport stops it falling back to `.env`'s `smtp-relay`, which CI doesn't have. ([!12](https://gitlab.com/silverback-web-apps/cwa/components-web-app/-/merge_requests/12), [#123](https://github.com/components-web-app/components-web-app/issues/123))
- Optional: add a `GITHUB_TOKEN` CI variable (a fine-grained token with no permissions is enough) and copy the composer step from `api/Dockerfile`, `build_api` from `bin/devops/k8s.sh`, the `COMPOSER_AUTH` block at the end of `bin/devops/setup.sh` and the build step's `GITHUB_TOKEN` in `.github/workflows/ci.yml`, so composer installs stop failing on GitHub's anonymous rate limit. Without the token nothing changes. ([!12](https://gitlab.com/silverback-web-apps/cwa/components-web-app/-/merge_requests/12), [#123](https://github.com/components-web-app/components-web-app/issues/123))
- Delete a `VARNISH_TOKEN` CI variable if you have one: nothing reads it any more. ([!12](https://gitlab.com/silverback-web-apps/cwa/components-web-app/-/merge_requests/12), [#123](https://github.com/components-web-app/components-web-app/issues/123))
- Delete any `NUXT_CWA_API_URL`, `NUXT_PUBLIC_CWA_API_URL`, `NUXT_PUBLIC_CWA_API_URL_BROWSER` or `NUXT_PUBLIC_CWA_ENVIRONMENT` CI variable: the deploy now fails on names the chart sets. Copy `bin/devops/k8s.sh`, the chart and, on GitHub, `github-export-secrets.sh` with its step; move site settings from build args to runtime env. ([#125](https://github.com/components-web-app/components-web-app/issues/125)) ([497e8ac](https://github.com/components-web-app/components-web-app/commit/497e8ac74cf3ba8b066982df0192bff238abd906))
- Rename `POSTGRES_USERNAME` to `POSTGRES_USER`. `POSTGRES_USER`/`_PASSWORD`/`_DB` now take effect in-cluster (it always ran as `example` / `!ChangeMe!` / `api`): if you set them, a new user or database restarts PostgreSQL empty, and a new password alone needs `kubectl delete pod <release>-postgresql-0`. ([e15f168](https://github.com/components-web-app/components-web-app/commit/e15f16818a61f9a3f68697808bea5998bf34b0dc))
- Fix the seeded layout once (fixtures keep existing rows): set the `main` layout's UI component to `CwaLayoutPrimary` in the admin, or `UPDATE _acb_layout SET ui_component = 'CwaLayoutPrimary' WHERE ui_component = 'CwaLayoutCwaLayoutPrimary';` then `bin/console silverback:api-components:purge-http-cache`. ([#126](https://github.com/components-web-app/components-web-app/issues/126), [6c0b9d8](https://github.com/components-web-app/components-web-app/commit/6c0b9d8514e64ea42e4162eeeda8f50dbb582ce3))

### Added
- Site settings without template edits: `NUXT_*` CI variables reach the PWA, `CWA_API_<NAME>` the API as `<NAME>`, through `envFrom`. ([#125](https://github.com/components-web-app/components-web-app/issues/125)) ([497e8ac](https://github.com/components-web-app/components-web-app/commit/497e8ac74cf3ba8b066982df0192bff238abd906))
- `CWA_ENVIRONMENT` / `NUXT_PUBLIC_CWA_ENVIRONMENT` name the environment from the deploy's track. ([#125](https://github.com/components-web-app/components-web-app/issues/125)) ([497e8ac](https://github.com/components-web-app/components-web-app/commit/497e8ac74cf3ba8b066982df0192bff238abd906))
- GitHub deploys export `NUXT_*` and `CWA_API_*` secrets, masked, without a workflow edit per secret. ([#125](https://github.com/components-web-app/components-web-app/issues/125)) ([75a416b](https://github.com/components-web-app/components-web-app/commit/75a416bc14edcdd601918bf44fa291f391abcbcf))
- Composer authenticates to github.com with an optional `GITHUB_TOKEN`, passed to the API build as a build secret, with at most 6 parallel downloads. ([!12](https://gitlab.com/silverback-web-apps/cwa/components-web-app/-/merge_requests/12), [#123](https://github.com/components-web-app/components-web-app/issues/123))
- Optional in-cluster PostgreSQL persistence (`CWA_CI_POSTGRES_PERSISTENCE`, `_PERSISTENCE_SIZE`, `CWA_CI_POSTGRES_STORAGE_CLASS`). A deploy that would change a live volume stops first and says what to run; review cleanup deletes the review volume. ([7675190](https://github.com/components-web-app/components-web-app/commit/767519054d9b8473a42eb30144ea6eaeae65d39a))

### Changed
- The template's CI settings are `CWA_CI_*`. ([3a4ab9a](https://github.com/components-web-app/components-web-app/commit/3a4ab9a2996c7b2639c93fa3f2afd9d90c157185), [1960c43](https://github.com/components-web-app/components-web-app/commit/1960c431e3688591ce1d87e5f11d6ffdb541c9c4), [151fa6f](https://github.com/components-web-app/components-web-app/commit/151fa6fb4e46b62fe711783f7f078f4064183d64))
- The API's optional runtime settings are set as `CWA_API_*` through the passthrough instead of their own chart wiring; an empty `CWA_API_` value is left out. ([d64c278](https://github.com/components-web-app/components-web-app/commit/d64c278997770b07fb0c2d04ed2fa7383059ab03))
- A canary release's SSR minimum defaults to 1 pod (production keeps 2). ([#124](https://github.com/components-web-app/components-web-app/issues/124), [095c074](https://github.com/components-web-app/components-web-app/commit/095c074eba4a660412fad08c74a6415c11591115))

### Fixed
- The fixtures seed the layout as `CwaLayoutPrimary` (was `CwaLayoutCwaLayoutPrimary`), so pages render through `primary.vue`. ([#126](https://github.com/components-web-app/components-web-app/issues/126), [6c0b9d8](https://github.com/components-web-app/components-web-app/commit/6c0b9d8514e64ea42e4162eeeda8f50dbb582ce3))
- A `create-cwa` project without fixtures no longer keeps fixture classes that reference deleted ones; the fixtures wire themselves with attributes. ([#127](https://github.com/components-web-app/components-web-app/issues/127), [78478ed](https://github.com/components-web-app/components-web-app/commit/78478ed90647a427646e9305057bb6b8b78a0fd2))
- GitLab creates the `main` pipeline with production switched off and fixtures on. ([e7d1be3](https://github.com/components-web-app/components-web-app/commit/e7d1be335105348503aaf74e0407598756d34760))
- A downstream functional test that sends email no longer reaches the live mail relay (`.env.test` uses the null transport), and tests that sign in get a JWT keypair. ([!12](https://gitlab.com/silverback-web-apps/cwa/components-web-app/-/merge_requests/12), [#123](https://github.com/components-web-app/components-web-app/issues/123))
- The registry pull secret is applied rather than replaced with `--force`, so releases that share a namespace don't race ("already exists"). The first deploy after this prints a harmless one-off warning about a missing `last-applied-configuration` annotation. ([!12](https://gitlab.com/silverback-web-apps/cwa/components-web-app/-/merge_requests/12), [#123](https://github.com/components-web-app/components-web-app/issues/123))
- `helm lint` and `helm template` work on the chart's own defaults: `jwt-passphrase` defaults to `""` instead of failing `b64enc`. ([!12](https://gitlab.com/silverback-web-apps/cwa/components-web-app/-/merge_requests/12), [#123](https://github.com/components-web-app/components-web-app/issues/123))
- Release steps tag with `--cleanup=verbatim`, so a tag message keeps the changelog's `###` headings. ([56f3065](https://github.com/components-web-app/components-web-app/commit/56f3065abea729f33375ee5db664510114fed341))
- `POSTGRES_USER`/`_PASSWORD`/`_DB` reach the in-cluster PostgreSQL and its `database-url`, now percent-encoded. ([e15f168](https://github.com/components-web-app/components-web-app/commit/e15f16818a61f9a3f68697808bea5998bf34b0dc))
- A `KUBERNETES_VERSION` or `HELM_VERSION` CI variable is honoured on GitLab, as on GitHub; `setup.sh` used to overwrite it. ([13243ae](https://github.com/components-web-app/components-web-app/commit/13243aea131252dd9be88174b9d57a5b35a44864))

### Removed
- `apiSecretToken` (`VARNISH_TOKEN`), which nothing in the chart read. ([!12](https://gitlab.com/silverback-web-apps/cwa/components-web-app/-/merge_requests/12), [#123](https://github.com/components-web-app/components-web-app/issues/123))

## [2.0.0-alpha.15](https://github.com/components-web-app/components-web-app/releases/tag/v2.0.0-alpha.15) - 2026-10-08

Since [v2.0.0-alpha.14](https://github.com/components-web-app/components-web-app/releases/tag/v2.0.0-alpha.14).

### Upgrade notes
- Update `components-web-app/api-components-bundle` to 2.0.0-alpha.9 and `@cwa/nuxt` to 2.0.0-alpha.8 **together**, and add the migration for the new `is_reachable_without_route` column on `_acb_page` and `_acb_abstract_page_data` (generate your own with `doctrine:migrations:diff`, or copy `Version20261008121224.php` if your schema matches the template's). The module's toggle needs the bundle's column. ([d1849ab](https://github.com/components-web-app/components-web-app/commit/d1849abb898385590190d470a883c22ff62018fb), [cca6db5](https://github.com/components-web-app/components-web-app/commit/cca6db54b842e47328c78deb96f455e8ceea7064))
- Migrations are upward-only: delete `down()` from your migrations, including new ones, so a rollback aborts instead of dropping data. ([3fbfb4e](https://github.com/components-web-app/components-web-app/commit/3fbfb4e142d6a7f20714843ff24c45e1b43c6ffc))

### Added
- Pages and page data have a **Public without a route** admin toggle (bundle `isReachableWithoutRoute`): a routeless page loaded by a custom fetch IRI, such as a share link, can be read by visitors (api-components-bundle#381, cwa-nuxt-module#369). ([d1849ab](https://github.com/components-web-app/components-web-app/commit/d1849abb898385590190d470a883c22ff62018fb), [cca6db5](https://github.com/components-web-app/components-web-app/commit/cca6db54b842e47328c78deb96f455e8ceea7064))

### Removed
- Every migration's `down()`; Doctrine's inherited one aborts. ([3fbfb4e](https://github.com/components-web-app/components-web-app/commit/3fbfb4e142d6a7f20714843ff24c45e1b43c6ffc))

## [2.0.0-alpha.14](https://github.com/components-web-app/components-web-app/releases/tag/v2.0.0-alpha.14) - 2026-10-08

Since [v2.0.0-alpha.13](https://github.com/components-web-app/components-web-app/releases/tag/v2.0.0-alpha.13).

### Upgrade notes
- **Production certificates are opt-in again:** with no `CLUSTER_ISSUER` variable, deploys use `letsencrypt-staging` (as before alpha.11). Every production site must set `CLUSTER_ISSUER=letsencrypt-prod`; alpha.12's advice that it could be deleted is withdrawn. Check it exists **before** syncing `bin/devops/setup.sh`. ([5f3f785](https://github.com/components-web-app/components-web-app/commit/5f3f78521fca025b9d6f9f0fdb8132cbb679b92d))
- Replace alpha.13's `routeRules` `/sw.js` block with `registerWebManifestInRouteRules: true` in the `pwa` block of `app/nuxt.config.ts`. ([e4ebb26](https://github.com/components-web-app/components-web-app/commit/e4ebb264617e5013ff4b5a70d477c27edd451209))

### Changed
- An unset `CLUSTER_ISSUER` gives `letsencrypt-staging`, so a misconfigured domain fails against the staging issuer's limits rather than production's; an explicit empty value still turns cert-manager off. ([5f3f785](https://github.com/components-web-app/components-web-app/commit/5f3f78521fca025b9d6f9f0fdb8132cbb679b92d))
- The service worker and manifest headers now come from `@vite-pwa/nuxt` (`public, max-age=0, must-revalidate`, plus the manifest's `Content-Type`) instead of the template's own rule. ([e4ebb26](https://github.com/components-web-app/components-web-app/commit/e4ebb264617e5013ff4b5a70d477c27edd451209))

## [2.0.0-alpha.13](https://github.com/components-web-app/components-web-app/releases/tag/v2.0.0-alpha.13) - 2026-10-08

Since [v2.0.0-alpha.12](https://github.com/components-web-app/components-web-app/releases/tag/v2.0.0-alpha.12).

### Upgrade notes
- Copy the `routeRules` block (`/sw.js` with `cache-control: no-cache`) into `app/nuxt.config.ts`. Then a Cloudflare zone can rely on Cloudflare's default caching of static files: no blanket "Bypass cache for everything" rule and no `/_nuxt` exception rule. ([4add7fe](https://github.com/components-web-app/components-web-app/commit/4add7fe97b9b191b5eec862dd8d50d27b4a70f37))

### Fixed
- After a deploy, a CDN could serve the previous build's service worker for hours, because Nitro sent `/sw.js` with no `Cache-Control` and Cloudflare caches `.js` by default. It now goes out `no-cache`. ([4add7fe](https://github.com/components-web-app/components-web-app/commit/4add7fe97b9b191b5eec862dd8d50d27b4a70f37))

## [2.0.0-alpha.12](https://github.com/components-web-app/components-web-app/releases/tag/v2.0.0-alpha.12) - 2026-10-08

Since [v2.0.0-alpha.11](https://github.com/components-web-app/components-web-app/releases/tag/v2.0.0-alpha.11).

### Upgrade notes
- **Copy `bin/devops/setup.sh` before deleting `CLUSTER_ISSUER`.** v2.0.0-alpha.11's `letsencrypt-prod` default never applied, because `setup.sh` set an unset value to `letsencrypt-staging` first, so a site that deleted the variable got an untrusted staging certificate on its next deploy. With this release's `setup.sh` (no `CLUSTER_ISSUER` default) and `k8s.sh`, an unset value gives `letsencrypt-prod`; an empty value still turns cert-manager off. Until you've synced both, keep `CLUSTER_ISSUER=letsencrypt-prod`. ([0225e8c](https://github.com/components-web-app/components-web-app/commit/0225e8ce48cbed0e49627938d965f335884e2269), [#119](https://github.com/components-web-app/components-web-app/issues/119))

### Fixed
- An unset `CLUSTER_ISSUER` now really gives `letsencrypt-prod`, and `setup.sh` no longer warns about an unset `CORS_ALLOW_ORIGIN` or `TRUSTED_HOSTS`, which `deploy` derives. ([0225e8c](https://github.com/components-web-app/components-web-app/commit/0225e8ce48cbed0e49627938d965f335884e2269), [#119](https://github.com/components-web-app/components-web-app/issues/119))

## [2.0.0-alpha.11](https://github.com/components-web-app/components-web-app/releases/tag/v2.0.0-alpha.11) - 2026-10-08

Since [v2.0.0-alpha.10](https://github.com/components-web-app/components-web-app/releases/tag/v2.0.0-alpha.10).

### Upgrade notes
- Deploys now default `INGRESS_ENABLED=true`, `CLUSTER_ISSUER=letsencrypt-prod`, `CORS_ALLOW_ORIGIN`, `TRUSTED_HOSTS` and `MERCURE_CORS_ORIGIN` (exact matches for the deploy's own hostname and, in production, `KUBE_INGRESS_ALIAS_DOMAINS`), `DATABASE_SSL_MODE=require` when `POSTGRESQL_ENABLED=false`, and an unset `CADDY_CACHE_CDN_CONFIG` now really means `strategy hard`. Copy `apply_site_defaults` and `site_hosts` from `bin/devops/k8s.sh` and the `caddy-cache-cdn-config` changes in `helm/cwa`, deploy once, then delete the CI variables that only repeated these values. Keep `CORS_ALLOW_ORIGIN`/`TRUSTED_HOSTS` if another site calls this API from the browser; set `CLUSTER_ISSUER` to an empty value on a cluster without cert-manager. Don't delete `CADDY_CACHE_CDN_CONFIG=strategy hard` before that deploy. ([be14ab0](https://github.com/components-web-app/components-web-app/commit/be14ab050a7f2b7d6bb843ab4dc85982fede316c))

### Fixed
- An unset `CADDY_CACHE_CDN_CONFIG` replaced the Caddyfile's `strategy hard` with an empty `cdn` block (Kubernetes received a newline), so Souin would keep stale copies of purged responses; every site had to set `strategy hard` by hand. ([be14ab0](https://github.com/components-web-app/components-web-app/commit/be14ab050a7f2b7d6bb843ab4dc85982fede316c))

## [2.0.0-alpha.10](https://github.com/components-web-app/components-web-app/releases/tag/v2.0.0-alpha.10) - 2026-10-08

Since [v2.0.0-alpha.9](https://github.com/components-web-app/components-web-app/releases/tag/v2.0.0-alpha.9).

### Upgrade notes
- Production CPU requests are lower: php 200m → 100m, SSR 250m → 100m, and the SSR autoscaler's CPU target 70% → 175%, so a pod is still added at about 175m. A site that sets only `PWA_AUTOSCALE_CPU_PERCENT` or only `PWA_CPU_REQUEST` must set the other to match (request × target ≈ 175m), or SSR scales on ordinary traffic. ([e79ad3b](https://github.com/components-web-app/components-web-app/commit/e79ad3b7fc18feb7f20fcfe8d810da3ef1973c09))

### Changed
- Production reserves less CPU per site: php and SSR pods request 100m instead of 200m and 250m. With page HTML cached, SSR pods mostly idle; the autoscaler still adds an SSR pod at about one render a second. ([e79ad3b](https://github.com/components-web-app/components-web-app/commit/e79ad3b7fc18feb7f20fcfe8d810da3ef1973c09))

## [2.0.0-alpha.9](https://github.com/components-web-app/components-web-app/releases/tag/v2.0.0-alpha.9) - 2026-10-08

Since [v2.0.0-alpha.8](https://github.com/components-web-app/components-web-app/releases/tag/v2.0.0-alpha.8).

### Upgrade notes
- Copy the `nitro` block from `app/nuxt.config.ts`, and the `goMemLimit` lines and `cwa.php.goMemLimit` helper from `helm/cwa` and `bin/devops/k8s.sh`. ([5e732e9](https://github.com/components-web-app/components-web-app/commit/5e732e9d36688fcbdb59b656f47ccbae1ccfd8e2))
- Copy the `@cache_tag` matcher and `header @cache_tag` block from `api/frankenphp/Caddyfile`, and the `NODE_OPTIONS` line from `app/Dockerfile`; if your deploy sets `NODE_OPTIONS`, add `--max-http-header-size=65536` to it. A site whose sitemap is empty, or whose SSR log shows `UND_ERR_HEADERS_OVERFLOW`, needs this. ([3eae185](https://github.com/components-web-app/components-web-app/commit/3eae1859ff82264773072b57856febb83e420a91))

### Fixed
- SSR fetches of large API collections no longer fail with `UND_ERR_HEADERS_OVERFLOW` (which left the sitemap empty from about 100 routes): `Cache-Tag` is added only for public hosts, never for SSR's internal ones, and the app image allows 64 KB of response headers. ([3eae185](https://github.com/components-web-app/components-web-app/commit/3eae1859ff82264773072b57856febb83e420a91), [#118](https://github.com/components-web-app/components-web-app/issues/118))
- php no longer runs out of memory under a burst of first-time visitors. Nitro now precompresses `/_nuxt` assets at build time (`nitro.compressPublicAssets`), so php's Caddy stops brotli-compressing every JS chunk per request, and the php container gets `GOMEMLIMIT` at 80% of its memory limit (`PHP_GOMEMLIMIT` overrides, `off` unsets). ([5e732e9](https://github.com/components-web-app/components-web-app/commit/5e732e9d36688fcbdb59b656f47ccbae1ccfd8e2), [#117](https://github.com/components-web-app/components-web-app/issues/117))
- A deploy now fails before helm, with a message naming the line, when `CADDY_CACHE_CDN_CONFIG` has a `cdn` directive with no value or an unexpanded `$NAME` (e.g. `api_key $CLOUDFLARE_API_TOKEN` when the token is a Protected GitLab variable and the branch isn't protected). Souin panics parsing it, so php crash-looped while helm reported the release deployed. ([f0e62d7](https://github.com/components-web-app/components-web-app/commit/f0e62d7b2a9dba93aa4b1a6e6a458d89bfdd8153), [#116](https://github.com/components-web-app/components-web-app/issues/116))

## [2.0.0-alpha.8](https://github.com/components-web-app/components-web-app/releases/tag/v2.0.0-alpha.8) - 2026-10-07

Since [v2.0.0-alpha.7](https://github.com/components-web-app/components-web-app/releases/tag/v2.0.0-alpha.7).

### Upgrade notes
- Sites with `provider cloudflare` in `CADDY_CACHE_CDN_CONFIG`: replace `api/frankenphp/souin/v1.7.9-cloudflare-purge.patch` with the new one (the Dockerfile lines are unchanged apart from a comment) and rebuild php. Cloudflare's purge limit is per account, so when several sites, or staging and production, share an account, give each a share of it with `CLOUDFLARE_PURGE_REQUESTS`, `CLOUDFLARE_PURGE_WINDOW` and `CLOUDFLARE_PURGE_BURST` (or set `CLOUDFLARE_PURGE_PLAN` if the account isn't on Free). To pass them through, copy the `compose.yaml`, `bin/devops/k8s.sh` and `helm/cwa` changes from the same commit. ([37afcb1](https://github.com/components-web-app/components-web-app/commit/37afcb10d2e4594c3e36b6f462ab76e3569fdacb))

### Fixed
- Cloudflare edge purges are no longer lost to Cloudflare's per-account purge rate limit (Free: 5 a minute, burst 25), which left pages stale at the edge for up to a year after a short editing session. The Cloudflare Souin patch now queues purges, deduplicates tags, sends up to 100 per request at the plan's rate, retries a `429` after `Retry-After` (and 5xx or network errors), and turns a backlog too big to send within a minute into one purge everything. Optional settings: `CLOUDFLARE_PURGE_PLAN` (`free` default, `pro`, `business`, `enterprise`), or `CLOUDFLARE_PURGE_REQUESTS` per `CLOUDFLARE_PURGE_WINDOW` and `CLOUDFLARE_PURGE_BURST`; set a lower rate when staging and production, or several sites, share a Cloudflare account. Only used with `provider cloudflare`. ([37afcb1](https://github.com/components-web-app/components-web-app/commit/37afcb10d2e4594c3e36b6f462ab76e3569fdacb), [#115](https://github.com/components-web-app/components-web-app/issues/115))

## [2.0.0-alpha.7](https://github.com/components-web-app/components-web-app/releases/tag/v2.0.0-alpha.7) - 2026-10-06

Since [v2.0.0-alpha.6](https://github.com/components-web-app/components-web-app/releases/tag/v2.0.0-alpha.6).

### Changed
- `@cwa/nuxt` 2.0.0-alpha.7: page-data pages no longer show the previous page's dynamic component to visitors after client-side navigation, and pick up live changes to it (cwa-nuxt-module#368). ([e746bd9](https://github.com/components-web-app/components-web-app/commit/e746bd989ba2da1573300e76bbab8e250d30d836))

### Fixed
- A full flush ("Purge all cached data", `purge-http-cache`, fixture loads, and deploys with `provider cloudflare`) no longer closes the Badger or Nuts store, which left nothing cached until php restarted (`BADGER-INSERTION-ERROR`). A fourth Souin patch makes the flush clear the surrogate keys instead of shutting the storage down; `bin/test/souin-flush-storage.sh` checks otter, badger and nuts in CI. Otter, the default, was never affected. ([8ebf5e9](https://github.com/components-web-app/components-web-app/commit/8ebf5e994687014d0496da33a209eafd2137cd93), [#114](https://github.com/components-web-app/components-web-app/issues/114))

## [2.0.0-alpha.6](https://github.com/components-web-app/components-web-app/releases/tag/v2.0.0-alpha.6) - 2026-10-06

Since [v2.0.0-alpha.5](https://github.com/components-web-app/components-web-app/releases/tag/v2.0.0-alpha.5).

### Upgrade notes
- In `app/nuxt.config.ts`, write the PWA `cacheWillUpdate` as a single expression: `async ({ response }) => /no-store|private/.test(response.headers.get('cache-control') || '') || response.status !== 200 ? null : response`. Workbox joins the function onto one line in `sw.js`, and from Nuxt 4.6.0 (which the next `@cwa/nuxt` requires) its source keeps no semicolons, so the old multi-statement version fails the build with "Unable to write the service worker file … Missing semicolon". Works on Nuxt 4.5 too. ([eac5e7b](https://github.com/components-web-app/components-web-app/commit/eac5e7bee474f04347a180e642163f7057e71949))

### Changed
- `@cwa/nuxt` 2.0.0-alpha.6 and Nuxt 4.6.0 (the module now requires it). Apply the `cacheWillUpdate` upgrade note above in the same change, or the build fails writing `sw.js`. ([125661d](https://github.com/components-web-app/components-web-app/commit/125661d07cd8c160e77fd5878e7854854ff39aa7))

### Added
- CI's unit-tests job runs `bin/test/caddy-validate.sh`: `frankenphp validate` on the image's Caddyfile for helm's `SERVER_NAME=:80` and compose's multi-port one. `adapt` only parses, so errors raised while modules load (a second unnamed Mercure hub, #113; a `#` inside the cache CEL expression) passed CI and only showed when php didn't start. ([843082a](https://github.com/components-web-app/components-web-app/commit/843082a54c663a44bc6267314f491647ec94275e), [f3912b0](https://github.com/components-web-app/components-web-app/commit/f3912b07f766bacf190e3ec57e81a4d0eb9d93d8))

## [2.0.0-alpha.5](https://github.com/components-web-app/components-web-app/releases/tag/v2.0.0-alpha.5) - 2026-10-05

Since [v2.0.0-alpha.4](https://github.com/components-web-app/components-web-app/releases/tag/v2.0.0-alpha.4).

### Upgrade notes
- **Add `name cwa` to the Caddyfile's `mercure` block** (or copy the template's). Without it, php doesn't start in the compose stack on an image with Mercure 1.0.3 or later. ([51ea465](https://github.com/components-web-app/components-web-app/commit/51ea465fc34749c1ceabfcf754705cbf4f4b220e), [#113](https://github.com/components-web-app/components-web-app/issues/113))

### Fixed
- php starts again in the compose stack (local dev and `compose.prod.yaml`) on Mercure 1.0.3+: the hub is named, so the `localhost`/`php.local:80`/`php.local:443` servers share one hub instead of being refused as two unnamed hubs. Helm deploys weren't affected. ([51ea465](https://github.com/components-web-app/components-web-app/commit/51ea465fc34749c1ceabfcf754705cbf4f4b220e), [#113](https://github.com/components-web-app/components-web-app/issues/113))

## [2.0.0-alpha.4](https://github.com/components-web-app/components-web-app/releases/tag/v2.0.0-alpha.4) - 2026-10-05

Since [v2.0.0-alpha.3](https://github.com/components-web-app/components-web-app/releases/tag/v2.0.0-alpha.3).

### Upgrade notes
- **Rebuild the API image** before deploying this Caddyfile: it uses two new Caddy modules (`query_allowlist`, `rate_limit`), and an old image refuses it. Locally: `docker compose build php && docker compose up -d php`. No new variable is required. If your pages read a query parameter other than `page`, `search`, `order[...]` or `cwa_force`, add it to `CACHE_QUERY_ALLOWLIST`, or SSR stops seeing it. Behind a proxy with public addresses other than Cloudflare (e.g. a Google load balancer), add its ranges to `CADDY_TRUSTED_PROXIES`. ([4cbe05a](https://github.com/components-web-app/components-web-app/commit/4cbe05a949518be7da67995f6d247807e7a39b7f), [#106](https://github.com/components-web-app/components-web-app/issues/106))
- **GitHub projects:** variables you had added by hand to a workflow's `env:` can stay, but are no longer needed. Any repository variable now reaches `k8s.sh`, so check none holds a stale value you were relying on GitHub to ignore. ([8f290d8](https://github.com/components-web-app/components-web-app/commit/8f290d85d234a60da74b0eec6be8294764b7e842), [#91](https://github.com/components-web-app/components-web-app/issues/91))
- The API's liveness probe now checks php over HTTP instead of TCP, so a pod whose php stops answering is restarted after about a minute. That includes a database outage. Rebuild the API image to pick up the patched Souin, and recreate the API pod. ([9b7bca6](https://github.com/components-web-app/components-web-app/commit/9b7bca608d019231a9458ea2406a3a4e4d881208), [#104](https://github.com/components-web-app/components-web-app/issues/104))
- **Mercure 1.0 (protocol change):** the API image builds Mercure 1.0, and the template now speaks its protocol: OAuth 2.0 access tokens, `match=` subscriptions, the `__Secure-mercure_access_token` cookie. **Deploy the bundle (2.0.0-alpha.8) and module updates in this release together with the rebuilt API image**: an older module subscribes with `topic=`, which the hub rejects. Copy `api/config/packages/mercure.yaml` (`protocol_version: '1.0'`, the `iss`/`sub`/`client_id` claims) and the Caddyfile's `mercure` block (an `issuer` block, `resource_identifier` pinned to `MERCURE_PUBLIC_URL`). Mercure 1.0 also rejects unknown directives and removed `demo` and `ui`: if `MERCURE_EXTRA_DIRECTIVES` sets either, use `debugger` (dev only). Anything of your own that read the `mercureAuthorization` cookie must change. An image built before this release can't load the Caddyfile. ([28fa2bb](https://github.com/components-web-app/components-web-app/commit/28fa2bb2b989fcdff007d84676931ed68e3a922e), [1a9f7a5](https://github.com/components-web-app/components-web-app/commit/1a9f7a5ea2a43f6d314f9c00f18137a241be3567), [#67](https://github.com/components-web-app/components-web-app/issues/67), [api-components-bundle#377](https://github.com/components-web-app/api-components-bundle/issues/377))
- The API uses API Platform's default request handling (`MainController` and the provider/processor chain) instead of Symfony event listeners: `use_symfony_listeners: true` is gone from `api_platform.yaml`. A site with its own code on `EventPriorities` or `kernel.view`/`kernel.request` for API resources must move it to a state provider or processor decorator, or set the flag back. ([fc0afb7](https://github.com/components-web-app/components-web-app/commit/fc0afb71bc7274db9cc6e3dd4ff51dbb64874650))
- **Behat is gone.** API tests are PHPUnit functional tests on API Platform's `ApiTestCase` (`api/tests/Functional`, base class `FunctionalTestCase`, which rebuilds the schema per test and refuses a database whose name lacks `test`). CI's `behat tests` job is now `functional tests` (`run_test_functional`; GitHub: `functional-tests`), and `production`/`canary` need it instead. A project with its own Behat features ports them to `tests/Functional`, or keeps Behat and its `behat.yml`, `features/` and `run_test_behat` itself. ([8885b3c](https://github.com/components-web-app/components-web-app/commit/8885b3c01adafbe6e37263553d84ae9cd572b714))
- **Cloudflare API rule (only if you added the optional one):** add `and not starts_with(http.request.uri.path, "/_api/_/component_positions/")` and purge everything once. Page-data positions vary by the `path` request header, which Cloudflare ignores, so page-data pages (e.g. blog articles) showed one page's content after client-side navigation. ([39c5f4a](https://github.com/components-web-app/components-web-app/commit/39c5f4a97d71e2e1edbdb7b5cb38440a4b247ddc), [docs#134](https://github.com/components-web-app/docs/issues/134))

### Changed
- With `provider cloudflare`, a full flush ("Purge all cached data", `purge-http-cache`, every fixture load) also purges everything at Cloudflare, and deploys flush instead of purging only rendered HTML, so edge-cached `/_api` responses can't outlive a release. No more manual Purge Everything. Rebuild the API image (the Souin Cloudflare patch changed). ([6a8c898](https://github.com/components-web-app/components-web-app/commit/6a8c8984b1408d48fced26655ad32b83afcbaeac))
- The `api`, `app`, `helm` and load-test READMEs are current: working docs links (cwa.rocks), the Nuxt 4 and pnpm workflow, and load testing since the query allowlist and rate limit. ([3d38d3a](https://github.com/components-web-app/components-web-app/commit/3d38d3a8638b34d3365e2534e2c8feac4a44edf7), [#112](https://github.com/components-web-app/components-web-app/issues/112))
- Caddy's access log records the visitor's resolved address as `visitor_ip` (behind Cloudflare, `client_ip` is Cloudflare's). The helm chart now requires `mercure.publicUrl` instead of falling back to an `http` URL that Mercure 1.0's `__Secure-` cookie refuses. ([b3b8622](https://github.com/components-web-app/components-web-app/commit/b3b8622d3fc1375da564668aab3dea9053e1807f), [#110](https://github.com/components-web-app/components-web-app/issues/110), [#111](https://github.com/components-web-app/components-web-app/issues/111))
- `@cwa/nuxt` `2.0.0-alpha.4` (Mercure 1.0 `match=` subscriptions, the `cwa_force` loop fix, stranded component group and orphaned file admin tools; needs Nuxt `>=4.5.2`), and every PHP and front-end dependency at its latest release, except TypeScript (still `6.0.3`: `vue-tsc` can't run on TypeScript 7) and `justinrainbow/json-schema` (5.x, held by `behatch/contexts` until Behat was removed; now 6.x). ([109c3e7](https://github.com/components-web-app/components-web-app/commit/109c3e7a611fba4da26e34d293d5f2098ce34958))
- Bundle `2.0.0-alpha.8`: Mercure 1.0 only, a liveness endpoint (`/_/health/live`), an orphaned file report (new table; the migration is included), file clean-up when uploadable entities are removed. The bundle now works with `use_symfony_listeners` on or off. ([1a9f7a5](https://github.com/components-web-app/components-web-app/commit/1a9f7a5ea2a43f6d314f9c00f18137a241be3567))
- pnpm 12.9.1 (drops the v11-only `confirmModulesPurge` setting, which pnpm 12 refuses) and PHPUnit 13.4.1. ([e919d06](https://github.com/components-web-app/components-web-app/commit/e919d069d24b7e74f59395d49772b394a70b036d))
- `@cwa/nuxt` `2.0.0-alpha.5`: navigating between page-data pages no longer shows the previous page's content under the new title and then a blank body ([cwa-nuxt-module#368](https://github.com/components-web-app/cwa-nuxt-module/issues/368)); live page-data updates show on other open pages straight away. ([f67cb96](https://github.com/components-web-app/components-web-app/commit/f67cb9621f76665ae4c960f9743a91ec4f9de89e))

### Added
- Origin protection: pages drop query parameters they don't use before the cache (so `/?x=1` is a cache hit), a per-visitor rate limit on cache misses that understands Cloudflare, and FrankenPHP sheds load with a fast 503 instead of queueing into a 504. All on by default, each tunable or off by an optional variable. `compose.prod.yaml` sets `CADDY_EDGE=true`, so a client facing Caddy directly can't dodge the limit with invented `X-Forwarded-For` headers. ([4cbe05a](https://github.com/components-web-app/components-web-app/commit/4cbe05a949518be7da67995f6d247807e7a39b7f), [d0021ba](https://github.com/components-web-app/components-web-app/commit/d0021ba64992a631fa7afa3c815754bb00f5d71e), [#106](https://github.com/components-web-app/components-web-app/issues/106))

### Fixed
- The API image builds again: FrankenPHP 1.13.0 requires Mercure 1.0.3, so the Mercure 0.24.2 pin is gone. ([28fa2bb](https://github.com/components-web-app/components-web-app/commit/28fa2bb2b989fcdff007d84676931ed68e3a922e), [#67](https://github.com/components-web-app/components-web-app/issues/67))
- Souin's Cloudflare purge now works (it called the wrong endpoint and failed silently), accepts a scoped Cache Purge token, and logs failures; responses carry `Cache-Tag` so Cloudflare can purge by tag. Only matters with `provider cloudflare` in `CADDY_CACHE_CDN_CONFIG`; rebuild the php image. ([cd99b55](https://github.com/components-web-app/components-web-app/commit/cd99b5541becc7e9b5539c29e2bb929769e97842), [#108](https://github.com/components-web-app/components-web-app/issues/108))
- GitHub deploys now receive every repository and environment variable, as GitLab does, so `INGRESS_ENABLED`, `CLUSTER_ISSUER` and the sizing, Caddy and mail variables take effect. Branch names no longer reach CI scripts unquoted. ([8f290d8](https://github.com/components-web-app/components-web-app/commit/8f290d85d234a60da74b0eec6be8294764b7e842), [#91](https://github.com/components-web-app/components-web-app/issues/91))
- A large file in Nuxt's `public/` (e.g. a PDF brochure) no longer runs the API container out of memory when someone downloads it. Only pages and the sitemap go through the page cache now, and PDFs under `/_api` are really excluded. ([7f84445](https://github.com/components-web-app/components-web-app/commit/7f84445927f3ff128cc5f2928a22f2a9d9cdd18e), [#105](https://github.com/components-web-app/components-web-app/issues/105))
- One stalled request no longer leaves the API pod unready for good. Souin is patched (darkweak/souin#850) so a timed-out call releases its cache key, and the kubelet's probes skip the cache. ([9b7bca6](https://github.com/components-web-app/components-web-app/commit/9b7bca608d019231a9458ea2406a3a4e4d881208), [#104](https://github.com/components-web-app/components-web-app/issues/104))

### Security
- Pages no longer keep `cwa_force` in the default `CACHE_QUERY_ALLOWLIST`: an anonymous `?cwa_force=<anything but true>` sent the server render into an infinite redirect loop, pinning an SSR pod until its liveness probe restarted it ([cwa-nuxt-module#366](https://github.com/components-web-app/cwa-nuxt-module/issues/366); the module fix is in its next release). A site that set `CACHE_QUERY_ALLOWLIST` itself should remove `cwa_force` from it. ([3f7130f](https://github.com/components-web-app/components-web-app/commit/3f7130f73ee2cdfab4579a26aefe2e4fd9dc0465))
- `api/.env`'s `TRUSTED_PROXIES` default trusted `172.0.0.0/8`, which includes public addresses; it's now the private `172.16.0.0/12`. No deployment used the default (compose and the chart set their own). Copy the fix to any project-specific `.env.local`. ([b5aa360](https://github.com/components-web-app/components-web-app/commit/b5aa360393fe77f0d2dbfd3ca33fa44bf7fe069b), [#107](https://github.com/components-web-app/components-web-app/issues/107))

## [2.0.0-alpha.3](https://github.com/components-web-app/components-web-app/releases/tag/v2.0.0-alpha.3) - 2026-09-26

Since [v2.0.0-alpha.2](https://github.com/components-web-app/components-web-app/releases/tag/v2.0.0-alpha.2).

### Upgrade notes
- A deploy with `JWT_SECRET_KEY` set but no `JWT_PASSPHRASE` now fails with a clear message, instead of getting a random passphrase that can't decrypt the key. ([85d3f43](https://github.com/components-web-app/components-web-app/commit/85d3f43e2ec75af0b19b9a18a56010c6dd16eaa8))
- **Run the new migration** for bundle 2.0.0-alpha.6's orphaned-resource report table, and update `@cwa/nuxt` to 2.0.0-alpha.3 at the same time. `clean-orphaned` no longer deletes anything. ([8bab085](https://github.com/components-web-app/components-web-app/commit/8bab085d597f165d950772faa878160146520525))

### Changed
- `generate_jwt_keys` derives `JWT_PUBLIC_KEY` from the secret key when it's empty. ([85d3f43](https://github.com/components-web-app/components-web-app/commit/85d3f43e2ec75af0b19b9a18a56010c6dd16eaa8))
- `api-components-bundle` 2.0.0-alpha.6 and `@cwa/nuxt` 2.0.0-alpha.3: an orphaned-resources admin page with bulk delete, and a scan that can email admins when the result changes. ([8bab085](https://github.com/components-web-app/components-web-app/commit/8bab085d597f165d950772faa878160146520525))

### Added
- A daily 03:00 orphaned-resource scan on production that emails `MAILER_EMAIL` when orphans change. ([c31d28f](https://github.com/components-web-app/components-web-app/commit/c31d28f929bd78ee5670a72c511aeb42e2415eb3), [#101](https://github.com/components-web-app/components-web-app/issues/101))

### Fixed
- The orphan scan's email reaches a `MAILER_EMAIL` in the `Name <address>` form (bundle 2.0.0-alpha.7). ([6bf6b7c](https://github.com/components-web-app/components-web-app/commit/6bf6b7c2cfd1a657b8d64ac00bfd1d325d326029))
- The orphan-scan CronJob no longer receives `RESET_DATABASE`, which would have dropped the schema nightly. ([70b9802](https://github.com/components-web-app/components-web-app/commit/70b9802d879f29e3e6fd3121e893a328ec85bf2e), [#103](https://github.com/components-web-app/components-web-app/issues/103))
- An empty `MAILER_EMAIL` no longer crashes the orphan scan. ([70b9802](https://github.com/components-web-app/components-web-app/commit/70b9802d879f29e3e6fd3121e893a328ec85bf2e))
- A deploy without `MAILER_DSN` no longer fails the helm render, and GitHub deploys pass the mail and orphan-scan variables. ([70b9802](https://github.com/components-web-app/components-web-app/commit/70b9802d879f29e3e6fd3121e893a328ec85bf2e), [#102](https://github.com/components-web-app/components-web-app/issues/102))

### Security
- `TRUSTED_HOSTS` defaults anchor every alternative, so no default trusts an attacker's hostname. Projects should check their own `TRUSTED_HOSTS` CI variable the same way. ([b43fd09](https://github.com/components-web-app/components-web-app/commit/b43fd0925b7f130d1362562ec8d0001285c05644), [#97](https://github.com/components-web-app/components-web-app/issues/97))

## [2.0.0-alpha.2](https://github.com/components-web-app/components-web-app/releases/tag/v2.0.0-alpha.2) - 2026-09-25

Since [v2.0.0-alpha.1](https://github.com/components-web-app/components-web-app/releases/tag/v2.0.0-alpha.1).

### Upgrade notes
- Bundle alpha.5: throttled email requests now return 429, and an application with its own `RouteGeneratorInterface` must add `generatePath()`. ([867c412](https://github.com/components-web-app/components-web-app/commit/867c4128d66553744a1fb6c6269e1b1a4452a667))
- **Staging no longer has a fixture job** (it shares production's database). `FIXTURES_PURGE` empties the database before a fixture load: `"true"` on review apps, `"force"` for production. ([!11](https://gitlab.com/silverback-web-apps/cwa/components-web-app/-/merge_requests/11))
- **Rename `NUXT_PUBLIC_CWA_API_URL` to `NUXT_CWA_API_URL`** in the same deploy as the module update. The old name still works, but it publishes the internal URL and logs a deprecation warning. ([66e9365](https://github.com/components-web-app/components-web-app/commit/66e93658cb394b52e39e5664e54153a21c74e99d))
- **Configure `user.email_links.default_origin`.** Without it, bundle alpha.4 refuses password-reset and verification emails with a 400. ([e23956d](https://github.com/components-web-app/components-web-app/commit/e23956dceafbbb7caaa2a9875be25e3325985742))
- `compose.prod.yaml` now needs every secret set. ([1456c7c](https://github.com/components-web-app/components-web-app/commit/1456c7cd1002d3da18f8b7191b69983c819c65fc))

### Changed
- `api-components-bundle` 2.0.0-alpha.5 and `@cwa/nuxt` 2.0.0-alpha.2: fixture loads with `--append` are idempotent, and drafts can be scheduled to publish. ([867c412](https://github.com/components-web-app/components-web-app/commit/867c4128d66553744a1fb6c6269e1b1a4452a667))
- Every fixture load ends by flushing the whole HTTP cache, so reloaded content isn't served stale. ([!11](https://gitlab.com/silverback-web-apps/cwa/components-web-app/-/merge_requests/11))
- `CLAUDE.md` trimmed from 1,992 to 351 lines of current guidance. ([d13dbe1](https://github.com/components-web-app/components-web-app/commit/d13dbe1aa2df04b0b004ce8c9cd3a4e56e08b296))
- Depend on `@cwa/nuxt` `^2.0.0-alpha.1`, its first tagged release, instead of an edge build. ([b3602d5](https://github.com/components-web-app/components-web-app/commit/b3602d5455581f47b62c280bb82f96d0f87577eb))
- `@cwa/nuxt` edge `5cc17ad`: readiness route, purgeable sitemap, private server API URL, first-run and API-down error pages. ([66e9365](https://github.com/components-web-app/components-web-app/commit/66e93658cb394b52e39e5664e54153a21c74e99d))
- `api-components-bundle` 2.0.0-alpha.4: uncached `/_api/_/health`, a failed purge no longer fails a saved write, and email links use a configured origin. ([e23956d](https://github.com/components-web-app/components-web-app/commit/e23956dceafbbb7caaa2a9875be25e3325985742))
- `create-cwa` downloads the template tag matching its own version, with `--ref` to choose another. ([c3a0984](https://github.com/components-web-app/components-web-app/commit/c3a09842bbbc3f524bb7fefabdabf734c34120d7))
- A branch without a review namespace shows orange (passed with warnings), not red. ([5b6a953](https://github.com/components-web-app/components-web-app/commit/5b6a953ee17221d8612648d4594f2b7f40608155))

### Added
- `CHANGELOG.md`, kept from now on and used as each release's notes. ([7d04051](https://github.com/components-web-app/components-web-app/commit/7d040513a14cbaaae5c167ff41a2cb8789db3ffc))
- Dev JWT keys are generated on first boot. ([1456c7c](https://github.com/components-web-app/components-web-app/commit/1456c7cd1002d3da18f8b7191b69983c819c65fc))
- `.gitguardian.yaml` for the required-secret placeholders in `compose.prod.yaml`. ([64f8d58](https://github.com/components-web-app/components-web-app/commit/64f8d58d36703aed3b3433c969002ebaf1576c9f))
- Release process documented in `CLAUDE.md`. ([5fc5e64](https://github.com/components-web-app/components-web-app/commit/5fc5e64fb843db67ee9c810c38fba189e69d558d))

### Fixed
- CORS exposes `Retry-After`, so a cross-origin site can count down a throttled email request. ([ba0ea40](https://github.com/components-web-app/components-web-app/commit/ba0ea409338e653e25b44afcfb545e0006809014), [#100](https://github.com/components-web-app/components-web-app/issues/100))
- `compose.prod.yaml` gives the app service its API URL and warm origin. ([ba0ea40](https://github.com/components-web-app/components-web-app/commit/ba0ea409338e653e25b44afcfb545e0006809014), [#98](https://github.com/components-web-app/components-web-app/issues/98))
- Review fixtures, warm, audit and stop jobs stop with a reason when the review job didn't deploy. ([ba0ea40](https://github.com/components-web-app/components-web-app/commit/ba0ea409338e653e25b44afcfb545e0006809014), [#99](https://github.com/components-web-app/components-web-app/issues/99))

### Security
- Local JWT keys, secrets and uploads are kept out of the API image. ([176fa9d](https://github.com/components-web-app/components-web-app/commit/176fa9d708e892f75acc367a05997f2c00a8633a))
- Caddy's admin API listens only on the php container's loopback, and port 2019 is no longer published. ([0170978](https://github.com/components-web-app/components-web-app/commit/0170978196ef9dd3092a15f761b5edf024c4d174))
- Removed a hardcoded, unused `COMPOSER_PACKAGIST_TOKEN` from the Behat job. ([cf6591e](https://github.com/components-web-app/components-web-app/commit/cf6591e9586df420834bdcab713b65efa4be7889))

## [2.0.0-alpha.1](https://github.com/components-web-app/components-web-app/releases/tag/v2.0.0-alpha.1) - 2026-09-24

First tagged release of the template, built against `api-components-bundle` 2.0.0-alpha.3 and `@cwa/nuxt` edge `9a15df5`.
