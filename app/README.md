# Components Web App: front end

The Nuxt 4 application, built on the [CWA Nuxt module](https://github.com/components-web-app/cwa-nuxt-module) (`@cwa/nuxt`). Documentation: https://cwa.rocks ([module setup](https://cwa.rocks/nuxt-module/module-setup)).

## Development

The app runs in the `app` container of the repository's Docker stack, which installs dependencies with pnpm and starts the dev server itself:

```sh
docker compose up -d        # from the repository root
```

Open https://localhost. Don't run `pnpm dev` on the host: only the container is reached through Caddy at `https://localhost`.

**Don't run `pnpm install` on the host while the stack is running.** `node_modules` is shared with the container, and a host install breaks the running dev server. If it happens, run `docker compose restart app`. To change dependencies, use `pnpm up` / `pnpm remove` with `--lockfile-only` on the host, then `docker compose restart app`.

## Production build

```sh
docker compose exec app pnpm run build    # also type-checks with vue-tsc
```

Deploys build the production image from `Dockerfile` (see https://cwa.rocks/deployment/docker and https://cwa.rocks/deployment/kubernetes).
