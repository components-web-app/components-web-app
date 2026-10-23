#!/bin/sh
# compose.prod.yaml renders with every required value, refuses to without each one, and keeps the settings
# the Kubernetes deploy sets (#207). The dev stack still renders with no values at all. Needs only the compose CLI.
# Usage (repository root): sh bin/test/compose-prod-config.sh
set -eu

failures=0
pass() { echo "ok: $*"; }
fail() { echo "FAILED: $*" >&2; failures=$((failures + 1)); }
out=$(mktemp)
trap 'rm -f "$out"' EXIT

# The template's own required values; a project's extra ${NAME:?…} values are found in the files and tested too.
TEMPLATE_REQUIRED="SITE_HOST APP_SECRET NUXT_APP_SECRET CADDY_MERCURE_JWT_SECRET POSTGRES_PASSWORD JWT_SECRET_KEY JWT_PUBLIC_KEY
  JWT_PASSPHRASE MAILER_DSN ADMIN_PASSWORD"
REQUIRED=$(grep -ho '[$]{[A-Za-z_][A-Za-z0-9_]*:[?]' compose.yaml compose.prod.yaml | sed 's/^[$]{//; s/:[?]$//' | sort -u | tr '\n' ' ')
for name in $TEMPLATE_REQUIRED; do
  case " $REQUIRED " in *" $name "*) ;; *) fail "$name is no longer required (\${$name:?…})" ;; esac
done
# A clean environment, so neither the caller's variables nor a local .env decide the result.
prod() { env -i PATH="$PATH" HOME="${HOME:-/tmp}" "$@" docker compose --env-file /dev/null -f compose.yaml -f compose.prod.yaml config; }
values() { for name in $REQUIRED; do printf ' %s=dummy-%s' "$name" "$name"; done; }

# shellcheck disable=SC2046
if prod $(values) SITE_HOST=example.com SITE_ALIASES=www.example.com > "$out" 2>&1; then
  pass "renders with every required value"
else
  fail "doesn't render with every required value: $(cat "$out")"
fi
has() { grep -qF -- "$1" "$out" && pass "$2" || fail "$2: no '$1' in the rendered config"; }
has 'SERVER_NAME: example.com www.example.com, php.local:80, php.local:443' "Caddy serves SITE_HOST, SITE_ALIASES and php.local"
has 'BROWSER_SERVER_NAME: example.com' "BROWSER_SERVER_NAME is SITE_HOST alone"
has 'NUXT_SITE_URL: https://example.com' "NUXT_SITE_URL (#140)"
has 'NUXT_PUBLIC_CWA_API_URL_BROWSER: https://example.com/_api' "the browser's API URL"
has 'NUXT_CWA_API_URL: http://php.local/_api' "SSR's API URL (#98)"
has 'MERCURE_PUBLIC_URL: https://example.com/.well-known/mercure' "the Mercure public URL"
has 'MAILER_DSN: dummy-MAILER_DSN' "MAILER_DSN"
has 'TRUSTED_HOSTS: ""' "TRUSTED_HOSTS left to the entrypoint"
has 'MEDIA_STORAGE: local' "media is local by default (#211)"
has 'target: /app/public/uploads' "media is in a volume, so it outlives php (#211)"
has 'max-size: 10m' "log rotation"
has 'condition: service_healthy' "php waits for a healthy database"
if grep -q '2019' "$out"; then fail "port 2019 (Caddy admin) appears in the config"; else pass "port 2019 isn't published"; fi
[ "$(grep -c 'restart: unless-stopped' "$out")" -ge 3 ] && pass "php, app and database restart" || fail "a service has no restart policy"

for name in $REQUIRED; do
  # shellcheck disable=SC2046
  if prod $(values | sed "s/ $name=[^ ]*//") > "$out" 2>&1; then
    fail "renders without $name"
  elif grep -q "$name" "$out"; then
    pass "refuses without $name"
  else
    fail "refuses without $name, but the error doesn't name it: $(cat "$out")"
  fi
done

# The dev stack needs nothing set.
if env -i PATH="$PATH" HOME="${HOME:-/tmp}" docker compose --env-file /dev/null config > "$out" 2>&1; then
  pass "the dev stack (compose.yaml + compose.override.yaml) renders with no values"
else
  fail "the dev stack doesn't render: $(cat "$out")"
fi

[ "$failures" -eq 0 ] || { echo "$failures check(s) failed." >&2; exit 1; }
echo "compose.prod.yaml checks passed."
