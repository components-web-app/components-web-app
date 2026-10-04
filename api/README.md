# Components Web App: API

The Symfony and API Platform application behind the CWA template, served by FrankenPHP with the Souin HTTP cache and a Mercure hub (`frankenphp/Caddyfile`). It runs the [API Components Bundle](https://github.com/components-web-app/api-components-bundle).

- Documentation: https://cwa.rocks (the API section starts at [Bundle setup](https://cwa.rocks/api/bundle-setup))
- Front end: the [CWA Nuxt module](https://github.com/components-web-app/cwa-nuxt-module), in `../app`

## Create an admin user

The pipeline's fixtures create one from `ADMIN_USERNAME`, `ADMIN_EMAIL` and `ADMIN_PASSWORD`. To create one by hand, see [`user:create`](https://cwa.rocks/api/console-commands):

```sh
# asks for the username, email and password; --super-admin gives access to /_cwa
docker compose exec php bin/console silverback:api-components:user:create --super-admin
```

## Built on API Platform

See API Platform's [documentation](https://api-platform.com/docs/) for the framework itself.
