#!/bin/sh
# Deploys this checkout on a single server (#212): build (or pull CI's images), back up before pending migrations, start,
# purge, image variants, warm. Safe to run again. Usage: bin/server/deploy.sh [--fixtures]
#   --fixtures  loads the fixtures (append: creates the admin and anything missing, keeps what exists). Run it once,
#               on the first deploy; every load resets the admin's password to ADMIN_PASSWORD.
# Needs .env.prod (bin/server/init), docker with compose, curl. php restarts when its image changes (a short outage).
set -eu

cd "$(dirname "$0")/../.."
. ./bin/server/lib.sh
fixtures=false
for arg in "$@"; do
  case "$arg" in
    --fixtures) fixtures=true ;;
    *) echo "Unknown option: $arg (usage: bin/server/deploy.sh [--fixtures])" >&2; exit 2 ;;
  esac
done
require_env_file
SITE_HOST=$(env_value SITE_HOST)

# CWA_SERVER_PHP_IMAGE and CWA_SERVER_APP_IMAGE (both, as name@digest or name:tag): run the images CI built and
# tested instead of building here. CWA_SERVER_REGISTRY_CONFIG is a DOCKER_CONFIG holding the pull's login.
php_image=${CWA_SERVER_PHP_IMAGE:-}
app_image=${CWA_SERVER_APP_IMAGE:-}
if [ -n "$php_image$app_image" ]; then
  [ -n "$php_image" ] && [ -n "$app_image" ] || { echo "Set both CWA_SERVER_PHP_IMAGE and CWA_SERVER_APP_IMAGE, or neither." >&2; exit 2; }
  echo "➡️ Pulling the images CI built..."
  for image in "$php_image" "$app_image"; do
    if [ -n "${CWA_SERVER_REGISTRY_CONFIG:-}" ]; then DOCKER_CONFIG=$CWA_SERVER_REGISTRY_CONFIG docker pull -q "$image"; else docker pull -q "$image"; fi \
      || { echo "❌ Couldn't pull $image. A server of another architecture than CI's runners can't run its images: build here instead (CWA_CI_SERVER_BUILD=true)." >&2; exit 1; }
  done
  printf 'services:\n  php:\n    image: %s\n  app:\n    image: %s\n' "$php_image" "$app_image" > "$IMAGES_FILE"
else
  rm -f "$IMAGES_FILE"
  echo "➡️ Building the images..."
  c build --pull
fi

echo "➡️ Starting the database..."
c up -d --wait --no-build database

# The new image's plan against the live database (#180); a first deploy has no php container yet and nothing to keep.
pending=0
if [ -n "$(c ps -a -q php)" ]; then
  echo "➡️ Checking for pending migrations..."
  plan=$(c run --rm --no-deps -T -e SKIP_MIGRATIONS=true -e PGOPTIONS="-c default_transaction_read_only=on" php bin/console app:database:migrations-plan) \
    || { echo "$plan"; echo "❌ The migrations plan failed: nothing was deployed." >&2; exit 1; }
  pending=$(printf '%s\n' "$plan" | sed -n 's/^CWA_MIGRATIONS_PENDING=\([0-9]*\).*/\1/p' | tail -n 1)
  echo "Pending migrations: ${pending:-0}"
fi
if [ "${pending:-0}" -gt 0 ]; then
  echo "➡️ Backing up before the migrations..."
  sh bin/server/backup.sh
fi

# The front end first, so no old-build SSR renders into the new API's cache (#71); php migrates as it starts (#85).
echo "➡️ Starting the front end, then the API..."
c up -d --wait --no-build --no-deps app
c up -d --wait --no-build php
c up -d --wait --no-build

if [ "$fixtures" = "true" ]; then
  echo "➡️ Loading the fixtures (append)..."
  c exec -T php bin/console doctrine:fixtures:load --append --no-interaction
fi

# Cached pages reference the old /_nuxt files (#71).
echo "➡️ Purging rendered HTML..."
c exec -T php bin/console silverback:api-components:purge-rendered-html
warm_api

status=0
generate_image_variants || status=$?

# The sitemap's pages, from this machine: the request never leaves it, whatever DNS says.
echo "➡️ Warming the page cache..."
CWA_CI_WARM_CACHE_CURL_OPTS="--resolve $SITE_HOST:443:127.0.0.1" warm_cache "https://$SITE_HOST" \
  || echo "WARNING: the page warm failed (above); the site is deployed, and pages render on their first visit." >&2

[ "$status" -eq 0 ] || { echo "❌ Deployed, but image variants failed (exit $status, above)." >&2; exit "$status"; }
echo "✅ Deployed https://$SITE_HOST"
