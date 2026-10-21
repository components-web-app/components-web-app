#!/bin/sh
# Regression test (#85): a scaled deploy's purge_rendered_html raises the API autoscaler's minimum by
# CWA_CI_API_WARM_SURGE, flushes, warms through the API service, puts the minimum back, then checks the cache is a Redis
# hit and only warns if not (#193); a single-pod deploy
# warms in its pod as before. Commands run in a ready pod, never `deploy/…`, which can pick a terminating one. Runs k8s.sh against a stub kubectl. Usage (repository root): bin/test/api-warm-surge.sh [k8s.sh]
set -eu

K8S="${1:-bin/devops/k8s.sh}"
[ -f "$K8S" ] || { echo "No $K8S." >&2; exit 2; }
if command -v busybox >/dev/null 2>&1 && busybox ash -c : 2>/dev/null; then
  K8S_SHELL="busybox ash"
elif command -v bash >/dev/null 2>&1; then
  K8S_SHELL=bash
else
  echo "Needs busybox ash or bash to source $K8S." >&2
  exit 2
fi
echo "Sourcing $K8S with $K8S_SHELL."

DIR=$(mktemp -d)
trap 'rm -rf "$DIR"' EXIT
mkdir "$DIR/bin"
# Records every call; answers the lookups purge_rendered_html makes. The API reports 4 ready pods.
cat >"$DIR/bin/kubectl" <<'STUB'
#!/bin/sh
echo "kubectl $*" >>"$STUB_LOG"
case "$*" in
  *"get deploy"*"name=cwa-pwa,"*) echo "deployment.apps/rel-cwa-pwa" ;;
  *"get deploy"*"name=cwa,"*) echo "deployment.apps/rel-cwa" ;;
  *"get deployment.apps/rel-cwa"*readyReplicas*) echo 4 ;;
  *"get pods"*"{{if .metadata.deletionTimestamp}}"*) ;;
  *"get pods"*"name=cwa,"*) echo "pod/rel-cwa-new" ;;
  *"exec"*" curl "*) printf 'HTTP/1.1 200 OK\r\nCache-Status: %s\r\n\r\n' "$STUB_CACHE_STATUS" ;;
  *"app:edge-cache:purge-everything"*) [ -z "${STUB_EDGE_FAIL:-}" ] || exit 1 ;;
esac
exit 0
STUB
chmod +x "$DIR/bin/kubectl"

# $2: the Cache-Status the stub's curl answers with (#193); default a Redis hit.
run() {
  : >"$DIR/log"
  status=0
  PATH="$DIR/bin:$PATH" STUB_LOG="$DIR/log" RELEASE=rel KUBE_NAMESPACE=ns \
    STUB_CACHE_STATUS="${2:-Souin; hit; ttl=99; key=GET-http-rel-cwa-/_api/_/site_config_parameters.jsonld; detail=REDIS}" $K8S_SHELL -c '
    unset CWA_CI_API_SCALED_PRODUCTION CWA_CI_API_AUTOSCALE_MIN CWA_CI_API_AUTOSCALE_MAX CWA_CI_API_WARM_SURGE \
      CWA_CI_API_WARM_CONCURRENCY CWA_CI_API_WARM_HTTP_CACHE_MAX_TIME CADDY_CACHE_CDN_CONFIG GITHUB_ACTIONS
    for setting in $2; do export "$setting"; done
    [ -z "${CDN_CLOUDFLARE:-}" ] || export CADDY_CACHE_CDN_CONFIG="provider cloudflare"
    . "$1" >/dev/null
    purge_rendered_html stable' k8s "$K8S" "$1" >"$DIR/out" 2>&1 || status=$?
}
said() {
  if ! grep -qF -- "$2" "$DIR/out"; then
    failures=$((failures + 1))
    echo "FAIL ($1): the output doesn't say: $2" >&2
  fi
}
quiet() {
  if grep -qF -- "$2" "$DIR/out"; then
    failures=$((failures + 1))
    echo "FAIL ($1): the output says: $2" >&2
  fi
}
succeeded() {
  if [ "$status" -ne 0 ]; then
    failures=$((failures + 1))
    echo "FAIL ($1): purge_rendered_html exited $status" >&2
  fi
}

failures=0
expect() {
  if ! grep -qF -- "$2" "$DIR/log"; then
    failures=$((failures + 1))
    echo "FAIL ($1): no call containing: $2" >&2
  fi
}
refuse() {
  if grep -qF -- "$2" "$DIR/log"; then
    failures=$((failures + 1))
    echo "FAIL ($1): unexpected call containing: $2" >&2
  fi
}
order() {
  first=$(grep -nF -- "$2" "$DIR/log" | head -1 | cut -d: -f1)
  second=$(grep -nF -- "$3" "$DIR/log" | head -1 | cut -d: -f1)
  if [ -z "$first" ] || [ -z "$second" ] || [ "$first" -ge "$second" ]; then
    failures=$((failures + 1))
    echo "FAIL ($1): '$2' must come before '$3'" >&2
  fi
}

run "CWA_CI_API_SCALED_PRODUCTION=true CWA_CI_API_WARM_SURGE=2"
expect surge '"minReplicas":4,"maxReplicas":4'
expect surge '"minReplicas":2,"maxReplicas":3'
expect surge 'purge-http-cache'
expect surge 'exec -n ns pod/rel-cwa-new -- php bin/console silverback:api-components:purge-http-cache'
refuse surge 'exec -n ns deployment.apps/rel-cwa '
expect surge '--base-url=http://rel-cwa --concurrency=8'
expect surge '--base-url=http://rel-cwa --concurrency=8 --requests-per-connection=1'
order surge '"minReplicas":4' 'purge-http-cache'
order surge 'deletionTimestamp' 'purge-http-cache'
order surge 'purge-http-cache' '--base-url=http://rel-cwa'
order surge '--accept-encoding=br' '"minReplicas":2'
# The post-rollout check (#193): after the warm and the surge's end, through the API service from a ready pod.
expect surge 'exec -n ns pod/rel-cwa-new -- curl -sS -o /dev/null -D - --max-time 10 -H Accept-Encoding: gzip http://rel-cwa/_api/_/site_config_parameters.jsonld'
order surge '"minReplicas":2' ' curl '
said surge 'the API cache is shared in Redis'
quiet surge 'NOT SHARED'
succeeded surge

# Not a Redis hit (each pod's own store, or Redis down): loud, but the live deploy's job carries on (#193).
run "CWA_CI_API_SCALED_PRODUCTION=true" "Souin; fwd=uri-miss; stored; key=GET-x; detail=OTTER"
said not-shared 'SCALED MODE: THE API CACHE IS NOT SHARED IN REDIS'
said not-shared "last Cache-Status: 'Souin; fwd=uri-miss; stored; key=GET-x; detail=OTTER'"
succeeded not-shared
if [ "$(grep -c ' curl ' "$DIR/log")" -ne 3 ]; then
  failures=$((failures + 1))
  echo "FAIL (not-shared): expected 3 requests, got $(grep -c ' curl ' "$DIR/log")" >&2
fi

run "CWA_CI_API_SCALED_PRODUCTION=true GITHUB_ACTIONS=true" "Souin; hit; ttl=9; key=GET-x; detail=DEFAULT"
said not-shared-github '::error title=API cache not shared::'
succeeded not-shared-github

run "CWA_CI_API_SCALED_PRODUCTION=true CWA_CI_API_AUTOSCALE_MAX=6 CWA_CI_API_WARM_SURGE=2"
expect surge-under-max '"minReplicas":4,"maxReplicas":6'
expect surge-under-max '"minReplicas":2,"maxReplicas":6'

run "CWA_CI_API_SCALED_PRODUCTION=true"
expect scaled 'purge-http-cache'
expect scaled '--base-url=http://rel-cwa --concurrency=4'
refuse scaled 'patch hpa'

# Per pod (#195): 2 pods x 3, and with the surge (2 + 2 pods) x 3.
run "CWA_CI_API_SCALED_PRODUCTION=true CWA_CI_API_WARM_CONCURRENCY=3"
expect concurrency '--base-url=http://rel-cwa --concurrency=6'

run "CWA_CI_API_SCALED_PRODUCTION=true CWA_CI_API_WARM_SURGE=2 CWA_CI_API_WARM_CONCURRENCY=3"
expect surge-concurrency '--base-url=http://rel-cwa --concurrency=12'

run ""
expect single 'purge-rendered-html'
expect single 'exec -n ns pod/rel-cwa-new -- php bin/console silverback:api-components:purge-rendered-html'
refuse single 'purge-http-cache'
refuse single 'patch hpa'
refuse single 'requests-per-connection'
refuse single ' curl '

# Per-track warm time (#217): production and canary fall back to the shared setting, staging and review to 0.
warm_time() { # warm_time <track> <want> [settings...]
  track=$1 want=$2; shift 2
  got=$(env -u CWA_CI_API_WARM_HTTP_CACHE_MAX_TIME "$@" $K8S_SHELL -c '. "$1" >/dev/null; api_warm_max_time "$2"' k8s "$K8S" "$track")
  [ "$got" = "$want" ] || { failures=$((failures + 1)); echo "FAIL (warm time $track $*): wanted $want, got $got" >&2; }
}
warm_time stable 60
warm_time canary 60
warm_time staging 0
warm_time review 0
warm_time stable 150 CWA_CI_API_WARM_HTTP_CACHE_MAX_TIME=150
warm_time staging 0 CWA_CI_API_WARM_HTTP_CACHE_MAX_TIME=150
warm_time staging 30 CWA_CI_API_WARM_HTTP_CACHE_MAX_TIME_STAGING=30
warm_time stable 0 CWA_CI_API_WARM_HTTP_CACHE_MAX_TIME=150 CWA_CI_API_WARM_HTTP_CACHE_MAX_TIME_PRODUCTION=0
warm_time canary 90 CWA_CI_API_WARM_HTTP_CACHE_MAX_TIME_CANARY=90

# One pod with Cloudflare (#218): rendered HTML locally, then the edge only; the pod keeps its postStart warm.
run "CDN_CLOUDFLARE=1"
expect cloudflare-single 'exec -n ns pod/rel-cwa-new -- php bin/console silverback:api-components:purge-rendered-html'
expect cloudflare-single 'exec -n ns pod/rel-cwa-new -- php bin/console app:edge-cache:purge-everything'
refuse cloudflare-single 'purge-http-cache'
refuse cloudflare-single 'warm-http-cache'
said cloudflare-single "the new pod warms /_api before it's ready"
# The edge purge failing falls back to the full flush (which purges Cloudflare through Souin) and the warm.
run "CDN_CLOUDFLARE=1 STUB_EDGE_FAIL=1"
expect cloudflare-fallback 'purge-http-cache'
expect cloudflare-fallback 'warm-http-cache'
said cloudflare-fallback "The edge-only purge failed"

if [ "$failures" -ne 0 ]; then
  echo "$failures checks failed." >&2
  exit 1
fi
echo "All checks passed."
