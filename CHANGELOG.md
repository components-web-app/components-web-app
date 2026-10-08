# Changelog

All notable changes to the CWA template and `create-cwa`, which share a version. Newest first.

Every change to `main` gets a line under **Unreleased**, linking its commit or merge request, before it's pushed. A release renames that section to its version and date, and the section becomes the tag's message and the GitHub release notes.

## Unreleased

### Upgrade notes
- Copy `run_test_functional` from `bin/devops/k8s.sh` **and** add `MAILER_DSN=null://null` to `api/.env.test`: the job unsets `MAILER_DSN` and `MAILER_EMAIL` so a test that sends email can't deliver it through your live relay (every CI variable reaches the test job and beats `api/.env.test`), and the null transport stops it falling back to `.env`'s `smtp-relay`, which CI doesn't have. ([!12](https://gitlab.com/silverback-web-apps/cwa/components-web-app/-/merge_requests/12), [#123](https://github.com/components-web-app/components-web-app/issues/123))
- Optional: add a `GITHUB_TOKEN` CI variable (a fine-grained token with no permissions is enough) and copy the composer step from `api/Dockerfile`, `build_api` from `bin/devops/k8s.sh`, the `COMPOSER_AUTH` block at the end of `bin/devops/setup.sh` and the build step's `GITHUB_TOKEN` in `.github/workflows/ci.yml`, so composer installs stop failing on GitHub's anonymous rate limit. Without the token nothing changes. ([!12](https://gitlab.com/silverback-web-apps/cwa/components-web-app/-/merge_requests/12), [#123](https://github.com/components-web-app/components-web-app/issues/123))
- Delete a `VARNISH_TOKEN` CI variable if you have one: nothing reads it any more. ([!12](https://gitlab.com/silverback-web-apps/cwa/components-web-app/-/merge_requests/12), [#123](https://github.com/components-web-app/components-web-app/issues/123))

### Added
- Composer authenticates to github.com with an optional `GITHUB_TOKEN`, passed to the API build as a build secret, with at most 6 parallel downloads. ([!12](https://gitlab.com/silverback-web-apps/cwa/components-web-app/-/merge_requests/12), [#123](https://github.com/components-web-app/components-web-app/issues/123))

### Fixed
- A downstream functional test that sends email no longer reaches the live mail relay (`.env.test` uses the null transport), and tests that sign in get a JWT keypair. ([!12](https://gitlab.com/silverback-web-apps/cwa/components-web-app/-/merge_requests/12), [#123](https://github.com/components-web-app/components-web-app/issues/123))
- The registry pull secret is applied rather than replaced with `--force`, so releases that share a namespace don't race ("already exists"). The first deploy after this prints a harmless one-off warning about a missing `last-applied-configuration` annotation. ([!12](https://gitlab.com/silverback-web-apps/cwa/components-web-app/-/merge_requests/12), [#123](https://github.com/components-web-app/components-web-app/issues/123))
- `helm lint` and `helm template` work on the chart's own defaults: `jwt-passphrase` defaults to `""` instead of failing `b64enc`. ([!12](https://gitlab.com/silverback-web-apps/cwa/components-web-app/-/merge_requests/12), [#123](https://github.com/components-web-app/components-web-app/issues/123))
- Release steps tag with `--cleanup=verbatim`, so a tag message keeps the changelog's `###` headings. ([56f3065](https://github.com/components-web-app/components-web-app/commit/56f3065abea729f33375ee5db664510114fed341))

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
