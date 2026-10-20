#!/bin/sh
# Runs the browser tests (#157) against the E2E_PHP_IMAGE and E2E_APP_IMAGE production images.
# Options (E2E_ARGS, E2E_KEEP_STACK) are in e2e/README.md.
set -eu

cd "$(dirname "$0")"
: "${E2E_PHP_IMAGE:?set E2E_PHP_IMAGE to the php image (frankenphp_prod)}"
: "${E2E_APP_IMAGE:?set E2E_APP_IMAGE to the app image (prod)}"

# Throwaway secrets: this stack only lives for one run.
rand() { openssl rand -hex 24; }
E2E_APP_SECRET=$(rand)
E2E_NUXT_APP_SECRET=$(rand)
E2E_MERCURE_JWT_SECRET=$(rand)
E2E_JWT_PASSPHRASE=$(rand)
E2E_ADMIN_PASSWORD=$(rand)
keydir=$(mktemp -d)
# Derive both keys from a plain one, so nothing has to read the passphrase back.
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out "$keydir/plain.pem"
openssl pkey -in "$keydir/plain.pem" -pubout -out "$keydir/public.pem"
openssl pkey -in "$keydir/plain.pem" -aes256 -passout "pass:$E2E_JWT_PASSPHRASE" -out "$keydir/private.pem"
E2E_JWT_SECRET_KEY=$(cat "$keydir/private.pem")
E2E_JWT_PUBLIC_KEY=$(cat "$keydir/public.pem")
rm -rf "$keydir"
export E2E_APP_SECRET E2E_NUXT_APP_SECRET E2E_MERCURE_JWT_SECRET E2E_JWT_PASSPHRASE E2E_ADMIN_PASSWORD E2E_JWT_SECRET_KEY E2E_JWT_PUBLIC_KEY

# One stack per checkout, so two projects' local runs never share or tear down each other's (#178).
project=$(printf '%s' "${COMPOSE_PROJECT_NAME:-cwa-e2e-$(basename "$(cd .. && pwd)")}" | tr 'A-Z' 'a-z' | tr -c 'a-z0-9_-' '-')
tests_container="$project-tests"
# E2E_SCALED=true: two php replicas on one Redis cache and one Mercure hub (#85).
files="-f compose.yaml"
[ "${E2E_SCALED:-}" = "true" ] && files="$files -f compose.scaled.yaml"
# shellcheck disable=SC2086
compose() { docker compose -p "$project" $files "$@"; }
cleanup() {
  status=$?
  if [ "$status" -ne 0 ]; then
    echo "---- php and app logs (last 80 lines each) ----"
    compose logs --tail 80 php app 2>&1 || true
  fi
  if [ "${E2E_KEEP_STACK:-}" = "true" ]; then
    echo "Stack $project left running; admin password: $E2E_ADMIN_PASSWORD"
    echo "Stop it with: docker compose -p $project -f e2e/compose.yaml down -v"
  else
    compose --profile tests down -v --remove-orphans >/dev/null 2>&1 || true
  fi
  exit "$status"
}
trap cleanup EXIT

compose pull --quiet --ignore-pull-failures
# The images' healthchecks: php and its database, then Node (#205). Never the tests service, which exits by design.
echo "Starting the stack and waiting for it to be healthy (migrations run on boot)..."
compose up -d --wait --wait-timeout 300 database gcs mailpit php app

compose exec -T php curl -fs -o /dev/null -X POST -H 'Content-Type: application/json' -d '{"name":"cwa-e2e"}' http://gcs:8000/storage/v1/b
compose exec -T -e SKIP_MERCURE_PUBLISH=true php bin/console doctrine:fixtures:load --no-interaction
compose exec -T php bin/console silverback:api-components:purge-http-cache --quiet

echo "Waiting for the site..."
tries=0
until compose exec -T php curl -fsk -o /dev/null -H 'Accept: text/html' https://localhost/; do
  tries=$((tries + 1))
  if [ "$tries" -gt 60 ]; then echo "The site never answered." >&2; exit 1; fi
  sleep 2
done

rm -rf playwright-report test-results
compose --profile tests build --quiet tests
set +e
if [ -n "${E2E_ARGS:-}" ]; then
  compose --profile tests run --name "$tests_container" tests node forward.mjs "npx playwright test $E2E_ARGS"
else
  compose --profile tests run --name "$tests_container" tests
fi
tests_status=$?
set -e
docker cp "$tests_container":/e2e/playwright-report ./playwright-report >/dev/null 2>&1 || true
docker cp "$tests_container":/e2e/test-results ./test-results >/dev/null 2>&1 || true
docker rm -f "$tests_container" >/dev/null 2>&1 || true

# A 5xx the UI hid still sends the production error mail (#162).
error_mails=$(compose exec -T php curl -fs 'http://mailpit:8025/api/v1/search?query=to:errors@cwa.test' | sed -n 's/.*"messages_count":\([0-9]*\).*/\1/p')
if [ "${error_mails:-0}" != "0" ]; then
  echo "The API answered with a server error during the run: $error_mails error mail(s). See the php log above or in the stack." >&2
  tests_status=1
fi

# Every object stays under GCLOUD_PATH_PREFIX, and the stop-review delete empties it (#166).
objects() { compose exec -T php curl -fs "http://gcs:8000/storage/v1/b/cwa-e2e/o$1" | grep -o '"name": *"[^"]*"' | wc -l | tr -d ' '; }
outside=$(( $(objects '') - $(objects '?prefix=review/e2e/') ))
compose exec -T php sh -c 'exec php bin/console silverback:api-components:delete-stored-files gcloud --all --only-if-value="$GCLOUD_PATH_PREFIX" --matching="~(^|/)review/[^/]+/\$~"'
left=$(objects '')
if [ "$outside" != "0" ] || [ "$left" != "0" ]; then
  echo "Storage prefix: $outside object(s) outside review/e2e/, $left left after delete-stored-files." >&2
  tests_status=1
fi
exit "$tests_status"
