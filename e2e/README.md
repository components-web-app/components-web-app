# Browser tests

Playwright tests that drive the built app and API the way visitors and editors do (#157). They run against this
commit's **production images** in a throwaway stack (`compose.yaml`): Postgres on tmpfs, a Cloud Storage emulator
for uploads, and Mailpit for emails.

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

- `E2E_ARGS="tests/admin.spec.ts"` (or `--grep …`) runs part of the suite.
- `E2E_KEEP_STACK=true` leaves the stack running afterwards.

The stack publishes no ports, so it runs beside the dev stack.

## Writing tests

- Import `test` and `expect` from `tests/fixtures.ts`, never from `@playwright/test`. Its `page` fails a test whose
  API write gets a 405, 406 or 415, or that throws an uncaught error in the page.
- `logIn(page)` signs in as the admin. The password is generated per run and loaded with the fixtures.
- Tests share one database and run one at a time. A test that edits content uses its own unique text.
- `check-all-ran.mjs` fails the run unless every listed test ran and passed.
- Keep `Dockerfile`'s Playwright image and `@playwright/test` on the same version.
