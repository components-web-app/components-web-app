#!/bin/sh
# Runs a build step that fetches from Debian with a hard time limit, up to three times (#176).
# A stalled fetch hung builds until the CI job limit; apt's own timeouts didn't end it.
# Usage: retry-fetch <seconds> <command> [args...]
limit="$1"
shift
for attempt in 1 2 3; do
	timeout "$limit" "$@" && exit 0
	echo "retry-fetch: attempt ${attempt} failed or passed ${limit}s: $*" >&2
	dpkg --configure -a || true
	# The stalls were on plain HTTP to deb.debian.org; retry over HTTPS.
	sed -i 's#http://deb.debian.org#https://deb.debian.org#' /etc/apt/sources.list.d/debian.sources
done
exit 1
