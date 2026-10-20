#!/bin/sh
# Regression test (#85): a scaled deploy's purge_rendered_html raises the API autoscaler's minimum by
# CWA_CI_API_WARM_SURGE, flushes, warms through the API service, then puts the minimum back; a single-pod deploy
# warms in its pod as before. Runs k8s.sh against a stub kubectl. Usage (repository root): bin/test/api-warm-surge.sh [k8s.sh]
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
esac
exit 0
STUB
chmod +x "$DIR/bin/kubectl"

run() {
  : >"$DIR/log"
  PATH="$DIR/bin:$PATH" STUB_LOG="$DIR/log" RELEASE=rel KUBE_NAMESPACE=ns $K8S_SHELL -c '
    unset CWA_CI_API_SCALED_PRODUCTION CWA_CI_API_AUTOSCALE_MIN CWA_CI_API_AUTOSCALE_MAX CWA_CI_API_WARM_SURGE \
      CWA_CI_API_WARM_CONCURRENCY CWA_CI_API_WARM_HTTP_CACHE_MAX_TIME CADDY_CACHE_CDN_CONFIG
    for setting in $2; do export "$setting"; done
    . "$1" >/dev/null
    purge_rendered_html stable >/dev/null 2>&1' k8s "$K8S" "$1"
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
expect surge '"minReplicas":4'
expect surge '"minReplicas":2'
expect surge 'purge-http-cache'
expect surge '--base-url=http://rel-cwa --concurrency=8'
order surge '"minReplicas":4' 'purge-http-cache'
order surge 'purge-http-cache' '--base-url=http://rel-cwa'
order surge '--accept-encoding=br' '"minReplicas":2'

run "CWA_CI_API_SCALED_PRODUCTION=true"
expect scaled 'purge-http-cache'
expect scaled '--base-url=http://rel-cwa --concurrency=4'
refuse scaled 'patch hpa'

run "CWA_CI_API_SCALED_PRODUCTION=true CWA_CI_API_WARM_CONCURRENCY=3"
expect concurrency '--base-url=http://rel-cwa --concurrency=3'

run ""
expect single 'purge-rendered-html'
refuse single 'purge-http-cache'
refuse single 'patch hpa'

if [ "$failures" -ne 0 ]; then
  echo "$failures checks failed." >&2
  exit 1
fi
echo "All checks passed."
