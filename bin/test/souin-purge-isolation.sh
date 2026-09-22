#!/bin/sh
# Regression test for issue #84 / darkweak/souin#867: a surrogate-key purge must
# not remove the index entry of any other tag. Souin v1.7.9 deletes purged tags
# with an unanchored regex, so purging a collection tag wiped every item's tag and
# left their cached responses unpurgeable. api/Dockerfile carries a patch.
#
# Runs the frankenphp binary on a throwaway Caddyfile: a cache in front of a stub
# that tags each response with its own path, so no php or database is needed.
# Usage: bin/test/souin-purge-isolation.sh [path-to-frankenphp]
set -eu

BIN="${1:-frankenphp}"
PORT=18080
ADMIN=localhost:12019
DIR=$(mktemp -d)
trap 'kill "$PID" 2>/dev/null || true; rm -rf "$DIR"' EXIT

cat > "$DIR/Caddyfile" <<CADDY
{
	admin $ADMIN
	auto_https off
	cache {
		ttl 1h
		api {
			souin
		}
	}
}

:$PORT {
	route {
		cache
		header Surrogate-Key "{path}"
		header Cache-Control "public, s-maxage=3600"
		respond "{path}"
	}
}
CADDY

"$BIN" run --config "$DIR/Caddyfile" --adapter caddyfile >"$DIR/log" 2>&1 &
PID=$!
i=0
until curl -s -o /dev/null "http://localhost:$PORT/"; do
	i=$((i + 1))
	if [ "$i" -gt 50 ]; then cat "$DIR/log"; echo "FAIL: server did not start"; exit 1; fi
	sleep 0.2
done

API="http://$ADMIN/souin-api/souin"
FAILED=0
fetch() { curl -s -o /dev/null "http://localhost:$PORT$1"; }
purge() { curl -s -o /dev/null -X PURGE -H "Surrogate-Key: $1" "$API"; sleep 0.5; }
indexed() { curl -s "$API/surrogate_keys" | grep -q "\"$1\""; }
status() { curl -s -D - -o /dev/null "http://localhost:$PORT$1" | tr -d '\r' | sed -n 's/^[Cc]ache-[Ss]tatus: //p'; }
fail() { echo "FAIL: $1"; FAILED=1; }

A=/_api/_/component_groups/00000000-0000-0000-0000-00000000000a
B=/_api/_/component_groups/00000000-0000-0000-0000-00000000000b
fetch "$A"; fetch "$B"; sleep 0.5
indexed "$A" || fail "setup: $A was never indexed"

# What API Platform sends when group B is written: the collection and the item.
purge "/_api/_/component_groups, $B"
indexed "$A" || fail "purging $B and its collection removed $A's tag"

purge "$A"
case "$(status "$A")" in
	*hit*) fail "$A is still a cache hit after purging its own tag" ;;
esac

# Routes: one IRI is a prefix of another with no collection involved.
R=/_api/_/routes//2026
RC=/_api/_/routes//2026/2026-programme
fetch "$R"; fetch "$RC"; sleep 0.5
purge "$R"
indexed "$RC" || fail "purging $R removed $RC's tag"

if [ "$FAILED" -ne 0 ]; then exit 1; fi
echo "OK: purges only removed their own tags"
