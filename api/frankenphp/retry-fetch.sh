#!/bin/sh
# Runs a build step that fetches from Debian or Go's module proxy with a hard time limit, up to three times (#176, #213).
# A stalled fetch hung builds until the CI job limit; apt's and Go's own timeouts didn't end it.
# Usage: retry-fetch <seconds> <command> [args...]
limit="$1"
shift
for attempt in 1 2 3; do
	timeout "$limit" "$@" && exit 0
	echo "retry-fetch: attempt ${attempt} failed or passed ${limit}s: $*" >&2
	dpkg --configure -a || true
done
exit 1
