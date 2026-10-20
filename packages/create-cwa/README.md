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
- **Start the Docker stack?** Before anything is downloaded, it checks that Docker is running and that ports 80, 443, 3001 and 5432 are free, and names whatever holds a port. If you don't start the stack now, it offers to install `app/` dependencies on your machine for editor types (default No): the app container installs its own either way.

Then follow the printed steps: the dev server runs in the `app` container, the site is at `https://localhost`, and the admin signs in at `https://localhost/login`.

## Options

- `--ref <tag or branch>`: the template version to download. By default `create-cwa` X downloads the template tagged `vX`, so an install is reproducible. `--ref main` gets the latest unreleased template.

## Privacy

`create-cwa` collects no telemetry. It only downloads the template and its manifest from GitHub.

## Licence

MIT
