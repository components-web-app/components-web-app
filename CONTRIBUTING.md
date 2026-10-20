# Contributing

Thanks for helping with Components Web App. This repository is the template that `create-cwa` installs, and the demo
of the [API bundle](https://github.com/components-web-app/api-components-bundle) and the
[Nuxt module](https://github.com/components-web-app/cwa-nuxt-module).

## Issues and pull requests

- **File issues and pull requests on [GitHub](https://github.com/components-web-app/components-web-app).** It is the
  public tracker. Questions about using CWA are answered in the docs at [cwa.rocks](https://cwa.rocks).
- A problem in the bundle or the module belongs on that repository; one in an upstream project (API Platform, Nuxt,
  Souin, …) belongs upstream.
- Security problems: never in public. See [SECURITY.md](SECURITY.md).
- The GitHub repository is a mirror: maintainers work on GitLab. An accepted pull request is merged there and mirrored
  back, so GitHub may show it as closed rather than merged. Your commits keep your authorship.
- If you use AI tools, review and test what they produce yourself. Unreviewed generated issues or pull requests will
  be closed.

## Running the stack

You need Docker. From the repository root:

```sh
docker compose up -d
docker compose exec php bin/console doctrine:fixtures:load --append
```

The site is at `https://localhost`; sign in at `https://localhost/login` as `admin` / `admin` (local only). The front
end runs in the `app` container: don't run `pnpm dev` on the host.

## Tests

```sh
# PHPUnit: unit tests
docker compose exec php vendor/bin/phpunit tests/Unit

# PHPUnit: functional tests drop the schema, so they need a database whose name contains "test"
docker compose exec -e APP_ENV=test -e 'DATABASE_URL=postgresql://app:!ChangeMe!@database:5432/app_test?serverVersion=16&charset=utf8' \
  php sh -c 'bin/console doctrine:database:create --if-not-exists && vendor/bin/phpunit tests/Functional'

# Front end: a production build, which type-checks with vue-tsc
docker compose exec app pnpm run build
```

- `bin/test/*.sh` check the deploy scripts, the Caddyfile and the patched Souin build. Each script's header says how
  to run it, e.g. `sh bin/test/deploy-promotion.sh` or `docker compose exec -T php sh -s < bin/test/caddy-validate.sh`.
- The Playwright browser tests: [e2e/README.md](e2e/README.md).

## Changes

- **Every change gets a line in [CHANGELOG.md](CHANGELOG.md)** under `## Unreleased`, in the right group (Upgrade
  notes, Changed, Added, Fixed, Security, Removed). Put anything an existing project must do by hand under *Upgrade
  notes*. A pull request's line links to the pull request.
- Commit subjects are one plain sentence ending with the issue number, e.g. `Fix the sitemap's lastmod (#123)`.
- Code comments are one line, two at most: what the line does or what not to change, with the issue number. The why
  goes in the issue and the changelog.
- The deploy scripts in `bin/devops/` run under busybox `ash` on GitLab: keep them POSIX.
- Settings for the template's CI and deploy are named `CWA_CI_*`.

## Code of conduct

Everyone taking part is expected to follow the [code of conduct](CODE_OF_CONDUCT.md).

Thanks also to Pascal Borreli and Antoine Bluchet for their early ideas, infrastructure work and bug reports.
