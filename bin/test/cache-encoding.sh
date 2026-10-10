#!/bin/sh
# Regression test (#145): the real Caddyfile caches pages compressed, one entry per normalised Accept-Encoding. No database needed.
# Usage: bin/test/cache-encoding.sh [path-to-frankenphp] [Caddyfile]
set -eu

BIN="${1:-frankenphp}"
CONFIG="${2:-/etc/caddy/Caddyfile}"
PORT=18086
UPSTREAM=18087
DIR=$(mktemp -d)
PID=
PHP_PID=
trap 'kill "$PID" "$PHP_PID" 2>/dev/null || true; rm -rf "$DIR"' EXIT

# The app's stand-in: a cacheable page that counts its renders.
cat > "$DIR/upstream.php" <<'PHP'
<?php
file_put_contents(__DIR__ . '/calls', "x\n", FILE_APPEND);
header('Content-Type: text/html; charset=utf-8');
header('Cache-Control: public, s-maxage=3600');
echo '<!doctype html><html><body>' . str_repeat('<div class="cwa">component</div>', 2000) . '</body></html>';
PHP

# A copy beside an empty worker.Caddyfile, so php isn't booted in worker mode.
cp "$CONFIG" "$DIR/Caddyfile"
: >"$DIR/worker.Caddyfile"

php -n -S "127.0.0.1:$UPSTREAM" "$DIR/upstream.php" >"$DIR/php.log" 2>&1 &
PHP_PID=$!
env \
	SERVER_NAME=":$PORT" \
	BROWSER_SERVER_NAME=localhost \
	APP_UPSTREAM="127.0.0.1:$UPSTREAM" \
	CADDY_CACHE_EXTRA_CONFIG=otter \
	MERCURE_PUBLISHER_JWT_KEY='!ChangeThisMercureHubJWTSecretKey!-test-only' \
	MERCURE_SUBSCRIBER_JWT_KEY='!ChangeThisMercureHubJWTSecretKey!-test-only' \
	MERCURE_PUBLIC_URL=https://localhost/.well-known/mercure \
	"$BIN" run --config "$DIR/Caddyfile" --adapter caddyfile >"$DIR/log" 2>&1 &
PID=$!
i=0
until [ "$(curl -s -o /dev/null -w '%{http_code}' -H 'Accept-Encoding: br' "http://localhost:$PORT/cache-encoding-warmup")" = 200 ]; do
	i=$((i + 1))
	if [ "$i" -gt 50 ]; then tail -n 5 "$DIR/log" "$DIR/php.log"; echo "FAIL: servers did not start"; exit 1; fi
	sleep 0.2
done
rm -f "$DIR/calls"

FAILED=0
# get <n> <Accept-Encoding> <want Content-Encoding> <want hit|stored>
get() {
	curl -s -o "$DIR/body.$1" -D "$DIR/head.$1" -H "Accept-Encoding: $2" -H 'Accept: text/html' "http://localhost:$PORT/page"
	enc=$(grep -i '^content-encoding:' "$DIR/head.$1" | cut -d: -f2 | tr -d ' \r')
	status=$(grep -i '^cache-status:' "$DIR/head.$1" | grep -o -E 'hit|stored' || true)
	if [ "$enc" != "$3" ] || [ "$status" != "$4" ]; then
		echo "FAIL: [$2] got encoding '$enc', cache '$status'; want '$3', '$4'"
		FAILED=1
	fi
}
get 1 'gzip, deflate, br, zstd' br stored
get 2 'br, gzip' br hit
get 3 'gzip, deflate' gzip stored
get 4 'GZIP' gzip hit
get 5 '' '' stored
get 6 'zstd' '' hit
cmp -s "$DIR/body.1" "$DIR/body.2" || { echo "FAIL: the br hit's body differs from the stored one"; FAILED=1; }
cmp -s "$DIR/body.3" "$DIR/body.4" || { echo "FAIL: the gzip hit's body differs from the stored one"; FAILED=1; }

CALLS=$(wc -l <"$DIR/calls" | tr -d ' ')
[ "$CALLS" -eq 3 ] || { echo "FAIL: upstream called $CALLS times, want 3 (one per encoding)"; FAILED=1; }

if [ "$FAILED" -ne 0 ]; then exit 1; fi
echo "OK: pages are cached compressed, one entry per encoding"
