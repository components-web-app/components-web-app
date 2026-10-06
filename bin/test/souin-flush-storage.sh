#!/bin/sh
# Regression test: a full flush must empty every storage the image builds and
# leave it usable. Souin v1.7.9's flush called the surrogate storage's Destruct,
# whose Reset closes Badger and Nuts (Redis, etcd and Olric too), so nothing was
# cached again until php restarted (BADGER-INSERTION-ERROR). api/Dockerfile
# carries a patch.
# https://github.com/components-web-app/components-web-app/issues/114
#
# Runs the frankenphp binary on a throwaway Caddyfile per storage: a cache in
# front of a stub, so no php or database is needed.
# Usage: bin/test/souin-flush-storage.sh [path-to-frankenphp]
set -eu

BIN="${1:-frankenphp}"
PORT=18081
ADMIN=localhost:12020
DIR=$(mktemp -d)
PID=
trap 'kill "$PID" 2>/dev/null || true; rm -rf "$DIR"' EXIT

API="http://$ADMIN/souin-api/souin"
FAILED=0
status() { curl -s -D - -o /dev/null "http://localhost:$PORT$1" | tr -d '\r' | sed -n 's/^[Cc]ache-[Ss]tatus: //p'; }
fail() { echo "FAIL: $1"; FAILED=1; }

for storage in otter badger nuts; do
	case "$storage" in
		otter) config=otter ;;
		*) config="$storage {
			path $DIR/$storage
		}" ;;
	esac
	cat > "$DIR/Caddyfile" <<CADDY
{
	admin $ADMIN
	auto_https off
	cache {
		ttl 1h
		api {
			souin
		}
		$config
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
		if [ "$i" -gt 50 ]; then cat "$DIR/log"; echo "FAIL: $storage: server did not start"; exit 1; fi
		sleep 0.2
	done

	status /before >/dev/null; sleep 0.5
	case "$(status /before)" in
		*hit*) ;;
		*) fail "$storage: setup: /before was never cached" ;;
	esac

	curl -s -o /dev/null -X PURGE "$API/flush"; sleep 0.5

	case "$(status /before)" in
		*hit*) fail "$storage: /before is still a hit after the flush" ;;
	esac
	after=$(status /after); sleep 0.5
	case "$after" in
		*ERROR*) fail "$storage: storing after the flush failed: $after" ;;
	esac
	case "$(status /after)" in
		*hit*) echo "ok:   $storage" ;;
		*) fail "$storage: nothing is cached after the flush ($after)" ;;
	esac

	kill "$PID"; wait "$PID" 2>/dev/null || true
done

if [ "$FAILED" -ne 0 ]; then exit 1; fi
echo "OK: a full flush empties every storage and leaves it usable"
