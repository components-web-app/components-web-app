#!/bin/sh
# Regression test (#170): the real Caddyfile waits 30s for a slow cold render (not Souin's 10s), and caches in otter. No database needed.
# Usage: bin/test/souin-backend-timeout.sh [path-to-frankenphp] [Caddyfile]
set -eu

BIN="${1:-frankenphp}"
CONFIG="${2:-/etc/caddy/Caddyfile}"
PORT=18088
UPSTREAM=18089
DIR=$(mktemp -d)
PID=
PHP_PID=
trap 'kill "$PID" "$PHP_PID" 2>/dev/null || true; rm -rf "$DIR"' EXIT

# The app's stand-in: a cacheable page that renders in 12s (#170's cold home page) and counts its renders.
cat > "$DIR/upstream.php" <<'PHP'
<?php
if (str_starts_with($_SERVER['REQUEST_URI'], '/slow')) {
    file_put_contents(__DIR__ . '/calls', "x\n", FILE_APPEND);
    sleep(12);
}
header('Content-Type: text/html; charset=utf-8');
header('Cache-Control: public, s-maxage=3600');
echo '<!doctype html><html><body>page</body></html>';
PHP

# A copy beside an empty worker.Caddyfile, so php isn't booted in worker mode, and the hub settings it imports (#85).
cp "$CONFIG" "$DIR/Caddyfile"
cp "$(dirname "$CONFIG")/mercure-hub.caddy" "$DIR/"
: >"$DIR/worker.Caddyfile"

PHP_CLI_SERVER_WORKERS=4 php -n -S "127.0.0.1:$UPSTREAM" "$DIR/upstream.php" >"$DIR/php.log" 2>&1 &
PHP_PID=$!

# start [VAR=value...]: (re)starts Caddy with the given extra env.
start() {
	if [ -n "$PID" ]; then kill "$PID" 2>/dev/null || true; wait "$PID" 2>/dev/null || true; fi
	env \
		SERVER_NAME=":$PORT" \
		BROWSER_SERVER_NAME=localhost \
		APP_UPSTREAM="127.0.0.1:$UPSTREAM" \
		MERCURE_PUBLISHER_JWT_KEY='!ChangeThisMercureHubJWTSecretKey!-test-only' \
		MERCURE_SUBSCRIBER_JWT_KEY='!ChangeThisMercureHubJWTSecretKey!-test-only' \
		MERCURE_PUBLIC_URL=https://localhost/.well-known/mercure \
		"$@" \
		"$BIN" run --config "$DIR/Caddyfile" --adapter caddyfile >"$DIR/log" 2>&1 &
	PID=$!
	i=0
	until [ "$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:$PORT/backend-timeout-warmup")" = 200 ]; do
		i=$((i + 1))
		if [ "$i" -gt 50 ]; then tail -n 5 "$DIR/log" "$DIR/php.log"; echo "FAIL: servers did not start"; exit 1; fi
		sleep 0.2
	done
	rm -f "$DIR/calls"
}

# get <name> <path>: writes code.<name>, time.<name> (whole seconds) and head.<name>.
get() {
	curl -s -o /dev/null -D "$DIR/head.$1" -w '%{http_code} %{time_total}' -H 'Accept: text/html' "http://localhost:$PORT$2" >"$DIR/out.$1" || true
	cut -d' ' -f1 <"$DIR/out.$1" >"$DIR/code.$1"
	cut -d' ' -f2 <"$DIR/out.$1" | cut -d. -f1 >"$DIR/time.$1"
}
calls() { if [ -f "$DIR/calls" ]; then wc -l <"$DIR/calls" | tr -d ' '; else echo 0; fi; }

FAILED=0
fail() { echo "FAIL: $*"; FAILED=1; }

# (a) The default backend timeout outlasts a 12s render, and the render is stored once.
start
get cold /slow
[ "$(cat "$DIR/code.cold")" = 200 ] || fail "a 12s cold render got $(cat "$DIR/code.cold") after $(cat "$DIR/time.cold")s, want 200 (backend timeout under 12s)"
[ "$(cat "$DIR/time.cold")" -ge 12 ] || fail "the cold render took $(cat "$DIR/time.cold")s, want 12s or more (was it rendered?)"
get warm /slow
grep -i '^cache-status:' "$DIR/head.warm" | grep -q 'hit' || fail "the second request wasn't a Souin hit: $(grep -i '^cache-status:' "$DIR/head.warm" | tr -d '\r')"
[ "$(calls)" -eq 1 ] || fail "upstream called $(calls) times for one page, want 1"

# (b) Concurrent cold requests coalesce onto one render, and all get it.
rm -f "$DIR/calls"
CURLS=
for n in 1 2 3; do
	get "c$n" /slow-coalesced &
	CURLS="$CURLS $!"
	if [ "$n" -eq 1 ]; then sleep 0.5; fi
done
# shellcheck disable=SC2086
wait $CURLS
for n in 1 2 3; do
	[ "$(cat "$DIR/code.c$n")" = 200 ] || fail "coalesced request $n got $(cat "$DIR/code.c$n"), want 200"
done
[ "$(calls)" -eq 1 ] || fail "upstream called $(calls) times for 3 concurrent requests, want 1 (not coalesced)"

# (d) With no CADDY_CACHE_STORAGE the store is otter, not Souin's unbounded default.
if grep -q 'default storage that is not optimized' "$DIR/log"; then fail "Souin fell back to its default storage, want otter"; fi

# (c) CADDY_CACHE_BACKEND_TIMEOUT is read.
start CADDY_CACHE_BACKEND_TIMEOUT=2s
get short /slow-short
[ "$(cat "$DIR/code.short")" = 504 ] || fail "with CADDY_CACHE_BACKEND_TIMEOUT=2s a 12s render got $(cat "$DIR/code.short"), want 504"
grep -i '^cache-status:' "$DIR/head.short" | grep -q 'DEADLINE-EXCEEDED' || fail "the 504 has no DEADLINE-EXCEEDED: $(grep -i '^cache-status:' "$DIR/head.short" | tr -d '\r')"
[ "$(cat "$DIR/time.short")" -lt 10 ] || fail "the 2s timeout took $(cat "$DIR/time.short")s"

if [ "$FAILED" -ne 0 ]; then exit 1; fi
echo "OK: a 12s cold render is served and stored, coalesced, in otter; CADDY_CACHE_BACKEND_TIMEOUT is read"
