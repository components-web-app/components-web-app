#!/bin/sh
# Provisions the Caddyfile (`validate`, which catches what `adapt` passes) for helm's and compose's SERVER_NAME (#113, #207).
# Runs in the API image with the job's CADDY_* env. Usage: bin/test/caddy-validate.sh [frankenphp] [Caddyfile]
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
# php's own hub, then scaled mode's (#85): php forwarding to the hub's pod.
for hub_upstream in '' 'example-mercure:80'; do
# compose.prod.yaml's shapes too (#207): SITE_HOST alone leaves a space before the comma; SITE_ALIASES is space-separated.
for server_name in ':80' 'localhost, php.local:80, php.local:443' 'example.com , php.local:80, php.local:443' \
	'example.com www.example.com other.example.org, php.local:80, php.local:443'; do
	if env \
		MERCURE_HUB_UPSTREAM="$hub_upstream" \
		SERVER_NAME="$server_name" \
		BROWSER_SERVER_NAME=localhost \
		APP_UPSTREAM=app:3000 \
		MERCURE_PUBLISHER_JWT_KEY="$KEY" \
		MERCURE_SUBSCRIBER_JWT_KEY="$KEY" \
		MERCURE_PUBLISHER_JWT_ALG=HS256 \
		MERCURE_SUBSCRIBER_JWT_ALG=HS256 \
		MERCURE_PUBLIC_URL=https://localhost/.well-known/mercure \
		"$BIN" validate --config "$CONFIG" --adapter caddyfile >"$OUT" 2>&1; then
		echo "ok:   SERVER_NAME='$server_name' MERCURE_HUB_UPSTREAM='$hub_upstream'"
	else
		echo "FAIL: SERVER_NAME='$server_name' MERCURE_HUB_UPSTREAM='$hub_upstream'"
		grep -E '"level":"error"|^Error' "$OUT" || tail -n 20 "$OUT"
		status=1
	fi
done
done

# Scaled mode's hub pod, from the same directory (it imports mercure-hub.caddy).
if env \
	MERCURE_PUBLISHER_JWT_KEY="$KEY" \
	MERCURE_SUBSCRIBER_JWT_KEY="$KEY" \
	MERCURE_PUBLISHER_JWT_ALG=HS256 \
	MERCURE_SUBSCRIBER_JWT_ALG=HS256 \
	MERCURE_PUBLIC_URL=https://localhost/.well-known/mercure \
	"$BIN" validate --config "$(dirname "$CONFIG")/mercure-hub.Caddyfile" --adapter caddyfile >"$OUT" 2>&1; then
	echo "ok:   mercure-hub.Caddyfile"
else
	echo "FAIL: mercure-hub.Caddyfile"
	grep -E '"level":"error"|^Error' "$OUT" || tail -n 20 "$OUT"
	status=1
fi

if [ "$status" -ne 0 ]; then
	echo "The Caddyfile parses but doesn't provision: php would not start." >&2
fi
exit "$status"
