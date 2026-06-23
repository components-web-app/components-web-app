# Components Web App

The official full-featured template for [CWA](https://cwa.rocks) — a decoupled web app platform built on Symfony + API Platform (PHP) and Nuxt (Vue).

## Getting started

### Option A — Scaffolder (recommended)

The `create-cwa` CLI prompts you for the features you want and generates a clean project with only what you selected:

```bash
npx create-cwa my-project
```

Prompts: project name, CI/CD pipeline (GitHub Actions / GitLab CI / none), features (navigation, HTML content, images, blog, nested pages, forms), and whether to include sample fixtures.

### Option B — Clone this repo

Clone or fork this repo if you want the full working example with every feature enabled:

```bash
gh repo create my-project \
  --template="components-web-app/components-web-app" \
  --private --clone
```

> The `packages/` directory contains the `create-cwa` scaffolder itself — it is not part of your application. Delete it after cloning:
> ```bash
> rm -rf packages/
> ```

Then follow the [installation guide](https://cwa.rocks/getting-started/installation) to start Docker, generate JWT keys, and load fixtures.

## Documentation

[cwa.rocks](https://cwa.rocks)
