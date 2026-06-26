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
npx create-cwa my-project
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

## Documentation

[cwa.rocks](https://cwa.rocks)
