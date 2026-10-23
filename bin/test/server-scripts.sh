#!/bin/sh
# Template CI only (#212): runs bin/server's init, deploy (twice), backup and restore against this ref's images, on
# compose.prod.yaml plus the browser tests' stand-ins (e2e/compose.yaml). Needs docker with compose and openssl.
# Usage (repository root): E2E_PHP_IMAGE=… E2E_APP_IMAGE=… sh bin/test/server-scripts.sh
set -eu

: "${E2E_PHP_IMAGE:?set E2E_PHP_IMAGE to the php image (frankenphp_prod)}"
: "${E2E_APP_IMAGE:?set E2E_APP_IMAGE to the app image (prod)}"
[ -f bin/server/deploy.sh ] || { echo "Run from the repository root." >&2; exit 2; }
failures=0
pass() { echo "ok: $*"; }
fail() { echo "FAILED: $*" >&2; failures=$((failures + 1)); }

env_file=.env.server-test
backups=$(mktemp -d)
log=$(mktemp)
# A clean environment, so a CI job's deploy variables (TRUSTED_HOSTS, DATABASE_URL…) never reach compose.
server() {
  env -i PATH="$PATH" HOME="${HOME:-/tmp}" ${DOCKER_HOST:+DOCKER_HOST="$DOCKER_HOST"} \
    CWA_SERVER_ENV_FILE="$env_file" CWA_SERVER_BACKUP_DIR="$backups" "$@"
}
c() { server docker compose --env-file "$env_file" "$@"; }
cleanup() {
  status=$?
  [ "$status" -eq 0 ] || c logs --tail 60 php app 2>&1 || true
  c --profile tests down -v --remove-orphans >/dev/null 2>&1 || true
  rm -rf "$env_file" "$backups" "$log"
  exit "$status"
}
trap cleanup EXIT
[ ! -e "$env_file" ] || { echo "$env_file exists: a previous run didn't clean up." >&2; exit 1; }

# 1. init writes the settings; refuses to overwrite them.
server SITE_HOST=localhost MAILER_DSN=smtp://mailpit:1025 sh bin/server/init > "$log" 2>&1 \
  && [ "$(stat -c %a "$env_file" 2>/dev/null || stat -f %Lp "$env_file")" = 600 ] \
  && pass "init writes $env_file, mode 600" || { fail "init: $(cat "$log")"; exit 1; }
if server SITE_HOST=localhost MAILER_DSN=x sh bin/server/init > "$log" 2>&1; then fail "init overwrote $env_file"; else pass "init refuses to overwrite"; fi
# This ref's images and the CI stand-ins instead of a build, in a project of its own.
sed -i.bak 's#^COMPOSE_FILE=.*#COMPOSE_FILE=compose.yaml:compose.prod.yaml:e2e/compose.yaml#' "$env_file" && rm -f "$env_file.bak"
{
  echo "COMPOSE_PROJECT_NAME=cwa-server-test"
  echo "E2E_PHP_IMAGE=$E2E_PHP_IMAGE"
  echo "E2E_APP_IMAGE=$E2E_APP_IMAGE"
} >> "$env_file"
admin_password=$(sed -n 's/^ADMIN_PASSWORD=//p' "$env_file")
site() { c exec -T php curl -sk --resolve localhost:443:127.0.0.1 -o /dev/null -w '%{http_code}' "https://localhost$1"; }

# 2. A first deploy with fixtures: the site answers and the admin signs in.
if server sh bin/server/deploy.sh --fixtures > "$log" 2>&1; then
  sed 's/^/  | /' "$log"
  pass "first deploy (with fixtures)"
else
  fail "first deploy: $(tail -n 40 "$log")"; exit 1
fi
[ "$(site /)" = 200 ] && pass "the home page answers 200" || fail "the home page answered $(site /)"
code=$(c exec -T php curl -sk -o /dev/null -w '%{http_code}' -H 'Content-Type: application/json' \
  -d "{\"username\":\"admin\",\"password\":\"$admin_password\"}" https://localhost/_api/login)
[ "$code" = 204 ] && pass "the admin from init signs in" || fail "admin login answered $code"

# 3. A backup, then an upload it doesn't have; the restore takes the upload away again.
server sh bin/server/backup.sh > "$log" 2>&1 && ls "$backups"/*-database.dump "$backups"/*-media.tar.gz >/dev/null 2>&1 \
  && pass "backup writes the database dump and the media archive" || fail "backup: $(tail -n 20 "$log")"
urls=$(c exec -T -e ADMIN_PASSWORD="$admin_password" php sh -s upload < e2e/media-checks.sh) || fail "upload after the backup"
original=$(echo "$urls" | cut -d' ' -f1)
path=${original#https://localhost}
if server sh bin/server/restore.sh --yes > "$log" 2>&1; then pass "restore"; else fail "restore: $(tail -n 30 "$log")"; fi
[ "$(site "$path")" = 404 ] && pass "the restore removed the upload made after the backup" || fail "after the restore $path answered $(site "$path")"
[ "$(site /)" = 200 ] && pass "the home page answers after the restore" || fail "after the restore the home page answered $(site /)"
c exec -T php bin/console silverback:api-components:maintenance status 2>&1 | grep -qi 'off' \
  && pass "maintenance is off after the restore" || fail "maintenance isn't off after the restore"

# 4. Deploying again changes nothing it shouldn't: no pending migrations, the site still answers.
if server sh bin/server/deploy.sh > "$log" 2>&1 && grep -q 'Pending migrations: 0' "$log"; then
  sed 's/^/  | /' "$log"
  pass "a second deploy (no pending migrations)"
else
  fail "second deploy: $(tail -n 40 "$log")"
fi
[ "$(site /)" = 200 ] && pass "the home page answers after the second deploy" || fail "after the second deploy the home page answered $(site /)"

[ "$failures" -eq 0 ] || { echo "$failures check(s) failed." >&2; exit 1; }
echo "bin/server checks passed."
