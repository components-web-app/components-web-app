#!/bin/sh
# Regression test (#85): k8s.sh's check_api_scaling allows more than one API pod only in scaled mode, by every route,
# and refuses settings scaled mode can't use. Usage (repository root): bin/test/api-scaling-config.sh [k8s.sh]
set -eu

K8S="${1:-bin/devops/k8s.sh}"
[ -f "$K8S" ] || { echo "No $K8S." >&2; exit 2; }

# GitLab deploys source k8s.sh in busybox ash; it isn't POSIX sh (function delete()), so dash can't.
if command -v busybox >/dev/null 2>&1 && busybox ash -c : 2>/dev/null; then
  K8S_SHELL="busybox ash"
elif command -v bash >/dev/null 2>&1; then
  K8S_SHELL=bash
else
  echo "Needs busybox ash or bash to source $K8S." >&2
  exit 2
fi
echo "Sourcing $K8S with $K8S_SHELL."

# track | settings | expected: ok:<min>-<max>-<redis Mi>, or refused:<part of the message>
CASES='
stable||ok:1-1-256
stable|CWA_CI_API_AUTOSCALE_MAX=2|refused:needs scaled mode: set CWA_CI_API_SCALED_PRODUCTION=true
stable|CWA_CI_API_AUTOSCALE_MIN=2|refused:needs scaled mode
stable|CWA_CI_API_AUTOSCALE=false CWA_CI_API_REPLICA_COUNT=2|refused:needs scaled mode
staging|CWA_CI_API_SCALED_PRODUCTION=true CWA_CI_API_AUTOSCALE_MAX=3|refused:set CWA_CI_API_SCALED_STAGING=true
canary|CWA_CI_API_SCALED_PRODUCTION=true|ok:1-1-256
stable|CWA_CI_API_SCALED_PRODUCTION=TRUE CWA_CI_API_AUTOSCALE_MAX=2|refused:needs scaled mode
stable|CWA_CI_API_SCALED_PRODUCTION=true|ok:2-3-256
staging|CWA_CI_API_SCALED_STAGING=true|ok:2-3-256
canary|CWA_CI_API_SCALED_CANARY=true CWA_CI_API_AUTOSCALE_MIN=1 CWA_CI_API_AUTOSCALE_MAX=2|ok:1-2-256
review|CWA_CI_API_SCALED_REVIEW=true CWA_CI_API_REDIS_MEMORY=512Mi|ok:2-3-512
stable|CWA_CI_API_SCALED_PRODUCTION=true CWA_CI_API_REDIS_MEMORY=1Gi|ok:2-3-1024
stable|CWA_CI_API_SCALED_PRODUCTION=true CWA_CI_API_REDIS_MEMORY=512MB|refused:CWA_CI_API_REDIS_MEMORY
stable|CWA_CI_API_SCALED_PRODUCTION=true CWA_CI_API_AUTOSCALE_MIN=4 CWA_CI_API_AUTOSCALE_MAX=3|refused:no more than its max
stable|CWA_CI_API_SCALED_PRODUCTION=true CWA_CI_API_AUTOSCALE_MIN=0|refused:at least 1
stable|CWA_CI_API_SCALED_PRODUCTION=true CWA_CI_API_AUTOSCALE=false|refused:runs the API under its autoscaler
stable|CWA_CI_API_SCALED_PRODUCTION=true CWA_CI_RESET_DATABASE=true|refused:drop the schema
stable|CWA_CI_API_SCALED_PRODUCTION=true CWA_API_CADDY_CACHE_STORAGE=otter|refused:the store is this release
stable|CWA_API_CADDY_CACHE_STORAGE=redis|refused:use scaled mode
stable|CWA_CI_API_AUTOSCALE_MAX=two|refused:whole numbers
'

# Every name the cases set, cleared first so a project's own CI variables can't leak into a case.
NAMES='CWA_CI_API_SCALED_PRODUCTION CWA_CI_API_SCALED_STAGING CWA_CI_API_SCALED_CANARY CWA_CI_API_SCALED_REVIEW
CWA_CI_API_AUTOSCALE CWA_CI_API_AUTOSCALE_MIN CWA_CI_API_AUTOSCALE_MAX CWA_CI_API_REPLICA_COUNT CWA_CI_API_REDIS_MEMORY
CWA_CI_RESET_DATABASE CWA_API_CADDY_CACHE_STORAGE'

result() {
  $K8S_SHELL -c '
    unset $3
    for setting in $2; do export "$setting"; done
    . "$1" >/dev/null
    err=$(mktemp)
    if check_api_scaling "$4" >/dev/null 2>"$err"; then
      printf "ok:%s-%s-%s" "$API_AUTOSCALE_MIN" "$API_AUTOSCALE_MAX" "$API_REDIS_MEMORY_MIB"
    else
      printf "refused:"; tr "\n" " " <"$err"
    fi
    rm -f "$err"' k8s "$K8S" "$2" "$NAMES" "$1"
}

failures=0
count=0
while IFS='|' read -r track settings expected; do
  [ -n "$track" ] || continue
  count=$((count + 1))
  got=$(result "$track" "$settings")
  case "$expected" in
    ok:*) [ "$got" = "$expected" ] && continue ;;
    refused:*) case "$got" in refused:*"${expected#refused:}"*) continue ;; esac ;;
  esac
  failures=$((failures + 1))
  echo "FAIL: $track [$settings]" >&2
  echo "  expected: $expected" >&2
  echo "  got:      $got" >&2
done <<EOF
$CASES
EOF

if [ "$failures" -ne 0 ]; then
  echo "$failures of $count cases failed." >&2
  exit 1
fi
echo "All $count cases passed."
