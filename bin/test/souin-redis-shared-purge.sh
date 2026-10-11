#!/bin/sh
# Regression test (#85): two Souin instances sharing one Redis must purge every page under a shared tag. No php or database needed.
# Usage: REDIS_ADDR=host:port bin/test/souin-redis-shared-purge.sh [path-to-frankenphp]
set -eu

BIN="${1:-frankenphp}"
REDIS_ADDR="${REDIS_ADDR:-redis:6379}"
PAGES="${PAGES:-200}"
ROUNDS="${ROUNDS:-3}"
HOST=shared.test
DIR=$(mktemp -d)
PIDS=
trap 'for p in $PIDS; do kill "$p" 2>/dev/null || true; done; rm -rf "$DIR"' EXIT

FAILED=0
fail() { echo "FAIL: $1"; FAILED=1; }

# Pod A on 18091 (admin 12031), pod B on 18092 (admin 12032).
for pod in 1 2; do
	cat > "$DIR/Caddyfile$pod" <<CADDY
{
	admin localhost:1203$pod
	auto_https off
	cache {
		ttl 1h
		api {
			souin
		}
		redis {
			configuration {
				Addrs $REDIS_ADDR
			}
		}
	}
}

:1809$pod {
	route {
		cache
		header Surrogate-Key "cwa-html, {path}"
		header Cache-Control "public, s-maxage=3600"
		respond "{path}"
	}
}
CADDY
	"$BIN" run --config "$DIR/Caddyfile$pod" --adapter caddyfile >"$DIR/log$pod" 2>&1 &
	PIDS="$PIDS $!"
	i=0
	until curl -s -o /dev/null "http://localhost:1809$pod/__up"; do
		i=$((i + 1))
		if [ "$i" -gt 50 ]; then cat "$DIR/log$pod"; echo "FAIL: pod $pod did not start"; exit 1; fi
		sleep 0.2
	done
done

# urls <port> <parity>: a curl config for every page (parity "all"), or the odd or even ones.
urls() {
	n=1
	while [ "$n" -le "$PAGES" ]; do
		case "$2:$((n % 2))" in
			all:* | odd:1 | even:0) printf 'url = "http://localhost:%s/page-%s"\noutput = "/dev/null"\n' "$1" "$n" ;;
		esac
		n=$((n + 1))
	done
}
# fetch <port> <parity> [curl args]: the pages in parallel, with the Host both pods share (it's in the cache key).
fetch() { port=$1 parity=$2; shift 2; urls "$port" "$parity" | curl -s -Z --parallel-max 50 -H "Host: $HOST" -K - "$@"; }
# statuses <port>: the Cache-Status of every page on that pod, one per line.
statuses() { fetch "$1" all -w '%header{cache-status}\n'; }

round=1
while [ "$round" -le "$ROUNDS" ]; do
	curl -s -o /dev/null -X PURGE "http://localhost:12031/souin-api/souin/flush"; sleep 0.5

	# First requests on both pods at once: each store adds its key to the shared cwa-html set.
	fetch 18091 odd &
	a=$!
	fetch 18092 even &
	b=$!
	wait "$a" "$b"
	sleep 1

	# Pod B must hit what pod A stored, from Redis, not a per-process fallback.
	cross=$(curl -s -D - -o /dev/null -H "Host: $HOST" "http://localhost:18092/page-1" | tr -d '\r' | sed -n 's/^[Cc]ache-[Ss]tatus: //p')
	case "$cross" in
		*hit*detail=REDIS*|*detail=REDIS*hit*) ;;
		*) cat "$DIR/log1"; echo "FAIL: round $round: pod B didn't hit pod A's page in Redis ($cross); is Redis at $REDIS_ADDR?"; exit 1 ;;
	esac
	cached=$(statuses 18091 | grep -c hit || true)
	if [ "$cached" -ne "$PAGES" ]; then fail "round $round: setup: $cached of $PAGES pages cached"; fi

	# Purge the shared tag through pod A only.
	curl -s -o /dev/null -X PURGE -H 'Surrogate-Key: cwa-html' "http://localhost:12031/souin-api/souin"; sleep 1

	left=$(statuses 18092 | grep -c hit || true)
	if [ "$left" -ne 0 ]; then
		fail "round $round: $left of $PAGES pages still cached after purging their shared tag"
	else
		echo "ok:   round $round: $PAGES pages stored by two pods, all purged"
	fi
	round=$((round + 1))
done

if [ "$FAILED" -ne 0 ]; then exit 1; fi
echo "OK: concurrent stores on two pods keep every page under its shared tag"
