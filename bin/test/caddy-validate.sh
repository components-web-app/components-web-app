#!/bin/sh
# Provisions the API's Caddyfile without starting the server, for each SERVER_NAME
# shape the template runs with: helm's ":80" (one server) and compose's
# "localhost, php.local:80, php.local:443" (one server per port).
#
# `frankenphp adapt` only parses. Errors raised while modules provision, such as
# Mercure >= 1.0.3 refusing a second unnamed hub, pass `adapt` and only show when
# php fails to start (#113). `validate` provisions every module, so it catches them.
# https://github.com/components-web-app/components-web-app/issues/113
#
# Runs in the API image (the CI unit-tests job, or `docker compose exec php`). The
# job's own environment is kept, so a project's CADDY_* settings are validated too;
# only the variables the Caddyfile needs without a default are set here, with
# throwaway values.
# Usage: bin/test/caddy-validate.sh [path-to-frankenphp] [path-to-Caddyfile]
set -eu

BIN="${1:-frankenphp}"
CONFIG="${2:-/etc/caddy/Caddyfile}"
# The prod worker's path is relative (`./public/index.php`), so validate from the
# app's root, as php runs: the image's /app, else this checkout's api/.
for dir in /app "$(dirname "$0")/../../api"; do
	if [ -f "$dir/public/index.php" ]; then
		cd "$dir"
		break
	fi
done
KEY='!ChangeThisMercureHubJWTSecretKey!-validate-only'
OUT=$(mktemp)
trap 'rm -f "$OUT"' EXIT

status=0
for server_name in ':80' 'localhost, php.local:80, php.local:443'; do
	if env \
		SERVER_NAME="$server_name" \
		BROWSER_SERVER_NAME=localhost \
		APP_UPSTREAM=app:3000 \
		MERCURE_PUBLISHER_JWT_KEY="$KEY" \
		MERCURE_SUBSCRIBER_JWT_KEY="$KEY" \
		MERCURE_PUBLISHER_JWT_ALG=HS256 \
		MERCURE_SUBSCRIBER_JWT_ALG=HS256 \
		MERCURE_PUBLIC_URL=https://localhost/.well-known/mercure \
		"$BIN" validate --config "$CONFIG" --adapter caddyfile >"$OUT" 2>&1; then
		echo "ok:   SERVER_NAME='$server_name'"
	else
		echo "FAIL: SERVER_NAME='$server_name'"
		grep -E '"level":"error"|^Error' "$OUT" || tail -n 20 "$OUT"
		status=1
	fi
done

if [ "$status" -ne 0 ]; then
	echo "The Caddyfile parses but doesn't provision: php would not start." >&2
fi
exit "$status"
