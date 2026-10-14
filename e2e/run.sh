#!/bin/sh
# Runs the browser tests (#157) against production images: E2E_PHP_IMAGE and E2E_APP_IMAGE.
# Needs docker (with compose) and openssl. Reports land in e2e/playwright-report and e2e/test-results.
# E2E_ARGS passes Playwright arguments (a spec file, --grep …); the every-test-ran check is skipped then.
# E2E_KEEP_STACK=true leaves the stack running afterwards (docker compose -f e2e/compose.yaml down -v to stop it).
set -eu

cd "$(dirname "$0")"
: "${E2E_PHP_IMAGE:?set E2E_PHP_IMAGE to the php image (frankenphp_prod)}"
: "${E2E_APP_IMAGE:?set E2E_APP_IMAGE to the app image (prod)}"

# Throwaway secrets: this stack only lives for one run.
rand() { openssl rand -hex 24; }
E2E_APP_SECRET=$(rand)
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
export E2E_APP_SECRET E2E_MERCURE_JWT_SECRET E2E_JWT_PASSPHRASE E2E_ADMIN_PASSWORD E2E_JWT_SECRET_KEY E2E_JWT_PUBLIC_KEY

compose() { docker compose -f compose.yaml "$@"; }
cleanup() {
  status=$?
  if [ "$status" -ne 0 ]; then
    echo "---- php and app logs (last 80 lines each) ----"
    compose logs --tail 80 php app 2>&1 || true
  fi
  if [ "${E2E_KEEP_STACK:-}" = "true" ]; then
    echo "Stack left running; admin password: $E2E_ADMIN_PASSWORD"
  else
    compose --profile tests down -v --remove-orphans >/dev/null 2>&1 || true
  fi
  exit "$status"
}
trap cleanup EXIT

compose pull --quiet --ignore-pull-failures database gcs mailpit php app
compose up -d database gcs mailpit php app

echo "Waiting for the API (migrations run on boot)..."
tries=0
until compose exec -T php curl -fsk -o /dev/null https://localhost/_api/_/site_config_parameters.jsonld; do
  tries=$((tries + 1))
  if [ "$tries" -gt 90 ]; then echo "The API never answered." >&2; exit 1; fi
  sleep 2
done

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
  compose --profile tests run --name cwa-e2e-tests tests node forward.mjs "npx playwright test $E2E_ARGS"
else
  compose --profile tests run --name cwa-e2e-tests tests
fi
tests_status=$?
set -e
docker cp cwa-e2e-tests:/e2e/playwright-report ./playwright-report >/dev/null 2>&1 || true
docker cp cwa-e2e-tests:/e2e/test-results ./test-results >/dev/null 2>&1 || true
docker rm -f cwa-e2e-tests >/dev/null 2>&1 || true

# A 5xx the UI hid still sends the production error mail (#162).
error_mails=$(compose exec -T php curl -fs 'http://mailpit:8025/api/v1/search?query=to:errors@cwa.test' | sed -n 's/.*"messages_count":\([0-9]*\).*/\1/p')
if [ "${error_mails:-0}" != "0" ]; then
  echo "The API answered with a server error during the run: $error_mails error mail(s). See the php log above or in the stack." >&2
  tests_status=1
fi
exit "$tests_status"
