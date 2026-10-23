# create-cwa

Create a new [CWA (Components Web App)](https://cwa.rocks) project: a Nuxt front end with the [`@cwa/nuxt`](https://github.com/components-web-app/cwa-nuxt-module) module, and a Symfony and API Platform API with the [API Components Bundle](https://github.com/components-web-app/api-components-bundle), run locally with Docker.

> **Prerelease.** CWA 2 is in alpha: expect breaking changes between versions. Each release's changes and upgrade notes are in the template's [CHANGELOG](https://github.com/components-web-app/components-web-app/blob/main/CHANGELOG.md).

## Usage

```sh
pnpm create cwa my-app
# or
npx create-cwa my-app
```

Requires Node.js 22.13 or later, and Docker to run the project.

The CLI asks for:

- **Project name**: lower-case letters, digits and dashes. It becomes the directory (which must not exist yet, or be empty) and the Docker Compose project name.
- **CI/CD pipeline**: GitHub Actions, GitLab CI (both deploy to Kubernetes) or None to decide later.
- **Features**: navigation links, an HTML content editor, image uploads, a blog, nested pages and an example form. Features another one needs are added for you.
- **Fixtures**: sample pages for the chosen features.
- **Start the Docker stack?** Before anything is downloaded, it checks that Docker is running and that ports 80, 443, 3001, 5432 and 8025 are free, and names whatever holds a port. If you don't start the stack now, it offers to install `app/` dependencies on your machine for editor types (default No): the app container installs its own either way.

If you start the stack, the CLI runs the project's `bin/up`: it waits until the stack is healthy, loads the fixtures (which create the admin, and the sample pages if you chose them), pre-compiles the first pages and prints the login. Run `bin/up` again any time; it's safe to repeat. The site is at `https://localhost`, the admin signs in at `https://localhost/login` (`admin` / `admin` in dev), and Mailpit shows the emails the API sends at `http://localhost:8025`. Without a POSIX shell (Windows without WSL), the CLI prints the steps instead.

## Options

- `--ref <tag or branch>`: the template version to download. By default `create-cwa` X downloads the template tagged `vX`, so an install is reproducible. `--ref main` gets the latest unreleased template.
- `--template-dir <path>`: copy the template from a local checkout instead of downloading it: the files git tracks (or would track), minus `export-ignore` paths, like a download. The manifest's excludes and feature stripping apply as usual. Can't be combined with `--ref`.

Each of these answers its question, so it isn't asked:

- `--pipeline <github|gitlab|none>`: the CI/CD pipeline.
- `--features <list>`: comma-separated feature ids (`navigation`, `html-content`, `image`, `blog`, `nested-pages`, `forms`), `all` or `none`. Features another one needs are still added.
- `--fixtures` / `--no-fixtures`: include the sample pages, or not.
- `--start` / `--no-start`: run `bin/up` once the project is created, or not. With `--start`, a check that fails (Docker not running, a port taken) stops the CLI before anything is created.
- `--install-deps` / `--no-install-deps`: `pnpm install` in `app/` on this machine; only when the stack isn't started.

For unattended runs:

- `-y`, `--yes`: take the default for every question no flag answers: GitHub Actions, no features, fixtures, start the stack (when Docker is there and the checks pass), no host install. The project name has no default, so it's still asked for when not given.
- `--ci`: never prompt (implies `--yes`). A missing or invalid project name is an error, and a failed `bin/up` makes the CLI exit 1. For example:

```sh
npx create-cwa my-app --ci --pipeline none --features all --no-start
```

## Privacy

`create-cwa` collects no telemetry. It only downloads the template and its manifest from GitHub.

## Licence

MIT
