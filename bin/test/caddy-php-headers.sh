#!/bin/sh
# Regression test (#224, #225), on the real Caddyfile: SSR's API responses carry no Surrogate-Key yet stay purgeable by
# tag, and php gets the visitor Caddy resolves (CWA_VISITOR_IP), never one a request header sets. No database needed.
# Usage: bin/test/caddy-php-headers.sh [path-to-frankenphp] [Caddyfile]
set -eu

BIN="${1:-frankenphp}"
CONFIG="${2:-/etc/caddy/Caddyfile}"
PORT=18088
DIR=$(mktemp -d)
PID=
trap 'kill "$PID" 2>/dev/null || true; rm -rf "$DIR"' EXIT

# php's stand-in: a cacheable collection tagged with 2,500 members (~35 KB of Surrogate-Key), and /_api/me (never
# cached) echoing the visitor.
mkdir "$DIR/public"
cat > "$DIR/public/index.php" <<'PHP'
<?php
if (str_starts_with($_SERVER['REQUEST_URI'], '/_api/me')) {
    header('Cache-Control: no-store, private');
    echo $_SERVER['CWA_VISITOR_IP'] ?? '(unset)';
    return;
}
file_put_contents(__DIR__ . '/../calls', "x\n", FILE_APPEND);
header('Content-Type: application/ld+json');
header('Cache-Control: public, s-maxage=3600');
header('Surrogate-Key: ' . implode(', ', [...array_map(static fn (int $i): string => "/_api/c/$i", range(1, 2500)), '/_api/c']));
echo '{}';
PHP

# A copy with php's root in the test directory, beside an empty worker.Caddyfile and the hub settings it imports.
sed "s#root \* /app/public#root * $DIR/public#" "$CONFIG" >"$DIR/Caddyfile"
cp "$(dirname "$CONFIG")/mercure-hub.caddy" "$DIR/"
: >"$DIR/worker.Caddyfile"

env \
	SERVER_NAME=":$PORT" \
	BROWSER_SERVER_NAME=localhost \
	APP_UPSTREAM=127.0.0.1:1 \
	MERCURE_PUBLISHER_JWT_KEY='!ChangeThisMercureHubJWTSecretKey!-test-only' \
	MERCURE_SUBSCRIBER_JWT_KEY='!ChangeThisMercureHubJWTSecretKey!-test-only' \
	MERCURE_PUBLIC_URL=https://localhost/.well-known/mercure \
	"$BIN" run --config "$DIR/Caddyfile" --adapter caddyfile >"$DIR/log" 2>&1 &
PID=$!
i=0
until [ "$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:$PORT/_api/me")" = 200 ]; do
	i=$((i + 1))
	if [ "$i" -gt 50 ]; then tail -n 5 "$DIR/log"; echo "FAIL: server did not start"; exit 1; fi
	sleep 0.2
done

FAILED=0
fail() { echo "FAIL: $*"; FAILED=1; }
# api <host> <want hit|stored>: GET the collection; leaves its headers in $DIR/h
api() {
	curl -s -o /dev/null -D "$DIR/h" -H "Host: $1" -H 'Accept: application/ld+json' "http://127.0.0.1:$PORT/_api/c"
	status=$(grep -i '^cache-status:' "$DIR/h" | grep -o -E 'hit|stored' || true)
	[ "$status" = "$2" ] || fail "[$1] cache '$status', want '$2'"
}
has() { grep -qi "^$1:" "$DIR/h"; }

api php.local stored
! has surrogate-key || fail "SSR's miss still carries Surrogate-Key"
api php.local hit
! has surrogate-key || fail "SSR's hit still carries Surrogate-Key"
api example.com stored
has surrogate-key || fail "a public host lost Surrogate-Key"
has cache-tag || fail "a public host lost Cache-Tag"

# Souin still holds every tag: purging one member drops SSR's entry.
curl -s -o /dev/null -X PURGE -H 'Surrogate-Key: /_api/c/2499' http://localhost:2019/souin-api/souin
sleep 0.5
api php.local stored

# visitor <want> [curl header args...]: from 127.0.0.1, a trusted proxy, so X-Forwarded-For gives {client_ip}.
visitor() {
	want=$1; shift
	got=$(curl -s "$@" "http://127.0.0.1:$PORT/_api/me")
	[ "$got" = "$want" ] || fail "visitor '$got', want '$want' ($*)"
}
visitor 127.0.0.1
visitor 198.51.100.7 -H 'X-Forwarded-For: 198.51.100.7'
visitor 203.0.113.9 -H 'X-Forwarded-For: 162.158.1.1' -H 'CF-Connecting-IP: 203.0.113.9'
visitor 198.51.100.7 -H 'X-Forwarded-For: 198.51.100.7' -H 'CF-Connecting-IP: 203.0.113.9'
visitor 198.51.100.7 -H 'X-Forwarded-For: 198.51.100.7' -H 'CWA-Visitor-IP: 6.6.6.6' -H 'CWA_VISITOR_IP: 6.6.6.6'

if [ "$FAILED" -ne 0 ]; then tail -n 5 "$DIR/log"; exit 1; fi
echo "OK: SSR's API responses carry no Surrogate-Key and stay purgeable; php gets Caddy's visitor"
