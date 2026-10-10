#!/bin/sh
# Regression test (#137): requests coalesced onto a 5xx must all get that 5xx, never an empty 200. No database needed.
# Usage: bin/test/souin-coalesced-5xx.sh [path-to-frankenphp]
set -eu

BIN="${1:-frankenphp}"
PORT=18082
UPSTREAM=18083
ADMIN=localhost:12021
DIR=$(mktemp -d)
PID=
PHP_PID=
trap 'kill "$PID" "$PHP_PID" 2>/dev/null || true; rm -rf "$DIR"' EXIT

# A slow failing upstream, so the later requests join the first one's call.
cat > "$DIR/upstream.php" <<'PHP'
<?php
file_put_contents(__DIR__ . '/calls', "x\n", FILE_APPEND);
usleep(700000);
http_response_code(500);
header('Content-Type: text/plain');
echo 'UPSTREAM_ERROR';
PHP

cat > "$DIR/Caddyfile" <<CADDY
{
	admin $ADMIN
	auto_https off
	cache {
		ttl 1h
	}
}

:$PORT {
	route {
		cache
		reverse_proxy 127.0.0.1:$UPSTREAM
	}
}
CADDY

php -S "127.0.0.1:$UPSTREAM" "$DIR/upstream.php" >"$DIR/php.log" 2>&1 &
PHP_PID=$!
"$BIN" run --config "$DIR/Caddyfile" --adapter caddyfile >"$DIR/log" 2>&1 &
PID=$!
i=0
until [ "$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:$PORT/warmup")" = 500 ]; do
	i=$((i + 1))
	if [ "$i" -gt 50 ]; then cat "$DIR/log" "$DIR/php.log"; echo "FAIL: servers did not start"; exit 1; fi
	sleep 0.2
done
rm -f "$DIR/calls"

N=5
CURLS=
for n in $(seq 1 "$N"); do
	curl -s -o "$DIR/body.$n" -w '%{http_code}' "http://localhost:$PORT/coalesced" >"$DIR/code.$n" &
	CURLS="$CURLS $!"
	if [ "$n" -eq 1 ]; then sleep 0.2; fi
done
# shellcheck disable=SC2086
wait $CURLS

FAILED=0
CALLS=$(wc -l <"$DIR/calls" | tr -d ' ')
[ "$CALLS" -eq 1 ] || { echo "FAIL: upstream called $CALLS times, want 1 (requests not coalesced, so this test proves nothing)"; FAILED=1; }
for n in $(seq 1 "$N"); do
	code=$(cat "$DIR/code.$n")
	body=$(cat "$DIR/body.$n")
	if [ "$code" != 500 ] || [ "$body" != UPSTREAM_ERROR ]; then
		echo "FAIL: request $n got $code \"$body\", want 500 \"UPSTREAM_ERROR\""
		FAILED=1
	fi
done

if [ "$FAILED" -ne 0 ]; then exit 1; fi
echo "OK: every coalesced request got the upstream's 500"
