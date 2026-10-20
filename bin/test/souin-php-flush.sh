#!/bin/sh
# Regression test (#185): a PHP flush() behind `cache` must not log FrankenPHP's "not a flusher" warning,
# and the cached response must stay whole. No database needed.
# Usage: bin/test/souin-php-flush.sh [path-to-frankenphp]
set -eu

BIN="${1:-frankenphp}"
PORT=18084
ADMIN=localhost:12022
DIR=$(mktemp -d)
PID=
trap 'kill "$PID" 2>/dev/null || true; rm -rf "$DIR"' EXIT

mkdir "$DIR/public"
# Symfony's debug HttpKernelRunner (and any StreamedResponse) ends with flush().
cat > "$DIR/public/index.php" <<'PHP'
<?php
header('Content-Type: text/plain');
header('Cache-Control: public, s-maxage=3600');
echo 'first,';
flush();
echo 'second';
PHP

cat > "$DIR/Caddyfile" <<CADDY
{
	admin $ADMIN
	auto_https off
	cache {
		ttl 1h
		{\$CADDY_CACHE_STORAGE:otter}
	}
}

:$PORT {
	root $DIR/public
	route {
		cache
		php_server
	}
}
CADDY

"$BIN" run --config "$DIR/Caddyfile" --adapter caddyfile >"$DIR/log" 2>&1 &
PID=$!
i=0
until curl -s -o /dev/null "http://localhost:$PORT/warmup.txt"; do
	i=$((i + 1))
	if [ "$i" -gt 50 ]; then cat "$DIR/log"; echo "FAIL: server did not start"; exit 1; fi
	sleep 0.2
done

FAILED=0
miss=$(curl -s -D "$DIR/miss.h" "http://localhost:$PORT/?n=1")
hit=$(curl -s -D "$DIR/hit.h" "http://localhost:$PORT/?n=1")
[ "$miss" = first,second ] || { echo "FAIL: miss body \"$miss\", want \"first,second\""; FAILED=1; }
grep -qi '^cache-status:.*stored' "$DIR/miss.h" || { echo "FAIL: the miss was not stored, so this test proves nothing"; FAILED=1; }
[ "$hit" = first,second ] || { echo "FAIL: hit body \"$hit\", want \"first,second\""; FAILED=1; }
grep -qi '^cache-status:.*hit' "$DIR/hit.h" || { echo "FAIL: the second request was not a hit"; FAILED=1; }
if grep -q 'is not a flusher' "$DIR/log"; then
	echo "FAIL: FrankenPHP logged \"the current responseWriter is not a flusher\" (Souin's writer has no Flush)"
	FAILED=1
fi

if [ "$FAILED" -ne 0 ]; then exit 1; fi
echo "OK: PHP's flush behind the cache logs no warning, and the response is stored whole"
