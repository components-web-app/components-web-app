#!/bin/sh
# Functions for the bin/server scripts (#212). Sourced from the repository root.

. ./bin/lib/site.sh

ENV_FILE=${CWA_SERVER_ENV_FILE:-.env.prod}

# docker compose with the site's settings (COMPOSE_FILE in it picks compose.yaml + compose.prod.yaml).
c() { docker compose --env-file "$ENV_FILE" "$@"; }

require_env_file() {
  [ -f "$ENV_FILE" ] || { echo "No $ENV_FILE: run bin/server/init first." >&2; exit 1; }
}

# One value from the env file, read the way sh reads it (init writes it sh-compatible).
env_value() { (set -a; case "$ENV_FILE" in /*) . "$ENV_FILE" ;; *) . "./$ENV_FILE" ;; esac; eval "printf '%s' \"\${$1:-}\""); }

# The two /_api warms a Kubernetes pod runs before it's ready (#160, #170), at SSR's key (plain HTTP to php.local).
warm_api() {
  local max_time="${CWA_SERVER_WARM_HTTP_CACHE_MAX_TIME:-60}"
  [ "$max_time" != "0" ] || return 0
  echo "➡️ Warming /_api (gzip, then br, at most ${max_time}s each)..."
  c exec -T php bin/console silverback:api-components:warm-http-cache --base-url=http://php.local --max-time="$max_time" --no-interaction \
    || echo "WARNING: the gzip /_api warm failed; first requests render cold." >&2
  c exec -T php bin/console silverback:api-components:warm-http-cache --base-url=http://php.local --accept-encoding=br --max-time="$max_time" --no-interaction \
    || echo "WARNING: the br /_api warm failed; first requests render cold." >&2
}

# Every missing image variant, in one-off containers capped at CWA_SERVER_IMAGE_VARIANTS_MEMORY (1536m), never in the
# serving php: vips allocates outside memory_limit (#153). Exit 3 (stopped at --max-memory) runs another, up to 50.
generate_image_variants() {
  local runs=0 total=0 status=0 name out generated
  out=$(mktemp)
  echo "➡️ Generating missing image variants..."
  while :; do
    runs=$((runs + 1))
    name="cwa-image-variants-$$-$runs"
    c run -d --name "$name" --no-deps -e SKIP_MIGRATIONS=true php \
      bin/console silverback:api-components:imagine:generate -v --max-memory="${CWA_SERVER_IMAGE_VARIANTS_MAX_MEMORY:-1G}" >/dev/null
    # The cap lands while the kernel boots, before any image is decoded.
    docker update --memory "${CWA_SERVER_IMAGE_VARIANTS_MEMORY:-1536m}" --memory-swap "${CWA_SERVER_IMAGE_VARIANTS_MEMORY:-1536m}" "$name" >/dev/null
    status=$(docker wait "$name")
    docker logs "$name" > "$out" 2>&1 || true
    docker rm "$name" >/dev/null 2>&1 || true
    grep -v '^  stored: ' "$out" || true
    generated=$(sed -n 's/^Generated: \([0-9][0-9]*\)$/\1/p' "$out")
    total=$((total + ${generated:-0}))
    [ "$status" -eq 3 ] && [ "$runs" -lt "${CWA_SERVER_IMAGE_VARIANTS_MAX_RUNS:-50}" ] || break
  done
  rm -f "$out"
  echo "Generated $total image variants in $runs run(s)."
  if [ "$total" -gt 0 ]; then
    echo "➡️ Purging the HTTP cache, so cached API responses list the new variants..."
    c exec -T php bin/console silverback:api-components:purge-http-cache
    warm_api
  fi
  case "$status" in
    0) ;;
    3) echo "WARNING: image variants still missing after $runs runs; the next deploy continues." >&2; return 0 ;;
    137) echo "Image variants ran out of memory (exit 137): raise CWA_SERVER_IMAGE_VARIANTS_MEMORY or lower CWA_SERVER_IMAGE_VARIANTS_MAX_MEMORY." >&2 ;;
    *) echo "imagine:generate exited $status (1: a variant failed, listed above)." >&2 ;;
  esac
  return "$status"
}
