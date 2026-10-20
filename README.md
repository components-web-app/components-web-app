# Components Web App

A full-stack template for building decoupled, content-driven web applications with an intuitive inline CMS. Built on **Symfony + API Platform** (PHP) and **Nuxt** (Vue 3).

CWA wires together the building blocks — JWT auth, Mercure real-time updates, draft/publish workflows, file uploads, dynamic forms, and a fluent fixture builder — so you spend your time building your app rather than infrastructure. Components expose REST endpoints automatically, and the admin panel lets editors manage content inline without leaving the page.

## Features

- **Draft & publish** — components are privately editable until explicitly published; editors work freely without affecting live content
- **Real-time updates** — Mercure broadcasts changes instantly to all connected browsers
- **File uploads & images** — Flysystem adapters (local, S3, GCS) with automatic image variant generation
- **Dynamic forms** — Symfony forms serialized to JSON, rendered and validated in the Nuxt layer
- **Paginated collections** — proxy components handle listing, search, and pagination automatically
- **Inline admin panel** — content managers edit directly on the page without a separate backend UI

## Getting started

Full installation instructions are at **[cwa.rocks](https://cwa.rocks/getting-started/installation)**.

### Option A — Scaffolder (recommended)

The `create-cwa` CLI prompts for the features you want and generates a clean project with only what you selected:

```bash
pnpm create cwa my-project
```

### Option B — Clone this repo

Clone or fork for the full working example with every feature enabled:

```bash
gh repo create my-project \
  --template="components-web-app/components-web-app" \
  --private --clone
```

> The `packages/` directory contains the `create-cwa` scaffolder — not part of your application. Delete it after cloning:
> ```bash
> rm -rf packages/
> ```

### Run it locally

With Docker running, from the project directory:

```bash
bin/up
```

It starts the stack and waits until it's healthy (the first run builds the images and installs dependencies: several minutes), loads the fixtures with `--append` (only what's missing: the admin and the sample pages), pre-compiles the first pages and prints the login. Run it again any time; `bin/up --skip-fixtures` keeps an admin password you changed, since each fixture load resets it to `ADMIN_PASSWORD`.

| URL | |
|---|---|
| https://localhost | The site |
| https://localhost/login | Sign in (dev: `admin` / `admin`) |
| http://localhost:8025 | Mailpit: every email the API sends in dev |

The browser warns about the certificate on the first visit: Caddy signs it with its own local CA, and accepting the warning is expected for local development. If a phase fails or times out, `bin/up` names it and prints that service's last log lines.

## Documentation

[cwa.rocks](https://cwa.rocks)

## Contributing, security and licence

- Issues and pull requests are welcome on GitHub: see [CONTRIBUTING.md](CONTRIBUTING.md) and the [code of conduct](CODE_OF_CONDUCT.md).
- Report security problems privately, as [SECURITY.md](SECURITY.md) describes, never in a public issue.
- Released under the [MIT licence](LICENSE). Projects created with `create-cwa` don't get this licence file: your project's licence is yours to choose.
