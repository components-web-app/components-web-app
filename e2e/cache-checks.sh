#!/bin/sh
# Single-server cache acceptance (#207, from #96). e2e/run.sh runs it in the php container (`sh -s`), after the fixtures.
# Prints one line per check and exits 1 if any failed.
set -eu

base=https://localhost
api=/_api/_/site_config_parameters.jsonld
headers=$(mktemp)
failures=0
pass() { echo "  ok: $*"; }
fail() { echo "  FAILED: $*" >&2; failures=$((failures + 1)); }

# Every page cold, whatever run.sh's wait for the site cached.
php bin/console silverback:api-components:purge-rendered-html --quiet

# A visitor's GET of path $1 (with Accept $2, default text/html): prints the status and keeps the headers.
get() { curl -sk -o /dev/null -D "$headers" -w '%{http_code}' -H "Accept: ${2:-text/html}" "$base$1"; }
header() { tr -d '\r' < "$headers" | sed -n "s/^$1: *//Ip" | head -n 1; }
# The page's cache result: hit, stored or the whole header when it's neither.
cache_result() {
  status=$(get "$@")
  value=$(header cache-status)
  case "$value" in
    *"; hit"*) echo "$status hit" ;;
    *"; stored"*) echo "$status stored" ;;
    *) echo "$status ${value:-no-cache-status}" ;;
  esac
}
expect() { # expect <path> <wanted "status result"> <what> [accept]
  got=$(cache_result "$1" "${4:-}")
  if [ "$got" = "$2" ]; then pass "$3 ($1: $got)"; else fail "$3 ($1: wanted $2, got $got)"; fi
}

# The sitemap's pages, as paths (one level of child sitemaps, as warm_cache reads it).
locs() { curl -skL "$base$1" | grep -o '<loc>[^<]*</loc>' | sed 's#<loc>\(.*\)</loc>#\1#; s#^https://[^/]*##; s#^$#/#'; }
pages=""
for loc in $(locs /sitemap.xml); do
  case "$loc" in
    *.xml) pages="$pages $(locs "$loc" | tr '\n' ' ')" ;;
    *) pages="$pages $loc" ;;
  esac
done
set -- $pages
if [ "$#" -lt 1 ]; then
  echo "The sitemap lists no pages; the checks need at least one." >&2
  exit 1
fi
page_a=$1
page_b=${2:-}
echo "Cache checks on $# sitemap pages."

echo "The API answers through php, and SSR's plain-HTTP route isn't redirected (#98):"
[ "$(get "$api" application/ld+json)" = 200 ] && pass "$api over HTTPS" || fail "$api over HTTPS"
ssr=$(curl -s -o /dev/null -w '%{http_code}' -H 'Accept: application/ld+json' "http://php.local$api")
[ "$ssr" = 200 ] && pass "http://php.local$api" || fail "http://php.local$api answered $ssr"

echo "Every sitemap page is a 200, stored on the first view and a hit on the second (the deploy's warm):"
for page in "$@"; do expect "$page" "200 stored" "first view"; done
for page in "$@"; do expect "$page" "200 hit" "second view"; done

echo "Purging one resource's tag drops only the pages that rendered it (what a write purges):"
# A one-page site has nothing to compare with: only the purge of every page below applies (#177).
if [ -z "$page_b" ]; then
  echo "  skipped: the sitemap lists one page"
else
get "$page_a" >/dev/null
keys_a=$(header surrogate-key | tr ',' '\n' | sed 's/^ *//; s/ *$//')
get "$page_b" >/dev/null
keys_b=$(header surrogate-key | tr ',' '\n' | sed 's/^ *//; s/ *$//')
# A component's IRI if page A has one of its own, else any key of A's that B lacks.
tag=""
for key in $(printf '%s\n' "$keys_a" | grep '^/_api/component/') $keys_a; do
  [ "$key" = cwa-html ] && continue
  printf '%s\n' "$keys_b" | grep -qxF "$key" || { tag=$key; break; }
done
if [ -z "$tag" ]; then
  fail "no Surrogate-Key on $page_a that $page_b doesn't also have"
else
  php bin/console silverback:api-components:purge-http-cache --tag="$tag" --quiet
  expect "$page_a" "200 stored" "purged page renders again ($tag)"
  expect "$page_b" "200 hit" "the other page stays cached"
fi
fi

echo "purge-rendered-html drops every page (cwa-html) and leaves the API cached:"
get "$api" application/ld+json >/dev/null
expect "$api" "200 hit" "API cached" application/ld+json
php bin/console silverback:api-components:purge-rendered-html --quiet
for page in "$@"; do expect "$page" "200 stored" "after purge-rendered-html"; done
expect "$api" "200 hit" "API still cached" application/ld+json

rm -f "$headers"
if [ "$failures" -gt 0 ]; then
  echo "$failures cache check(s) failed." >&2
  exit 1
fi
echo "All cache checks passed."
