# Browser tests

Playwright tests that drive the built app and API the way visitors and editors do (#157). They run against this
commit's **production images** in a throwaway stack: the repository's `compose.yaml` + `compose.prod.yaml` (the
single-server production config, #207), with `e2e/compose.yaml` on top adding only the CI stand-ins: the images
instead of builds, no published ports, Postgres on tmpfs, a Cloud Storage emulator (the production image always uses
Cloud Storage, and your own specs may upload) and Mailpit for emails. `run.sh` sets the values `compose.prod.yaml`
requires (throwaway secrets, `SITE_HOST=localhost`) and unsets everything else those files read, so nothing from your
shell or a local `.env` reaches the stack.

Before the browser tests, `cache-checks.sh` runs in the php container: every sitemap page is `stored` on its first
view and a `hit` on its second, purging one component's tag drops only the page that rendered it, and
`purge-rendered-html` drops every page but leaves the API cached. Then `run.sh` checks Caddy's admin API (port 2019)
can't be reached from the app container.

## In CI

Opt-in: set the CI variable `CWA_CI_E2E_ENABLED` to `"true"`.

- **GitLab:** a `browser tests` job in the `test` stage. Review, staging, canary and production deploys wait for it.
- **GitHub:** a `Browser tests` job in `ci.yml`, before review and staging, and in `production.yml`, before the deploy.

The Playwright report, traces, screenshots and videos of failures are kept as job artifacts for 14 days.

## Locally

Needs Docker and openssl. Build the images, then run:

```sh
docker build --target frankenphp_prod -t cwa-e2e-php:local api
docker build --target prod -t cwa-e2e-app:local app
E2E_PHP_IMAGE=cwa-e2e-php:local E2E_APP_IMAGE=cwa-e2e-app:local sh e2e/run.sh
```

- `E2E_ARGS="tests/admin.spec.ts"` (or `--grep …`) runs part of the suite. The check that every test ran is skipped then.
- `E2E_KEEP_STACK=true` leaves the stack running afterwards, and prints the command that stops it (from the
  repository root, `docker compose -p <project> down -v`).
- `E2E_SCALED=true` runs the same tests against scaled mode (#85): two php replicas on one Redis cache and one Mercure
  hub (`compose.scaled.yaml`). In CI, set `CWA_CI_E2E_SCALED="true"`.
- `E2E_STORAGE=gcloud` stores media in a Cloud Storage stand-in (`fake-gcs-server`) instead of the local volume that
  `compose.prod.yaml` uses (#211). In CI, set `CWA_CI_E2E_STORAGE="gcloud"`. Either way, `run.sh` uploads an image,
  checks it and its WebP variants are served, recreates php and checks again (`media-checks.sh`). A project
  without the image feature (no `api/src/Entity/Image.php`) skips that step.
- Each checkout gets its own stack, `cwa-e2e-<directory>` (`COMPOSE_PROJECT_NAME` overrides it), so two projects can
  run at once on one machine (#178).
- Reports land in `playwright-report/` and `test-results/`.
- The registry's images are amd64 only. On an ARM Mac, run them with `DOCKER_DEFAULT_PLATFORM=linux/amd64`.

The stack publishes no ports, so it runs beside the dev stack.

## Writing tests

- Import `test` and `expect` from `tests/fixtures.ts`, never from `@playwright/test` (types are fine). Its `page` fails a
  test whose API write gets a 405, 406 or 415, or that throws an uncaught error in the page.
- Use the `visitor` fixture to see a page as an anonymous visitor beside a signed-in `page`. It has its own browser
  context, checked the same way and closed after the test.
- Find elements the way a person does: `getByRole`, `getByLabel`, `getByText`, with exact names. Fall back to CSS only
  where the markup gives nothing better, and say why in a comment.
- The template's tests assume only what every project has: the admin user and the pages the sitemap lists, never
  the sample content (#177). Your own specs can test your site's pages and content.
- `logIn(page)` signs in as the admin. The password is generated per run and loaded with the fixtures.
- Tests share one database and run one at a time. A test that edits content uses its own unique text.
- `check-all-ran.mjs` fails the run unless every listed test ran and passed.
- Every Playwright call and every helper that returns a promise is awaited, and assertions use the retrying form
  (`await expect(locator).toBeVisible()`, not `expect(await locator.isVisible())`). No fixed waits
  (`waitForTimeout`) and no `force: true`: wait for the response, URL or element the test is about.
- The tests are type-checked (`npm run typecheck`, strict `tsconfig.json`) and linted (`npm run lint`, `lint:fix`):
  the module's style (`@nuxt/eslint-config`), Playwright's rules and typescript-eslint's `no-floating-promises`, all as
  errors. Playwright only strips types, so the runner runs both before the tests, and either failing fails the job.
  Run `npm ci` here for your editor's types and lint.
- Keep `Dockerfile`'s Playwright image and `@playwright/test` on the same version.
