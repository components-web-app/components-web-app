# Changelog

All notable changes to the CWA template and `create-cwa`, which share a version. Newest first.

Every change to `main` gets a line under **Unreleased**, linking its commit or merge request, before it's pushed. A release renames that section to its version and date, and the section becomes the tag's message and the GitHub release notes.

## Unreleased

### Fixed
- The orphan-scan CronJob no longer receives `RESET_DATABASE`, which would have dropped the schema nightly. ([70b9802](https://github.com/components-web-app/components-web-app/commit/70b9802d879f29e3e6fd3121e893a328ec85bf2e), [#103](https://github.com/components-web-app/components-web-app/issues/103))
- An empty `MAILER_EMAIL` no longer crashes the orphan scan. ([70b9802](https://github.com/components-web-app/components-web-app/commit/70b9802d879f29e3e6fd3121e893a328ec85bf2e))
- A deploy without `MAILER_DSN` no longer fails the helm render, and GitHub deploys pass the mail and orphan-scan variables. ([70b9802](https://github.com/components-web-app/components-web-app/commit/70b9802d879f29e3e6fd3121e893a328ec85bf2e), [#102](https://github.com/components-web-app/components-web-app/issues/102))

### Added
- A daily 03:00 orphaned-resource scan on production that emails `MAILER_EMAIL` when orphans change. ([c31d28f](https://github.com/components-web-app/components-web-app/commit/c31d28f929bd78ee5670a72c511aeb42e2415eb3), [#101](https://github.com/components-web-app/components-web-app/issues/101))

### Upgrade notes
- **Run the new migration** for bundle 2.0.0-alpha.6's orphaned-resource report table, and update `@cwa/nuxt` to 2.0.0-alpha.3 at the same time. `clean-orphaned` no longer deletes anything. ([8bab085](https://github.com/components-web-app/components-web-app/commit/8bab085d597f165d950772faa878160146520525))

### Changed
- `api-components-bundle` 2.0.0-alpha.6 and `@cwa/nuxt` 2.0.0-alpha.3: an orphaned-resources admin page with bulk delete, and a scan that can email admins when the result changes. ([8bab085](https://github.com/components-web-app/components-web-app/commit/8bab085d597f165d950772faa878160146520525))

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
